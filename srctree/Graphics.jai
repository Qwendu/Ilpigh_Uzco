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
	plt : *Platform = args.plt;

	draw_context := Context.{};
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

	while atomic_volatile_read(args.exit) == 0
	{
		buffer : *Draw_Buffer = get_Read_Pointer(command_reader);
		render_Triangles_In_Draw_Buffer(plt, buffer);

		
		before := current_time_monotonic();
		plt.update_Window(plt.window);
		plt.sleep(1);
		after := current_time_monotonic();
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






depth_buffer : [] float;
shader_buffer : [] Shader_Input;

render_Triangles_In_Draw_Buffer :: (plt : *Platform, draw_buffer : *Draw_Buffer)
{
	LOG_CLIPPING :: false;
	LOG_CULLING  :: false;


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
		if n_outside != 8
		{
			active := array_add(*active_meshes);
			active.instance_to_projection = instance_to_projection;
			active.mesh_ptr = mesh;
		}else{
			#if LOG_CULLING log("Culled instance %", it);
		}
	}
	//log("% Active Instances", active_meshes.count);
	


	n_vertices := 0;
	for active_meshes
	{
		n_vertices += it.mesh_ptr.triangles.count * 3;
	}
	//log("Vertex Buffer Size = %", n_vertices);
	vertices_screen := NewArray(n_vertices,            Vector(2, s32));
	depth\  _screen := NewArray(vertices_screen.count, float);
	
	FIXEDPOINT_BITS :: 8;
	FIXEDPOINT_MASK :: (1<<FIXEDPOINT_BITS)-1;
	FIXEDPOINT_ONE  ::  1<<FIXEDPOINT_BITS;
	
	screen2 :: Vector(2, s32 /*fixed_point 26.6*/);
	det_2d :: (a :screen2, b: screen2, p : screen2) -> s32
	{
		return ((b.x-a.x)*(p.y-a.y)>>FIXEDPOINT_BITS) - ((b.y-a.y)*(p.x-a.x)>>FIXEDPOINT_BITS);
	}

	factor_x := cast(s32)FIXEDPOINT_ONE * bb.size.x;
	factor_y := cast(s32)FIXEDPOINT_ONE * bb.size.y;
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

			if a_out != 0 && b_out != 0 && c_out != 0 
			{
				#if LOG_CLIPPING log("Clipping Triangle %:% [% % %]", it_index, triangle_idx, a_out, b_out, c_out);
				continue triangle;
			}

			// TODO(Qwendo): Clipping
		

			half :: screen2.{FIXEDPOINT_ONE/2, FIXEDPOINT_ONE/2};
			a_s := screen2.{cast(s32) (a.x * factor_x), cast(s32) (a.y * factor_y)};
			b_s := screen2.{cast(s32) (b.x * factor_x), cast(s32) (b.y * factor_y)};
			c_s := screen2.{cast(s32) (c.x * factor_x), cast(s32) (c.y * factor_y)};

			if det_2d(a_s, b_s, c_s) == 0  continue; // dont rasterize 0 area triangles

			vertices_screen [idx + 0] = a_s;
			vertices_screen [idx + 1] = b_s;
			vertices_screen [idx + 2] = c_s;

			depth_screen[idx + 0] = a.z;
			depth_screen[idx + 1] = b.z;
			depth_screen[idx + 2] = c.z;
			
			
			idx += 3;
		}
		vertex_base = idx;
	}
	n_vertices  = vertex_base; // Set to the actual number of vertices

	//log("% Triangles are being rasterized", n_vertices/3);
	


	triangle_start := 0;

	while triangle_start < n_vertices
	{
		defer triangle_start += 3;
		a := vertices_screen[triangle_start + 0];
		b := vertices_screen[triangle_start + 1];
		c := vertices_screen[triangle_start + 2];
		area_2 := det_2d(a, b, c);
		min_tri  := screen2.{min(a.x, b.x, c.x), min(a.y, b.y, c.y)};
		min_tri.x = cast(s32) max((-bb.size.x << FIXEDPOINT_BITS)/2, min_tri.x);
		min_tri.y = cast(s32) max((-bb.size.y << FIXEDPOINT_BITS)/2, min_tri.y);

		max_tri := screen2.{max(a.x, b.x, c.x), max(a.y, b.y, c.y)};
		max_tri.x = cast(s32) min(( bb.size.x << FIXEDPOINT_BITS)/2, max_tri.x);
		max_tri.y = cast(s32) min(( bb.size.y << FIXEDPOINT_BITS)/2, max_tri.y);

		pxl := min_tri;
		pxl.x = cast(s32) (pxl.x + FIXEDPOINT_MASK) & ~FIXEDPOINT_MASK;
		pxl.y = cast(s32) (pxl.y + FIXEDPOINT_MASK) & ~FIXEDPOINT_MASK;
		start := pxl;

		isTopLeft :: (a : screen2, b : screen2) -> bool
		{
			return (a.y == b.y && a.x > b.x) || a.y > b.y;
		}

		det_0_base := det_2d(a,b,pxl);// + ifx isTopLeft(a,b) then 0 else FIXEDPOINT_ONE;
		det_1_base := det_2d(b,c,pxl);// + ifx isTopLeft(b,c) then 0 else FIXEDPOINT_ONE;
		det_2_base := det_2d(c,a,pxl);// + ifx isTopLeft(c,a) then 0 else FIXEDPOINT_ONE;

		det_0_delta := b-a;
		det_1_delta := c-b;
		det_2_delta := a-c;


		det_0 := det_0_base;
		det_1 := det_1_base;
		det_2 := det_2_base;

		depth_1 := depth_screen[triangle_start + 0];
		depth_2 := depth_screen[triangle_start + 1];
		depth_0 := depth_screen[triangle_start + 2];

		u_delta := depth_1 - depth_0;
		v_delta := depth_2 - depth_0;

		y_off := (pxl.y + cast(s32)bb.size.y * FIXEDPOINT_ONE / 2) >> FIXEDPOINT_BITS;
		while pxl.y < max_tri.y
		{
			pxl.x = start.x;
			x_off := (pxl.x + cast(s32)bb.size.x * FIXEDPOINT_ONE / 2) >> FIXEDPOINT_BITS;

			det_0_saved := det_0;
			det_1_saved := det_1;
			det_2_saved := det_2;


			while pxl.x < max_tri.x
			{
				if(det_0 >= 0 && det_1 >= 0 && det_2 >= 0) {
					// inside the triangle
					u := det_1/cast(float)area_2;
					v := det_2/cast(float)area_2;
					depth := depth_0 + u * u_delta + v * v_delta;
					if depth < depth_buffer[y_off * bb.stride + x_off]
					{
						depth_buffer[y_off * bb.stride + x_off] = depth;
						input := Shader_Input.{
							uv = .{u,v},
							depth = depth
						};
						shader_buffer[y_off * bb.stride + x_off] = input;
					}
				}
				det_0 -= det_0_delta.y;
				det_1 -= det_1_delta.y;
				det_2 -= det_2_delta.y;
				pxl.x += FIXEDPOINT_ONE;
				x_off += 1;
			}
			det_0 = det_0_saved + det_0_delta.x;
			det_1 = det_1_saved + det_1_delta.x;
			det_2 = det_2_saved + det_2_delta.x;

			pxl.y += FIXEDPOINT_ONE;
			y_off += 1;
		}
		
	}

	//log("Applying Pixel Shader");
	for y:0..bb.size.y-1
	{
		for x:0..bb.size.x-1
		{
			if depth_buffer[y * bb.stride + x] == 1 continue x;
			out := depth_shader(shader_buffer[y * bb.stride + x]);
			color := out.color.vec * 255.0;
			pixel := Pixel.{r = xx clamp(color.x, 0, 255), g = xx clamp(color.y, 0, 255), b = xx clamp(color.z, 0, 255)};

			bb.data[y * bb.stride + x] = pixel;
		}
	}
}


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
	out.color = material.color;
	return out;
}










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
