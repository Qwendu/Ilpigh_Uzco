#scope_export

PHYSICS_FREQUENCY :: 100;
dt :: 1.0/PHYSICS_FREQUENCY;


//#load "Physics/old.jai";


Physics_ID :: #type,distinct u16;
Physics_ID_INVALID : Physics_ID : cast,no_check(Physics_ID) 0;


Shape_Type :: enum u8 
{
	UNKOWN    ::  255;
	SPHERE    ::  0;
	TETRAEDER ::  1;
}


formatID :: #bake_arguments formatInt(
	base = 16, 
	minimum_digits   = size_of(Physics_ID) * 2,
	digits_per_comma = 0, 
	comma_string = "_"
);



Physics_Base :: struct
{
	translation : PVA(float3);
	mass        : float = 1; @"assert(mass > 0, \"We cannot have negative masses, or masses that are zero\")";
}

Physics_Object :: struct(shape_type : Shape_Type)
{
	using base : Physics_Base;
	using shape      : Shape(shape_type);
}

Shape :: struct(shape_type : Shape_Type)
{
	#if shape_type == .SPHERE
	{
		using sphere : Sphere;
	}else #if shape_type ==.TETRAEDER
	{
		using tetraeder : Tetraeder;
	}else{
		unkown_shape : void;
	}
}



Tetraeder :: struct
{
	vertices : [4] float3;
};


Sphere    :: struct
{
	radius : float ;
}

reset_Entire_Physics_State :: ()
{
	physics_state.spheres.count   = 0;
	physics_state.tetraeder.count = 0;
}




create_Physics_Object :: (base : Physics_Base, shape : $S/Shape) -> Physics_ID
{
	log("Creating object with base %", base);

	#if shape.shape_type == .SPHERE
	{
		id := create_Sphere(base, shape);
		demangle_Physics_ID(id);
		return id;
	}else #if shape.shape_type == .TETRAEDER
	{
		id := create_Tetraeder(base, shape);
		demangle_Physics_ID(id);
		return id;
	}else{
		assert(false, "Shape % is not valid", shape.shape_type);
	}
}

SPHERE_DEFAULT :: (Shape(.SPHERE)).{
	radius = 1,
};

TETRAEDER_DEFAULT :: (Shape(.TETRAEDER)).{
	vertices = .[
		.{-1, .5,0},
		.{0,-.5,0},
		.{#run cos(60/180.0 * PI), .5,#run -sin( 60/180.0 * PI)},
		.{#run cos(60/180.0 * PI), .5,#run  sin( 60/180.0 * PI)},
	],
};

AABB :: struct
{
	min : float3;
	max : float3;
};

merge :: (a : AABB, b : AABB) -> AABB
{
	r : AABB = a;
	for 0..2
	{
		r.min.data[it] = min(a.min.data[it], b.min.data[it]);
		r.max.data[it] = max(a.max.data[it], b.max.data[it]);
	}
	return r;
}

Associated_AABB :: struct
{
	#as using aabb : AABB;
	id : Physics_ID = Physics_ID_INVALID;
}

#load "Physics/Broad_Phase.jai";


tick_Physics :: ()
{
	//log("tick");
	dbg_Clear_Visualizations();

	do_broad_phase(dt);
	

	//
	//  Collision Resolving
	//
	{
		for broad_phase.clusters
		{
			for primary_idx : it.start..it.end-1
			{
				primary := broad_phase.id_clusters[primary_idx];
				for secondary_idx : primary_idx+1..it.end-1
				{
					secondary := broad_phase.id_clusters[secondary_idx];
					//log("Resolving collision between % and %", primary, secondary);
					
				}
			}
		}
	}
	
	physics_state.time += microseconds_to_apollo(xx (dt * 1000 * 1000));
	append_State();
}


Pending_Collision :: struct
{
	a : Physics_ID = Physics_ID_INVALID;
	b : Physics_ID = Physics_ID_INVALID;
	time  : float = -1;
	a_point : float3 = ---;
	b_point : float3 = ---;
	normal  : float3 = ---;
};


detect_Collision :: (a : Physics_ID, b : Physics_ID, dt : float) -> Pending_Collision
{
	a_shape, a_index := demangle_Physics_ID(a);
	b_shape, b_index := demangle_Physics_ID(b);
	res : Pending_Collision;
	res.a = a;
	res.b = b;
	if a_shape == .SPHERE && b_shape == .SPHERE
	{
		res.time, _, res.a_point, res.b_point, res.normal = cast_Bounding_Sphere(*physics_state.spheres[a_index], *physics_state.spheres[b_index], dt);
	}else {
		assert(false, "% - % Collision detection is not implemented!", a_shape, b_shape);
	}
	return res;
}


get_Base :: (id : Physics_ID) -> Physics_Base
{
	shape, index := demangle_Physics_ID(id);
	if #complete shape ==
	{
	case .SPHERE;
		return physics_state.spheres[index].base;
	case .TETRAEDER;
		return physics_state.tetraeder[index].base;
	case .UNKOWN;
		return .{};
	}
}

get_AABB :: (id : Physics_ID) -> AABB
{
	shape, index := demangle_Physics_ID(id);
	if #complete shape == 
	{
	case .SPHERE;
		center := physics_state.spheres[index].translation.position;
		radius := physics_state.spheres[index].radius;
		radius_v := float3.{radius, radius, radius};
		return .{center - radius_v, center + radius_v};
	case .TETRAEDER;
		obj := physics_state.tetraeder[index];
		min := obj.vertices[0];
		max := obj.vertices[0];
		for 1..3
		{
			min.x = ifx obj.vertices[it].x < min.x obj.vertices[it].x else min.x;
			min.y = ifx obj.vertices[it].y < min.y obj.vertices[it].y else min.y;
			min.z = ifx obj.vertices[it].z < min.z obj.vertices[it].z else min.z;
			max.x = ifx obj.vertices[it].x > max.x obj.vertices[it].x else max.x;
			max.y = ifx obj.vertices[it].y > max.y obj.vertices[it].y else max.y;
			max.z = ifx obj.vertices[it].z > max.z obj.vertices[it].z else max.z;
		}
		return .{obj.translation.position + min, obj.translation.position + max};
	case .UNKOWN;
		return .{};
	}
}



PVA :: struct(T : Type)
{
	position     : T;
	velocity     : T;
	acceleration : T;
}




cast_Tetraeder :: (a : *Physics_Object(.TETRAEDER), b : *Physics_Object(.TETRAEDER), dt : float) -> (time: float, collision: bool, point_local_to_a: float3, point_local_to_b: float3, normal : float3)
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
		test_Point_Tet(b.shape.vertices[0] + b.translation.position, a.shape.vertices, a.translation.position, *collision_point_b, *collision_point_a, false);
		test_Point_Tet(b.shape.vertices[1] + b.translation.position, a.shape.vertices, a.translation.position, *collision_point_b, *collision_point_a, false);
		test_Point_Tet(b.shape.vertices[2] + b.translation.position, a.shape.vertices, a.translation.position, *collision_point_b, *collision_point_a, false);
		test_Point_Tet(b.shape.vertices[3] + b.translation.position, a.shape.vertices, a.translation.position, *collision_point_b, *collision_point_a, false);
	}
	{
		// Invert normal when it comes from the b side! @@Direction_Used_For_Plastic_Collision
		test_Point_Tet(a.shape.vertices[0] + a.translation.position, b.shape.vertices, b.translation.position, *collision_point_a, *collision_point_b, true);
		test_Point_Tet(a.shape.vertices[1] + a.translation.position, b.shape.vertices, b.translation.position, *collision_point_a, *collision_point_b, true);
		test_Point_Tet(a.shape.vertices[2] + a.translation.position, b.shape.vertices, b.translation.position, *collision_point_a, *collision_point_b, true);
		test_Point_Tet(a.shape.vertices[3] + a.translation.position, b.shape.vertices, b.translation.position, *collision_point_a, *collision_point_b, true);
	}

	line_line_collision_is_earliest : bool = false;
	L :: struct{a:s8; b:s8;c : s8; d : s8;};
	lines_indices :: L.[.{0,1,2,3}, .{0,3,1,2}, .{0,2,3,1},.{1,2,0,3}, .{1,3,2,0}, .{2,3,0,1}];
	for a_line : lines_indices
	{
		for b_line : lines_indices
		{
			Other_Delta := b.translation.position - a.translation.position;
			A := a.shape.vertices[a_line.a];
			B := a.shape.vertices[a_line.b];

			C := b.shape.vertices[b_line.a];
			D := b.shape.vertices[b_line.b];
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

cast_Bounding_Sphere :: (a : *Physics_Object(.SPHERE), b : *Physics_Object(.SPHERE), dt : float) -> (intersect_time : float, do_intersect : bool, col_point_a : float3, col_point_b : float3, normal : float3)
{
	combined_radius := a.shape.radius + b.shape.radius;
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
		col_point_a = normal * a.shape.radius;
		col_point_b = normal * a.shape.radius * -1;
	}
	return hit_time , do_collide, col_point_a, col_point_b, normal;
}


cast_Bounding_Sphere_Tetraeder :: (sphere : *Physics_Object(.SPHERE), tetraeder : *Physics_Object(.TETRAEDER), dt : float) -> (intersect_time : float, do_intersect : bool, col_point_a : float3, col_point_b : float3, normal : float3)
{
	assert(false, "Not implemented");
	return -1, false, .{}, .{}, .{};
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


Physics_Objects_Iterator :: struct(shape_type : Shape_Type) {};

for_expansion :: (using po : $P/Physics_Objects_Iterator,  code : Code, $flags : For_Flags) #expand
{
	reverse    :: cast(bool) flags & .REVERSE;
	by_pointer :: cast(bool) flags & .POINTER;
	#assert by_pointer;
	#if shape_type == .SPHERE
	{
		for * <=reverse sphere, index: physics_state.spheres
		{
			`it       := sphere;
			`it_index := mangle_Physics_ID(shape_type, index);
			 #insert code;
		}
	}else #if shape_type == .TETRAEDER
	{
		for * <=reverse tet, index : physics_state.tetraeder
		{
			`it       := tet;
			`it_index := mangle_Physics_ID(shape_type, index);
			#insert code;
		}
	}else{
		assert(false, "We cant iterate over %.", o.shape_type);
	}
}


#scope_module

SHAPE_ENCODING_BITS :: #run -> s64
{
	#import "Bit_Operations";
	ti := type_info(Shape_Type);
	highest_set_bit := 0;
	for ti.values
	{
		if it == xx Shape_Type.UNKOWN  continue;
		highest_set_bit = max(highest_set_bit, bit_scan_reverse(it));
	}
	return highest_set_bit;
};

physics_state : struct
{
	time : Apollo_Time;
	tetraeder : Static_Auto_Array(100,Physics_Object(.TETRAEDER));
	spheres   : Static_Auto_Array(100,Physics_Object(.SPHERE));
	//TODO(qwendo): boxes 
	//TODO(qwendo): capsules
	

	
}






create_Sphere :: (base : Physics_Base, shape : Shape(.SPHERE)) -> Physics_ID
{
	sphere, idx := array_add(*physics_state.spheres);
	if !sphere 
	{
		log_error("Could not add Sphere to Physics State!");
		return Physics_ID_INVALID;
	}

	sphere.* = .{base, shape};

	return mangle_Physics_ID(.SPHERE, idx);
}

create_Tetraeder :: (base : Physics_Base, shape : Shape(.TETRAEDER)) -> Physics_ID
{
	tet, idx := array_add(*physics_state.tetraeder);
	if !tet
	{
		log_error("Could not add Tetraeder to Physics State!");
		return Physics_ID_INVALID;
	}
	tet.* = .{base, shape};

	return mangle_Physics_ID(.TETRAEDER, idx);
}


SHAPE_BIT_SHIFT :: (size_of(Physics_ID) * 8) - SHAPE_ENCODING_BITS;
SHAPE_MASK      :: (cast(Physics_ID) (1<<SHAPE_ENCODING_BITS) - 1);
MIN_LEGAL_INDEX :: 1;
MAX_LEGAL_INDEX :: (1 << (size_of(Physics_ID) * 8 - SHAPE_ENCODING_BITS)) - 1;

MANGLE_CHECKS :: true;

mangle_Physics_ID :: (shape_type : Shape_Type, index : int) -> Physics_ID
{

	if shape_type == .UNKOWN  return Physics_ID_INVALID;
	shape_part : u16 = xx shape_type;

	#if MANGLE_CHECKS
	{
		#assert physics_state.spheres.count   < MAX_LEGAL_INDEX - MIN_LEGAL_INDEX;
		#assert physics_state.tetraeder.count < MAX_LEGAL_INDEX - MIN_LEGAL_INDEX;
		assert(0 <= index && index <= MAX_LEGAL_INDEX - MIN_LEGAL_INDEX, 
			"Index % is out of range, [%, %] are valid indices", index, 0, MAX_LEGAL_INDEX - MIN_LEGAL_INDEX);
		if shape_type == .SPHERE    assert(index < physics_state.spheres  .capacity, 
			"Spheres can only have indices in range [%, %] but it was %",   0, physics_state.spheres.count,   index);
		if shape_type == .TETRAEDER assert(index < physics_state.tetraeder.capacity, 
			"Tetraeder can only have indices in range [%, %] but it was %", 0, physics_state.tetraeder.count, index);

	}

	index_part    : u16 = cast(u16) index + MIN_LEGAL_INDEX;
	return xx ((shape_part << SHAPE_BIT_SHIFT) | index_part);
}

demangle_Physics_ID :: (id : Physics_ID) -> (shape_type : Shape_Type, index : int)
{
	if id == Physics_ID_INVALID  return .UNKOWN, -1;
	#if MANGLE_CHECKS
	{
		#run
		{
			ti := type_info(Shape_Type);
			for ti.values
			{
				if it != xx Shape_Type.UNKOWN 
				{
					assert(it < (1 << SHAPE_ENCODING_BITS), "We can only encode up to %, but % has value %", (1 << SHAPE_ENCODING_BITS) - 1, ti.names[it_index], it);
				}
			}
		}
	}
	
	shape_type := cast(Shape_Type) (id >> SHAPE_BIT_SHIFT) & SHAPE_MASK;
	index    : int = xx (id & ~(SHAPE_MASK << SHAPE_BIT_SHIFT)) - MIN_LEGAL_INDEX;

	#if MANGLE_CHECKS
	{
		assert(0 <= index && index <= MAX_LEGAL_INDEX - MIN_LEGAL_INDEX, "Decoded index % which is out of range for [%,%]!", index, 0, MAX_LEGAL_INDEX - MIN_LEGAL_INDEX);
		if shape_type == .SPHERE  assert(0 <= index && index < physics_state.spheres.capacity, 
			"Decoded index is %, which is out of range [0, %]!\nWhere did we get this from?", index, physics_state.spheres.count - 1);
		if shape_type == .TETRAEDER  assert(0 <= index && index < physics_state.tetraeder.capacity, 
			"Decoded index is %, which is out of range [0, %]!\nWhere did we get this from?", index, physics_state.tetraeder.count - 1);
	}

	return shape_type, xx index;
}

Physics_Objects_By_ID :: struct {};

for_expansion :: (p : Physics_Objects_By_ID, code : Code, flags : For_Flags) #expand
{
	`it       : Physics_ID;
	`it_index : int;
	
	for _, index : *physics_state.spheres
	{
		it = mangle_Physics_ID(.SPHERE, index);
		#insert code;
		it_index += 1;
	}
	for _, index : *physics_state.tetraeder
	{
		it = mangle_Physics_ID(.TETRAEDER, index);
		#insert code;
		it_index += 1;
	}
}




#load "Physics/Error_Reporting.jai";
#load "Physics/Visualization.jai";



#import "IUMath";
#import "Vector";
using,except(.["operator +", "operator -"]) Math :: #import "Math";
#import "Basic";
#import "Static_Auto_Array";
#import "Ring_Buffer";
#import "Color";
#import "Sort";
