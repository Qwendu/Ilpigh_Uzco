#scope_module

setup_Buffers :: ()
{
	bytes_to_alloc := 256 * 1024 * 1024;//Mebi(256);
	buffer_memory.data = platform.allocate_Large(bytes_to_alloc);
	log("Large page returned %\n", buffer_memory.data);
	if buffer_memory.data  buffer_memory.count = bytes_to_alloc;
}

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
render_Draw_Buffer :: (window : Window, draw_buffer : *Draw_Buffer)
{
	Profiler.TimeZone(#procedure_name());
	LOG_CLIPPING :: false;
	LOG_CULLING  :: false;

	FIXEDPOINT_BITS :: 4;
	FIXEDPOINT_ONE  ::  1<<FIXEDPOINT_BITS;
	FIXEDPOINT_MASK :: (FIXEDPOINT_ONE)-1;
	
	active_lights : [] Light_Source = to_view(*draw_buffer.light_sources);


	mouse_pos_ndc := float2.{xx draw_buffer.mouse_position_relative_to_top_left.x, xx draw_buffer.mouse_position_relative_to_top_left.y};



	bb := platform.get_BackBuffer(window);
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
		for *draw_buffer.instances
		{
			mesh     := get_Mesh(it.id);
			if !mesh
			{
				log("Failed to load mesh of id %", it.id);
				continue;
			}
			corners_mesh  :=  aabb_To_Corners(mesh.aabb);
			instance_to_world      := it.mesh_to_world;
			instance_to_projection := world_to_projection * it.mesh_to_world;
			n_outside := 0;

			for vertex: corners_mesh
			{
				proj := project_Point(instance_to_projection, vertex);
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
				#if LOG_CULLING log("Culled instance %", it_index);
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
							if depth < depth_buffer[y_off * bb.stride + x_off] //TODO(Qwendo): Add Occlusion Shader test?
							{
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
		for draw_buffer.lines
		{
			start := project_Point(world_to_projection, it.start);
			end   := project_Point(world_to_projection, it.end);
			if outcode(start.xyz) != 0 || outcode(end.xyz) != 0  continue;
			
			render_Line_2D(start.xy, end.xy, it.color, bb, depth_buffer);
		}
	}


	//
	// Bezier Curves
	//
	{
		for draw_buffer.bezier_2d
		{
			render_Bezier_Curve(it, bb, depth_buffer);
		}
		for draw_buffer.bezier_3d
		{
			render_Bezier_Curve(it,world_to_projection, bb, depth_buffer);
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
} @OnlyInThread(render_Thread) @Disassemble(Rasterizer.asm)

#scope_file

buffer_memory : [] u8;
depth_buffer : [] float;
shader_buffer : [] Shader_Input;


#load "Line2D.jai";
#import "Memory";
