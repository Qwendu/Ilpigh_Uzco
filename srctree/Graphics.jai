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
	push_context,defer_pop draw_context;
	output : Output;

	command_reader, command_writer := get_Ends(*command_buffer);

	output.command_buffer_writer = command_writer;
	atomic_write(*args.output, *output);

	m1 := array_add(*loaded_meshes);
	m1.matrix = identity(4, float);
	m1.vertices = .[
		.{0,0,-1},
		.{1,0,-1},
		.{0,1,-1},
		.{0,0,0}
	];
	m1.triangles = .[
		.{0,1,2},
		.{0,3,1}
	];

	m2 := array_add(*loaded_meshes);
	m2.matrix = identity(4, float);
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


add_Mesh :: (buffer : *Draw_Buffer, mesh_id : int, orientation : float4x4, vel : float3 = .{}) 
{
	using buffer;
	if n_inserted < instances.count
	{
		instances[n_inserted].id = mesh_id;
		instances[n_inserted].model_to_world = orientation;
		instances[n_inserted].velocity = vel;
		n_inserted += 1;
	}
}

clear_Models :: (draw_buffer : *Draw_Buffer)
{
	draw_buffer.n_inserted = 0;
}

#scope_file



Draw_Buffer :: struct
{
	submission_time : Apollo_Time;
	Model_Instance :: struct
	{
		id : int;
		model_to_world : float4x4;
		velocity : float3;
	};
	
	n_inserted : int;
	instances  : [300] Model_Instance;

	camera : Camera;
};



loaded_meshes : [..] Mesh;




depth_buffer : [] float;


render_Triangles_In_Draw_Buffer :: (plt : *Platform, draw_buffer : *Draw_Buffer)
{
	print("Got mesh buffer with % meshes to draw\n", draw_buffer.n_inserted);

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

		memset(bb.data, 0, size_of(Pixel) * bb.stride * bb.size.y); // Clear Backbuffer
		for *depth_buffer
		{
			<<it = 1;
		}
	}

	far := 6.0;
	camera := *draw_buffer.camera;
	projection := projection_Matrix(fov = 90, aspect = aspect, near = 0.1, far = far);
	world_to_camera := world_To_Camera(camera);

	world_to_projection := projection * world_to_camera;
	
	render_time := current_time_monotonic();
	delta := cast(float)to_milliseconds(render_time - draw_buffer.submission_time)/1000;
	print("Delta %\n", delta);

	for instance_idx:  0..draw_buffer.n_inserted-1
	{
		instance := *draw_buffer.instances[instance_idx];
		mesh           := *loaded_meshes[instance.id];
		model_to_world :=  instance.model_to_world;
		add_Offset(*model_to_world, instance.velocity * delta);
		mesh_to_world  := model_to_world * mesh.matrix;
	
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
							bb.data[y_off * bb.stride + x_off] = .{r = depth_color, g = depth_color, b = depth_color, a = 0xFF};
						}
					}
				}
			}
			
		}
	}
}














#import "Atomics";
#import "Async_Buffer";
#import "Basic";
#import "Vector";
#import "Matrix";
#import "Camera";
#import "Math";
