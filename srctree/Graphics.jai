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
	atomic_write(*args.output, *output);

	material_1 := Material.{};
	material_1.color = .{0,1,0,0};

	m1 := array_add(*loaded_meshes);
	m1.material = .{.{1,0,0, 0}};
	m1.vertices = .[
		.{0,0,-1},
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

	while atomic_read(args.exit) == 0
	{
		buffer : *Draw_Buffer = get_Read_Pointer(command_reader);
		render_Triangles_In_Draw_Buffer(plt, buffer);

		
		before := current_time_monotonic();
		plt.update_Window(plt.window);
		plt.sleep(1);
		after := current_time_monotonic();
	}

	atomic_write(args.exit, 0);

}


add_Mesh :: (buffer : *Draw_Buffer, instance : Model_Instance)
{
	using buffer;
	if n_instances < instances.count
	{
		instances[n_instances] = instance;
		n_instances += 1;
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
	velocity : float3;
	draw_lines : bool;
};

#scope_file


draw_logger :: (message : string, data : *void, info : Log_Info)
{
	print("[RENDER] %\n", message);
}



Shader_Input :: struct
{
	position    : float3;
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
	instances  : [300] Model_Instance;

	camera : Camera;
};



loaded_meshes : [..] Mesh;







render_Triangles_In_Draw_Buffer :: (plt : *Platform, draw_buffer : *Draw_Buffer)
{
	log("% Instances", draw_buffer.n_instances);
	bb := plt.get_BackBuffer(plt.window);
	aspect : float = bb.size.x/cast(float)bb.size.y;

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
		res += ((cast(u8) (v.z <  0)) & 1) << 5;
		
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
		}
	}
	log("% Active Instances", active_meshes.count);
	

	n_vertices := 0;
	for active_meshes
	{
		n_vertices += it.mesh_ptr.triangles.count * 3;
	}
	log("Vertex Buffer Size = %", n_vertices);
	vertices_screen := NewArray(n_vertices,            Vector(2, s32));
	depth\  _screen := NewArray(vertices_screen.count, float);
	
	FIXEDPOINT_BITS :: 6;
	FIXEDPOINT_MASK :: 1<<6-1;
	FIXEDPOINT_ONE  :: 1<<6;
	
	screen2 :: Vector(2, s32 /*fixed_point 26.6*/);
	det_2d :: (a :screen2, b: screen2, p : screen2) -> s32
	{
		return ((b.x-a.x)*(p.y-a.y)>>FIXEDPOINT_BITS) - ((b.y-a.y)*(p.x-a.x)>>FIXEDPOINT_BITS);
	}

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

			if a_out != 0 || b_out != 0 || c_out != 0  continue triangle;

			// No Infs, Nans, No triangles that get clipped
			// TODO(Qwendo): Clipping
			if !(-1 < a.x && a.x < 1) continue triangle;
			if !(-1 < b.x && b.x < 1) continue triangle;
			if !(-1 < c.x && c.x < 1) continue triangle;

			if !(-1 < a.y && a.y < 1) continue triangle;
			if !(-1 < b.y && b.y < 1) continue triangle;
			if !(-1 < c.y && c.y < 1) continue triangle;

			if !( 0 < a.z && a.z < 1) continue triangle;
			if !( 0 < b.z && b.z < 1) continue triangle;
			if !( 0 < c.z && c.z < 1) continue triangle;
		
			factor_x := cast(s32)FIXEDPOINT_ONE * bb.size.x;
			factor_y := cast(s32)FIXEDPOINT_ONE * bb.size.y;

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
			// TODO Clipping
		}
		vertex_base = idx;
	}
	n_vertices  = vertex_base; // Set to the actual number of vertices

	log("% Triangles are being rasterized", n_vertices/3);
	


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

		det_0_base := det_2d(a,b,pxl);
		det_1_base := det_2d(b,c,pxl);
		det_2_base := det_2d(c,a,pxl);

		det_0_delta := b-a;
		det_1_delta := c-b;
		det_2_delta := a-c;

		det_0 := det_0_base;
		det_1 := det_1_base;
		det_2 := det_2_base;

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
				if det_0 < 0 || det_1 < 0 || det_2 < 0
				{

				}else{
					
					bb.data[y_off * bb.stride + x_off] = .{r = 0xFF};
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
	
}





depth_buffer : [] float;
shader_buffer : [] Shader_Input;

OLD_render_Triangles_In_Draw_Buffer :: (plt : *Platform, draw_buffer : *Draw_Buffer)
{
	print("[RENDER] draw_buffer.n_instances = %\n", draw_buffer.n_instances);
	if draw_buffer.n_instances == 0
	{
		draw_buffer.n_instances += 1;
	}
	bb := plt.get_BackBuffer(plt.window);
	aspect : float = bb.size.x/cast(float)bb.size.y;
	{
		if !depth_buffer
		{
			depth_buffer = NewArray(bb.stride * bb.size.y, float);
		}
		if depth_buffer.count != bb.stride * bb.size.y
		{
			free(depth_buffer.data);
			depth_buffer.count = 0;
			depth_buffer = NewArray(bb.stride * bb.size.y, float);
		}
		if !shader_buffer
		{
			shader_buffer = NewArray(bb.stride * bb.size.y, Shader_Input);
		}
		if shader_buffer.count != bb.stride * bb.size.y
		{
			free(shader_buffer.data);
			shader_buffer.count = 0;
			shader_buffer = NewArray(bb.stride * bb.size.y, Shader_Input);
		}

		memset(bb.data, 0, size_of(Pixel) * bb.stride * bb.size.y); // Clear Backbuffer
		for *depth_buffer
		{
			<<it = 1;
		}
		for *shader_buffer
		{
			<<it = .{};
		}
	}

	far := 6.0;
	camera := *draw_buffer.camera;
	projection := projection_Matrix(fov = 90, aspect = aspect, near = 0.1, far = far);
	world_to_camera := world_To_Camera(camera);

	world_to_projection := projection * world_to_camera;
	
	render_time := current_time_monotonic();
	delta := cast(float)to_milliseconds(render_time - draw_buffer.submission_time)/1000;

	for instance_idx:  0..draw_buffer.n_instances-1
	{

		instance       := *draw_buffer.instances[instance_idx];
		mesh           := *loaded_meshes[instance.id];
		model_to_world :=  instance.model_to_world;
		print("%\n", model_to_world);
		add_Offset(*model_to_world, instance.velocity * delta);
		mesh_to_world  := model_to_world;
	
		mesh_to_projection := world_to_projection * mesh_to_world;


		for triangle : mesh.triangles
		{
			a_i : int = triangle[0];
			b_i : int = triangle[1];
			c_i : int = triangle[2];
			
			a_mesh := mesh.vertices[a_i];
			b_mesh := mesh.vertices[b_i];
			c_mesh := mesh.vertices[c_i];

			a_hom := project_Point(mesh_to_projection, a_mesh);
			b_hom := project_Point(mesh_to_projection, b_mesh);
			c_hom := project_Point(mesh_to_projection, c_mesh);


			if a_hom.w < 0 continue;
			if b_hom.w < 0 continue;
			if c_hom.w < 0 continue;
			
			a_hom.x *= bb.size.x/2;
			b_hom.x *= bb.size.x/2;
			c_hom.x *= bb.size.x/2;

			a_hom.y *= bb.size.y/2;
			b_hom.y *= bb.size.y/2;
			c_hom.y *= bb.size.y/2;

			a_screen := int2.{xx a_hom.x, xx a_hom.y};
			b_screen := int2.{xx b_hom.x, xx b_hom.y};
			c_screen := int2.{xx c_hom.x, xx c_hom.y};

			screen_min :int2;
			screen_max :int2;
			screen_min.x = max(cast(int) min(a_screen.x, b_screen.x, c_screen.x), -bb.size.x/2);
			screen_min.y = max(cast(int) min(a_screen.y, b_screen.y, c_screen.y), -bb.size.y/2);
			screen_max.x = min(cast(int) max(a_screen.x, b_screen.x, c_screen.x),  bb.size.x/2);
			screen_max.y = min(cast(int) max(a_screen.y, b_screen.y, c_screen.y),  bb.size.y/2);

			det_2d :: (a :int2, b: int2, p : int2) -> int
			{
				return (b.x-a.x)*(p.y-a.y) - (b.y-a.y)*(p.x-a.x);
			}

			for pxl_y: screen_min.y..screen_max.y-1
			{
				y_off := pxl_y + bb.size.y/2;
				for pxl_x: screen_min.x..screen_max.x-1
				{
					x_off := pxl_x + bb.size.x/2;
					pxl := int2.{pxl_x, pxl_y};

					side_0 := det_2d(a_screen, b_screen , pxl);
					side_1 := det_2d(b_screen, c_screen , pxl);
					side_2 := det_2d(c_screen, a_screen , pxl);
					if side_0 > 0 && side_1 > 0 && side_2 > 0
					{
						area_2 := det_2d(a_screen, b_screen, c_screen);;
						l_0 := side_1/cast(float)area_2;
						l_1 := side_2/cast(float)area_2;
						l_2 := side_0/cast(float)area_2;

						z_0 := a_hom.z;
						z_1 := b_hom.z;
						z_2 := c_hom.z;
						w_0 := a_hom.w;
						w_1 := b_hom.w;
						w_2 := c_hom.w;

						depth := l_0 * z_0 + l_1 * z_1 + l_2 * z_2;

						if depth < depth_buffer[y_off * bb.stride + x_off]
						{
							depth_linear := l_0 * w_0 + l_1 * w_1 + l_2 * w_2;
							depth_buffer[y_off * bb.stride + x_off] = depth;
							depth_color := 255 - cast(u8)clamp(depth_linear/far * 255, 0, 255);
							in : Shader_Input;
							in.position = (a_mesh * l_0) + (b_mesh * l_1) + (c_mesh * l_2);
							in.material = mesh.material;
							shader_buffer[y_off * bb.stride + x_off] = in;
						}
					}
				}
			}
			draw_Line :: (start : int2, end : int2) #expand
			{

				// TODO(Qwendo): Clip these to the screen so we avoid taking unecessary 
				// steps out of bounds
				start_depth := a_hom.z;
				end\ _depth := b_hom.z;
				delta := end - start;
				number_steps := max(abs(delta.x), abs(delta.y));
				step  := float2.{delta.x/cast(float)number_steps, delta.y/cast(float)number_steps};
				for 0..number_steps-1
				{
					t := it/cast(float)number_steps;
					depth := start_depth * (1 - t) + end_depth * t - 0.01;
					x := cast(int)(start.x + step.x * it);
					y := cast(int)(start.y + step.y * it);
					if x < 0 || x >= bb.size.x  continue;
					if y < 0 || y >= bb.size.y  continue;
					if depth < 0 || depth > 1   continue;
					if depth < depth_buffer[y * bb.stride + x]
					{
						bb.data[y * bb.stride + x] = .{r = 0xFF, a = 0xFF};
						depth_buffer[y * bb.stride + x] = depth;
					}
				}	
			}
			if instance.draw_lines
			{
				start := a_screen + bb.size/2;
				end   := b_screen + bb.size/2; 

				draw_Line(a_screen + bb.size/2,	b_screen + bb.size/2);
				draw_Line(b_screen + bb.size/2,	c_screen + bb.size/2);
				draw_Line(c_screen + bb.size/2,	a_screen + bb.size/2);
				
			}

			if false // draw AABBs of the Triangles
			{
				bl := screen_min + bb.size/2;
				tr := screen_max + bb.size/2;
				br := int2.{tr.x, bl.y};
				tl := int2.{bl.x, tr.y};
				draw_Line(bl, tl);
				draw_Line(bl, br);
				draw_Line(tr, tl);
				draw_Line(tr, br);
			}
		}
	}

	for y : 0..bb.size.y-1
	{
		for x : 0..bb.size.x-1
		{
			if depth_buffer[y * bb.stride + x] == 1  continue;
			color := shader_1(shader_buffer[y * bb.stride + x]).color;
			pxl := Pixel.{};
			pxl.r = cast(u8)clamp(color.r * 255, 0, 255);
			pxl.g = cast(u8)clamp(color.g * 255, 0, 255);
			pxl.b = cast(u8)clamp(color.b * 255, 0, 255);
			bb.data[y * bb.stride + x] = pxl;
		}
	}
	
}


shader_1 :: (in : Shader_Input) -> Shader_Output
{
	out : Shader_Output;
	out.color = in.material.color;
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
