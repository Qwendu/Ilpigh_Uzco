#import "Common";


#program_export
game_entry : ENTRY_FUNCTION : (platform_init : *Platform) #c_call
{
	if !platform_init return;
	platform = platform_init;
	c : Context;
	c.allocator = platform.general_heap;

	push_context,defer_pop c;

	
	draw_thread_exit : int = 0;
	args := Draw_Args.{exit = *draw_thread_exit, plt = platform, c = *context};
	platform.start_Thread(xx draw, *args);

	while atomic_read(*args.output) == null
	{}

	graphics := args.output;

	while atomic_read(*platform.exit) == 0
	{
		t := get_Write_Pointer(graphics.command_buffer_writer);
	}

	atomic_write(*draw_thread_exit, 1);
	while atomic_read(*draw_thread_exit) != 0
	{}
	
	atomic_write(*platform.exit, 0);
}


platform : *Platform;




#import,file "Graphics.jai";
#import "Basic";
#import "Atomics";
#import "AsyncBuffer";

