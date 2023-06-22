#import "Common";



#add_context STARTUP_TIME : Apollo_Time;


objects : [3] PO;
collision_points : [..] float3;




PHYSICS_FREQUENCY :: 100;

#program_export
game_entry : ENTRY_FUNCTION : (platform_init : *Platform) #c_call
{
	BOUNDING_SPHERE_COLLISIONS :: false;


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

	position := float3.{x = 2.22,y = 1.2, z = 2.3};
	camera_pitch_yaw : float2 = .{y = -PI/4};
	
	N_COLLISIONS := 0;
	log("Entering Main Loop");
	reset_Physics :: () #expand
	{
		log("Reset Simulation with state:");
		log("% Hz:", PHYSICS_FREQUENCY);
		log("Number of collisions %", N_COLLISIONS);
		N_COLLISIONS = 0;
		for objects
		{
			log("[%] pos %", it_index, it.translation.position);
			log("[%] vel %", it_index, it.translation.velocity);
		}
		for collision_points
		{
			log("[%] %", it_index, it);
		}
		array_reset(*collision_points);


		objects[0].translation.position = .{y =  4};
		objects[0].translation.velocity = .{y = -0.8};
		objects[0].mass = 1;

		objects[1].translation.position = .{y =  1};
		objects[1].translation.velocity = .{x =  0};
		objects[1].mass = 0.01;
#if objects.count > 2
{
		objects[2].translation.position = .{y = -5};
		objects[2].translation.velocity = .{y =  0.2};
		objects[2].mass = 1;
}
		
		for objects  log("[%] vol = %", it_index, orientation(it.tet[0], it.tet[1],it.tet[2],it.tet[3]));

	}
	reset_Physics();
	

	while atomic_volatile_read(*platform.exit) == 0
	{
		DELTA :: 1.0/PHYSICS_FREQUENCY;
		Profiler.Frame("Physics");
		now := current_time_monotonic();

		input := ifx IGNORE_INPUT then Input.{} else platform.get_Input(platform.window);

		mouse_delta := float2.{input.mouse.delta.x * 0.1, input.mouse.delta.y * 0.1};
		
		DO_PHYSICS_STEP :bool = false;
	
		draw_buffer.submission_time = current_time_monotonic();
		draw_buffer.mouse_position_relative_to_top_left = input.mouse.position_relative_to_top_left;

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
			dt :: DELTA;
			gizmo_At :: (center : float3, size : float = 1) #expand
			{
				add_Line(draw_buffer, center, center + .{y = size}, GREEN);
				add_Line(draw_buffer, center, center + .{z = size}, BLUE);
				add_Line(draw_buffer, center, center + .{x = size}, RED);
			}

			for objects  if length_Squared(it.translation.position) > 100
			{
				reset_Physics();
				break;
			}
			
			for *o, i: objects
			{
				o.translation.velocity += o.translation.acceleration * dt;
				//gizmo_At(o.translation.position);!
			}
			collision_pairs : [..] struct {a : int; b : int; time : float; a_point : float3; b_point : float3; normal : float3;};
			array_reserve(*collision_pairs, objects.count * objects.count - 1);
			defer array_free(collision_pairs);


			//log("O(n^2) Collision checking loop:");
			for active_idx : 0..objects.count-1
			{
				active := *objects[active_idx];
				active.local_time = 0;

				//add_Line(draw_buffer, active.start, active.end, GREEN);
				for colliding_with_idx : active_idx+1..objects.count-1
				{
					colliding_with := *objects[colliding_with_idx];

					time, colliding, active_point, colliding_with_point, normal := cast_Tetraeder(active, colliding_with, dt);
					if colliding 
					{
						array_add(*collision_pairs, .{
							a = active_idx,
							b = colliding_with_idx, 
							time = time,
							a_point = active_point, 
							b_point = colliding_with_point, 
							normal = normal
						});
					}
				}
			}
			
			for collision_pairs
			{
				a := *objects[it.a];
				b := *objects[it.b];
				a_col := a.translation.position + it.time * a.translation.velocity;
				b_col := b.translation.position + it.time * b.translation.velocity;
				//add_Line(draw_buffer, a.translation.position, a_col, BLUE);
				//add_Line(draw_buffer, b.translation.position, b_col, GREEN);
				//add_Line(draw_buffer, a_col, b_col, RED);
			}
			cmp :: (a : type_of(collision_pairs.data[0]), b : type_of(a)) -> s64
			{
				delta := a.time - b.time;
				if delta > 0  return  1;
				if delta < 0  return -1;
				return 0;
			}
			quick_sort(collision_pairs, cmp);
			current_time : float = 0;

			advance_In_Time_To_No_Collision :: (obj : * PO, time : float) #expand
			{
				if DO_PHYSICS_STEP  log("Advancing [%] to time % from %", obj, time, current_time);
				assert(time >= current_time);
				delta_time := time - current_time;
				assert(obj.local_time <= time);
				distance_traveled := (time - current_time) * (obj.translation.velocity);
				if DO_PHYSICS_STEP  obj.translation.position += distance_traveled;
			}
			FOLLOW_UP_COLLISIONS := 0;

			for collision_pairs
			{
				N_COLLISIONS += 1;
				
				a := *objects[it.a];
				b := *objects[it.b];

#if BOUNDING_SPHERE_COLLISIONS //--------------------------------------------
{
	#run print("Bounding Sphere Collisions only\n");
				
				assert(it.time >= current_time);
				advance_In_Time_To_No_Collision(a, it.time);
				advance_In_Time_To_No_Collision(b, it.time);
				current_time = it.time;
				add_Line(draw_buffer, a.translation.position, b.translation.position, PURPLE);

				direction := normalize(b.translation.position - a.translation.position, .{});
				
				a_vel_in_direction := dot(a.translation.velocity, direction);
				a.translation.velocity -= direction * a_vel_in_direction;

				b_vel_in_direction := dot(b.translation.velocity, direction);
				b.translation.velocity -= direction * b_vel_in_direction;
				array_add(*collision_points, a.translation.position + direction * a.bounding_sphere_radius);
				combined_mass := a.mass + b.mass;

				a_vel_in_direction_after := (a.mass - b.mass)/combined_mass * a_vel_in_direction + 2 * b.mass/combined_mass * b_vel_in_direction;
				b_vel_in_direction_after := 2 * a.mass/combined_mass * a_vel_in_direction + (b.mass - a.mass)/combined_mass * b_vel_in_direction;

				a_change := direction * a_vel_in_direction_after;
				b_change := direction * b_vel_in_direction_after;
				a.translation.velocity += a_change;
				b.translation.velocity += b_change; 
				
				//
				// @Incomplete: This is fine for 2 objects, but as soon as a third one comes into play
				//  we need to reevaluate the collisions, because now the bounce might
				//  collide with the third one despite it before not doing so
				//
				#if 1
				{
				for * o, oi: objects
				{
					if oi != it.a && oi != it.b
					{
						collision_time, are_colliding := cast_Bounding_Sphere(a, o);
						collision_time += current_time;
						if are_colliding && collision_time <= dt
						{
							array_add(*collision_pairs, .{it.a, oi, collision_time});
							FOLLOW_UP_COLLISIONS += 1;
						}
					}
					if oi != it.b && oi != it.a
					{
						collision_time, are_colliding := cast_Bounding_Sphere(b, o);
						collision_time += current_time;
						if are_colliding && collision_time <= dt
						{
							array_add(*collision_pairs, .{it.b, oi, collision_time});
							FOLLOW_UP_COLLISIONS += 1;
						}
					}
				}
				quick_sort(collision_pairs, cmp);
				}
}else{ // -----------------------------------------------------------------------
				// Note(Qwendo): Sometimes we seem to be having issues with numerical stability
				//   I think it would be good to revise the cast_Tetraeder Function at a later date
				//   with regards to numerical stability
				//   once we implement moving the physics origiin to keep precision!
				// Before then this seems to be good enough
	#run print("Tetraeder Collisions\n");
				
				draw_Tet :: (a : float3, b : float3, c : float3, d : float3, color : Color) #expand
				{
					add_Line(draw_buffer, a, b, color);
					add_Line(draw_buffer, a, c, color);
					add_Line(draw_buffer, a, d, color);

					add_Line(draw_buffer, b, c, color);
					add_Line(draw_buffer, b, d, color);

					add_Line(draw_buffer, c, d, color);
				}

				

				
				assert(it.time >= current_time);
				advance_In_Time_To_No_Collision(a, it.time);
				advance_In_Time_To_No_Collision(b, it.time);
				current_time = it.time;

				direction := normalize(it.normal, .{}); @@Direction_Used_For_Plastic_Collision
				

				a_vel_in_direction := dot(a.translation.velocity, direction);
				a.translation.velocity -= direction * a_vel_in_direction;

				b_vel_in_direction := dot(b.translation.velocity, direction);
				b.translation.velocity -= direction * b_vel_in_direction;
				array_add(*collision_points, a.translation.position + direction * a.bounding_sphere_radius);

				combined_mass := a.mass + b.mass;

				a_vel_in_direction_after := (a.mass - b.mass)/combined_mass * a_vel_in_direction + 2 * b.mass/combined_mass * b_vel_in_direction;
				b_vel_in_direction_after := 2 * a.mass/combined_mass * a_vel_in_direction + (b.mass - a.mass)/combined_mass * b_vel_in_direction;

				a_change := direction * a_vel_in_direction_after;
				b_change := direction * b_vel_in_direction_after;
				a.translation.velocity += a_change;
				b.translation.velocity += b_change; 

				
				for * o, oi: objects
				{
					if oi != it.a && oi != it.b
					{
						time, colliding, p_a, p_o, normal := cast_Tetraeder(a, o, dt);
						time += current_time;
						if colliding && time <= dt
						{
							array_add(*collision_pairs, .{
								a = it.a, 
								b = oi,
								time = time, 
								a_point = p_a, 
								b_point = p_o,
								normal = normal
							});
							FOLLOW_UP_COLLISIONS += 1;
						}
					}
					if oi != it.b && oi != it.a
					{
						time, colliding, p_b, p_o, normal := cast_Tetraeder(b, o, dt);
						time += current_time;
						if colliding && time <= dt
						{
							array_add(*collision_pairs, .{
								a = it.b, 
								b = oi,
								time = time, 
								a_point = p_b, 
								b_point = p_o,
								normal = normal
							});
							FOLLOW_UP_COLLISIONS += 1;
						}
					}
				}
				quick_sort(collision_pairs, cmp);

}//------------------------------------------
				
			}


			for * objects
			{
				advance_In_Time_To_No_Collision(it, dt);
			}

			

			if DO_PHYSICS_STEP && FOLLOW_UP_COLLISIONS  log("Number of follow up collisions %", FOLLOW_UP_COLLISIONS);


			id := identity(4, float);
			TET :: 4;
			for * o : objects
			{
				add_Mesh(draw_buffer, .{TET, add_Offset(id, o.translation.position)});
				gizmo_At(o.translation.position);
				//add_Line(draw_buffer, o.translation.position, o.translation.position + o.translation.velocity * dt, RED);
				// add_Line(draw_buffer, o.tet[0] + o.translation.position, o.tet[1] + o.translation.position, GREY);
				// add_Line(draw_buffer, o.tet[0] + o.translation.position, o.tet[2] + o.translation.position, GREY);
				// add_Line(draw_buffer, o.tet[0] + o.translation.position, o.tet[3] + o.translation.position, GREY);

				// add_Line(draw_buffer, o.tet[1] + o.translation.position, o.tet[2] + o.translation.position, GREY);
				// add_Line(draw_buffer, o.tet[1] + o.translation.position, o.tet[3] + o.translation.position, GREY);
				// add_Line(draw_buffer, o.tet[2] + o.translation.position, o.tet[3] + o.translation.position, GREY);
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
	
	atomic_volatile_write(*platform.exit, 0);
}

logger :: (message : string, data : *void, info : Log_Info)
{
	now := current_time_monotonic() - context.STARTUP_TIME;
	print("[PHYSICS]+%: %\n", to_milliseconds(now),message);
}


platform : *Platform;




#import,file "Graphics.jai"(PROFILER);
#import,file "Physics.jai"(PROFILER);
Profiler :: #import "Tracy"(PROFILER);
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
