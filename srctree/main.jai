#load "platform/interface.jai";


#program_export
game_entry : ENTRY_FUNCTION : (platform_init : *Platform) #c_call
{
	if !platform_init return;
	platform = platform_init;
	c : Context;
	c.allocator = platform.general_heap;
	push_context,defer_pop c;

	
	draw_thread_exit : int = 0;
	args := Draw_Args.{*draw_thread_exit, platform, *context};
	platform.start_Thread(xx draw, *args);

	while atomic_read(*platform.exit) == 0
	{
	}

	atomic_write(*draw_thread_exit, 1);
	while atomic_read(*draw_thread_exit) != 0
	{}
	
	atomic_write(*platform.exit, 0);
}


platform : *Platform;



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
		bb := plt.get_BackBuffer(platform.window);
		for y : 0..bb.size.y-1
		{
			for x : 0..bb.size.x-1
			{
				bb.data[y * bb.stride + x] = .{code=0xFFA00000};
			}
		}
		plt.update_Window(platform.window);
	}
	atomic_write(args.exit, 0);
}

#import "Basic";
#import "Atomics";

