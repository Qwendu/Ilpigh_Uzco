#import "Common";


#program_export
game_entry : ENTRY_FUNCTION : (platform_init : *Platform) #c_call
{
	if !platform_init return;
	platform = platform_init;
	c : Context;
	c.allocator = platform.general_heap;

	push_context,defer_pop c;

	
	draw_thread_exit : int = 0;
	args := Draw_Args.{exit = *draw_thread_exit, plt = platform, c = *context};
	platform.start_Thread(xx draw, *args);

	while atomic_read(*args.output) == null
	{}

	graphics := args.output;



	positions := float3.[
		.{0,0,-1},
		.{1,0,-1},
		.{2,0,-1},
		.{3,0,-1},
	];

	ticks_since_start : int = 0;

	loop := 100;
	
	while atomic_read(*platform.exit) == 0
	{
		center : float3 = .{y=1};// positions[ticks_since_start % positions.count];
		print("center = %\n", center);
		draw_buffer := get_Write_Pointer(graphics.command_buffer_writer);
		<<draw_buffer = .{};

		mat := identity(4, float);
		//mat.row_vectors[0].w = center.x;
		//mat.row_vectors[1].w = center.y;
		//mat.row_vectors[2].w = center.z;

		add_Mesh(draw_buffer, 0, mat);
		add_Mesh(draw_buffer, 1, mat);
		draw_buffer.camera.position = center;

		delta :float = ticks_since_start/cast(float)loop - 0.5;
		pitch := rotation_Around_Axis(.{1,0,0}, 0.3 * PI);
		yaw   := rotation_Around_Axis(.{0,1,0}, delta * 0.5 * PI);
		rotation := yaw * pitch ;
		
		draw_buffer.camera.rotation = rotation;
		
		ticks_since_start = (ticks_since_start + 1)%loop;
		platform.sleep(250);
	}

	atomic_write(*draw_thread_exit, 1);
	while atomic_read(*draw_thread_exit) != 0
	{}
	
	atomic_write(*platform.exit, 0);
}


platform : *Platform;




#import,file "Graphics.jai";
#import "Basic";
#import "Atomics";
#import "AsyncBuffer";
#import "Math";
#import "Vector";
#import "Matrix";
#import "Quaternion";
