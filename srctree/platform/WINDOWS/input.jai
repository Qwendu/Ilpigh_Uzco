#scope_module


mouse_Move :: (window_info : *Window_Info, u_message : UINT, wparam : WPARAM, lparam : LPARAM) #expand
{
		//https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-mousemove
		// @BetterMouse
		// Maybe add here that we track where the mouse is?
		// And maybe support modes where the mouse stays in the center of the screen
		mutex_acquire(window_info.input_mutex);
		window_info.input.mouse.position_relative_to_top_left.x =  clamp((lparam >>  0) & 0xFFFF, 0, window_info.bitmap.size.x);
		window_info.input.mouse.position_relative_to_top_left.y =  clamp((lparam >> 16) & 0xFFFF, 0, window_info.bitmap.size.y);
		mutex_release(window_info.input_mutex);
}

handle_Input :: (window_info : *Window_Info, u_message : UINT, wparam : WPARAM, lparam : LPARAM) #expand
{ 
	// https://web.archive.org/web/20120223150901/http://www.toymaker.info/Games/html/raw_input.html
	size_required : u32;
	GetRawInputData(cast(HRAWINPUT)lparam, RID_INPUT, null, *size_required, size_of(RAWINPUTHEADER));
	if window_info.raw_input_buffer.count < size_required  array_resize(*window_info.raw_input_buffer, size_required);
	GetRawInputData(cast(HRAWINPUT)lparam, RID_INPUT, window_info.raw_input_buffer.data, *size_required, size_of(RAWINPUTHEADER));
	raw : *RAWINPUT = xx window_info.raw_input_buffer.data;
	if raw.header.dwType == RIM_TYPEMOUSE
	{
		mouse_raw := raw.data.mouse;
		mutex_acquire(window_info.input_mutex);
		using window_info.input;
		if !mouse_raw.usFlags & MOUSE_MOVE_ABSOLUTE
		{
			using window_info.input;
			mouse.delta.x += mouse_raw.lLastX;
			mouse.delta.y += mouse_raw.lLastY;
		}
		if mouse_raw.usButtonFlags & RI_MOUSE_LEFT_BUTTON_DOWN
		{
			if key_states[windows_key_map[VK_LBUTTON]].start_pressed < key_states[windows_key_map[VK_LBUTTON]].stop_pressed
			{
				key_states[windows_key_map[VK_LBUTTON]].start_pressed = current_time_monotonic();
			}
		}
		if mouse_raw.usButtonFlags & RI_MOUSE_LEFT_BUTTON_UP
		{
			key_states[windows_key_map[VK_LBUTTON]].stop_pressed = current_time_monotonic();
		}
		if mouse_raw.usButtonFlags & RI_MOUSE_RIGHT_BUTTON_DOWN
		{
			if key_states[windows_key_map[VK_RBUTTON]].start_pressed < key_states[windows_key_map[VK_RBUTTON]].stop_pressed
			{
				key_states[windows_key_map[VK_RBUTTON]].start_pressed = current_time_monotonic();
			}
		}
		if mouse_raw.usButtonFlags & RI_MOUSE_RIGHT_BUTTON_UP
		{
			key_states[windows_key_map[VK_RBUTTON]].stop_pressed = current_time_monotonic();
		}

		mutex_release(window_info.input_mutex);

	}
}

key_Down :: (window_info : *Window_Info, u_message : UINT, wparam : WPARAM, lparam : LPARAM) #expand
{
	// https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-keydown
	mutex_acquire(window_info.input_mutex);
	using window_info.input;
	now := current_time_monotonic();
	button_code := windows_key_map[wparam % windows_key_map.count];
	if key_states[button_code].start_pressed < key_states[button_code].stop_pressed
	{
		key_states[button_code].start_pressed = now;
	}
	`result = 0;
	mutex_release(window_info.input_mutex);
}


key_Up :: (window_info : *Window_Info, u_message : UINT, wparam : WPARAM, lparam : LPARAM) #expand
{
	mutex_acquire(window_info.input_mutex);
	using window_info.input;
	now := current_time_monotonic();
	button_code := windows_key_map[wparam % windows_key_map.count];
	key_states[button_code].stop_pressed = now;

	`result = 0;
	mutex_release(window_info.input_mutex);
}




#scope_file
windows_key_map :[256] Button_Code : #run -> [256] Button_Code
{
	arr : [256] Button_Code;
	arr[#char "A"] = .A;
	arr[#char "B"] = .B;
	arr[#char "C"] = .C;
	arr[#char "D"] = .D;
	arr[#char "E"] = .E;
	arr[#char "F"] = .F;
	arr[#char "G"] = .G;
	arr[#char "H"] = .H;
	arr[#char "I"] = .I;
	arr[#char "J"] = .J;
	arr[#char "K"] = .K;
	arr[#char "L"] = .L;
	arr[#char "M"] = .M;
	arr[#char "N"] = .N;
	arr[#char "O"] = .O;
	arr[#char "P"] = .P;
	arr[#char "Q"] = .Q;
	arr[#char "R"] = .R;
	arr[#char "S"] = .S;
	arr[#char "T"] = .T;
	arr[#char "U"] = .U;
	arr[#char "V"] = .V;
	arr[#char "W"] = .W;
	arr[#char "X"] = .X;
	arr[#char "Y"] = .Y;
	arr[#char "Z"] = .Z;
	arr[VK_LBUTTON] = .MOUSE_LEFT;
	arr[VK_RBUTTON] = .MOUSE_RIGHT;
	arr[VK_F1 ] = .F1 ;
	arr[VK_F2 ] = .F2 ;
	arr[VK_F3 ] = .F3 ;
	arr[VK_F4 ] = .F4 ;
	arr[VK_F5 ] = .F5 ;
	arr[VK_F6 ] = .F6 ;
	arr[VK_F7 ] = .F7 ;
	arr[VK_F8 ] = .F8 ;
	arr[VK_F9 ] = .F9 ;
	arr[VK_F10] = .F10;
	arr[VK_F11] = .F11;
	arr[VK_F12] = .F12;

	return arr;
};
