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



Platform :: struct
{
	STARTUP_TIME : Apollo_Time;
	window : Window;
	exit   : int; @Atomic;
	calls : Platform_Calls;
};


#import "Basic";
#import "Vector";
#import "Input_System";
#import "Platform_Interface";
