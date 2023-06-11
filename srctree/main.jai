#import "Common";


PHYSICS_FREQUENCY :: 2;

#program_export
game_entry : ENTRY_FUNCTION : (platform_init : *Platform) #c_call
{
	if !platform_init return;
	platform = platform_init;
	c : Context;
	c.allocator = platform.general_heap;
	c.logger = logger;

	push_context,defer_pop c;
	STARTUP_TIME = current_time_monotonic();

	
	draw_thread_exit : int = 0;
	args := Draw_Args.{exit = *draw_thread_exit, plt = platform, c = *context};
	platform.start_Thread(xx draw, *args);

	while atomic_read(*args.output) == null
	{}

	graphics := atomic_read(*args.output);


	ticks_since_start : int = 0;

	ms_pause : int =  1000/PHYSICS_FREQUENCY;
	pos :float3 = .{x = -0.1, y = -0.1,z = 1};
	
	draw_buffer := get_Write_Pointer(graphics.command_buffer_writer);
	t := 0;
	while atomic_read(*platform.exit) == 0
	{
		Frame();
		input := platform.get_Input(platform.window);


		t += 1;
		draw_buffer.submission_time = current_time_monotonic();



		//pos += .{0.1, 0,0};
		if pos.x > 1.3  pos.x = -1.3;

		



		mat := identity(4, float);
		add_Offset(*mat, pos);

		instance_1 := Model_Instance.{id = 0, model_to_world = mat};
		instance_2 := Model_Instance.{id = 1, model_to_world = identity(4, float)};

		add_Mesh(draw_buffer, instance_1);
		//add_Mesh(draw_buffer, instance_2);
		add_Offset(*instance_1.model_to_world, .{y = -0.1 ,z = -2});
		add_Mesh(draw_buffer, instance_1);

		draw_buffer.camera.position = .{0,1,.1};

		delta :float = ((t % 20)-10)/100.0;
		log("delta %", delta);
		pitch := rotation_Around_Axis(.{-1,0,0}, delta * PI);
		yaw   := rotation_Around_Axis(.{0,1,0},  delta * PI);
		rotation := yaw * pitch ;
		
		draw_buffer.camera.rotation = rotation;
		//draw_buffer.camera.position = pos;
		

		draw_buffer = get_Write_Pointer(graphics.command_buffer_writer);
		clear_Instances(draw_buffer);


		platform.sleep(ms_pause);
	}

	atomic_write(*draw_thread_exit, 1);
	while atomic_read(*draw_thread_exit) != 0
	{}
	
	atomic_write(*platform.exit, 0);
}

logger :: (message : string, data : *void, info : Log_Info)
{
	now := current_time_monotonic() - STARTUP_TIME;
	print("[PHYSICS]+%: %\n", to_milliseconds(now),message);
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
#import "Tracy";
