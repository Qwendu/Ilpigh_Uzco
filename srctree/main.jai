#import "Common";



#add_context STARTUP_TIME : Apollo_Time;

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
	bounding_sphere_radius : float = 1;
}

Casted_Sphere :: struct
{
	start  : float3;
	end    : float3;
	radius : float;
};

objects : [2] PO;

n_casted_bounding_spheres : int = 0;
casted_bounding_spheres : [objects.count] Casted_Sphere;

add_Casted_Sphere :: (sphere : Casted_Sphere)
{
	if n_casted_bounding_spheres < casted_bounding_spheres.count
	{
		casted_bounding_spheres[n_casted_bounding_spheres] = sphere;
		n_casted_bounding_spheres += 1;
	}else{
		log_error("Too many Casted Spheres");
	}
}


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

	position := float3.{y = 1, z = 2};
	camera_pitch_yaw : float2 = .{y = -.2};
	
	log("Entering Main Loop");
	objects[0].translation.position.x = 3;
	objects[1].translation.position.x = 0;
	objects[0].translation.position.y = 0;
	objects[1].translation.position.y = 0.2;
	
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
			if objects[0].translation.position.x <  0  objects[0].translation.position.x = 3;
			if objects[1].translation.position.x < -1  objects[0].translation.position.x = 0;
			objects[0].translation.velocity.x = -0.1;
			objects[1].translation.velocity.x = -0.15;
			n_casted_bounding_spheres = 0;
			
			for *o, i: objects
			{
				o.translation.velocity += o.translation.acceleration * dt;
				new_pos := o.translation.position + o.translation.velocity * dt;
				//gizmo_At(o.translation.position);
				add_Casted_Sphere(.{o.translation.position, new_pos, o.bounding_sphere_radius});
			}
			collision_pairs : [..] struct {a : int; b : int; time : float;};
			array_reserve(*collision_pairs, objects.count * objects.count - 1);
			defer array_free(collision_pairs);

			solve_Quadratic :: (t2 : float, t1 : float, t0 : float) -> (x1 : float, x2 : float, n_sol : int)
			{
				EPS :: 0.00001;
				//  -t1 +- sqrt(t1 * t1 - 4 * t2 * t0)
				// ------------------------
				//           2 * t2

				if abs(t2) < EPS && abs(t1) > EPS
				{
					return t0/t1,0,1;
				}else if abs(t2) < EPS && abs(t1) < EPS
				{
					return 0,0,0;
				}else  if abs(t2) > EPS && abs(t1) < EPS
				{
					n_discr  := t0/t2;
					if n_discr < 0  return 0,0,0;
					sol := sqrt(n_discr);
					return sol, -sol, 2;
				}else{
					denom := 2 * t2;
					discr := t1 * t1 - 4 * t2 * t0;
					if discr < 0  return 0,0,0;
					sqrt_solved := sqrt(discr);
					sol1 := (-t1 + sqrt_solved)/denom;
					sol2 := (-t1 - sqrt_solved)/denom;
					return sol1, sol2, 2;
				}
			}


			for active_idx : 0..n_casted_bounding_spheres-1
			{
				active := *casted_bounding_spheres[active_idx];
				//add_Line(draw_buffer, active.start, active.end, GREEN);
				for colliding_with_idx : active_idx+1..n_casted_bounding_spheres-1
				{
					colliding_with := *casted_bounding_spheres[colliding_with_idx];
					combined_radius := active.radius + colliding_with.radius;
					start_diff := active.start - colliding_with.start;
					delta_diff := active.end - active.start - colliding_with.end + colliding_with.start;
					t2_part := dot(delta_diff, delta_diff);
					t1_part := 2 * dot(start_diff, delta_diff);
					t0_part := dot(start_diff, start_diff) - combined_radius * combined_radius;
					sol1, sol2, exists := solve_Quadratic(t2_part, t1_part, t0_part);
					if exists
					{
						hit_time : float;
						if exists == 1  hit_time = sol1;
						else            hit_time = min(sol1, sol2);
						if hit_time <= 1 && hit_time >= 0
						{
							log("Bounding Spheres are hitting at %0%%", hit_time);
							array_add(*collision_pairs, .{active_idx, colliding_with_idx, hit_time});
						}
					}
				}
			}

			
			id := identity(4, float);
			TET :: 4;
			for o : objects
			{
				add_Mesh(draw_buffer, .{TET, add_Offset(id, o.translation.position)});
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
