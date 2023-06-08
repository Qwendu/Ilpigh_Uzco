#import "Common";


PHYSICS_FREQUENCY :: 50;

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

	graphics := atomic_read(*args.output);


	ticks_since_start : int = 0;

	ms_pause : int =  1000/PHYSICS_FREQUENCY;
	
	draw_buffer := get_Write_Pointer(graphics.command_buffer_writer);
	while atomic_read(*platform.exit) == 0
	{
		clear_Instances(draw_buffer);


		mat := identity(4, float);

		instance_1 := Model_Instance.{id = 0, model_to_world = mat};
		instance_2 := Model_Instance.{id = 1, model_to_world = identity(4, float)};

		add_Mesh(draw_buffer, instance_1);
		add_Mesh(draw_buffer, instance_2);

		draw_buffer.camera.position = .{0,1,.1};

		delta :float = - 0.5;
		pitch := rotation_Around_Axis(.{1,0,0}, 0 * PI);
		yaw   := rotation_Around_Axis(.{0,1,0}, delta * 0 * PI);
		rotation := yaw * pitch ;
		
		draw_buffer.camera.rotation = rotation;
		

		draw_buffer.submission_time = current_time_monotonic();
		draw_buffer = get_Write_Pointer(graphics.command_buffer_writer);
		platform.sleep(ms_pause);
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
#import "Async_Buffer";
#import "Math";
#import "Vector";
#import "Matrix";
#import "Quaternion";
