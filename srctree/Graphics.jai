#import "Common";
#import "Mesh";


Draw_Args :: struct
{
	exit: *int;
	plt : *Platform;
	c   : *Context;

	output : *Output;
};


Output :: struct
{
	command_buffer_writer : Async_Buffer_End(Draw_Buffer, .WRITER);
};

command_buffer : Async_Buffer(Draw_Buffer);


draw :: (args :*Draw_Args) #c_call
{
	Profiler.NameThread(#procedure_name());
	plt : *Platform = args.plt;

	draw_context := Context.{};
	draw_context.STARTUP_TIME = args.plt.STARTUP_TIME;
	draw_context.logger = draw_logger;
	push_context,defer_pop draw_context;
	output : Output;

	command_reader, command_writer := get_Ends(*command_buffer);

	output.command_buffer_writer = command_writer;
	atomic_volatile_write(*args.output, *output);

	material_1 := Material.{};
	material_1.color = .{0,1,0,0};

	m1 := array_add(*loaded_meshes);
	m1.material = .{.{1,0,0, 0}};
	m1.vertices = .[
		.{-1,0,-1},
		.{1,0,-1},
		.{0,1,-1},
		//.{0,0,0}
	];
	m1.triangles = .[
		.{0,1,2},
		//.{0,3,1}
	];
	m1.aabb = generate_AABB_Of_Mesh(m1);

	m2 := array_add(*loaded_meshes);
	m2.material = .{.{0,1,0, 0}};;
	m2.vertices = .[
		.{-1, 0,-1},
		.{ 1, 0,-1},
		.{-1, 0,-10},
		.{ 1, 0,-10},
	];
	m2.triangles = .[
		.{0,1,2},
		.{1,3,2}
	];
	m2.aabb = generate_AABB_Of_Mesh(m2);

	floor_tile := array_add(*loaded_meshes);
	floor_tile.material = .{.{0.2,.2,.2,1}};
	floor_tile.vertices = .[
		.{0,1,1},
		.{1,1,1},
		.{0,0,1},
		.{1,0,1},
	];
	floor_tile.triangles = .[
		.{0,3,1},
		.{0,2,3}
	];

	height_map_res :: int2.{30, 30};
	height_map_dims :: float3.{10, .7, 10};
	height_map := array_add(*loaded_meshes);
	height_map.material.color = .{.2,.5,.5,1};
	height_map.vertices = NewArray(height_map_res.x * height_map_res.y, float3);
	height_map.aabb = generate_AABB_Of_Mesh(height_map);
	for h: 0..height_map_res.y-1
	{
		for w: 0..height_map_res.x-1
		{
			w_sample := cast(float)w/(height_map_res.x - 1);
			h_sample := cast(float)h/(height_map_res.y - 1);
			v := *height_map.vertices[h * height_map_res.x + w];
			v.x = w_sample * height_map_dims.x - height_map_dims.x/2;
			v.z = h_sample * height_map_dims.z - height_map_dims.z/2;
			v.y = cast(float)(sin(w_sample * 2 * PI)) * height_map_dims.y;
		}
	}
	height_map.triangles = NewArray((height_map_res.x - 1) * 2 * (height_map_res.y - 1), int3);
	idx := 0;
	for h: 0..height_map_res.y-2
	{
		for w: 0..height_map_res.x-2
		{
			v1 := h * height_map_res.x + w;
			v2 := h * height_map_res.x + (w + 1);
			v3 := (h + 1) * height_map_res.x + w;
			v4 := (h + 1) * height_map_res.x + (w + 1);
			height_map.triangles[idx + 0] = .{v1,v3, v2}; 
			height_map.triangles[idx + 1] = .{v2,v3, v4}; 
			idx += 2;
		}
	}
	log("% vertices, % triangles in heightmap", height_map.vertices.count, height_map.triangles.count);


	while atomic_volatile_read(args.exit) == 0
	{
		Profiler.TimeZone();
		buffer : *Draw_Buffer = get_Read_Pointer(command_reader);
		render_Triangles_In_Draw_Buffer(plt, buffer);

		
		plt.update_Window(plt.window);
	}

	atomic_volatile_write(args.exit, 0);

}


add_Mesh :: (buffer : *Draw_Buffer, instance : Model_Instance)
{
	using buffer;
	if n_instances < instances.count
	{
		instances[n_instances] = instance;
		n_instances += 1;
	}else{
		log_error("Too many meshes got queued!");
	}
}


clear_Instances :: (draw_buffer : *Draw_Buffer)
{
	draw_buffer.n_instances = 0;
}

Model_Instance :: struct
{
	id : int;
	model_to_world : float4x4;
};

#scope_file


draw_logger :: (message : string, data : *void, info : Log_Info)
{
	now := current_time_monotonic() - context.STARTUP_TIME;
	print("[RENDER]+%: %\n", to_milliseconds(now), message);
}




Shader_Input :: struct
{
	uv : float2;
	depth : float;
	material    : Material;
};

Shader_Output :: struct
{
	color : Color;
};


Draw_Buffer :: struct
{
	submission_time : Apollo_Time;

	
	n_instances : int;
	instances  : [600] Model_Instance;

	camera : Camera;
};



loaded_meshes : [..] Mesh;



screen2 :: Vector(2, s32 /*fixed_point 26.6*/);


depth_buffer : [] float;
shader_buffer : [] Shader_Input;
vertices_screen_space : [..] screen2;
depth_screen_space    : [..] float;

material_sequence : [..] struct {end_vertex : int; material: Material;};


// Optimization Records, in CSV format
/*
Optimization,  Samples, Mean(ms), Sigma(us)
NONE,          8674,    3.89,     600.45

*/
//
//
render_Triangles_In_Draw_Buffer :: (plt : *Platform, draw_buffer : *Draw_Buffer)
{
	Profiler.TimeZone(#procedure_name());
	LOG_CLIPPING :: false;
	LOG_CULLING  :: false;

	FIXEDPOINT_BITS :: 4;
	FIXEDPOINT_MASK :: (1<<FIXEDPOINT_BITS)-1;
	FIXEDPOINT_ONE  ::  1<<FIXEDPOINT_BITS;

	start := current_time_monotonic();
	defer
	{
		end := current_time_monotonic();
		//log("rendertime %ms", to_milliseconds(end-start));
	}
	
	bb := plt.get_BackBuffer(plt.window);
	aspect : float = bb.size.x/cast(float)bb.size.y;

	//
	// Reset Buffers Depth, Shader, Pixel
	//
	{
		Profiler.TimeZone("Reset Buffers");
		n_elements := bb.size.y * bb.stride;
		if depth_buffer.count != n_elements
		{
			array_free(depth_buffer);
			array_free(shader_buffer);
			depth\_buffer = NewArray(n_elements, float);
			shader_buffer = NewArray(n_elements, Shader_Input);
		}


		memset(bb.data, 0, size_of(Pixel) * n_elements);
		for 0..n_elements-1
		{
			depth_buffer[it] = 1;
		}
	}


	camera := *draw_buffer.camera;
	world_to_camera := world_To_Camera(camera);
	projection := projection_Matrix(fov = camera.fov, aspect = aspect, near = camera.near, far = camera.far);

	Active_Instance :: struct
	{
		instance_to_projection : float4x4;
		mesh_ptr : * Mesh;
	}
	
	active_meshes : [..] Active_Instance;
	defer array_reset(*active_meshes);
	array_reserve(*active_meshes, 100);

	outcode :: (v : float3) -> u8
	{
		res : u8;
		// -z +z -y +y -x +x
		res += ((cast(u8) (v.x >  1)) & 1) << 0;
		res += ((cast(u8) (v.x < -1)) & 1) << 1;
		res += ((cast(u8) (v.y >  1)) & 1) << 2;
		res += ((cast(u8) (v.y < -1)) & 1) << 3;
		res += ((cast(u8) (v.z >  1)) & 1) << 4;
		res += ((cast(u8) (v.z < -1)) & 1) << 5;
		
		return res;
	}
	
	{
		Profiler.TimeZone("AABB Culling");
		for 0..draw_buffer.n_instances-1
		{
			instance := *draw_buffer.instances[it];
			mesh     := *loaded_meshes[instance.id];
			corners_mesh  :=  aabb_To_Corners(mesh.aabb);
			instance_to_projection := projection * world_to_camera * instance.model_to_world;
			n_outside := 0;

			for corners_mesh
			{
				proj := project_Point(instance_to_projection, it);
				if outcode(proj.xyz) != 0
				{
					n_outside += 1;
				}
			}
			if n_outside != 8 || true
			{
				active := array_add(*active_meshes);
				active.instance_to_projection = instance_to_projection;
				active.mesh_ptr = mesh;
			}else{
				#if LOG_CULLING log("Culled instance %", it);
			}
		}
		Profiler.Plot("Active Instances", active_meshes.count);
		//log("% Active Instances", active_meshes.count);
	}


	n_vertices := 0;
	for active_meshes
	{
		n_vertices += it.mesh_ptr.triangles.count * 3;
	}
	n_triangles := n_vertices/3;
	//log("Vertex Buffer Size = %", n_vertices);
	if n_vertices   > vertices_screen_space.count  array_resize(*vertices_screen_space, n_vertices);
	if n_vertices   > depth_screen_space   .count  array_resize(*depth_screen_space,    n_vertices);
	

	

	det_2d :: (a :screen2, b: screen2, p : screen2) -> type_of(screen2.x)
	{
		return ((b.x-a.x)*(p.y-a.y) - (b.y-a.y)*(p.x-a.x)) >>FIXEDPOINT_BITS;
	}

	//
	//  Translate all vertices and fill the material sequence
	//
	{
		Profiler.TimeZone("Translate");
		material_sequence.count = 0;
		factor_x := cast(type_of(screen2.x))FIXEDPOINT_ONE * bb.size.x;
		factor_y := cast(type_of(screen2.x))FIXEDPOINT_ONE * bb.size.y;
		vertex_base := 0;
		for active_meshes
		{
			idx := vertex_base;
			for triangle, triangle_idx : it.mesh_ptr.triangles
			{
				
				a := project_Point(it.instance_to_projection, it.mesh_ptr.vertices[triangle.x]).xyz;
				b := project_Point(it.instance_to_projection, it.mesh_ptr.vertices[triangle.y]).xyz;
				c := project_Point(it.instance_to_projection, it.mesh_ptr.vertices[triangle.z]).xyz;
				a_out := outcode(a);
				b_out := outcode(b);
				c_out := outcode(c);

				if a_out != 0 || b_out != 0 || c_out != 0 
				{
					#if LOG_CLIPPING log("Clipping Triangle %:% [% % %]", it_index, triangle_idx, a_out, b_out, c_out);
					continue triangle;
				}

				// TODO(Qwendo): Clipping
			

				half :: screen2.{FIXEDPOINT_ONE/2, FIXEDPOINT_ONE/2};
				a_s := screen2.{cast(type_of(screen2.x)) (a.x * factor_x), cast(type_of(screen2.x)) (a.y * factor_y)};
				b_s := screen2.{cast(type_of(screen2.x)) (b.x * factor_x), cast(type_of(screen2.x)) (b.y * factor_y)};
				c_s := screen2.{cast(type_of(screen2.x)) (c.x * factor_x), cast(type_of(screen2.x)) (c.y * factor_y)};

				if det_2d(a_s, b_s, c_s) == 0  continue triangle; // dont rasterize 0 area triangles

				vertices_screen_space [idx + 0] = a_s;
				vertices_screen_space [idx + 1] = b_s;
				vertices_screen_space [idx + 2] = c_s;

				depth_screen_space[idx + 0] = a.z;
				depth_screen_space[idx + 1] = b.z;
				depth_screen_space[idx + 2] = c.z;
				
				idx += 3;
			}
			if idx != vertex_base
			{
				seq := array_add(*material_sequence);
				seq.end_vertex = idx;
				seq.material = it.mesh_ptr.material;
			}
			vertex_base = idx;
		}
		n_vertices  = vertex_base; // Set to the actual number of vertices
		//log("% Triangles are being rasterized", n_vertices/3);
		Profiler.Plot("Triangles", n_vertices);
	}



	

	//
	// Rasterization
	//
	{
		Profiler.TimeZone("Rasterization");
		triangle_start := 0;
		material_sequence_idx := 0;
		while triangle_start < n_vertices
		{
			if material_sequence[material_sequence_idx].end_vertex <= triangle_start
			{
				material_sequence_idx += 1;
			}
			seq := *material_sequence[material_sequence_idx];
			assert(seq.end_vertex > triangle_start);

			defer triangle_start += 3;
			a := vertices_screen_space[triangle_start + 0];
			b := vertices_screen_space[triangle_start + 1];
			c := vertices_screen_space[triangle_start + 2];
			area_2 := det_2d(a, b, c);
			min_tri  := screen2.{min(a.x, b.x, c.x), min(a.y, b.y, c.y)};
			min_tri.x = cast(type_of(screen2.x)) max((-bb.size.x * FIXEDPOINT_ONE)/2, min_tri.x);
			min_tri.y = cast(type_of(screen2.x)) max((-bb.size.y * FIXEDPOINT_ONE)/2, min_tri.y);

			max_tri := screen2.{max(a.x, b.x, c.x), max(a.y, b.y, c.y)};
			max_tri.x = cast(type_of(screen2.x)) min(( bb.size.x * FIXEDPOINT_ONE)/2, max_tri.x);
			max_tri.y = cast(type_of(screen2.x)) min(( bb.size.y * FIXEDPOINT_ONE)/2, max_tri.y);

			pxl := min_tri;
			round :: (p : screen2) -> screen2 #expand
			{
				res := p;
				res.x = xx (res.x + FIXEDPOINT_MASK) & ~FIXEDPOINT_MASK;
				res.y = xx (res.y + FIXEDPOINT_MASK) & ~FIXEDPOINT_MASK;
				return res;
			}
			pxl = round(pxl);
			start := pxl;

			isTopLeft :: (a : screen2, b : screen2) -> bool
			{
				return (a.y == b.y && a.x > b.x) || a.y > b.y;
			}


		
			det_0_base := det_2d(a,b,pxl);
			det_1_base := det_2d(b,c,pxl);
			det_2_base := det_2d(c,a,pxl);

			det_base := Vector(3, s32).{det_0_base, det_1_base, det_2_base};
			

			_det_0_delta := b-a;
			_det_1_delta := c-b;
			_det_2_delta := a-c;

			det_delta_x := Vector(3, s32).{(b-a).x,(c-b).x,(a-c).x};
			det_delta_y := Vector(3, s32).{(b-a).y,(c-b).y,(a-c).y};

			det := det_base;

			det_0 := det_0_base;
			det_1 := det_1_base;
			det_2 := det_2_base;

			depth_1 := depth_screen_space[triangle_start + 0];
			depth_2 := depth_screen_space[triangle_start + 1];
			depth_0 := depth_screen_space[triangle_start + 2];

			u_delta := depth_1 - depth_0;
			v_delta := depth_2 - depth_0;

			y_off : s32 = ((pxl.y + cast(s32)bb.size.y * FIXEDPOINT_ONE / 2) / FIXEDPOINT_ONE);
			while pxl.y < max_tri.y
			{
				pxl.x = start.x;
				x_off : s32 = ((pxl.x + cast(s32)bb.size.x * FIXEDPOINT_ONE / 2) / FIXEDPOINT_ONE);

				det_saved := det;
				while pxl.x < max_tri.x
				{
					if(det.x >= 0 && det.y >= 0 && det.z >= 0) {
						// inside the triangle
						// @Performance This results in divps, we can like with 
						//  the determinant compute a delta and then just do adds, 
						//  maybe thats better.
						u := det.y/cast(float)area_2; 
						v := det.z/cast(float)area_2;
						depth := depth_0 + u * u_delta + v * v_delta;
						if depth < depth_buffer[y_off * bb.stride + x_off]
						{
							depth_buffer[y_off * bb.stride + x_off] = depth;
							input := Shader_Input.{
								uv = .{u,v},
								depth = depth,
								material = seq.material
							};
							shader_buffer[y_off * bb.stride + x_off] = input;
						}
					}
					det   -= det_delta_y;

					pxl.x += FIXEDPOINT_ONE;
					x_off += 1;
				}
				det = det_saved + det_delta_x;
				pxl.y += FIXEDPOINT_ONE;
				y_off += 1;
			}
			
		}
	}

	//
	// Pixel Shader
	//
	{
		Profiler.TimeZone("Pixel Shader");
		actual_shader_calls : int = 0;
		for y:0..bb.size.y-1
		{
			for x:0..bb.size.x-1
			{
				if depth_buffer[y * bb.stride + x] == 1 continue x;
				actual_shader_calls += 1;
				out := color_shader(shader_buffer[y * bb.stride + x]);
				color := out.color.vec * 255.0;
				pixel := Pixel.{r = xx clamp(color.x, 0, 255), g = xx clamp(color.y, 0, 255), b = xx clamp(color.z, 0, 255)};

				bb.data[y * bb.stride + x] = pixel;
			}
		}
		Profiler.Plot("Pixel Shader Calls", actual_shader_calls);
	}
} @Disassemble


depth_shader :: (in : Shader_Input) -> Shader_Output
{
	using in;
	start := Color.{r=1, g=1, b=1};
	out : Shader_Output;
	out.color = .{vec = start.vec * sqrt(1 - in.depth)};
	return out;
}

color_shader :: (in : Shader_Input) -> Shader_Output
{
	using in;
	out : Shader_Output;
	out.color = in.material.color;
	return out;
}




Profiler :: #import "Tracy"(true);
#import "Atomics";
#import "Async_Buffer";
#import "Basic";
#import "Vector";
#import "Matrix";
#import "Camera";
#import "Math";
#import "Color";
#import "Material";
#import "AABB";
#import "Sync";
