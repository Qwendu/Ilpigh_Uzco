#scope_export

draw_Debug_Visualizations :: (draw_buffer : *Draw_Buffer)
{
	for arrows
	{
		add_Line(draw_buffer, start = it.start, end = it.end, color = it.color);
	}
}

#scope_module


Arrow :: struct
{
	start : float3;
	end   : float3;
	color : Color;
};

dbg_Arrow :: (start : float3, end : float3, color : Color = RED) #expand
{
	array_add(*arrows, .{start = start, end = end, color = color});
}

dbg_Line :: (start : float3, end : float3, color : Color = BLUE) #expand
{
	array_add(*arrows, .{start = start, end = end, color = color});
}

dbg_Clear_Visualizations :: () #expand
{
	arrows.count = 0;
	lines.count  = 0;
}

arrows : Static_Auto_Array(100, Arrow);
lines  : Static_Auto_Array(100, Line);

#import "Line";
#import "Draw_Buffer";
#import "Color";
