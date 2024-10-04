SECONDS_BEFORE_ERROR :: Config.DUMP_STATE_FROM_SECONDS_AGO;



HISTORY_LENGTH :: cast(int) SECONDS_BEFORE_ERROR * PHYSICS_FREQUENCY;

history : Ring_Buffer(type_of(physics_state), HISTORY_LENGTH, .WRITER_INVALIDATES);

append_State :: () #expand
{
	append(*history, `physics_state);
}

diagnostics_For_Physics : Diagnostic_Function : (log_file_builder : *String_Builder, dump_file : *String_Builder) -> string #c_call
{
	// TODO(Qwendo): Save the entire history buffer until now
	ctx : Context = create_Diagnostic_Context("Physics", log_file_builder);
	push_context,defer_pop ctx;

	state := read(*history);
	log("Dumping Physics State at tick %", #procedure_name(), to_milliseconds(state.time));
	log("\tspheres    registered %", state.spheres.count);
	log("\ttetraeders registered %", state.tetraeder.count);
	
	serialized_version := jerialize(*state);
	append(dump_file, serialized_version);
	return "physics.state";
}


#import "File";
#import "Jerialize";
#import "Common";
#import "Platform_Interface";
#import "Diagnostic";
Config :: #import "Config";
