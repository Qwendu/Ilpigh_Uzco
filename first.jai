RUN\ GAME :: true; // I just have to do this even though it is horrible for searching and stuff





build_Game :: (os : Operating_System_Tag = .WINDOWS) -> bool
{
	build_name := sprint("Platform %", os);
	exec_name  := sprint("IU_%",os);

	platform_modules := sprint("srctree/platform/%/", os);
	modules          := "srctree/modules";


	workspace_platform := Jai.compiler_create_workspace(build_name);
	options\ _platform := Jai.get_build_options(workspace_platform);
	
	
	options_platform.    text_output_flags = xx 2;

	options_platform.    output_type = .EXECUTABLE;

	options_platform.    output_executable_name = exec_name;
	
	options_platform.    output_path = "binaries";

	options_platform.    dead_code_elimination = .NONE;

	import : [..] string;
	array_add(*import, ..options_platform.import_path); // We need this for RuntimeSupport
	array_add(*import, platform_modules);
	array_add(*import,          modules);
	options_platform.import_path = import; 
	
	Jai.set_build_options(options_platform    , workspace_platform);
	



	Jai.compiler_begin_intercept(workspace_platform);
	Jai.add_build_file("srctree/platform/platform_main.jai", workspace_platform);

	succeeded_in_the_games_industry : bool = true;
	while true
	{
		msg := Jai.compiler_wait_for_message();
		if msg.kind == .COMPLETE 
		{
			succeeded_in_the_games_industry = (cast(*Jai.Message_Complete)msg).error_code == .NONE;
			break;
		}
	}
	Jai.compiler_end_intercept(workspace_platform);
	return succeeded_in_the_games_industry;
}

#run {
	Jai.set_build_options_dc(.{do_output = false});

	succ := build_Game();
	if(succ && RUN\ GAME)
	{

	}
}


Jai :: #import "Compiler";
#import "Basic";



