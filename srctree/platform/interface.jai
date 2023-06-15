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

Input :: struct
{
	N_BUTTONS :: #run (cast(*Type_Info_Enum)Button_Code).names.count;
	Key_State :: struct
	{
		start_pressed : Apollo_Time;
		stop\_pressed : Apollo_Time;
	};

	key_states : [N_BUTTONS] Key_State;

	Mouse :: struct
	{
		delta : int2;
	}
	mouse : Mouse;
};


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
};

Button_Code :: enum
{
	A;
	B;
	C;
	D;
	E;
	F;
	G;
	H;
	I;
	J;
	K;
	L;
	M;
	N;
	O;
	P;
	Q;
	R;
	S;
	T;
	U;
	V;
	W;
	X;
	Y;
	Z;
	MOUSE_LEFT;
	MOUSE_RIGHT;
	// @Incomplete
};	


is_Button_Pressed :: (input : *Input, button : Button_Code) -> bool
{
	// We can add things like recognizing released buttons, if they have been released after a certain time
	// Which makes implementing cayote time and stuff like that maybe more convenient
	// TODO
	state := input.key_states[button];
	return state.start_pressed > state.stop_pressed;
}


#import "Basic";
#import "Vector";
