#scope_export

Bezier_Curve :: struct(DIM : int, n : int)
{
	#assert n > 0;
	#assert DIM >= 2;
	#assert DIM <= 3;
	control_points : [n + 1] Vector(DIM, float);
	subdivisions : int   = 12;
	color        : Color = RED;
}

Bezier_Curve_3D :: #bake_arguments Bezier_Curve(DIM = 3, n = 2);
Bezier_Curve_2D :: #bake_arguments Bezier_Curve(DIM = 2, n = 2);

interpolate :: (curve : Bezier_Curve($DIM,2), t : float) -> type_of(curve.control_points[0])
{
	b_20 := bernstein_Poly_2_0(t);
	b_21 := bernstein_Poly_2_1(t);
	b_22 := bernstein_Poly_2_2(t);
	return curve.control_points[0] * b_20 + curve.control_points[1] * b_21 + curve.control_points[2] * b_22;
}

bernstein_Poly_2_0 :: (t : float) -> float
{
	return (1-t) * (1-t);
}

bernstein_Poly_2_1 :: (t : float) -> float
{
	return 2 * t * (1-t);
}
bernstein_Poly_2_2 :: (t : float) -> float
{
	return t * t;
}

#scope_file
#import "Vector";
#import "Color";
