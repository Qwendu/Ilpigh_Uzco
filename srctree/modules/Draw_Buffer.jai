#scope_export


Draw_Buffer :: struct
{
	submission_time : Apollo_Time;
	mouse_position_relative_to_top_left : int2;
	
	instances     : Static_Auto_Array(600, Mesh_Instance);
	light_sources : Static_Auto_Array(20, Light_Source);

	lines     : Static_Auto_Array(8000, Line);
	bezier_2d : Static_Auto_Array(100, Bezier_Curve_2D);
	bezier_3d : Static_Auto_Array(100, Bezier_Curve_3D);

	camera : Camera;
};

add_Light_Source :: (buffer : *Draw_Buffer, light : Light_Source)
{
	if buffer.light_sources.count == buffer.light_sources.data.count
	{
		log_error("Too many lights got queued");
	}
	array_add(*buffer.light_sources, light);
}

instance_Mesh :: (buffer : *Draw_Buffer, instance : Mesh_Instance)
{
	if buffer.instances.count == buffer.instances.data.count
	{
		log_error("Too many meshes got queued!");
	}
}

add_Line :: (buffer : *Draw_Buffer, start : float3, end : float3, color : Color)
{
	if buffer.lines.count == buffer.lines.data.count
	{
		log_error("Too many lines got queued!");
	}
	array_add(*buffer.lines, .{start, end, color});
}

#scope_file
#import "Light";
#import "Mesh";
#import "Line";
#import "Vector";
#import "Camera";
#import "Static_Auto_Array";
#import "Bezier";
#import "Color";
#import "Basic";
