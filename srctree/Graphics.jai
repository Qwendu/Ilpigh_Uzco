#scope_export
#import "Common";
#import "Mesh";
GAMMA : float : 2.2;


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

	{
		bytes_to_alloc := Mebi(256);
		buffer_memory.data = plt.allocate_Large(bytes_to_alloc);
		log("Large page returned %\n", buffer_memory.data);
		if buffer_memory.data  buffer_memory.count = bytes_to_alloc;
	}
	
	material_1 := Material.{};
	material_1.color = .{0,1,0,0};

	m1_id, m2_id, floor_tile_id, height_map_id: int;

	{
		m1 : Mesh;
		m1.material = .{.{1,1,0, 0}};
		m1.vertices = .[
			.{-1,0,-1},
			.{1,0,-1},
			.{0,1,-8},
			//.{0,0,0}
		];
		m1.triangles = .[
			.{0,1,2},
			//.{0,3,1}
		];
		m1.aabb = generate_AABB_Of_Mesh(m1);
		m1_id := register_Mesh(m1);
	}
	{
		m2 : Mesh;
		m2.material = .{.{0,1,0, 0}};;
		m2.vertices = .[
			.{-1, 0,0},
			.{ 1, 0,-4},
			.{-1, 0,-10},
			.{ 1, 0,-10},
		];
		m2.triangles = .[
			.{0,1,2},
			.{1,3,2}
		];
		m2.aabb = generate_AABB_Of_Mesh(m2);
		m2_id = register_Mesh(m2);
	}
	{
		floor_tile : Mesh;
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
		floor_tile.aabb = generate_AABB_Of_Mesh(floor_tile);
		floor_tile_id = register_Mesh(floor_tile);
	}

	{
		height_map_res :: int2.{30, 30};
		height_map_dims :: float3.{10, .7, 10};
		height_map : Mesh;
		height_map.material.color = .{1,1,1,1};
		height_map.vertices = NewArray(height_map_res.x * height_map_res.y, float3);

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
		height_map.aabb = generate_AABB_Of_Mesh(height_map);
		height_map_id = register_Mesh(height_map);
	}

	tet_id : int;
	{
		angle :: 120.0/180 * PI;
		cosa :: #run cos(angle);
		sina :: #run sin(angle);
		tet : Mesh;
		tet.vertices = .[
			.{0, .5,0},
			.{1,-.5,0},
			.{ cosa,-.5,-sina},
			.{ cosa,-.5, sina},
		];
		tet.triangles = .[
			.{2,1,3},
			.{0,1,2},
			.{1,0,3},
			.{0,2,3},
		];
		tet.aabb = generate_AABB_Of_Mesh(tet);
		tet.material.color = .{1,0.3,0.5, 0};
		tet_id  = register_Mesh(tet);
	}

	while atomic_volatile_read(args.exit) == 0
	{
		Profiler.TimeZone();
		Profiler.Frame("Graphics");
		buffer : *Draw_Buffer = get_Read_Pointer(command_reader);
		render_Draw_Buffer(plt, buffer);
		plt.update_Window(plt.window);
		plt.sleep(30);
	}

	atomic_volatile_write(args.exit, 0);

}


add_Light_Source :: (buffer : *Draw_Buffer, light : Light_Source)
{
	using buffer;
	if n_light_sources < instances.count
	{
		light_sources[n_light_sources] = light;
		n_light_sources += 1;
	}else{
		log_error("Too many lights got queued");
	}

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

add_Line :: (buffer : *Draw_Buffer, start : float3, end : float3, color : Color)
{
	using buffer;
	if n_lines < lines.count
	{
		lines[n_lines] = .{start = start, end = end, color = color};
		n_lines += 1;
	}else{
		log_error("Too many lines got queued!");
	}
}


register_Mesh :: (mesh : Mesh) -> int
{
	id := loaded_meshes.count;
	mesh_ptr := array_add(*loaded_meshes);
	mesh_ptr.* = mesh;
	return id;
}

clear_Instances :: (draw_buffer : *Draw_Buffer)
{
	draw_buffer.n_instances = 0;
	draw_buffer.n_light_sources = 0;
	draw_buffer.n_lines = 0;
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



Shader_Global :: struct
{
	camera_position : float3;
	camera_direction : float3;
};




Shader_Input :: struct
{
	position : float3;
	normal : float3;
	depth : float;
	material    : Material;
};

Shader_Output :: struct
{
	color : Color;
};


Line :: struct
{
	start : float3;
	end   : float3;
	color : Color;
}

Draw_Buffer :: struct
{
	submission_time : Apollo_Time;
	mouse_position_relative_to_top_left : int2;
	
	n_instances : int;
	instances  : [600] Model_Instance;

	n_light_sources : int;
	light_sources : [20] Light_Source;

	n_lines : int;
	lines   : [8000] Line;

	camera : Camera;
};



loaded_meshes : [..] Mesh;



Active_Instance :: struct
{
	instance_to_projection : float4x4;
	instance_to_world : float4x4;
	mesh_ptr : * Mesh;
}
active_meshes : [..] Active_Instance;


screen2 :: Vector(2, s32 /*fixed_point 26.6*/);



buffer_memory : [] u8;
depth_buffer : [] float;
shader_buffer : [] Shader_Input;
shader_global : Shader_Global;

// Optimization Records, in CSV format
/* 400x300
Optimization,  Samples, Mean(ms), Sigma(us)
NONE,          33094,   3.43,     365.24
AVector,       33964,   3.17,     261.11
MoreAVector,   40103,   2.17,     412.86
*/
/* 800x600
Optimization,  Samples, Mean(ms), Sigma(us)
BASELINE,      24699,   9.6,      534.95

*/
//
//
render_Draw_Buffer :: (plt : *Platform, draw_buffer : *Draw_Buffer)
{
	Profiler.TimeZone(#procedure_name());
	LOG_CLIPPING :: false;
	LOG_CULLING  :: false;

	FIXEDPOINT_BITS :: 4;
	FIXEDPOINT_ONE  ::  1<<FIXEDPOINT_BITS;
	FIXEDPOINT_MASK :: (FIXEDPOINT_ONE)-1;
	
	active_lights : [] Light_Source = draw_buffer.light_sources;
	active_lights.count = draw_buffer.n_light_sources;


	mouse_pos_ndc := float2.{xx draw_buffer.mouse_position_relative_to_top_left.x, xx draw_buffer.mouse_position_relative_to_top_left.y};



	bb := plt.get_BackBuffer(plt.window);
	mouse_pos_ndc = .{mouse_pos_ndc.x/bb.size.x, mouse_pos_ndc.y/bb.size.y};
	mouse_pos_ndc.y = 1 - mouse_pos_ndc.y;
	mouse_pos_ndc *= 2;
	mouse_pos_ndc -= .{1,1};
	aspect : float = bb.size.x/cast(float)bb.size.y;

	//
	// Setup shader globals
	// 
	{
		shader_global.camera_position  = draw_buffer.camera.position;
		shader_global.camera_direction = affine_Transform(camera_To_World_Rotation(*draw_buffer.camera), float3.{0,0,-1}).xyz;
	}

	//
	// Reset Buffers Depth, Shader, Pixel
	//
	{
		Profiler.TimeZone("Reset Buffers");


		n_elements := bb.size.y * bb.stride;


		depth\_buffer_size := n_elements * size_of(float32);
		shader_buffer_size := n_elements * size_of(Shader_Input);
		bytes_needed := depth_buffer_size + shader_buffer_size;
		if buffer_memory.count < bytes_needed
		{
			error := tprint("We need % bytes for buffers, but only have allocated %", bytes_needed, buffer_memory.count);
			log_error(error);
			assert(!(buffer_memory.count < bytes_needed),error);
		}
		depth_buffer.data = xx buffer_memory.data;
		depth_buffer.count = n_elements;
		shader_buffer.data = xx *buffer_memory[depth_buffer_size];
		shader_buffer.count = n_elements;

		memset(bb.data, 0, size_of(Pixel) * n_elements);
		for 0..n_elements-1
		{
			depth_buffer[it] = 1;
		}
	}


	camera := *draw_buffer.camera;
	world_to_camera := world_To_Camera(camera);
	projection := projection_Matrix(fov = camera.fov, aspect = aspect, near = camera.near, far = camera.far);

	world_to_projection := projection * world_to_camera;

	active_meshes.count = 0;
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
			instance_to_world      := instance.model_to_world;
			instance_to_projection := world_to_projection * instance.model_to_world;
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
				active.instance_to_world = instance_to_world;
				active.mesh_ptr = mesh;
			}else{
				#if LOG_CULLING log("Culled instance %", it);
			}
		}
		Profiler.Plot("Active Instances", active_meshes.count);
		//log("% Active Instances", active_meshes.count);
	}

	det_2d :: (a :screen2, b: screen2, p : screen2) -> type_of(screen2.x)
	{
		return ((b.x-a.x)*(p.y-a.y) - (b.y-a.y)*(p.x-a.x)) >>FIXEDPOINT_BITS;
	}

	//
	// Rasterization
	//
	{
		factor_x := cast(type_of(screen2.x))FIXEDPOINT_ONE * bb.size.x/2;
		factor_y := cast(type_of(screen2.x))FIXEDPOINT_ONE * bb.size.y/2;
		Profiler.TimeZone("Rasterization");
		for active_meshes
		{
			mesh := it.mesh_ptr;
			for triangle, triangle_idx : it.mesh_ptr.triangles
			{
				a_mesh := mesh.vertices[triangle.x];
				b_mesh := mesh.vertices[triangle.y];
				c_mesh := mesh.vertices[triangle.z];
				
				a_world := affine_Transform(it.instance_to_world, a_mesh).xyz;
				b_world := affine_Transform(it.instance_to_world, b_mesh).xyz;
				c_world := affine_Transform(it.instance_to_world, c_mesh).xyz;
	
				normal := cross(b_world - a_world, c_world - a_world);

				a := project_Point(it.instance_to_projection, a_mesh);
				b := project_Point(it.instance_to_projection, b_mesh);
				c := project_Point(it.instance_to_projection, c_mesh);
				a_out := outcode(a.xyz);
				b_out := outcode(b.xyz);
				c_out := outcode(c.xyz);

				if a_out != 0 || b_out != 0 || c_out != 0 
				{
					#if LOG_CLIPPING log("Clipping Triangle %:% [% % %]", it_index, triangle_idx, a_out, b_out, c_out);
					continue triangle;
				}

			
				a_s := screen2.{cast(type_of(screen2.x)) (a.x * factor_x), cast(type_of(screen2.x)) (a.y * factor_y)};
				b_s := screen2.{cast(type_of(screen2.x)) (b.x * factor_x), cast(type_of(screen2.x)) (b.y * factor_y)};
				c_s := screen2.{cast(type_of(screen2.x)) (c.x * factor_x), cast(type_of(screen2.x)) (c.y * factor_y)};

				if det_2d(a_s, b_s, c_s) == 0  continue triangle; // dont rasterize 0 area triangles

//------------------------------------------------------------------------------------------------------------------------
				//
				//  Rasterization
				//
				area_2 := det_2d(a_s, b_s, c_s);
				min_tri  := screen2.{min(a_s.x, b_s.x, c_s.x), min(a_s.y, b_s.y, c_s.y)};
				min_tri.x = cast(type_of(screen2.x)) max((-bb.size.x * FIXEDPOINT_ONE)/2, min_tri.x);
				min_tri.y = cast(type_of(screen2.x)) max((-bb.size.y * FIXEDPOINT_ONE)/2, min_tri.y);

				max_tri := screen2.{max(a_s.x, b_s.x, c_s.x), max(a_s.y, b_s.y, c_s.y)};
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


			
				det_0_base := det_2d(a_s,b_s,pxl);
				det_1_base := det_2d(b_s,c_s,pxl);
				det_2_base := det_2d(c_s,a_s,pxl);

				det_base := AVector(4, s32).{det_0_base, det_1_base, det_2_base, 0};
				
				det_delta_x := AVector(4, s32).{(b_s-a_s).x,(c_s-b_s).x,(a_s-c_s).x, 0};
				det_delta_y := AVector(4, s32).{(b_s-a_s).y,(c_s-b_s).y,(a_s-c_s).y, 0};
		

				det := det_base;

				det_0 := det_0_base;
				det_1 := det_1_base;
				det_2 := det_2_base;

				depth_1 := a.z;
				depth_2 := b.z;
				depth_0 := c.z;

				u_delta := depth_1 - depth_0;
				v_delta := depth_2 - depth_0;
				

				a_p := a_world/a.w;
				b_p := b_world/b.w;
				c_p := c_world/c.w;

				v0_2 := 1/a.w;
				v1_2 := 1/b.w;
				v2_2 := 1/c.w;

				uv_delta := AVector(4, float32).{1, u_delta, v_delta, 0};

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
							
							depth := dot(AVector(4, float32).{depth_0, u, v, 0}, uv_delta);
							if depth < depth_buffer[y_off * bb.stride + x_off]
							{
								// Bug, perspective incorrect interpolation! 
								detf := convert(det, float32)/cast(float)area_2;
								position : float3;
								denom := (detf.y * v0_2 + detf.z * v1_2 + detf.x * v2_2);
								position = (a_p * detf.y + b_p * detf.z + c_p * detf.x)/denom;
								
				
								depth_buffer[y_off * bb.stride + x_off] = depth;
								input := Shader_Input.{
									position = position,
									normal = normal,
									depth = depth,
									material = mesh.material
								};
								shader_buffer[y_off * bb.stride + x_off] = input;
							}
						}
						det   = det - det_delta_y;

						pxl.x += FIXEDPOINT_ONE;
						x_off += 1;
					}
					det = det_saved + det_delta_x;
					pxl.y += FIXEDPOINT_ONE;
					y_off += 1;
				}
//----------------------------------------------------------------------
			}
		}
	}


	//
	// Lines
	//
	{
		clip_Line :: (start : float2, end : float2, min : float2, max : float2) -> (start : float2, end : float2, succ : bool)
		{
			LEFT   :: 1;
			RIGHT  :: 2;
			TOP    :: 4;
			BOTTOM :: 8;
			//https://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm
			outcode_2 :: (a : float2, min : float2, max : float2) -> u8
			{
				res : u8;
				if a.x < min.x  res |= LEFT;
				if a.x > max.x  res |= RIGHT;
				if a.y > max.x  res |= TOP;
				if a.y < min.x  res |= BOTTOM;
				return res;
			}
		
			start_copy := start;
			end\ _copy := end;
			succ : bool = false;
			out_start_copy := outcode_2(start_copy, min, max);
			out_end_copy   := outcode_2(end_copy, min, max);
			pick_next := 0;
			it := 0;
			while it < 10
			{
				it += 1;
				if out_start_copy == 0 && out_end_copy == 0
				{
					succ = true;
					break;
				}else if (out_start_copy & out_end_copy) != 0
				{
					succ = false;
					break;
				}else if out_start_copy != 0{
					if out_start_copy & TOP
					{
						start_copy.x += (end_copy.x - start_copy.x) * (max.y - start_copy.y)/(end_copy.y - start_copy.y);
						start_copy.y = max.y;
					}else if out_start_copy & BOTTOM
					{
						start_copy.x += (end_copy.x - start_copy.x) * (min.y - start_copy.y)/(end_copy.y - start_copy.y);
						start_copy.y = min.y;
					}else if out_start_copy & RIGHT
					{
						start_copy.y += (end_copy.y - start_copy.y) * (max.x - start_copy.x)/(end_copy.x - start_copy.x);
						start_copy.x = max.x;
					}else if out_start_copy & LEFT
					{
						start_copy.y += (end_copy.y - start_copy.y) * (min.x - start_copy.x)/(end_copy.x - start_copy.x);
						start_copy.x = min.x;
					}
				}else if out_end_copy != 0{
					if out_end_copy & TOP
					{
						end_copy.x += (end_copy.x - start_copy.x) * (max.y - end_copy.y)/(end_copy.y - start_copy.y);
						end_copy.y = max.y;
					}else if out_end_copy & BOTTOM
					{
						end_copy.x += (end_copy.x - start_copy.x) * (min.y - end_copy.y)/(end_copy.y - start_copy.y);
						end_copy.y = min.y;
					}else if out_end_copy & RIGHT
					{
						end_copy.y += (end_copy.y - start_copy.y) * (max.x - end_copy.x)/(end_copy.x - start_copy.x);
						end_copy.x = max.x;
					}else if out_end_copy & LEFT
					{
						end_copy.y += (end_copy.y - start_copy.y) * (min.x - end_copy.x)/(end_copy.x - start_copy.x);
						end_copy.x = min.x;
					}
				}
				out_start_copy = outcode_2(start_copy, min, max);
				out_end\ _copy = outcode_2(end\ _copy, min, max);
			}
			return start_copy, end_copy, succ;
		}
		render_Line_2D :: (start : float2, end : float2, color : Color) #expand
		{
			start_clipped, end_clipped, s := clip_Line(start, end, .{-1,-1}, .{1,1});
			if !s return;
			start_screen := (start_clipped + .{1,1})/2;
			start_screen.x *= bb.size.x;
			start_screen.y *= bb.size.y;
			end_screen   := (end_clipped + .{1,1})/2;
			end_screen.x *= bb.size.x;
			end_screen.y *= bb.size.y;
			delta := end_screen - start_screen;
			len := max(abs(delta.x), abs(delta.y));
			delta /= len;

			runner := start_screen;
			traversed := 0.0;
			while traversed < len
			{
				x := cast(int)runner.x;
				y := cast(int)runner.y;
				if   0 <= x && x < bb.size.x
				  && 0 <= y && y < bb.size.y
				{
					depth_buffer[y * bb.stride + x] = 1;
					bb.data[y * bb.stride + x ] = .{
						r = xx clamp(color.r * 255, 0, 255),
						g = xx clamp(color.g * 255, 0, 255),
						b = xx clamp(color.b * 255, 0, 255)
					};
				}

				runner += delta;
				traversed += 1;
			}
		}
		for it_index: 0..draw_buffer.n_lines-1
		{
			it := draw_buffer.lines[it_index];
			start := project_Point(world_to_projection, it.start);
			end   := project_Point(world_to_projection, it.end);
			if outcode(start.xyz) != 0 || outcode(end.xyz) != 0  continue;
			
			render_Line_2D(start.xy, end.xy, it.color);
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
			for x: 0..bb.size.x-1
			{
				if depth_buffer[y * bb.stride + x] == 1 continue x;
				actual_shader_calls += 1;
				out := fullbright_shader(shader_buffer[y * bb.stride + x], active_lights);
				color := AVector(4, float32).{data = out.color.vec.data};
				color = pow(color, GAMMA);
				rgb := convert(clamp(color * 255, .{0,0,0,0}, .{255,255,255,255}), s32);
				rgb_copy := rgb;
				shuffle := AVector(16, u8).{x = 0x08,y = 0x04,z = 0x00,w = 0x0C};
				#asm
				{
					pshufb rgb_copy, shuffle;
				}
				bb.data[y * bb.stride + x].code = cast,no_check(u32)rgb_copy.x;
			}
		}
		Profiler.Plot("Pixel Shader Calls", actual_shader_calls);
	}
} @Disassemble


Pixel_Shader :: #type (Shader_Input, [] Light_Source) -> Shader_Output;

depth_shader : Pixel_Shader: (in : Shader_Input, lights : [] Light_Source) -> Shader_Output
{
	using in;
	start := Color.{r=1, g=1, b=1};
	out : Shader_Output;
	out.color = .{vec = start.vec * sqrt(1 - in.depth)};
	return out;
}

color_shader :Pixel_Shader: (in : Shader_Input, lights : [] Light_Source) -> Shader_Output
{
	using in;
	out : Shader_Output;
	out.color = in.material.color;
	return out;
}

fullbright_shader : Pixel_Shader : (in : Shader_Input, lights : [] Light_Source) -> Shader_Output
{
	using in;
	using shader_global;

	out : Shader_Output;
	camera_dot := dot(normalize(position - camera_position, .{}), camera_direction);
	brightness_factor : float = 0.8 + max(camera_dot, 0) * 0.2;
	out.color = material.color * brightness_factor;
	return out;
}

lighted_shader :Pixel_Shader: (in : Shader_Input, lights : [] Light_Source) -> Shader_Output
{
	using in;
	out : Shader_Output;
	out.color = in.material.color;

	light_contribution : Color;
	for light : lights
	{
		delta := light.position - position;
		delta_unit := normalize(delta, .{});
		dist := length_Squared(delta);
		r2  := light.range * light.range;
		if  dist < r2
		{
			frac := (1 - dist/r2) * clamp(dot(normal, delta_unit), 0, 1);
			light_contribution.vec += float4.{frac,frac,frac,1};
		}
	}
	
	out.color *= light_contribution;

	return out;
}



Profiler :: #import "Tracy";
#import "Atomics";
#import "Async_Buffer";
#import "Basic";
#import "Vector";
#import "VectorAsm";
#import "Matrix";
#import "Camera";
#import "Math";
#import "Color";
#import "Material";
#import "Light";
#import "AABB";
#import "Sync";
#import "Memory";
#import "Mutex";
