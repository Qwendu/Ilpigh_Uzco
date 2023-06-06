
main :: ()
{

	platform_context : Platform;
	platform_context.general_heap = context.allocator;
	platform_context.start_Thread  = start_Thread;
	platform_context.stop\_Thread  = stop\_Thread;
	platform_context.update_Window = xx update_Window;
	platform_context.get_BackBuffer = xx get_BackBuffer;
	platform_context.window = xx create_Window("Ilpigh Uzco", .{400, 300});
	platform_context.sleep = sleep;

	game := load_Game_Code(Game_DLL_Name);

	start_Thread(xx game, *platform_context);
	
	while true
	{
		// TODO(Qwendo): here do we update the input?
		should_exit := handle_Events(xx platform_context.window);
		if should_exit 
		{
			atomic_write(*platform_context.exit, 1);	
			break;
		}
	}
	
	while atomic_read(*platform_context.exit) == 1
	{
		// repeat this until the game says it has shutdown
		try_Close(xx platform_context.window);
	}
}

load_Game_Code :: ($dll_name : string) -> ENTRY_FUNCTION
{
	#if COMPILATION_MODE == .DEVELOPEMENT
	{
		print("Attempting to load from \"%\"\n", dll_name);
		lib := load_Dynamic_Library(dll_name);
		return cast(ENTRY_FUNCTION) load_Function(*lib, ENTRY_FUNCTION_NAME);
	}else{
		assert(false, "This has not been done yet");
		print("We are in release mode, so we do not load from a dll\n");
		return null;
	}
}


#import "platform";
#import "Basic";
#import "Atomics";

//#run main();
