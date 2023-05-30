#import "Common";
#import "Mesh";

Draw_Args :: struct
{
	exit: *int;
	plt : *Platform;
	c   : *Context;
	
};


draw :: (args :*Draw_Args) #c_call
{
	plt : *Platform = args.plt;
	push_context,defer_pop args.c;

	while atomic_read(args.exit) == 0
	{
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
					bb.data[y * bb.stride + x] = .{code=0xFFA00000};
				}
			}
		}
		
		
		plt.update_Window(plt.window);
	}
	atomic_write(args.exit, 0);
}
#import "Atomics";
#import "AsyncBuffer";
