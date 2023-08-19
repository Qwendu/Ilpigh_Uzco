#scope_export

Input :: struct
{
	N_BUTTONS :: #run (cast(*Type_Info_Enum)Button_Code).names.count;
	Key_State :: struct
	{
		start_pressed : Apollo_Time;
		stop\_pressed : Apollo_Time;
	};

	key_states : [N_BUTTONS] Key_State;
	last_retrieval_time : Apollo_Time;

	Mouse :: struct
	{
		position_relative_to_top_left : int2; //@BetterMouse
		delta : int2;
	}
	mouse : Mouse;
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
	F1;
	F2;
	F3;
	F4;
	F5;
	F6;
	F7;
	F8;
	F9;
	F10;
	F11;
	F12;
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

was_Button_Just_Pressed :: (input : *Input, button : Button_Code) -> bool
{
	return input.key_states[button].start_pressed >= input.last_retrieval_time;
}


#scope_file

#import "Vector";
#import "Basic";
