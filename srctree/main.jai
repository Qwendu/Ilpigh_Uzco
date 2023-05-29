#load "platform/interface.jai";

#program_export
game_entry : ENTRY_FUNCTION : (platform_init : *Platform) #c_call
{
	if !platform_init return;
	platform = platform_init;

	c : Context;
	c.allocator = platform.general_heap;
	push_context,defer_pop c;

	args := Draw_Args.{platform, *context};
	platform.start_Thread(xx draw, *args);
}

platform : *Platform;



Draw_Args :: struct
{
	plt : *Platform;
	c   : *Context;
}
draw :: (data :*Draw_Args) #c_call
{
	plt : *Platform = data.plt;
	push_context,defer_pop data.c;

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

#import "Basic";

