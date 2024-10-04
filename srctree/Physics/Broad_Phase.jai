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

	clusters    : Static_Auto_Array(associated_aabbs.capacity, Cluster);
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


do_broad_phase :: inline (dt : float)
{
	using broad_phase;

	broad_phase.reset();

	idx := 1;
	for Physics_Objects_By_ID.{}
	{
		defer idx += 1;
		base := get_Base(it);
		velocity := base.translation.velocity * dt;
		aabb := get_AABB(it);
		aabb_after_vel := AABB.{aabb.min + velocity, aabb.max + velocity};
		aabb_with_velocity := merge(aabb, aabb_after_vel);
		array_add(*associated_aabbs, .{aabb_with_velocity, it});

		{
			dbg_AABB(associated_aabbs[it_index]);
			array_add(*orders[0],  idx);
			array_add(*orders[0], -idx);

			array_add(*orders[1],  idx);
			array_add(*orders[1], -idx);

			array_add(*orders[2],  idx);
			array_add(*orders[2], -idx);
		}
	}

	array_add(*clusters, .{0, orders[0].count});

	quick_sort(to_view(*orders[0]), a => 
		ifx a < 0 then 
			broad_phase.associated_aabbs[-a - 1].max.x
		else
			broad_phase.associated_aabbs[ a - 1].min.x
	);
	quick_sort(to_view(*orders[1]), a => 
		ifx a < 0 then 
			broad_phase.associated_aabbs[-a - 1].max.y
		else
			broad_phase.associated_aabbs[ a - 1].min.y
	);
	quick_sort(to_view(*orders[2]), a => 
		ifx a < 0 then 
			broad_phase.associated_aabbs[-a - 1].max.z
		else
			broad_phase.associated_aabbs[ a - 1].min.z
	);

	//
	// Setup Entry and leave times
	// 
	{
		for axis : 0..2
		{
			resize(*leave_time[axis], associated_aabbs.count);
			resize(*entry_time[axis], associated_aabbs.count);

			for orders[axis]
			{
				if it < 0
				{
					id := -it - 1;
					leave_time[axis][id] = it_index;
				}else{
					id :=  it - 1;
					entry_time[axis][id] = it_index;
				}
			}
		}
	}

	//
	// Trivial Clustering
	//
	{
		partition :: (
			$axis : int,
			$split_axis : int,

			cluster     : Cluster,
			split_point : int
		){
			#assert axis != split_axis;
			resize(*broad_phase.temp, broad_phase.orders[axis].count);
			left_write_pointer  := cluster.start;
			right_write_pointer := split_point;
			for cluster.start..cluster.end-1
			{
				id_raw := broad_phase.orders[axis][it];
				id := ifx id_raw < 0 then -id_raw - 1 else id_raw - 1;
				entry := broad_phase.entry_time[split_axis][id];
				leave := broad_phase.leave_time[split_axis][id];
				new_index : int;
				if broad_phase.entry_time[split_axis][id] < split_point
				{
					assert(broad_phase.leave_time[split_axis][id] < split_point);
					broad_phase.temp[left_write_pointer] = id_raw;
					new_index = left_write_pointer;
					left_write_pointer += 1;
				}else{
					broad_phase.temp[right_write_pointer] = id_raw;
					new_index  = right_write_pointer;
					right_write_pointer += 1;
				}
				
				if id_raw < 0
				{
					broad_phase.leave_time[axis][id] = new_index;
				}else{
					broad_phase.entry_time[axis][id] = new_index;
				}
			}
			for cluster.start..cluster.end-1
			{
				broad_phase.orders[axis][it] = broad_phase.temp[it];
			}
		}
		number_of_splits := 1;
		while number_of_splits
		{
			number_of_splits = 0;
			do_Split :: ($axis : int, cluster_idx : int) #expand
			{
				cluster := clusters[cluster_idx];
				axis_p1 :: (axis + 1) % 3;
				axis_p2 :: (axis + 2) % 3;

				stack_depth := 0;
				number_of_intermediates := 0;
				for it_index : cluster.start..cluster.end-1
				{
					it := orders[axis][it_index];
					id := ifx it < 0 then -it - 1 else it - 1;

					if it > 0 stack_depth += 1;
					else      stack_depth -= 1;
					number_of_intermediates += 1;

					if stack_depth == 0 && it_index < cluster.end - 1
					{
						number_of_splits += 1;

						split_point := cluster.start + number_of_intermediates;
						

						left_cluster    := cluster;
						left_cluster.end = split_point;

						right_cluster      := cluster;
						right_cluster.start = split_point;
						clusters[cluster_idx] = right_cluster;
						ordered_insert_at(*clusters, left_cluster, cluster_idx);

						partition(axis_p2, axis, cluster, left_cluster.end);
						partition(axis_p1, axis, cluster, left_cluster.end);
						number_of_intermediates = 0;
					}
				}
			}
			cluster_idx : int = 0;
			while cluster_idx < clusters.count
			{
				defer cluster_idx += 1;
				do_Split(0, cluster_idx);
				do_Split(1, cluster_idx);
				do_Split(2, cluster_idx);
			}
		}
	}

	//broad_phase.print_Order_Arrays();
	id_clusters_write_pointer := 0;
	resize(*broad_phase.id_clusters, associated_aabbs.count);
	for * clusters
	{
		start_of_cluster := id_clusters_write_pointer;
		for index : it.start..it.end-1
		{
			id := orders[0][index];
			if id > 0 
			{
				id_clusters[id_clusters_write_pointer] = associated_aabbs[id - 1].id;
				id_clusters_write_pointer += 1;
			}
		}
		it.start = start_of_cluster;
		it.end   = id_clusters_write_pointer;
	}
}



#scope_file



