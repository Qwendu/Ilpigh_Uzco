
main :: ()
{

	platform_context : Platform;
	platform_context.general_heap = context.allocator;
	platform_context.start_Thread  = start_Thread;
	platform_context.stop\_Thread  = stop\_Thread;
	platform_context.update_Window = xx update_Window;
	platform_context.get_BackBuffer = xx get_BackBuffer;


	platform_context.window = xx create_Window("Ilpigh Uzco");

	game := load_Game_Code(Game_DLL_Name);

	game(*platform_context);
	
	// Other stuff for input and networking and event loops

	while true
	{
		// Do event loop
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

//#run main();
