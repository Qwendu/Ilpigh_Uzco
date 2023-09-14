#import "Common";

#add_context STARTUP_TIME : Apollo_Time;


#program_export
game_entry : ENTRY_FUNCTION : (platform_init : *Platform) #c_call
{
	Profiler.NameThread(#procedure_name());
	if !platform_init return;
	init(*platform_init.calls);
	c : Context;
	c.STARTUP_TIME = platform_init.STARTUP_TIME;
	c.allocator = platform.general_heap;
	c.logger = logger;



	push_context,defer_pop c;

	draw_context := context;
	{
		
	}
	
	draw_thread_exit : int = 0;
	args := Draw_Args.{
		exit         = *draw_thread_exit,
		window       = platform_init.window,
		startup_time = context.STARTUP_TIME,
		draw_context = draw_context
	};

	platform.start_Thread(xx render_Thread, *args);
	platform.register_Diagnostic(diagnostics_For_Physics);
	

	while atomic_volatile_read(*args.output) == null
	{
		//log("Waiting for drawing thread to startup");
	}
	log("Drawing thread has started up");

	graphics := atomic_volatile_read(*args.output);



	ms_pause : int =  1000/PHYSICS_FREQUENCY;
	
	draw_buffer := get_Write_Pointer(graphics.command_buffer_writer);

	position := float3.{-3.320918,  1.891694, -3.306482};
	camera_pitch_yaw := float2.{-3.98, -0.3954};
	
	N_COLLISIONS := 0;
	log("Entering Main Loop");


	obj1, obj2, obj3, obj4 : Physics_ID;
	reset_Physics :: () #expand
	{
		log("Reset Simulation with state:");
		log("% Hz:", PHYSICS_FREQUENCY);
		log("Number of collisions %", N_COLLISIONS);

		reset_Entire_Physics_State();

	#if true
	{
		obj1 = create_Physics_Object(Physics_Base.{translation = .{.{0,0,0}, .{}, .{}}}, TETRAEDER_DEFAULT);
		obj2 = create_Physics_Object(Physics_Base.{translation = .{.{3,0,0}, .{}, .{}}}, TETRAEDER_DEFAULT);
		obj3 = create_Physics_Object(Physics_Base.{translation = .{.{0,0,3}, .{}, .{}}}, TETRAEDER_DEFAULT);
		obj4 = create_Physics_Object(Physics_Base.{translation = .{.{3,0,3}, .{}, .{}}}, TETRAEDER_DEFAULT);
	}else{
		obj1 = create_Physics_Object(Physics_Base.{translation = .{.{0,0,0}, .{1,0,0}, .{}}}, TETRAEDER_DEFAULT);
		obj2 = create_Physics_Object(Physics_Base.{translation = .{.{3,0,0}, .{0,0,1}, .{}}}, TETRAEDER_DEFAULT);
		obj3 = create_Physics_Object(Physics_Base.{translation = .{.{0,0,3}, .{0,0,-1}, .{}}}, TETRAEDER_DEFAULT);
		obj4 = create_Physics_Object(Physics_Base.{translation = .{.{3,0,3}, .{-1,0,0}, .{}}}, TETRAEDER_DEFAULT);

	}
	}

	reset_Physics();
	

	while atomic_volatile_read(*platform_init.exit) == 0
	{
		DELTA :: 1.0/PHYSICS_FREQUENCY;

		Profiler.Frame("Physics");
		now := current_time_monotonic();

		input := ifx IGNORE_INPUT then Input.{} else platform.get_Input(platform_init.window);

		if was_Button_Just_Pressed(*input, .F11)
		{
			log("F11 pressed, we are saving a dump");
			platform.dump();
		}
		mouse_delta := float2.{input.mouse.delta.x * 0.1, input.mouse.delta.y * 0.1};
		
		DO_PHYSICS_STEP :bool = true;
	
		draw_buffer.submission_time = current_time_monotonic();
		draw_buffer.mouse_position_relative_to_top_left = input.mouse.position_relative_to_top_left;

		if is_Button_Pressed(*input, .P) log("%:%", position, camera_pitch_yaw);

		{
			if is_Button_Pressed(*input, .R) reset_Physics();
			if is_Button_Pressed(*input, .N) DO_PHYSICS_STEP = true;
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
				velocity *= 3;
			}
			//
			// Rotation
			//
			{
				rot : float2;
				rot = mouse_delta * 1.0;
				rot.y *= -1;
				
				if is_Button_Pressed(*input, .MOUSE_LEFT)
				{
					camera_pitch_yaw += rot * DELTA;
					camera_pitch_yaw.y = clamp(camera_pitch_yaw.y, -PI/2, PI/2);
				}
			}
			pitch := rotation_Around_Axis(.{-1,0,0}, camera_pitch_yaw.y);
			yaw   := rotation_Around_Axis(.{0,1,0},  camera_pitch_yaw.x);
			rotation := pitch * yaw;

			camera_orientation := rotation_Matrix(inverse(rotation));
			while camera_pitch_yaw.x >= 2 * PI  camera_pitch_yaw.x -= 2 * PI;
			while camera_pitch_yaw.x <  0       camera_pitch_yaw.x += 2 * PI;
			
			position += affine_Transform(camera_orientation,velocity).xyz * DELTA;
			draw_buffer.camera.position = position;
			draw_buffer.camera.rotation = rotation;
			draw_buffer.camera.far = 20;
		}

		gizmo_At :: (center : float3, size : float = 1) #expand
		{
			add_Line(draw_buffer, center, center + .{y = size}, GREEN);
			add_Line(draw_buffer, center, center + .{z = size}, BLUE);
			add_Line(draw_buffer, center, center + .{x = size}, RED);
		}
	
		//
		// Scene
		//
		{
			p1 := float3.{-2,  2, 0};
			add_Light_Source(draw_buffer, .{position = p1, range = 10, color = .{1,1,1,1}});
			gizmo_At(p1);

			gizmo_At(.{}, 10);
			//array_add(*draw_buffer.bezier_3d, Bezier_Curve_3D.{control_points = .[.{}, .{1,1,0}, .{2,0,0}]});
			//array_add(*draw_buffer.bezier_3d, Bezier_Curve_3D.{control_points = .[.{}, .{1,0,1}, .{2,1,0}]});
			//array_add(*draw_buffer.bezier_3d, Bezier_Curve_3D.{control_points = .[.{}, .{0,1,0}, .{0,0,1}]});
	
		}
		
		//
		// Physics
		//
		if true
		{
			tick_Physics();
			draw_Debug_Visualizations(draw_buffer);

			id := identity(4, float);
			for *< Physics_Objects_Iterator(.TETRAEDER).{}
			{
				o := it;
				instance_Mesh(draw_buffer, .{get_Mesh_ID("tet"), add_Offset(id, o.translation.position)});
				add_Line(draw_buffer, o.shape.vertices[0] + o.translation.position, o.shape.vertices[1] + o.translation.position, RED);
				add_Line(draw_buffer, o.shape.vertices[0] + o.translation.position, o.shape.vertices[2] + o.translation.position, RED);
				add_Line(draw_buffer, o.shape.vertices[0] + o.translation.position, o.shape.vertices[3] + o.translation.position, RED);
				add_Line(draw_buffer, o.shape.vertices[1] + o.translation.position, o.shape.vertices[2] + o.translation.position, RED);
				add_Line(draw_buffer, o.shape.vertices[1] + o.translation.position, o.shape.vertices[3] + o.translation.position, RED);
				add_Line(draw_buffer, o.shape.vertices[2] + o.translation.position, o.shape.vertices[3] + o.translation.position, RED);
			}

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
	
	atomic_volatile_write(*platform_init.exit, 0);
}

logger :: (message : string, data : *void, info : Log_Info)
{
	now := current_time_monotonic() - context.STARTUP_TIME;
	for String_By_Line.{message}
	{
		print("[PHYSICS]+%: %\n", to_milliseconds(now), it);
	}
}



#import,file "Graphics.jai";
#import,file "Physics.jai";
#import "Draw_Buffer";
Profiler :: #import "Tracy";
#import "Basic";

#import "Async_Buffer";
#import "Math";
#import "Vector";
#import "Matrix";
#import "Quaternion";
#import "Atomics";
#import "Sync";
#import "Color";
#import "Sort";
#import "IUMath";
#import "Camera";
#import "Logging_Utils";
#import "Input_System";
#import "Platform_Interface";
#import "Bezier";
#import "Static_Auto_Array";
