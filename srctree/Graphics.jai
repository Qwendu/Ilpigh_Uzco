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
	command_buffer_writer : Async_Buffer_End(Mesh_Buffer,.WRITER);
};

command_buffer : Async_Buffer(Mesh_Buffer);

Mesh_Buffer :: struct
{
	data : int;
}


draw :: (args :*Draw_Args) #c_call
{
	plt : *Platform = args.plt;

	draw_context := Context.{};
	push_context,defer_pop draw_context;
	output : Output;

	command_reader, command_writer := get_Ends(*command_buffer);

	output.command_buffer_writer = command_writer;
	atomic_write(*args.output, *output);


	counter :int = 1;
	while atomic_read(args.exit) == 0
	{

		buffer : *Mesh_Buffer = get_Read_Pointer(command_reader);
		render_Triangles_In_Mesh_Buffer(plt, counter);

		counter += 1;
		plt.update_Window(plt.window);
	}
	atomic_write(args.exit, 0);
}



#scope_file






render_Triangles_In_Mesh_Buffer :: (plt : *Platform, counter : int)
{
	mesh := Mesh.{};
	verts : [3] float3;
	verts[0] = .{0,0,-1};
	verts[1] = .{1,0,-1};
	verts[2] = .{0,1,-1};
	
	mesh.vertices = verts;
	mesh.triangles = .[.{0,1,2}];

	mesh.vertices[0].x = cast(float)counter/1000;
	print("x = %\n", mesh.vertices[0].x);

	camera : Camera;


	bb := plt.get_BackBuffer(plt.window);
	memset(bb.data, 0, size_of(Pixel) * bb.stride * bb.size.y); // Clear Backbuffer


	aspect : float = bb.size.x/cast(float)bb.size.y;
	camera.projection = projection_Matrix(fov = 90, aspect = aspect, near = 0.1, far = 10);

	compound_matrix := camera.projection;

	for triangle : mesh.triangles
	{
		a_i : int = triangle[0];
		b_i : int = triangle[1];
		c_i : int = triangle[2];
		
		a_mesh := mesh.vertices[a_i];
		b_mesh := mesh.vertices[b_i];
		c_mesh := mesh.vertices[c_i];

		a_hom := project_Point(compound_matrix, a_mesh);
		b_hom := project_Point(compound_matrix, b_mesh);
		c_hom := project_Point(compound_matrix, c_mesh);
		
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
		screen_min.x = max(cast(int) min(a_hom.x, b_hom.x, c_hom.x), -bb.size.x/2);
		screen_min.y = max(cast(int) min(a_hom.y, b_hom.y, c_hom.y), -bb.size.y/2);
		screen_max.x = min(cast(int) max(a_hom.x, b_hom.x, c_hom.x),  bb.size.x/2);
		screen_max.y = min(cast(int) max(a_hom.y, b_hom.y, c_hom.y),  bb.size.y/2);

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
					bb.data[y_off * bb.stride + x_off] = .{code = 0xFF00FF00};
				}
			}
		}
		
	}
		
}














#import "Atomics";
#import "AsyncBuffer";
#import "Basic";
#import "Vector";
#import "Matrix";
#import "Camera";
