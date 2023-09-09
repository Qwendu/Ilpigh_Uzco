#scope_export

GAMMA : float : 2.2;

Draw_Args :: struct
{
	exit         : *int;
	draw_context : Context;
	window       : Window;
	startup_time : Apollo_Time;
	output       : *Output;
};


Output :: struct
{
	command_buffer_writer : Async_Buffer_End(Draw_Buffer, .WRITER);
};

command_buffer : Async_Buffer(Draw_Buffer);


render_Thread :: (args :*Draw_Args) #c_call
{
	Profiler.NameThread(#procedure_name());

	args.draw_context.logger = draw_logger;
	push_context,defer_pop args.draw_context;
	output : Output;
	
	command_reader, command_writer := get_Ends(*command_buffer);
	output.command_buffer_writer = command_writer;
	atomic_volatile_write(*args.output, *output);

	setup_Buffers();
	
	//
	// Loading always loaded meshes
	//
	material_1 := Material.{};
	material_1.color = .{0,1,0,0};

	tet_id : Mesh_ID;
	m1_id  : Mesh_ID;
	m2_id  : Mesh_ID;
	floor_tile_id : Mesh_ID;
	height_map_id : Mesh_ID;
	{
		{
			m1_id = register_Mesh("mesh_1");
			m1 : Mesh;
			m1.material = .{.{1,1,0, 0}};
			m1.vertices = .[
				.{-1,0,-1},
				.{1,0,-1},
				.{0,1,-8},
				//.{0,0,0}
			];
			m1.triangles = .[
				.{0,1,2},
				//.{0,3,1}
			];
			m1.aabb = generate_AABB_Of_Mesh(m1);
			set_Mesh(m1_id, m1);
		}
		{
			m2_id = register_Mesh("m2");
			m2 : Mesh;
			m2.material = .{.{0,1,0, 0}};;
			m2.vertices = .[
				.{-1, 0,0},
				.{ 1, 0,-4},
				.{-1, 0,-10},
				.{ 1, 0,-10},
			];
			m2.triangles = .[
				.{0,1,2},
				.{1,3,2}
			];
			m2.aabb = generate_AABB_Of_Mesh(m2);
			set_Mesh(m2_id, m2);
		}
		{
			floor_tile_id = register_Mesh("floor_tile");
			floor_tile : Mesh;
			floor_tile.material = .{.{0.2,.2,.2,1}};
			floor_tile.vertices = .[
				.{0,1,1},
				.{1,1,1},
				.{0,0,1},
				.{1,0,1},
			];
			floor_tile.triangles = .[
				.{0,3,1},
				.{0,2,3}
			];
			floor_tile.aabb = generate_AABB_Of_Mesh(floor_tile);
			set_Mesh(floor_tile_id, floor_tile);
		}

		{
			height_map_res :: int2.{30, 30};
			height_map_dims :: float3.{10, .7, 10};
			height_map : Mesh;
			height_map.material.color = .{1,1,1,1};
			height_map.vertices = NewArray(height_map_res.x * height_map_res.y, float3);

			for h: 0..height_map_res.y-1
			{
				for w: 0..height_map_res.x-1
				{
					w_sample := cast(float)w/(height_map_res.x - 1);
					h_sample := cast(float)h/(height_map_res.y - 1);
					v := *height_map.vertices[h * height_map_res.x + w];
					v.x = w_sample * height_map_dims.x - height_map_dims.x/2;
					v.z = h_sample * height_map_dims.z - height_map_dims.z/2;
					v.y = cast(float)(sin(w_sample * 2 * PI)) * height_map_dims.y;
				}
			}
			height_map.triangles = NewArray((height_map_res.x - 1) * 2 * (height_map_res.y - 1), int3);
			idx := 0;
			for h: 0..height_map_res.y-2
			{
				for w: 0..height_map_res.x-2
				{
					v1 := h * height_map_res.x + w;
					v2 := h * height_map_res.x + (w + 1);
					v3 := (h + 1) * height_map_res.x + w;
					v4 := (h + 1) * height_map_res.x + (w + 1);
					height_map.triangles[idx + 0] = .{v1,v3, v2}; 
					height_map.triangles[idx + 1] = .{v2,v3, v4}; 
					idx += 2;
				}
			}
			log("% vertices, % triangles in heightmap", height_map.vertices.count, height_map.triangles.count);
			height_map.aabb = generate_AABB_Of_Mesh(height_map);
			height_map_id = register_Mesh("height_map");
			set_Mesh(height_map_id, height_map);
		}

		{
			angle :: 120.0/180 * PI;
			cosa :: #run cos(angle);
			sina :: #run sin(angle);
			tet : Mesh;
			tet.vertices = .[
				.{0, .5,0},
				.{1,-.5,0},
				.{ cosa,-.5,-sina},
				.{ cosa,-.5, sina},
			];
			tet.triangles = .[
				.{2,1,3},
				.{0,1,2},
				.{1,0,3},
				.{0,2,3},
			];
			tet.aabb = generate_AABB_Of_Mesh(tet);
			tet.material.color = .{1,0.3,0.5, 0};
			tet_id  = register_Mesh("tet");
			set_Mesh(tet_id, tet);
		}
	}


	while atomic_volatile_read(args.exit) == 0
	{
		Profiler.TimeZone();
		Profiler.Frame("Graphics");
		buffer : *Draw_Buffer = get_Read_Pointer(command_reader);
		render_Draw_Buffer(args.window, buffer);
		platform.update_Window(args.window);
		platform.sleep(30);
	}

	atomic_volatile_write(args.exit, 0);

}


clear_Instances :: (draw_buffer : *Draw_Buffer)
{
	draw_buffer.instances.count = 0;
	draw_buffer.light_sources.count = 0;
	draw_buffer.lines.count = 0;
	draw_buffer.bezier_2d.count = 0;
	draw_buffer.bezier_3d.count = 0;
}




#scope_module

draw_logger :: (message : string, data : *void, info : Log_Info)
{
	now := current_time_monotonic() - context.STARTUP_TIME;
	for String_By_Line.{message}
	{
		print("[RENDER]+%: %\n", to_milliseconds(now), it);
	}
}




Active_Instance :: struct
{
	instance_to_projection : float4x4;
	instance_to_world : float4x4;
	mesh_ptr : * Mesh;
}
active_meshes : [..] Active_Instance;


screen2 :: Vector(2, s32 /*fixed_point 26.6*/);


#load "Graphics/Rasterizer.jai";
#load "Graphics/Shaders.jai";
#load "Graphics/Mesh_Loader.jai";


#import "Draw_Buffer";

Profiler :: #import "Tracy";
#import "Atomics";
#import "Async_Buffer";
#import "Basic";
#import "Vector";
#import "VectorAsm";
#import "Matrix";
#import "Camera";
#import "Math";
#import "Color";
#import "Material";

#import "Light";
#import "Line";
#import "Bezier";

#import "AABB";
#import "Sync";
#import "Memory";
#import "Mutex";
#import "Predicated_Array";
#import "Platform_Interface";
#import "Logging_Utils";
#import "Static_Auto_Array";

#import "Common";
#import "Mesh";


