#scope_export

#import "Common";

Window_Info :: struct
{
	module         : HINSTANCE;
	handle         : HWND;
	bitmap         : Bitmap;
	size           : int2;
	display_name   : string;
	class_name     : string;
	window_class   : WNDCLASSEXW;
	wnd_Proc       : *void;
	device_context : HDC;
	window_context : Context;
	active : bool;
	input_devices : struct {
		//@WM_INPUT
		keyboard: RAWINPUTDEVICE;
		mouse   : RAWINPUTDEVICE;
	};
	raw_input_buffer : [..] u8;
	
	

	input : Mutex(Input);

	exit           : bool; @Atomic;
	clear_input    : bool; @Atomic;
};

GLOBAL_LARGE_PAGE_ENABLE := false;
GLOBAL_LARGE_PAGE_SIZE_INITTED : bool = false;
GLOBAL_LARGE_PAGE_SIZE := cast(u64) #run Kibi(4);
GLOBAL_LARGE_PAGE_AVAILABLE : bool = false;

active_windows : Bucket_Array(Window_Info, 20);
active_threads : [..] Thread_Info;


create_Window :: (display_name : string, size : int2) -> *Window_Info #must
{
	if !GLOBAL_LARGE_PAGE_SIZE_INITTED && GLOBAL_LARGE_PAGE_ENABLE
	{
		token : HANDLE;
		if OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, *token)
		{
			priv : TOKEN_PRIVILEGES;
			priv.PrivilegeCount = 1;
			priv.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
			if LookupPrivilegeValueW(null, utf8_to_wide(SE_LOCK_MEMORY_NAME), *priv.Privileges[0].Luid) // BAD WE ARE MIXING W and A
			{
				AdjustTokenPrivileges(token, BOOL.FALSE, *priv, size_of(type_of(priv)), null,null);
				if GetLastError() == 0
				{
					GLOBAL_LARGE_PAGE_SIZE = GetLargePageMinimum();
					GLOBAL_LARGE_PAGE_AVAILABLE = true;
					log("LARGE PAGES ENABLED");
				}else{
					log_error("SeLockMemoryPrivilege denied");
				}
			}else{
				log_error("LookupPrivilegeValueA failed");
			}
		}else{
			log_error("OpenProcessToken failed");
		}

		if GLOBAL_LARGE_PAGE_AVAILABLE
			log("Large Pages are % bytes", GLOBAL_LARGE_PAGE_SIZE);
		else
			log("No Large Pages available");
		GLOBAL_LARGE_PAGE_SIZE_INITTED = true;
	}else{
		log("Large Pages disabled");
	}
	//
	// Window Creation
	//
	main_window : *Window_Info = find_and_occupy_empty_slot(*active_windows);
	main_window.window_context = context;
	{
		main_window.class_name = sprint("WC_%\0", display_name);
		main_window.module     = GetModuleHandleW(null);
		main_window.wnd_Proc   = cast(*void)window_Proc;

		{
			using main_window.window_class;
			cbSize        = size_of(type_of(main_window.window_class));
			style         = CS_OWNDC;
			lpfnWndProc   = main_window.wnd_Proc;
			hInstance     = main_window.module;
			hIcon         = xx 0;
			hCursor       = LoadCursorW(null, IDC_ARROW);
			lpszMenuName  = null;
			lpszClassName = utf8_to_wide(main_window.class_name);
		}

		register_result := RegisterClassExW(*main_window.window_class);
		if register_result == 0
		{
			log_error("Failed to register window class %", main_window.window_class);
			return null;
		}
		style := WS_OVERLAPPEDWINDOW & ~WS_SIZEBOX;
		
		main_window.display_name = sprint("%\0", display_name); 
		rect : RECT;
		rect.top = 0;
		rect.left = 0;
		rect.right  = xx size.x;
		rect.bottom = xx size.y;
		extended_style : int = 0;
		AdjustWindowRectEx(*rect, xx style, 0, xx extended_style);
		log("Adjusted rect %", rect);
		main_window.size = .{rect.right - rect.left, rect.bottom - rect.top};
		log("Window Size %", main_window.size);

		main_window.handle = CreateWindowExW
		(
			   dwExStyle     = xx extended_style
			,  lpClassName   = utf8_to_wide(main_window.class_name)
			,  lpWindowName  = utf8_to_wide(main_window.display_name)
			,  dwStyle       = xx style
			,  x = CW_USEDEFAULT
			,  y = CW_USEDEFAULT
			,  nWidth  = xx main_window.size.x
			,  nHeight = xx main_window.size.y
			,  hwndParent = null
			,  hMenu      = null
			,  hInstance  = main_window.module
			,  lpParam    = null
		);
		if !main_window.handle
		{
			log_error("Failed to create window\nReason :%", GetLastError());
			return null;
		}
		main_window.device_context = GetDC(main_window.handle);



	}


	//
	// Register Raw Input
	//
	{
		using main_window.input_devices;
		keyboard.usUsagePage = 1;
		keyboard.usUsage     = 6;
		keyboard.dwFlags     = 0;
		keyboard.hwndTarget = main_window.handle;

		mouse.usUsagePage = 1;
		mouse.usUsage     = 2;
		mouse.dwFlags     = 0;
		mouse.hwndTarget = main_window.handle;
	
		res := RegisterRawInputDevices(*main_window.input_devices, 2, size_of(RAWINPUTDEVICE));
		if res == 0  // @WM_INPUT
		{
			log_error("Failed to create Input devices %\nReason :%",res, GetLastError());
		}

	}

	//
	// Create Bitmap for the Window and update it
	//
	{
		update := UpdateWindow(main_window.handle);
		ShowWindow(main_window.handle, SW_SHOW);

		drawable_area: RECT;
		GetClientRect(main_window.handle, *drawable_area);
		
		main_window.bitmap = create_Bitmap(.{
			x = drawable_area.right - drawable_area.left, 
			y = drawable_area.bottom - drawable_area.top
		});
	}
	return main_window;
}

update_Window :: (window : *Window_Info) #c_call
{
	atomic_volatile_write(*window.bitmap.wait_for_blit, 1);
	RedrawWindow(window.handle, null, null, RDW_INVALIDATE | RDW_UPDATENOW);
	while atomic_volatile_read(*window.bitmap.wait_for_blit) == 1
	{

	}
}



Bitmap :: struct
{
	size : int2;
	stride_in_bytes : int;
	data : [] Pixel; @"assert(data.count >= dimensions.x * dimensions.y);";

	info : BITMAPINFO;
	wait_for_blit : int;
}

DLL :: struct
{
	name : *u16;
	module : HMODULE;
}

load_Dynamic_Library :: (dll_name : string) -> DLL
{
	dll := DLL.{name = utf8_to_wide(dll_name)};
	dll.module = LoadLibraryW(dll.name);
	if !dll.module
	{
		err := GetLastError();
		log_error("Failed load with error %", err);
	}
	return dll;
}

load_Function :: (dll : *DLL, function_name : string) -> *void
{
	name_zero_terminated := to_c_string(function_name);
	defer free(name_zero_terminated);
	addr := GetProcAddress(dll.module, name_zero_terminated);
	err := GetLastError();
	return addr;
}

Thread_Info :: struct
{
	function : (*void) -> int #c_call;
	data : *void;
	handle : HANDLE;
};

#import "Memory";

THREAD_STACK_SIZE :: #run Mebi(8);
THREAD_CREATION_FLAGS : Creation_Flags;

start_Thread :: (f : (*void) -> int #c_call, data : *void) -> Thread #c_call
{
	push_context,defer_pop c;
	handle := CreateThread(null, THREAD_STACK_SIZE, xx f, data, THREAD_CREATION_FLAGS, null);
	if !handle  return xx null;

	thread_id : *DWORD;


	info := array_add(*active_threads);

	<<info = Thread_Info.{function = f, data = data, handle = handle};
	return xx null;
}

stop_Thread :: (thread : Thread)  #c_call
{
	//TODO(Qwendo): implement this
}

get_BackBuffer :: (window : *Window_Info) -> BackBuffer #c_call
{
	bb := BackBuffer.{};
	// Note(Qwendo): This will have to be properly locked once we do multithreading!!!
	// @Race @Threading

	bb.size = window.bitmap.size;
	bb.stride = window.bitmap.stride_in_bytes/size_of(Pixel);
	bb.data = xx window.bitmap.data.data;

	return bb;
}




handle_Events :: (window : *Window_Info) -> (should_exit : bool)
{
	should_exit := false;
	msg : MSG;
	// As soon as the WM_CLOSE is received, this loop
	// does not run anymore  @GracefullyExit
	while PeekMessageW(*msg, window.handle, 0, 0, PM_REMOVE)
	{
		TranslateMessage(*msg);
		DispatchMessageW(*msg);
	}
	should_exit = window.exit;
	if should_exit
	{
		log("we should exit");
	}
	return should_exit;
}

try_Close :: (window : *Window_Info)
{
	// @GracefullyExit so here we set the bitmap to be
	// drawn, it does not matter anymore really
	atomic_volatile_write(*window.bitmap.wait_for_blit, 0);
}

sleep :: (duration_ms : int) #c_call
{
	Sleep(xx duration_ms);
}



get_Input :: (window : Window) -> Input #c_call
{
	win := cast(*Window_Info)window;
	push_context,defer_pop win.window_context;
	in := acquire(*win.input);
	res := in.*;

	in.mouse.delta = .{};
	in.last_retrieval_time = current_time_monotonic();

	release(*win.input);
	return res;
}

// TODO: peek_Input :: (window : Window) -> Input #c_call { // non destructively get most up to date input}



allocate_Large_Page :: (size: int) -> (memory_start : *void) #c_call
{
	if size < 0 return null;
	size_to_allocate := round_Up_To_Multiple(cast(u64) size, multiple_of = GLOBAL_LARGE_PAGE_SIZE);
	if size_to_allocate < 0  return null; 	

	addr := VirtualAlloc(
		lpAddress = xx Tebi(2),
		dwSize = cast(u64)size_to_allocate,
		flAllocationType = MEM_COMMIT | MEM_RESERVE | ifx GLOBAL_LARGE_PAGE_AVAILABLE then MEM_LARGE_PAGES else cast(u32)0,
		flProtect = PAGE_READWRITE,
	);
	if addr == null  
	{	
		initted := GLOBAL_LARGE_PAGE_SIZE_INITTED;
		err := GetLastError();
		curr := GetCurrentProcess();
	}

	return addr;
}

ExceptionRecord :: struct {};
ContextRecord   :: struct {};
Exception_Pointers     :: struct
{
	exception_record : *ExceptionRecord;
	context\ _record : *ContextRecord;
}

register_Diagnostic :: (diag : Diagnostic_Function)  #c_call
{
	array_add_c_call(*functions_to_call_if_crash_occurs, diag);
}

register_Crash_Handler :: ()
{
	#if true
	{
		old_exception_handler_to_call_after_our_processing_is_done = SetUnhandledExceptionFilter(crash_Handler);
		log("Registered crash handler");
	}
}


functions_to_call_if_crash_occurs : Static_Auto_Array(Diagnostic_Function, 4) = .{};
old_exception_handler_to_call_after_our_processing_is_done :type_of(crash_Handler) = null;
handling_a_crash_right_now := false;

recover_dump :: () #c_call
{
	// pause all threads
	
}

dump :: () #c_call
{
	log_file_builder : String_Builder;
	ctx : Context = create_Diagnostic_Context("WINDOWS", *log_file_builder);
	push_context,defer_pop ctx;
	
	path_of_crash_dump := sprint("./dump_%/", to_milliseconds(current_time_monotonic()));
	if make_directory_if_it_does_not_exist(path_of_crash_dump)
	{
		
		for functions_to_call_if_crash_occurs
		{
			if it  
			{
				file_builder : String_Builder;
				file_name:= it(*log_file_builder, *file_builder);
				write_entire_file(sprint("%/%", path_of_crash_dump, file_name), *file_builder);
			}
		}
		write_entire_file(sprint("%/log.txt", path_of_crash_dump), *log_file_builder);
	}
	context.allocator.proc(.SHUTDOWN, 0, 0,null,null);
}


crash_Handler :: (ptr : *EXCEPTION_POINTERS) -> s32 #c_call
{
	if !handling_a_crash_right_now
	{
		handling_a_crash_right_now = true;
		dump();
	}
	if old_exception_handler_to_call_after_our_processing_is_done 
	{
		return old_exception_handler_to_call_after_our_processing_is_done(ptr);
	}
	return 0x01;
}



#scope_file


create_Bitmap :: (size : int2) -> Bitmap
{
	bitmap : Bitmap;
	bitmap.size = size;
	{
		using bitmap.info.bmiHeader;
		biSize   = size_of(type_of(bitmap.info));
		biWidth  = xx size.x;
		biHeight = xx size.y;
		biPlanes = 1;

		biBitCount    = 8 * size_of(Pixel);
		biCompression = BI_RGB;
		bitmap.stride_in_bytes = ((((biWidth * biBitCount) + 31) & ~31) >> 3);
	}

	bitmap_size := bitmap.stride_in_bytes * size.y;
	
	bitmap.data.data  = xx alloc(bitmap_size);
	bitmap.data.count = bitmap_size/size_of(Pixel);

	assert(bitmap_size % size_of(Pixel) == 0);
	
	log("Bitmap has size %", bitmap.size);
	return bitmap;
}

c : Context;


draw_Window :: (window : *Window_Info)
{
	using window;
	scanlines_copied   := StretchDIBits(
		  window.device_context
		, xx 0, xx 0, xx window.size.x, xx window.size.y
		, xx 0, xx 0, xx bitmap.size.x, xx bitmap.size.y
		, bitmap.data.data
		, *bitmap.info
		, DIB_RGB_COLORS
		, rop = xx ROP.SRCCOPY
	);
	if scanlines_copied != bitmap.size.y
	{
		err := GetLastError();
		log_error("[Error]: Windows Error %", err);
	}
	atomic_volatile_write(*window.bitmap.wait_for_blit, 0);
}


UINT :: u32;

window_Proc :: (window_handle : HWND, u_message : UINT, wparam : WPARAM, lparam : LPARAM) -> LRESULT #c_call
{
	window_info : *Window_Info;
	for * active_windows  if it.handle == window_handle  window_info = it;

	result : LRESULT = 0;
	if window_info 
	{
		push_context,defer_pop window_info.window_context;

		if u_message == {
		case WM_PAINT;
			if atomic_volatile_read(*window_info.bitmap.wait_for_blit)
			{
				draw_Window(window_info);
			}

		case WM_SIZE;
			log("We got resized to %", window_info.size);
			window_info.size.x = xx (lparam & 0x0000FFFF) >> 0;
			window_info.size.y = xx (lparam & 0xFFFF0000) >> 16;

		case WM_DESTROY; #through;
		case WM_CLOSE;
			log("Close message %", u_message);
			window_info.exit = true;
			result = DefWindowProcW(window_handle, u_message, wparam, lparam);


		case WM_ACTIVATE;
			// https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-activate
			WA_INACTIVE     :: 0;
			WA_ACTIVE       :: 1;
			WA_CLICKACTIVE :: 2;

			capture_cursor := wparam == WA_ACTIVE || wparam == WA_CLICKACTIVE;
			// Clipping the cursor to the window
			// https://learn.microsoft.com/en-us/windows/win32/learnwin32/other-mouse-operations#confining-the-cursor
			if capture_cursor 
			{
				/*
				pt1 := POINT.{0,0};
				pt2 := POINT.{xx window_info.size.x, xx window_info.size.y};
				ClientToScreen(window_info.handle, *pt1);
				ClientToScreen(window_info.handle, *pt2);
				rect :=  RECT.{pt1.x, pt1.y, pt2.x, pt2.y};
				window_info.active = ClipCursor(*rect) != 0;
				*/
			}
			else
			{
				ClipCursor(null);
				window_info.active = false;
			}
		case WM_MOUSEMOVE;
			//https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-mousemove
			// @BetterMouse
			// Maybe add here that we track where the mouse is?
			// And maybe support modes where the mouse stays in the center of the screen
			in := acquire(*window_info.input);
			in.mouse.position_relative_to_top_left.x =  clamp((lparam >>  0) & 0xFFFF, 0, window_info.bitmap.size.x);
			in.mouse.position_relative_to_top_left.y =  clamp((lparam >> 16) & 0xFFFF, 0, window_info.bitmap.size.y);
			release(*window_info.input);

			

			
		case WM_INPUT;
			// https://web.archive.org/web/20120223150901/http://www.toymaker.info/Games/html/raw_input.html
			size_required : u32;
			GetRawInputData(cast(HRAWINPUT)lparam, RID_INPUT, null, *size_required, size_of(RAWINPUTHEADER));
			if window_info.raw_input_buffer.count < size_required  array_resize(*window_info.raw_input_buffer, size_required);
			GetRawInputData(cast(HRAWINPUT)lparam, RID_INPUT, window_info.raw_input_buffer.data, *size_required, size_of(RAWINPUTHEADER));
			raw : *RAWINPUT = xx window_info.raw_input_buffer.data;
			if raw.header.dwType == RIM_TYPEMOUSE
			{
				mouse_raw := raw.data.mouse;
				if !mouse_raw.usFlags & MOUSE_MOVE_ABSOLUTE
				{
					in := acquire(*window_info.input);
					using in;
					mouse.delta.x += mouse_raw.lLastX;
					mouse.delta.y += mouse_raw.lLastY;
					release(*window_info.input);
				}

			}



				
			
		case WM_KEYDOWN;
			// https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-keydown
			in := acquire(*window_info.input);
			using in;
			now := current_time_monotonic();
			check_And_Set_Pressed :: (windows_code : int, code : Button_Code) #expand
			{
				if wparam == windows_code && key_states[code].start_pressed < key_states[code].stop_pressed
				{
					key_states[code].start_pressed = now;
				}
			}
			// TODO: Refactor this to a lookup
			check_And_Set_Pressed(#char "A", Button_Code.A);
			check_And_Set_Pressed(#char "B", Button_Code.B);
			check_And_Set_Pressed(#char "C", Button_Code.C);
			check_And_Set_Pressed(#char "D", Button_Code.D);
			check_And_Set_Pressed(#char "E", Button_Code.E);
			check_And_Set_Pressed(#char "F", Button_Code.F);
			check_And_Set_Pressed(#char "G", Button_Code.G);
			check_And_Set_Pressed(#char "H", Button_Code.H);
			check_And_Set_Pressed(#char "I", Button_Code.I);
			check_And_Set_Pressed(#char "J", Button_Code.J);
			check_And_Set_Pressed(#char "K", Button_Code.K);
			check_And_Set_Pressed(#char "L", Button_Code.L);
			check_And_Set_Pressed(#char "M", Button_Code.M);
			check_And_Set_Pressed(#char "N", Button_Code.N);
			check_And_Set_Pressed(#char "O", Button_Code.O);
			check_And_Set_Pressed(#char "P", Button_Code.P);
			check_And_Set_Pressed(#char "Q", Button_Code.Q);
			check_And_Set_Pressed(#char "R", Button_Code.R);
			check_And_Set_Pressed(#char "S", Button_Code.S);
			check_And_Set_Pressed(#char "T", Button_Code.T);
			check_And_Set_Pressed(#char "U", Button_Code.U);
			check_And_Set_Pressed(#char "V", Button_Code.V);
			check_And_Set_Pressed(#char "W", Button_Code.W);
			check_And_Set_Pressed(#char "X", Button_Code.X);
			check_And_Set_Pressed(#char "Y", Button_Code.Y);
			check_And_Set_Pressed(#char "Z", Button_Code.Z);

			check_And_Set_Pressed(VK_LBUTTON, Button_Code.MOUSE_LEFT);
			check_And_Set_Pressed(VK_RBUTTON, Button_Code.MOUSE_RIGHT);
			check_And_Set_Pressed(VK_F1, Button_Code.F1);
			check_And_Set_Pressed(VK_F2, Button_Code.F2);
			check_And_Set_Pressed(VK_F3, Button_Code.F3);
			check_And_Set_Pressed(VK_F4, Button_Code.F4);
			check_And_Set_Pressed(VK_F5, Button_Code.F5);
			check_And_Set_Pressed(VK_F6, Button_Code.F6);
			check_And_Set_Pressed(VK_F7, Button_Code.F7);
			check_And_Set_Pressed(VK_F8, Button_Code.F8);
			check_And_Set_Pressed(VK_F9, Button_Code.F9);
			check_And_Set_Pressed(VK_F10, Button_Code.F10);
			check_And_Set_Pressed(VK_F11, Button_Code.F11);
			check_And_Set_Pressed(VK_F12, Button_Code.F12);


			result = 0;
			release(*window_info.input);
		case WM_KEYUP;
			in := acquire(*window_info.input);
			using in;
			now := current_time_monotonic();
			if wparam == 
			{
				case #char "A"; key_states[Button_Code.A].stop_pressed = now;
				case #char "B"; key_states[Button_Code.B].stop_pressed = now;
				case #char "C"; key_states[Button_Code.C].stop_pressed = now;
				case #char "D"; key_states[Button_Code.D].stop_pressed = now;
				case #char "E"; key_states[Button_Code.E].stop_pressed = now;
				case #char "F"; key_states[Button_Code.F].stop_pressed = now;
				case #char "G"; key_states[Button_Code.G].stop_pressed = now;
				case #char "H"; key_states[Button_Code.H].stop_pressed = now;
				case #char "I"; key_states[Button_Code.I].stop_pressed = now;
				case #char "J"; key_states[Button_Code.J].stop_pressed = now;
				case #char "K"; key_states[Button_Code.K].stop_pressed = now;
				case #char "L"; key_states[Button_Code.L].stop_pressed = now;
				case #char "M"; key_states[Button_Code.M].stop_pressed = now;
				case #char "N"; key_states[Button_Code.N].stop_pressed = now;
				case #char "O"; key_states[Button_Code.O].stop_pressed = now;
				case #char "P"; key_states[Button_Code.P].stop_pressed = now;
				case #char "Q"; key_states[Button_Code.Q].stop_pressed = now;
				case #char "R"; key_states[Button_Code.R].stop_pressed = now;
				case #char "S"; key_states[Button_Code.S].stop_pressed = now;
				case #char "T"; key_states[Button_Code.T].stop_pressed = now;
				case #char "U"; key_states[Button_Code.U].stop_pressed = now;
				case #char "V"; key_states[Button_Code.V].stop_pressed = now;
				case #char "W"; key_states[Button_Code.W].stop_pressed = now;
				case #char "X"; key_states[Button_Code.X].stop_pressed = now;
				case #char "Y"; key_states[Button_Code.Y].stop_pressed = now;
				case #char "Z"; key_states[Button_Code.Z].stop_pressed = now;

				case VK_LBUTTON; key_states[Button_Code.MOUSE_LEFT ].stop_pressed = now;
				case VK_RBUTTON; key_states[Button_Code.MOUSE_RIGHT].stop_pressed = now;
				case VK_F1;  key_states[Button_Code.F1] .stop_pressed = now;
				case VK_F2;  key_states[Button_Code.F2] .stop_pressed = now;
				case VK_F3;  key_states[Button_Code.F3] .stop_pressed = now;
				case VK_F4;  key_states[Button_Code.F4] .stop_pressed = now;
				case VK_F5;  key_states[Button_Code.F5] .stop_pressed = now;
				case VK_F6;  key_states[Button_Code.F6] .stop_pressed = now;
				case VK_F7;  key_states[Button_Code.F7] .stop_pressed = now;
				case VK_F8;  key_states[Button_Code.F8] .stop_pressed = now;
				case VK_F9;  key_states[Button_Code.F9] .stop_pressed = now;
				case VK_F10; key_states[Button_Code.F10].stop_pressed = now;
				case VK_F11; key_states[Button_Code.F11].stop_pressed = now;
				case VK_F12; key_states[Button_Code.F12].stop_pressed = now;
			};
			result = 0;
			release(*window_info.input);
			
		case WM_CHAR;
			// https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-char
			result = 0;
		case;
			result = DefWindowProcW(window_handle, u_message, wparam, lparam);
		}
	}else{
		// Windows calls this procedure when we have not yet added the Window_Info
		// So just do the standard thing
		result = DefWindowProcW(window_handle, u_message, wparam, lparam);
	}

	return result;
}





gdi      :: #system_library "Gdi32";
user32   :: #system_library "User32";
kernel   :: #system_library "Kernel32";
advapi32 :: #system_library "Advapi32";


PAINTSTRUCT :: struct {
	hdc    : HDC;
	fErase : BOOL;
	rcPaint: RECT;

	fRestore   : BOOL;
	fIncUpdate : BOOL;
	rgbReserved: [32] u8;
};
StretchDIBits :: (
	  hdc : HDC

	, xDest : s32
	, yDest : s32
	, DestWidth : s32
	, DestHeight : s32
	, xSrc : s32
	, ySrc : s32
	, SrcWidth  : s32
	, SrcHeight : s32

	, lpBits    : *void
	, lpbmi     : *BITMAPINFO
	, iUsage : u32
	, rop : DWORD
) -> s32 #foreign gdi;

BeginPaint :: (
	  hWnd    : HWND
	, lpPaint : *PAINTSTRUCT
) -> HDC #foreign user32; 
EndPaint :: (
	  hWnd    : HWND
	, lpPaint : *PAINTSTRUCT
) -> HDC #foreign user32; 


LONG :: s32;

LUID :: struct { LowPart : DWORD; HighPart : LONG;};
LUID_AND_ATTRIBUTES :: struct
{
	Luid : LUID;
	Attributes : DWORD;
};

TOKEN_PRIVILEGES :: struct
{
	PrivilegeCount : DWORD;
	Privileges : [1] LUID_AND_ATTRIBUTES;
}

GetLargePageMinimum :: () -> u64 #foreign kernel;

OpenProcessToken :: (
	ProcessHandle : HANDLE,
	DesiredAcces  : DWORD,
	TokenHandle   : *HANDLE) -> BOOL #foreign advapi32;

AdjustTokenPrivileges :: (
	TokenHandle : HANDLE,
	DisableAllPrivileges : BOOL,
	NewState : *TOKEN_PRIVILEGES,
	BufferLength : DWORD,
	PreviousState : *TOKEN_PRIVILEGES,
	ReturnLength : *DWORD) -> BOOL #foreign advapi32;


LookupPrivilegeValueW :: (
		lpSystemName : *u16,
		lpName : *u16,
		lpLuid : *LUID
	) -> BOOL #foreign advapi32;

SE_LOCK_MEMORY_NAME :: "SeLockMemoryPrivilege";
SE_PRIVILEGE_ENABLED :: 0x2;
TOKEN_ADJUST_PRIVILEGES : u32 : 0x0020;
TOKEN_QUERY             : u32 : 0x0008;

InvalidateRect :: (
	  hWnd : HWND
	, lpRect : *RECT
	, erase_background : BOOL
) #foreign user32;


HRGN :: HANDLE;
RedrawWindow :: (
	hWnd       : HWND,
	lprcUpdate : * RECT,
	hrgnUpdate : HRGN,
	flags      : u32
) -> BOOL #foreign user32;
// From: http://www.pinvoke.net/search.aspx?search=RDW_INVALIDATE&namespace=[All]
RDW_INVALIDATE : u32 : 0x0001;
RDW_UPDATENOW  : u32 : 0x0100;

WM_ACTIVATE :: 0x0006;

#import "Windows";
#import "Basic";
#import "Windows_Utf8";
#import "Vector";
#import "Atomics";
#import "Sync";
#import "Async_Buffer";
#import "Bucket_Array";
#import "Mutex";
#import "Memory";
#import "IUMath";
#import "Static_Auto_Array";
#import "Diagnostic";
#import "File";
