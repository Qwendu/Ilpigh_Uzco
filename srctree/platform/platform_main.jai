STARTUP_TIME : Apollo_Time;
main :: ()
{
	Profiler.NameThread(#procedure_name());
	Profiler.AppInfo(Config.Profiler_Info);

	STARTUP_TIME = current_time_monotonic();
	context.logger = logger;

	register_Crash_Handler();

	platform_context : Platform;
	{
		platform_context.STARTUP_TIME = STARTUP_TIME;
		platform_context.window = cast(Window) create_Window("Ilpigh Uzco", .{800, 600});
		platform_context.exit = 0;
		platform_calls := Platform_Calls.{
			general_heap   = context.allocator,
			start_Thread   = xx start_Thread,
			stop\_Thread   = xx stop\_Thread,
			update_Window  = xx update_Window,
			get_BackBuffer = xx get_BackBuffer,
			get_Input      = xx get_Input,
			sleep          = xx sleep,
			allocate_Large = xx allocate_Large_Page,
			register_Diagnostic = xx register_Diagnostic,
			dump           = xx dump,
		};
		platform_context.calls = platform_calls;
	}

	game := load_Game_Code(Config.Game_DLL_Name);

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
	#if Config.COMPILATION_MODE == .DEVELOPEMENT
	{
		print("Attempting to load from \"%\"\n", dll_name);
		lib := load_Dynamic_Library(dll_name);
		return cast(Config.ENTRY_FUNCTION) load_Function(*lib, Config.ENTRY_FUNCTION_NAME);
	}else{
		print("We are in release mode, so we do not load from a dll\n");
		assert(false, "This has not been done yet");
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
Profiler :: #import "Tracy";
Config   :: #import "Config";
#import "Platform_Interface";
