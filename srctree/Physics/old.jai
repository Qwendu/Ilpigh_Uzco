cast_Tetraeder :: (a : *PO, b : *PO, dt : float) -> (time: float, collision: bool, point_local_to_a: float3, point_local_to_b: float3, normal : float3)
{
	//@incomplete
	// We do not yet respect rotations in 3D space, although we could
	// CHANGE THAT!

	relative_velocity := b.translation.velocity - a.translation.velocity;

	collision_time :float= dt + 1;
	collision_point_a : float3;
	collision_point_b : float3;
	collision_normal  : float3;


	test_Point_Tet :: (point : float3, tet : [4] float3, tet_position : float3, collision_point_point : *float3, collision_point_tet : *float3, $$invert_normal : bool = false) #expand
	{
		col_t, col, col_point_tet, col_normal := point_Tet_Collision(point, ifx invert_normal then relative_velocity * -1 else relative_velocity, tet, tet_position, dt);
		if col && float_compare(col_t, collision_time, .L)
		{
			collision_time = col_t;
			collision_normal   = ifx invert_normal then col_normal * -1 else col_normal;
			collision_point_point.* = point;
			collision_point_tet  .* = col_point_tet + tet_position;
		}
	}
	{
		test_Point_Tet(b.tet[0] + b.translation.position, a.tet, a.translation.position, *collision_point_b, *collision_point_a, false);
		test_Point_Tet(b.tet[1] + b.translation.position, a.tet, a.translation.position, *collision_point_b, *collision_point_a, false);
		test_Point_Tet(b.tet[2] + b.translation.position, a.tet, a.translation.position, *collision_point_b, *collision_point_a, false);
		test_Point_Tet(b.tet[3] + b.translation.position, a.tet, a.translation.position, *collision_point_b, *collision_point_a, false);
	}
	{
		// Invert normal when it comes from the b side! @@Direction_Used_For_Plastic_Collision
		test_Point_Tet(a.tet[0] + a.translation.position, b.tet, b.translation.position, *collision_point_a, *collision_point_b, true);
		test_Point_Tet(a.tet[1] + a.translation.position, b.tet, b.translation.position, *collision_point_a, *collision_point_b, true);
		test_Point_Tet(a.tet[2] + a.translation.position, b.tet, b.translation.position, *collision_point_a, *collision_point_b, true);
		test_Point_Tet(a.tet[3] + a.translation.position, b.tet, b.translation.position, *collision_point_a, *collision_point_b, true);
	}

	line_line_collision_is_earliest : bool = false;
	L :: struct{a:s8; b:s8;c : s8; d : s8;};
	lines_indices :: L.[.{0,1,2,3}, .{0,3,1,2}, .{0,2,3,1},.{1,2,0,3}, .{1,3,2,0}, .{2,3,0,1}];
	for a_line : lines_indices
	{
		for b_line : lines_indices
		{
			Other_Delta := b.translation.position - a.translation.position;
			A := a.tet[a_line.a];
			B := a.tet[a_line.b];

			C := b.tet[b_line.a];
			D := b.tet[b_line.b];
			time, collision, ab_point_delta, cd_point_delta := line_Collision(relative_velocity,A,B,C + Other_Delta,D + Other_Delta, dt);
			ab_point := A + ab_point_delta;
			cd_point := C + cd_point_delta;
			if collision && float_compare(0,time, .LE) && float_compare(time, collision_time, .L)
			{
				line_line_collision_is_earliest = true;
				collision_time = time;
				collision_point_a = ab_point + a.translation.position;
				collision_point_b = cd_point + b.translation.position;
			}
		}
	}
	if line_line_collision_is_earliest 
	{
		collision_normal = relative_velocity; // Hack
	}

	return collision_time, float_compare(0, collision_time, .LE) && float_compare(collision_time, dt, .LE), collision_point_a, collision_point_b, collision_normal;
}


cast_Bounding_Sphere :: (a : *PO, b : *PO, dt : float) -> (intersect_time : float, do_intersect : bool, col_point_a : float3, col_point_b : float3, normal : float3)
{
	combined_radius := a.bounding_sphere_radius + b.bounding_sphere_radius;
	start_diff := a.translation.position - b.translation.position;
	delta_diff := a.translation.velocity - b.translation.velocity;
	t2_part :=     dot(delta_diff, delta_diff);
	t1_part := 2 * dot(start_diff, delta_diff);
	t0_part :=     dot(start_diff, start_diff) - combined_radius * combined_radius;
	sol1, sol2, exists := solve_Quadratic(t2_part, t1_part, t0_part);
	hit_time :float= dt + 1;
	// Comparing with NaN is possible here, so we filter it out now so we can later rely on non NaN compares which are faster!
	sol1_l := float_compare(0, sol1, .L);
	sol1_u := float_compare(sol1, dt, .LE);
	sol2_l := float_compare(0, sol2, .L);
	sol2_u := float_compare(sol2, dt, .LE);
	if sol1_l && sol1_u  hit_time = sol1;
	if sol2_l && sol2_u && sol2 < hit_time  hit_time = sol2;
	do_collide  := exists && (float_compare(0, hit_time, .L) && float_compare(hit_time, dt, .LE));
	normal : float3;
	col_point_a : float3;
	col_point_b : float3;
	if do_collide
	{
		pa := a.translation.position + a.translation.velocity * hit_time;
		pb := b.translation.position + b.translation.velocity * hit_time;
		normal = normalize(pb - pa, .{});
		col_point_a = normal * a.shape.bounding_sphere.radius;
		col_point_b = normal * a.shape.bounding_sphere.radius * -1;
	}
	return hit_time , do_collide, col_point_a, col_point_b, normal;
}


point_Tet_Collision :: ( point : float3, vel : float3, tet : [4] float3, tet_position : float3, dt : float) -> (float, bool, point_on_tet: float3, normal : float3)
{
	side_Collision :: (rel : float3, vel : float3, a : float3, b : float3, c : float3) -> float, normal : float3
	{
		normal := cross(b - a, c - a);
		return -dot(rel, normal)/dot(vel, normal), normal;
	}
	point_rel := point - tet_position;
	// All sides by indices in correct order
	// 012
	// 132
	// 310
	// 302

	earliest_collision : float3;
	earliest_collision_normal : float3;
	earliest_collision_time : float = dt + 1;
	s0, s0_norm := side_Collision(point_rel - tet[0], vel, tet[0], tet[1], tet[2]);
	if float_compare(0, s0, .LE) && float_compare(s0, dt, .LE)
	{
		col_point_tet := point_rel + vel * s0;
		s0_1 := orientation(tet[1], tet[3], tet[2], col_point_tet);
		s0_2 := orientation(tet[3], tet[1], tet[0], col_point_tet);
		s0_3 := orientation(tet[3], tet[0], tet[2], col_point_tet);
		if float_compare(s0_1, 0, .GE) && float_compare(s0_2, 0, .GE) && float_compare(s0_3, 0, .GE)
		{
			if earliest_collision_time > s0
			{
				earliest_collision = col_point_tet;
				earliest_collision_normal = s0_norm;
				earliest_collision_time = s0;
			}
		}
	}

	s1, s1_norm := side_Collision(point_rel - tet[1], vel, tet[1], tet[3], tet[2]);
	if float_compare(0, s1, .LE) && float_compare(s1, dt, .LE)
	{
		col_point_tet := point_rel + vel * s1;
		s1_1 := orientation(tet[0], tet[1], tet[2], col_point_tet);
		s1_2 := orientation(tet[3], tet[1], tet[0], col_point_tet);
		s1_3 := orientation(tet[3], tet[0], tet[2], col_point_tet);

		if float_compare(s1_1, 0, .GE) && float_compare(s1_2, 0, .GE) && float_compare(s1_3, 0, .GE)
		{
			if earliest_collision_time > s1
			{
				earliest_collision = col_point_tet;
				earliest_collision_normal = s1_norm;
				earliest_collision_time = s1;
			}
		}
	}


	s2, s2_norm := side_Collision(point_rel - tet[2], vel, tet[3], tet[1], tet[0]);
	if float_compare(0, s2, .LE) && float_compare(s2, dt, .LE)
	{
		col_point_tet := point_rel + vel * s2;
		s2_1 := orientation(tet[0], tet[1], tet[2], col_point_tet);
		s2_2 := orientation(tet[1], tet[3], tet[2], col_point_tet);
		s2_3 := orientation(tet[3], tet[0], tet[2], col_point_tet);

		if float_compare(s2_1, 0, .GE) && float_compare(s2_2, 0, .GE) && float_compare(s2_3, 0, .GE)
		{
			if earliest_collision_time > s2
			{
				earliest_collision = col_point_tet;
				earliest_collision_normal = s2_norm;
				earliest_collision_time = s2;
			}
		}
	}

	s3, s3_norm := side_Collision(point_rel - tet[3], vel, tet[3], tet[0], tet[2]);
	if float_compare(0, s3, .LE) && float_compare(s3, dt, .LE)
	{
		col_point_tet := point_rel + vel * s3;
		s3_1 := orientation(tet[0], tet[1], tet[2], col_point_tet);
		s3_2 := orientation(tet[1], tet[3], tet[2], col_point_tet);
		s3_3 := orientation(tet[3], tet[1], tet[0], col_point_tet);

		if float_compare(s3_1, 0, .GE) && float_compare(s3_2, 0, .GE) && float_compare(s3_3, 0, .GE)
		{
			if earliest_collision_time > s3
			{
				earliest_collision = col_point_tet;
				earliest_collision_normal = s3_norm;
				earliest_collision_time = s3;
			}
		}
	}

	return earliest_collision_time, float_compare(0, earliest_collision_time, .LE) && float_compare(earliest_collision_time, dt, .LE), earliest_collision, earliest_collision_normal;
}
