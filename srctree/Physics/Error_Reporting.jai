SECONDS_BEFORE_ERROR :: 3;



HISTORY_LENGTH :: cast(int) SECONDS_BEFORE_ERROR * PHYSICS_FREQUENCY;
#run log("HISTORY LENGTH = %", HISTORY_LENGTH);

history : Ring_Buffer(type_of(physics_state), HISTORY_LENGTH, .WRITER_INVALIDATES);


CRASH_HANDLER_IS_ACTIVE := false;
on_unexpected_shutdown :: ()
{
	state := read(*history);
	//serialized_version := jerialize(*state);
}


#import "File";

#import "Execute_On_Exit";
#import "Jerialize";
