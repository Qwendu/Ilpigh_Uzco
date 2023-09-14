#scope_export

draw_Debug_Visualizations :: (draw_buffer : *Draw_Buffer)
{
	for arrows
	{
		add_Line(draw_buffer, start = it.start, end = it.end, color = it.color);
	}
	for lines
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

/*
dbg_Arrow :: (start : float3, end : float3, color : Color = RED)
{
	array_add(*arrows, .{start = start, end = end, color = color});
}
*/

dbg_Line :: (start : float3, end : float3, color : Color = BLUE)
{
	array_add(*lines, .{start = start, end = end, color = color});
}

dbg_AABB :: (min : float3, max : float3, color : Color = YELLOW)
{
	dbg_Line(min, .{min.x, min.y, max.z}, color);
	dbg_Line(min, .{min.x, max.y, min.z}, color);
	dbg_Line(min, .{max.x, min.y, min.z}, color);

	dbg_Line(max, .{max.x, max.y, min.z}, color);
	dbg_Line(max, .{max.x, min.y, max.z}, color);
	dbg_Line(max, .{min.x, max.y, max.z}, color);

	dbg_Line(.{min.x, max.y, max.z}, .{min.x, min.y, max.z}, color);
	dbg_Line(.{max.x, min.y, max.z}, .{min.x, min.y, max.z}, color);

	dbg_Line(.{min.x, max.y, max.z}, .{min.x, max.y, min.z}, color);
	dbg_Line(.{max.x, max.y, min.z}, .{min.x, max.y, min.z}, color);

	dbg_Line(.{max.x, min.y, max.z}, .{max.x, min.y, min.z}, color);
	dbg_Line(.{max.x, max.y, min.z}, .{max.x, min.y, min.z}, color);
}

dbg_AABB :: (aabb : $T/interface AABB, color : Color = YELLOW)
{
	dbg_AABB(aabb.min, aabb.max, color);
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
