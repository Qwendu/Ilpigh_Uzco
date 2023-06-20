#import "Common";



#add_context STARTUP_TIME : Apollo_Time;

PHYSICS_FREQUENCY :: 100;

#program_export
game_entry : ENTRY_FUNCTION : (platform_init : *Platform) #c_call
{
	Profiler.NameThread(#procedure_name());
	if !platform_init return;
	platform = platform_init;
	c : Context;
	c.STARTUP_TIME = platform.STARTUP_TIME;
	c.allocator = platform.general_heap;
	c.logger = logger;

	push_context,defer_pop c;

	
	draw_thread_exit : int = 0;
	args := Draw_Args.{exit = *draw_thread_exit, plt = platform, c = *context};
	platform.start_Thread(xx draw, *args);

	while atomic_volatile_read(*args.output) == null
	{
		//log("Waiting for drawing thread to startup");
	}
	log("Drawing thread has started up");

	graphics := atomic_volatile_read(*args.output);


	ticks_since_start : int = 0;

	ms_pause : int =  1000/PHYSICS_FREQUENCY;
	
	draw_buffer := get_Write_Pointer(graphics.command_buffer_writer);

	position := float3.{y = 2, z = 5};
	camera_pitch_yaw : float2 = .{y = -.2};
	
	log("Entering Main Loop");
	
	while atomic_volatile_read(*platform.exit) == 0
	{
		DELTA :: 1.0/PHYSICS_FREQUENCY;
		Profiler.Frame("Physics");
		now := current_time_monotonic();
#import "Tracy"(PROFILER);

		input := ifx IGNORE_INPUT then Input.{} else platform.get_Input(platform.window);

		mouse_delta := float2.{input.mouse.delta.x * 0.1, input.mouse.delta.y * 0.1};
		
	
		draw_buffer.submission_time = current_time_monotonic();
		draw_buffer.mouse_position_relative_to_top_left = input.mouse.position_relative_to_top_left;

		{
			//
			// Movement
			//
			velocity :float3;
			{
				if(is_Button_Pressed(*input, .W)) velocity += .{ 0, 0,-1};
				if(is_Button_Pressed(*input, .A)) velocity += .{-1, 0, 0};
				if(is_Button_Pressed(*input, .S)) velocity += .{ 0, 0, 1};
				if(is_Button_Pressed(*input, .D)) velocity += .{ 1, 0, 0};
				if(is_Button_Pressed(*input, .Q)) velocity += .{ 0, 1, 0};
				if(is_Button_Pressed(*input, .E)) velocity += .{ 0,-1, 0};

			}
			//
			// Rotation
			//
			{
				rot : float2;
				#if false
				{
					if(is_Button_Pressed(*input, .I))  rot += .{ 0, 1};
					if(is_Button_Pressed(*input, .J))  rot += .{-1, 0};
					if(is_Button_Pressed(*input, .K))  rot += .{ 0,-1};
					if(is_Button_Pressed(*input, .L))  rot += .{ 1, 0};
				}else{
				
					rot = mouse_delta * 1.0;
					rot.y *= -1;
				}
				camera_pitch_yaw += rot * DELTA;
				camera_pitch_yaw.y = clamp(camera_pitch_yaw.y, -PI/2, PI/2);
			}
			pitch := rotation_Around_Axis(.{-1,0,0}, camera_pitch_yaw.y);
			yaw   := rotation_Around_Axis(.{0,1,0},  camera_pitch_yaw.x);
			rotation := pitch * yaw;
			camera_orientation := rotation_Matrix(inverse(rotation));
			
			position += affine_Transform(camera_orientation,velocity).xyz * DELTA;
			draw_buffer.camera.position = position;
			draw_buffer.camera.rotation = rotation;
			draw_buffer.camera.far = 12;
			log("(% % %)  (% %)", position.x, position.y, position.z, camera_pitch_yaw.y, camera_pitch_yaw.x);
		}
	
		//
		// Scene
		//
		{
			mat := identity(4, float);
			//add_Mesh(draw_buffer, .{id = 3, model_to_world = mat});

			floor_tile := Model_Instance.{id = 2, model_to_world = identity(4, float)};
			EXTENT :: 1;
			for y: 0..EXTENT
			{
				for x: 0..EXTENT
				{
					offset := float3.{xx (x - 1),xx (y - 1), -1};
					model_to_world_matrix := add_Offset(mat, offset);
					floor_tile.model_to_world = model_to_world_matrix;
					//add_Mesh(draw_buffer, floor_tile);
				}
			}

			instance_1 := Model_Instance.{id = 0, model_to_world = mat};
			instance_2 := Model_Instance.{id = 1, model_to_world = identity(4, float)};
			//add_Mesh(draw_buffer, instance_1);
			//add_Mesh(draw_buffer, instance_2);
			//add_Offset(*instance_1.model_to_world, .{y = -0.1 ,z = -2});
			//add_Mesh(draw_buffer, instance_1);

			add_Light_Source(draw_buffer, .{position = .{0, 2, 0}, range = 5, color = .{1,1,1,1}});
			add_Light_Source(draw_buffer, .{position = .{0, -2, 0}, range = 5, color = .{1,1,1,1}});
		}
		
		//
		// Physics
		//
		{
			PVA :: struct(T : Type)
			{
				position     : T;
				velocity     : T;
				acceleration : T;
			}
			PO :: struct
			{
				translation : PVA(float3);
				rotation    : PVA(Quaternion);
			}
			p1 : float3;
			add_Mesh(draw_buffer, .{4, identity(4, float)});
			
		}







		

		draw_buffer = get_Write_Pointer(graphics.command_buffer_writer);
		clear_Instances(draw_buffer);


		platform.sleep(ms_pause);
	}

	atomic_volatile_write(*draw_thread_exit, 1);
	while atomic_volatile_read(*draw_thread_exit) != 0
	{
		//log("Waiting for exit");
	}
	
	atomic_volatile_write(*platform.exit, 0);
}

logger :: (message : string, data : *void, info : Log_Info)
{
	now := current_time_monotonic() - context.STARTUP_TIME;
	print("[PHYSICS]+%: %\n", to_milliseconds(now),message);
}


platform : *Platform;




#import,file "Graphics.jai"(PROFILER);
Profiler :: #import "Tracy"(PROFILER);
#import "Basic";

#import "Async_Buffer";
#import "Math";
#import "Vector";
#import "Matrix";
#import "Quaternion";
#import "Atomics";
#import "Sync";
