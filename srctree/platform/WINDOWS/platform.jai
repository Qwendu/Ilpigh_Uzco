#scope_export
INTERFACE :: #import,file "../interface.jai";

Window_Info :: struct
{
	module       : HINSTANCE;
	handle       : HWND;
	bitmap       : Bitmap;
	size         : int2;
	display_name : string;
	class_name   : string;
	window_class : WNDCLASSEXW;
	wnd_Proc     : *void;
	device_context : HDC;
};

active_windows : [..] Window_Info;


platform_main :: (display_name : string)
{
	//
	// Window Creation
	//
	array_add(*active_windows, .{});
	
	c =  context;
	main_window_idx := active_windows.count - 1;
	main_window : *Window_Info = *active_windows[main_window_idx];
	{
		main_window.size = .{300, 300};

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
			return;
		}
		style := WS_VISIBLE | WS_SYSMENU;
		
		main_window.display_name = sprint("%\0", display_name); 

		main_window.handle = CreateWindowExW
		(
			   dwExStyle     = 0
			,  lpClassName   = utf8_to_wide(main_window.class_name)
			,  lpWindowName  = utf8_to_wide(main_window.display_name)
			,  dwStyle       = xx style
			,  x = 0
			,  y = 0
			,  nWidth  = xx main_window.size.x
			,  nHeight = xx main_window.size.y
			,  hwndParent = null
			,  hMenu      = null
			,  hInstance  = main_window.module
			,  lpParam    = null
		);
		if !main_window.handle  log_error("[ERROR] Failed to create window\nReason :%", GetLastError());
		//
		// Because CreateWindowExW does not init the size of the drawable region to what we specified ..
		//
		{
			size := main_window.size;
			r := RECT.{xx 0,xx 0, xx size.x, xx size.y};
			AdjustWindowRect(*r, 0, 0);
		}
		main_window.device_context = GetDC(main_window.handle);
		update := UpdateWindow(main_window.handle);
		ShowWindow(main_window.handle, SW_SHOW);
		main_window.bitmap = create_Bitmap(main_window.size);
	}
	y := 0;
	while true
	{
		y = (y + 1) % main_window.bitmap.size.y;
		for x: 0..main_window.bitmap.size.x-1
		{
			print("% %\n", x, y);
			main_window.bitmap.data[y * main_window.bitmap.size.x + x] = .{r = 255, g = 255};
		}
		RedrawWindow(main_window.handle, null, null, RDW_INVALIDATE | RDW_UPDATENOW);
	}
}

Pixel :: struct
{
	r : u8;
	g : u8;
	b : u8;
	a : u8;
}

Bitmap :: struct
{
	size : int2;
	stride : int;
	data : [] Pixel; @"assert(data.count >= dimensions.x * dimensions.y);";

	info : BITMAPINFO;
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
		bitmap.stride = ((((biWidth * biBitCount) + 31) & ~31) >> 3);
	}

	bitmap_size := bitmap.stride * size.y;
	
	bitmap.data.data  = xx alloc(bitmap_size);
	bitmap.data.count = bitmap_size/size_of(Pixel);

	assert(bitmap_size % size_of(Pixel) == 0);
	

	return bitmap;
}

c : Context;


draw_Window :: (window : *Window_Info) #c_call
{
	using window;
	scanlines_copied   := StretchDIBits(
		  window.device_context
		, xx 0, xx 0, xx bitmap.size.x, xx bitmap.size.y
		, xx 0, xx 0, xx bitmap.size.x, xx bitmap.size.y
		, bitmap.data.data
		, *bitmap.info
		, DIB_RGB_COLORS
		, rop = xx ROP.SRCCOPY
	);
	push_context c
	{
		if scanlines_copied != bitmap.size.y
		{
			err := GetLastError();
			log_error("[Error]: Windows Error %\n", err);
		}
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
		// Windows calls this procedure when we have not yet added the Window_Info
		// So just do the standard thing

		if u_message == {
		case WM_PAINT;
			draw_Window(window_info);
		case;
			result = DefWindowProcW(window_handle, u_message, wparam, lparam);
		}
	}else{
		result = DefWindowProcW(window_handle, u_message, wparam, lparam);
	}
	return result;
}


gdi      :: #system_library "Gdi32";
user32   :: #system_library "user32";
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
RDW_INVALIDATE : u32 : ;

#import "Windows";
#import "Basic";
#import "Windows_Utf8";
#import "Vector";
