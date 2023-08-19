#scope_export

ENTRY_FUNCTION :: #type (*Platform) -> void #c_call;

Window :: #type,distinct *void;
Thread :: #type,distinct *void;

Pixel :: struct
{
	b : u8;
	g : u8;
	r : u8;
	a : u8;
	#place b;
	code : u32 = ---; // 0xAARRGGBB Default color notation format AA = Alpha, RR = Red, GG = Green, BB = Blue
}

BackBuffer :: struct
{
	size   : int2;
	stride : int;
	data   : *Pixel;
}

Diagnostic_Function :: #type (log_file : *String_Builder, dump_file : *String_Builder) -> string #c_call;

Platform :: struct 
{
	STARTUP_TIME : Apollo_Time;
	window : Window;
	exit   : int; @Atomic;
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
};





#import "Basic";
#import "Vector";
#import "Input_System";
