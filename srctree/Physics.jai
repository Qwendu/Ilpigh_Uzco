#scope_export



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
	mass : float = 1;

	bounding_sphere_radius : float = 1;
	local_time : float; // Used for resolving physics
	tet : [4] float3 = .[
			.{1,-.5,0},
			.{0, .5,0},
			.{#run cos(120/180.0 * PI),-.5,#run -sin(120/180.0 * PI)},
			.{#run cos(120/180.0 * PI),-.5,#run  sin(120/180.0 * PI)},
	];
}

cast_Tetraeder :: (a : *PO, b : *PO, dt : float) -> (time: float, collision: bool, point_local_to_a: float3, point_local_to_b: float3, normal : float3)
{
	//@incomplete
	// We do not yet respect rotations in 3D space, although we could
	// CHANGE THAT!

	relative_velocity := b.translation.velocity - a.translation.velocity;
	point_Tet_Collision :: ( point : float3, vel : float3, tet : [4] float3, tet_position : float3, dt : float) -> (float, bool, point_on_tet: float3, normal : float3)
	{
		side_Collision :: (rel : float3, vel : float3, a : float3, b : float3, c : float3) -> float, normal : float3
		{
			normal := cross(b - a, c - a);
			return -dot(rel, normal)/dot(vel, normal), normal;
		}
		point_rel := point - tet_position;

		earliest_collision : float3;
		earliest_collision_normal : float3;
		earliest_collision_time : float = dt + 1;
		s0, s0_norm := side_Collision(point_rel - tet[0], vel, tet[0], tet[1], tet[2]);
		if 0 <= s0 && s0 <= dt
		{
			col_point_tet := point_rel + vel * s0;
			s0_1 := orientation(tet[1], tet[3], tet[2], col_point_tet);
			s0_2 := orientation(tet[3], tet[1], tet[0], col_point_tet);
			s0_3 := orientation(tet[3], tet[0], tet[2], col_point_tet);
			if s0_1 >= 0 && s0_2 >= 0 && s0_3 >= 0
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
		if 0 <= s1 && s1 <= dt
		{
			col_point_tet := point_rel + vel * s1;
			s1_1 := orientation(tet[0], tet[1], tet[2], col_point_tet);
			s1_2 := orientation(tet[3], tet[1], tet[0], col_point_tet);
			s1_3 := orientation(tet[3], tet[0], tet[2], col_point_tet);

			if s1_1 >= 0 && s1_2 >= 0 && s1_3 >= 0
			{
				if earliest_collision_time > s1
				{
					earliest_collision = col_point_tet;
					earliest_collision_normal = s1_norm;
					earliest_collision_time = s1;
				}
			}
		}

		s2, s2_norm := side_Collision(point_rel - tet[2], vel, tet[2], tet[3], tet[0]);
		if 0 <= s2 && s2 <= dt
		{
			col_point_tet := point_rel + vel * s2;
			s2_1 := orientation(tet[0], tet[1], tet[2], col_point_tet);
			s2_2 := orientation(tet[1], tet[3], tet[2], col_point_tet);
			s2_3 := orientation(tet[3], tet[0], tet[2], col_point_tet);

			if s2_1 >= 0 && s2_2 >= 0 && s2_3 >= 0
			{
				if earliest_collision_time > s2
				{
					earliest_collision = col_point_tet;
					earliest_collision_normal = s2_norm;
					earliest_collision_time = s2;
				}
			}
		}

		s3, s3_norm := side_Collision(point_rel - tet[3], vel, tet[3], tet[1], tet[0]);
		if 0 <= s3 && s3 <= dt
		{
			col_point_tet := point_rel + vel * s3;
			s3_1 := orientation(tet[0], tet[1], tet[2], col_point_tet);
			s3_2 := orientation(tet[1], tet[3], tet[2], col_point_tet);
			s3_3 := orientation(tet[2], tet[3], tet[0], col_point_tet);

			if s3_1 >= 0 && s3_2 >= 0 && s3_3 >= 0
			{
				if earliest_collision_time > s3
				{
					earliest_collision = col_point_tet;
					earliest_collision_normal = s3_norm;
					earliest_collision_time = s3;
				}
			}
		}

		return earliest_collision_time, 0 <= earliest_collision_time && earliest_collision_time <= dt, earliest_collision, earliest_collision_normal;
	}
	collision_time :float= dt + 1;
	collision_point_a : float3;
	collision_point_b : float3;
	collision_normal  : float3;
	{
		col_0_t, col_0, col_0_point_tet, col_0_normal := point_Tet_Collision(b.tet[0] + b.translation.position, relative_velocity, a.tet, a.translation.position, dt);
		col_1_t, col_1, col_1_point_tet, col_1_normal := point_Tet_Collision(b.tet[1] + b.translation.position, relative_velocity, a.tet, a.translation.position, dt);
		col_2_t, col_2, col_2_point_tet, col_2_normal := point_Tet_Collision(b.tet[2] + b.translation.position, relative_velocity, a.tet, a.translation.position, dt);
		col_3_t, col_3, col_3_point_tet, col_3_normal := point_Tet_Collision(b.tet[3] + b.translation.position, relative_velocity, a.tet, a.translation.position, dt);

		if col_0_t < collision_time && col_0 {collision_time = col_0_t; collision_point_a = col_0_point_tet; collision_point_b = b.tet[0]; collision_normal = col_0_normal;}
		if col_1_t < collision_time && col_1 {collision_time = col_1_t; collision_point_a = col_1_point_tet; collision_point_b = b.tet[1]; collision_normal = col_1_normal;}
		if col_2_t < collision_time && col_2 {collision_time = col_2_t; collision_point_a = col_2_point_tet; collision_point_b = b.tet[2]; collision_normal = col_2_normal;}
		if col_3_t < collision_time && col_3 {collision_time = col_3_t; collision_point_a = col_3_point_tet; collision_point_b = b.tet[3]; collision_normal = col_3_normal;}
	}
	{
		col_0_t, col_0, col_0_point_tet, col_0_normal := point_Tet_Collision(a.tet[0] + a.translation.position, -1 * relative_velocity, b.tet, b.translation.position, dt);
		col_1_t, col_1, col_1_point_tet, col_1_normal := point_Tet_Collision(a.tet[1] + a.translation.position, -1 * relative_velocity, b.tet, b.translation.position, dt);
		col_2_t, col_2, col_2_point_tet, col_2_normal := point_Tet_Collision(a.tet[2] + a.translation.position, -1 * relative_velocity, b.tet, b.translation.position, dt);
		col_3_t, col_3, col_3_point_tet, col_3_normal := point_Tet_Collision(a.tet[3] + a.translation.position, -1 * relative_velocity, b.tet, b.translation.position, dt);

		// Invert normal when it comes from the b side! @@Direction_Used_For_Plastic_Collision
		if col_0_t < collision_time && col_0 {collision_time = col_0_t; collision_point_b = col_0_point_tet; collision_point_a = a.tet[0]; collision_normal = col_0_normal * -1;}
		if col_1_t < collision_time && col_1 {collision_time = col_1_t; collision_point_b = col_1_point_tet; collision_point_a = a.tet[1]; collision_normal = col_1_normal * -1;}
		if col_2_t < collision_time && col_2 {collision_time = col_2_t; collision_point_b = col_2_point_tet; collision_point_a = a.tet[2]; collision_normal = col_2_normal * -1;}
		if col_3_t < collision_time && col_3 {collision_time = col_3_t; collision_point_b = col_3_point_tet; collision_point_a = a.tet[3]; collision_normal = col_3_normal * -1;}
	}
	return collision_time, 0 <= collision_time && collision_time <= dt, collision_point_a, collision_point_b, collision_normal;
}

orientation :: (v0 : float3, v1 : float3, v2 : float3, v3 : float3) -> float
{
	d1 := v1 - v0;
	d2 := v2 - v0;
	d3 := v3 - v0;
	return dot(d1, cross(d2, d3))/6.0;
}

cast_Bounding_Sphere :: (active : *PO, colliding_with : *PO, dt : float) -> (intersect_time : float, do_intersect : bool)
{
	combined_radius := active.bounding_sphere_radius + colliding_with.bounding_sphere_radius;
	start_diff := active.translation.position - colliding_with.translation.position;
	delta_diff := active.translation.velocity - colliding_with.translation.velocity;
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
	return hit_time , exists && (0 < hit_time && hit_time <= dt);
}

solve_Quadratic :: (t2 : float, t1 : float, t0 : float) -> (x1 : float, x2 : float, n_sol : bool)
{
	d := t1 * t1 - 4 * t2 * t0;
	if float_compare(d, 0, .L)  return -1,-1,false;
	r := sqrt(d);
	return 2 * t0/(-t1 - r), 2 * t0/(-t1 + r), true;
}
#module_parameters(PROFILER : bool);
#scope_file



#import "IUMath";
#import "Vector";
#import "Math";
