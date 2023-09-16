#scope_module




Cluster :: struct
{
	start : int;
	end   : int;
}

broad_phase : struct
{
	
	associated_aabbs  : Static_Auto_Array(#run type_of(physics_state.tetraeder).data.count + type_of(physics_state.spheres).data.count, Associated_AABB);
	orders : [3] Static_Auto_Array(associated_aabbs.capacity * 2, int);


	entry_time : [3] Static_Auto_Array(associated_aabbs.capacity, int);
	leave_time : [3] Static_Auto_Array(associated_aabbs.capacity, int);

	temp     : Static_Auto_Array(associated_aabbs.capacity * 2, int);

	clusters : Static_Auto_Array(associated_aabbs.capacity, Cluster);
	id_clusters : Static_Auto_Array(associated_aabbs.capacity, Physics_ID);




	reset :: () {
		using broad_phase;
		associated_aabbs.count = 0;

		orders[0].count  = 0;
		orders[1].count  = 0;
		orders[2].count  = 0;
		clusters.count = 0;
	}

	print_Order_Arrays :: ()
	{
		using broad_phase;
		fmt :: #bake_arguments formatInt(base = 10, minimum_digits = 4);
		builder : String_Builder;
		cluster_idx := 0;
		append(*builder, "orders[0] : ");
		for orders[0]
		{
			if it_index == clusters[cluster_idx].end 
			{
				cluster_idx += 1;
				append(*builder, " | ");
			}
			print_to_builder(*builder, "% ", fmt(it));
		}
		append(*builder, "\n");
		append(*builder, "orders[1] : ");
		cluster_idx  = 0;
		for orders[1]
		{
			if it_index == clusters[cluster_idx].end 
			{
				cluster_idx += 1;
				append(*builder, " | ");
			}
			print_to_builder(*builder, "% ", fmt(it));
		}
		append(*builder, "\n");
		append(*builder, "orders[2] : ");
		cluster_idx  = 0;
		for orders[2]
		{
			if it_index == clusters[cluster_idx].end 
			{
				cluster_idx += 1;
				append(*builder, " | ");
			}
			print_to_builder(*builder, "% ", fmt(it));
		}
		append(*builder, "\n\n");
		append(*builder, "clusters: ");
		for clusters
		{
			print_to_builder(*builder, "[%, %) ", it.start, it.end);
		}
		append(*builder, "\n");
		{
			append(*builder, "\nentry_time[0]: ");
			for entry_time[0]
			{
				print_to_builder(*builder, " %", it);
			}
			append(*builder, "\nleave_time[0]: ");
			for leave_time[0]
			{
				print_to_builder(*builder, " %", it);
			}
		}
		{
			append(*builder, "\nentry_time[1]: ");
			for entry_time[1]
			{
				print_to_builder(*builder, " %", it);
			}
			append(*builder, "\nleave_time[1]: ");
			for leave_time[1]
			{
				print_to_builder(*builder, " %", it);
			}
		}
		{
			append(*builder, "\nentry_time[2]: ");
			for entry_time[2]
			{
				print_to_builder(*builder, " %", it);
			}
			append(*builder, "\nleave_time[2]: ");
			for leave_time[2]
			{
				print_to_builder(*builder, " %", it);
			}
		}
		
		
		
		log(builder_to_string(*builder, do_reset = true));
	}

	print_Cluster :: (cluster : Cluster)
	{
		using broad_phase;
		for cluster.start..cluster.end-1
		{
			log("%|%|%", orders[0][it], orders[1][it], orders[2][it]);
		}
	}
} = .{};

#scope_file



