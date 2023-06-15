RUN\ GAME :: true; // I just have to do this even though it is horrible for searching and stuff




build_Game :: (os : Operating_System_Tag = .WINDOWS) -> bool
{
	BACKEND_X64 :: false;
	OPTIMIZATION : Jai.Optimization_Type:  .DEBUG;
	
	build_name := sprint("Platform %", os);
	exec_name  := sprint("IU_%",os);
	game_name  := sprint("Ilpigh Uzco");

	platform_modules := sprint("srctree/platform/%/", os);
	modules          := "srctree/modules";


	workspace_platform := Jai.compiler_create_workspace(build_name);
	options\ _platform := Jai.get_build_options(workspace_platform);

	workspace_game     := Jai.compiler_create_workspace(game_name);
	options\ _game     := Jai.get_build_options(workspace_game);
	#if BACKEND_X64
	{
		options_platform.backend = .X64;
		options_game.backend = .X64;
	}else{
		options_platform.backend = .LLVM;
		options_game.backend     = .LLVM;
	}
	
	{
		options_platform.text_output_flags = xx 0;
		options_platform.output_type = .EXECUTABLE;
		options_platform.output_executable_name = exec_name;
		options_platform.output_path = "binaries";
		options_platform.dead_code_elimination = .NONE;


		import : [..] string;
		array_add(*import, ..options_platform.import_path); // We need this for RuntimeSupport
		array_add(*import, platform_modules);
		array_add(*import,          modules);
		options_platform.import_path = import; 
		Jai.set_optimization(*options_platform, OPTIMIZATION);

		Jai.set_build_options(options_platform    , workspace_platform);
	}

	{
		options_game.text_output_flags = xx 0;
		options_game.output_type = .DYNAMIC_LIBRARY;
		options_game.output_executable_name = game_name;
		options_game.output_path = "binaries";
		options_game.dead_code_elimination = .NONE;

		Jai.set_optimization(*options_game, OPTIMIZATION);

		import : [..] string;
		array_add(*import, ..options_platform.import_path); // We need this for RuntimeSupport
		array_add(*import,          modules);
		options_game.import_path = import; 

		Jai.set_build_options(options_game    , workspace_game);
	}

	shared_build_string := sprint(#string DONE
		Game_DLL_Name    : string                        : "%";
		COMPILATION_MODE : enum {RELEASE; DEVELOPEMENT;} : %;
		ENTRY_FUNCTION_NAME :: "game_entry";
	DONE, game_name, ".DEVELOPEMENT");
	



	Jai.compiler_begin_intercept(workspace_platform);


	Jai.add_build_string(shared_build_string, workspace_platform);
	Jai.add_build_file("srctree/platform/platform_main.jai", workspace_platform);

	succeeded_in_the_games_industry : bool = true;
	while true
	{
		msg := Jai.compiler_wait_for_message();
		if msg.kind == .COMPLETE 
		{
			succeeded_in_the_games_industry &= (cast(*Jai.Message_Complete)msg).error_code == .NONE;
			break;
		}
	}
	Jai.compiler_end_intercept(workspace_platform);
	if !succeeded_in_the_games_industry  return false;


	Jai.compiler_begin_intercept(workspace_game);
	Jai.add_build_string(shared_build_string, workspace_game);
	Jai.add_build_file("srctree/main.jai", workspace_game);

	while true
	{
		msg := Jai.compiler_wait_for_message();
		if msg.kind == .COMPLETE 
		{
			succeeded_in_the_games_industry &= (cast(*Jai.Message_Complete)msg).error_code == .NONE;
			break;
		}
	}
	Jai.compiler_end_intercept(workspace_game);

	return succeeded_in_the_games_industry;
}

#run {
	Jai.set_build_options_dc(.{do_output = false});

	succ := build_Game();
	if succ print("Built game!\n");
	if(succ && RUN\ GAME)
	{

	}
}


Jai :: #import "Compiler";
#import "Basic";



