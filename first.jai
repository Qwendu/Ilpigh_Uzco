WANT_VTUNE  :: false;
BACKEND_X64 :: false;


Disassembler :: #import,dir "srctree/modules/Disassembler"(ENABLE = true);


modules          :: "srctree/modules";

build_Game :: (os : Operating_System_Tag = .WINDOWS) -> bool
{
	make_directory_if_it_does_not_exist(".build");
	log("Backend = %", ifx BACKEND_X64 then "X64" else "LLVM");
	//OPTIMIZATION : Jai.Optimization_Type:  .VERY_OPTIMIZED;
	OPTIMIZATION : Jai.Optimization_Type:  .DEBUG;
	log("Optimization = %", OPTIMIZATION);

	OPTIMIZING_BUILD := (OPTIMIZATION == Jai.Optimization_Type.OPTIMIZED || OPTIMIZATION == .VERY_OPTIMIZED);


	PROFILER_ENABLED := false;
	VTUNE := false;
	if OPTIMIZING_BUILD
	{
		PROFILER_ENABLED = false;
		VTUNE            = true;
		log("VTune Build");
	}
	if PROFILER_ENABLED  log("Profiler Enabled");
	
	build_name := sprint("Platform %", os);
	defer free(build_name);
	exec_name  := sprint("IU_%",os);
	defer free(exec_name);
	game_name  := sprint("Ilpigh Uzco");
	defer free(game_name);

	platform_modules := sprint("srctree/platform/%/", os);
	defer free(platform_modules);



	workspace_platform := Jai.compiler_create_workspace(build_name);
	options\ _platform := Jai.get_build_options(workspace_platform);

	workspace_game     := Jai.compiler_create_workspace(game_name);
	options\ _game     := Jai.get_build_options(workspace_game);
	#if BACKEND_X64
	{
		options_platform.backend = .X64;
		options_game.backend     = .X64;
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

		if options_game.backend == .LLVM && OPTIMIZATION >= .OPTIMIZED
		{
			print("Outputting llvm ir\n");
			options_game.llvm_options.output_llvm_ir_before_optimizations = true;
			options_game.llvm_options.output_llvm_ir = true;
		}

		Jai.set_optimization(*options_game, OPTIMIZATION);

		import : [..] string;
		array_add(*import, ..options_platform.import_path); // We need this for RuntimeSupport
		array_add(*import,          modules);
		options_game.import_path = import; 

		Jai.set_build_options(options_game    , workspace_game);
	}

	{
		generated_config : String_Builder;
		print_to_builder(*generated_config, #string DONE
#scope_export
Profiler_Info : string : "Optimization Level = %\n";
Game_DLL_Name : string : "%";
COMPILATION_MODE : enum { RELEASE; DEVELOPEMENT;} : .DEVELOPEMENT;
Profiler_Enabled : bool : %;
ENTRY_FUNCTION  :: #type (*Platform) -> void #c_call;
ENTRY_FUNCTION_NAME : string : "game_entry";
DUMP_STATE_FROM_SECONDS_AGO : int : 3;

#scope_file

#import "Basic";
#import "Common";

		DONE, OPTIMIZATION, game_name, PROFILER_ENABLED);
		
		if !write_entire_file(".build/Generated_Config.jai", *generated_config)
		{
			log("Failed to write Generated_Config");
			return false;
		}
	
	}


	compile :: (workspace : Workspace, $main_file : string, plugins : [] string = .[]) -> bool #expand
	{
		Jai.compiler_begin_intercept(workspace);
		disassembler := Disassembler.get_plugin();
		disassembler.workspace = workspace;

		Jai.add_build_file(main_file, workspace);

		success : bool = true;
		while true
		{
			msg := Jai.compiler_wait_for_message();
			disassembler.message(disassembler, msg);
			if msg.kind == .PHASE
			{
				phase := cast(*Jai.Message_Phase)msg;
				if phase.phase == .POST_WRITE_EXECUTABLE
				{
					success &= phase.linker_exit_code == 0;
					if !success  log("Linker exited with Code %", phase.linker_exit_code);
				}
			}
			if msg.kind == .COMPLETE 
			{
				success &= (cast(*Jai.Message_Complete)msg).error_code == .NONE;
				break;
			}
		}
		disassembler.finish(disassembler);
		Jai.compiler_end_intercept(workspace);
		return success;
	}
	if !compile(workspace_game    , "srctree/main.jai") return false;
	if !compile(workspace_platform, "srctree/platform/platform_main.jai")
	{
		log("Could not write to platform layer!");
	}
	
	return true;
}

#run {
	Jai.set_build_options_dc(.{do_output = false});

	context.logger = logger;
	succ := build_Game();
	if succ log("Success");
}


Jai :: #import "Compiler";
#import "Basic";


logger :: (message : string, data : *void, log_info : Log_Info)
{
	if message.count == 0  return;
	print("[Build] ");
	print("%",message);
	print("\n");
}


#import "File";
