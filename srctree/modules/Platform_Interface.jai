#scope_export

Platform_Calls :: struct 
{
	general_heap  : Allocator;
	start_Thread  : ((*void) -> int #c_call, *void) -> Thread #c_call;
	stop\_Thread  : (Thread) #c_call;
	update_Window : (Window) #c_call;
	get_BackBuffer : (Window) -> BackBuffer #c_call;
	get_Input      : (Window) -> Input #c_call;
	sleep          : (int) #c_call;
	allocate_Large : (int) -> (*void) #c_call;
	register_Diagnostic : (Diagnostic_Function) -> void #c_call;
	dump           : () -> void #c_call;
	mutex_create   : () -> int #c_call;
	mutex_acquire   : (int) -> () #c_call;
	mutex_release   : (int) -> () #c_call;
};

platform : Platform_Calls;

init :: (calls : *Platform_Calls) #c_call
{
	platform = calls.*;
}

Diagnostic_Function :: #type (log_file : *String_Builder, dump_file : *String_Builder) -> string #c_call;

#scope_file
#import "Common";
#import "Basic";
#import "Input_System";
