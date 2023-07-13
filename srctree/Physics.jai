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


line_Collision :: (vel : float3, A : float3, B : float3, C : float3, D : float3, dt : float) -> (time : float, does_collide : bool, ab_point : float3, cd_point : float3)
{
/*
	Thanks Wolfram Alpha !!!


Derivation for line-line interstection:
A-B
C-D

v1 = B - A
v2 = C - A = (a,b,c)
v3 = D - A = (g,h,i)
vel = (d,e,f)
(
	i b - c h + i e t - c e t + b f t - f h t + e f t^2 - e f t^2,
	 -i a + c g - i d t + c d t - a f t + f g t,
	 -b g + a h - b d t + a e t - e g t + d h t - d e t^2 + d e t^2
)

Cancel
(
	i b - c h + i e t - c e t + b f t - f h t,
	 -i a + c g - i d t + c d t - a f t + f g t,
	 -b g + a h - b d t + a e t - e g t + d h t
)

Express in terms of t:
Sol(t) = (
	  i b - c h + t * (  i e - c e + b f - f h),
	 -i a + c g + t * (- i d + c d - a f + f g),
	 -b g + a h + t * (- b d + a e - e g + d h)
)

dot(v1,sol(t)) = 0

v1.x ( i b - c h) + v1.y (-i a + c g) + v1.z (-b g + a h) 
+ t * v.x * (  i e - c e + b f - f h)
+ t * v.y * (- i d + c d - a f + f g)
+ t * v.z * (- b d + a e - e g + d h) = 0


v1.x ( i b - c h) + v1.y (-i a + c g) + v1.z (-b g + a h) 
+ t * (v.x * (  i e - c e + b f - f h) + v.y * (- i d + c d - a f + f g) + v.z * (- b d + a e - e g + d h)) = 0


t * (v.x * (  i e - c e + b f - f h) + v.y * (- i d + c d - a f + f g) + v.z * (- b d + a e - e g + d h)) = -( v1.x ( i b - c h) + v1.y (-i a + c g) + v1.z (-b g + a h))

t = -( v1.x ( i b - c h) + v1.y (-i a + c g) + v1.z (-b g + a h))/(v.x * (  i e - c e + b f - f h) + v.y * (- i d + c d - a f + f g) + v.z * (- b d + a e - e g + d h))

Derivation for line segment intersection:
We want that, when looking along the velocity
A and B are on different sides of C-D
C and D are on different sides of A-B

n_cdv = cross(D-C, vel)
n_abv = cross(B-A, vel)

dot(A-C, n_cdv) * dot(B-C, n_cdv) < 0
dot(C-A, n_abv) * dot(D-A, n_abv) < 0

*/


	DB := B - A;
	DC := C - A;
	DD := D - A;

	a := DC.x;
	b := DC.y;
	c := DC.z;
	
	d := vel.x;
	e := vel.y;
	f := vel.z;

	g := DD.x;
	h := DD.y;
	i := DD.z;

	num   := -( DB.x * (i*b - c*h) + DB.y * (-i*a + c*g) + DB.z * (-b*g + a*h));
	denom :=  ( DB.x * (i*e - c*e + b*f - f*h) + DB.y * (-i*d + c*d - a*f + f*g) + DB.z * (-b*d + a*e - e*g + d*h));
	time := num/denom;


	// Line segement intersection

	n_cdv := cross(D-C, vel);
	n_abv := cross(B-A, vel);
	
	NC := C + vel * time;
	ND := D + vel * time;

	ab_on_different_sides_of_cd := float_compare(dot(A-NC, n_cdv) * dot(B-NC, n_cdv), 0, .L);
	cd_on_different_sides_of_ab := float_compare(dot(NC-A, n_abv) * dot(ND-A, n_abv), 0, .L);

	CD_POINT_DELTA : float3;
	{
		CMA := NC - A;
		DMA := ND - A;
		BMA := B - A;
		C_NORMAL_AB := C - BMA * dot(CMA, BMA)/dot(BMA,BMA);
		D_NORMAL_AB := D - BMA * dot(DMA, BMA)/dot(BMA,BMA);
		CD_NORMAL_AB := D_NORMAL_AB - C_NORMAL_AB;
		CD_POINT_DELTA = (D - C) * dot(A - C_NORMAL_AB, CD_NORMAL_AB)/dot(CD_NORMAL_AB, CD_NORMAL_AB);
	}

	AB_POINT_DELTA : float3;
	{
		AMC := A - NC;
		BMC := B - NC;
		DMC := D - C;
		A_NORMAL_CD := A - DMC * dot(AMC, DMC)/dot(DMC,DMC);
		B_NORMAL_CD := B - DMC * dot(BMC, DMC)/dot(DMC,DMC);
		AB_NORMAL_CD := B_NORMAL_CD - A_NORMAL_CD;
		AB_POINT_DELTA = (B - A) * dot(C - A_NORMAL_CD, AB_NORMAL_CD)/dot(AB_NORMAL_CD,AB_NORMAL_CD);
	}


	return time, float_compare(0, time, .LE) && float_compare(time, dt, .LE) && cd_on_different_sides_of_ab && ab_on_different_sides_of_cd, AB_POINT_DELTA, CD_POINT_DELTA;
}





#scope_file





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


#scope_file




#import "IUMath";
#import "Vector";
#import "Math";
#import "Basic";
