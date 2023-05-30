#import "Common";
#import "Mesh";


Mesh_Reference :: #type,distinct int;

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
	infos : [100] Mesh_Info;
}

Mesh_Info :: struct
{
	mesh : Mesh_Reference;
	// TODO(Qwendo): more data here
};


draw :: (args :*Draw_Args) #c_call
{
	plt : *Platform = args.plt;

	draw_context := Context.{};
	push_context,defer_pop draw_context;
	output : Output;

	command_reader, command_writer := get_Ends(*command_buffer);

	output.command_buffer_writer = command_writer;
	atomic_write(*args.output, *output);

	while atomic_read(args.exit) == 0
	{
		buffer : *Mesh_Buffer = get_Read_Pointer(command_reader);

		mesh : Mesh;
		mesh.vertices = .[.{0,0,1}, .{1,0,1}, .{0,1,1}];
		mesh.triangles = .[.{0,1,2}];


		bb := plt.get_BackBuffer(plt.window);
		for triangle : mesh.triangles
		{
			for y : 0..bb.size.y-1
			{
				for x : 0..bb.size.x-1
				{
					bb.data[y * bb.stride + x] = .{r =xx(x % 256), g =xx(y %256)};
				}
			}
		}
		
		
		plt.update_Window(plt.window);
	}
	atomic_write(args.exit, 0);
}
#import "Atomics";
#import "AsyncBuffer";
#import "Basic";
