STARTUP_TIME : Apollo_Time;
main :: ()
{
	Profiler.NameThread(#procedure_name());
	Profiler.AppInfo(OPTIMIZATIONS);
	STARTUP_TIME = current_time_monotonic();
	context.logger = logger;

	platform_context : Platform;
	{
		platform_context.STARTUP_TIME = STARTUP_TIME;
		platform_context.general_heap = context.allocator;
		platform_context.start_Thread  = start_Thread;
		platform_context.stop\_Thread  = stop\_Thread;
		platform_context.update_Window = xx update_Window;
		platform_context.get_BackBuffer = xx get_BackBuffer;
		platform_context.get_Input = get_Input;
		platform_context.window = xx create_Window("Ilpigh Uzco", .{800, 600});
		platform_context.sleep = sleep;
	}

	game := load_Game_Code(Game_DLL_Name);

	start_Thread(xx game, *platform_context);
	
	while true
	{
		// TODO(Qwendo): here do we update the input?
		should_exit := handle_Events(xx platform_context.window);
		if should_exit 
		{
			atomic_volatile_write(*platform_context.exit, 1);	
			break;
		}
	}
	
	while atomic_volatile_read(*platform_context.exit) == 1
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


logger :: (message : string, data : *void, info : Log_Info)
{
	now := current_time_monotonic() - STARTUP_TIME;
	print("[PLATFORM]+%: %\n", to_milliseconds(now),message);
}


#import "platform";
#import "Basic";
#import "Atomics";
#import "Sync";
#import "Common";
Profiler :: #import "Tracy"(PROFILER);

//#run main();
