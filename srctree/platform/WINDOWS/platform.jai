#scope_export
#load "../interface.jai";
INTERFACE :: #import,file "../interface.jai";

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
	exit           : bool;
};

active_windows : [..] Window_Info;
active_threads : [..] Thread_Info;


create_Window :: (display_name : string, size : int2) -> *Window_Info #must
{
	//
	// Window Creation
	//
	c =  context;
	main_window : *Window_Info = array_add(*active_windows);
	main_window.window_context = c;
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
			log_error("Failed to register window class %\n", main_window.window_class);
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
		print("Adjusted rect %\n", rect);
		main_window.size = .{rect.right - rect.left, rect.bottom - rect.top};
		print("%\n", main_window.size);

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
		if !main_window.handle  log_error("[ERROR] Failed to create window\nReason :%", GetLastError());
		main_window.device_context = GetDC(main_window.handle);
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
	RedrawWindow(window.handle, null, null, RDW_INVALIDATE | RDW_UPDATENOW);
}



Bitmap :: struct
{
	size : int2;
	stride_in_bytes : int;
	data : [] Pixel; @"assert(data.count >= dimensions.x * dimensions.y);";

	info : BITMAPINFO;
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
		print("Failed load with %\n", err);
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

THREAD_STACK_SIZE :: #run Megabytes(8);
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
	while PeekMessageW(*msg, window.handle, 0, 0, PM_REMOVE)
	{
		TranslateMessage(*msg);
		DispatchMessageW(*msg) <= 0;
	}
	print("After handle events %\n", should_exit);
	should_exit = window.exit;
	if should_exit print("we should exit\n");
	return should_exit;
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
	
	print("Bitmap has size %\n", bitmap.size);
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
		log_error("[Error]: Windows Error %\n", err);
	}
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
			draw_Window(window_info);

		case WM_SIZE;
			print("We got resized to %\n", window_info.size);
			window_info.size.x = xx (lparam & 0x0000FFFF) >> 0;
			window_info.size.y = xx (lparam & 0xFFFF0000) >> 16;

		case WM_DESTROY; #through;
		case WM_CLOSE;
			print("Close message %\n", u_message);
			window_info.exit = true;
			result = DefWindowProcW(window_handle, u_message, wparam, lparam);
		
		case WM_ACTIVATEAPP;
		
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

#import "Windows";
#import "Basic";
#import "Windows_Utf8";
#import "Vector";
