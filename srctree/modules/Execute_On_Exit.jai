// This module is about registering things that should be done when the program halts unexpectedly
// Crashes, faults, assertions, memory corruption etc..



HANDLER_TYPE :: #type () -> void;

Execute_On_Exit_State :: struct
{
	already_executing : bool = false;
	handlers : Static_Auto_Array(HANDLER_TYPE, 10);
}

execute_on_exit : Execute_On_Exit_State;

#import "Static_Auto_Array";
