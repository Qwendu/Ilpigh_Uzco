RUN\ GAME :: true; // I just have to do this even though it is horrible for searching and stuff





build_Game :: () -> bool
{
	workspace_game := Jai.compiler_create_workspace("Ilpigh Uzco");
	options\ _game := Jai.get_build_options(workspace_game);
	
	
	options_game.    text_output_flags = xx 2;

	options_game.    output_type = .EXECUTABLE;

	options_game.    output_executable_name = "Ilpigh Uzco";
	
	options_game.    output_path = "binaries";

	options_game.    dead_code_elimination = .NONE;

	import : [..] string;
	array_add(*import, ..options_game.import_path);
	array_add(*import, "srctree/modules");
	options_game.import_path = import; 
	
	Jai.set_build_options(options_game    , workspace_game);
	



	Jai.compiler_begin_intercept(workspace_game);
	Jai.add_build_file("srctree/main.jai", workspace_game);

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
	Jai.compiler_end_intercept(workspace_game);
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



