#scope_export


AABB :: struct (N : int, T : Type)
{
	center      : Vector(N, T);
	half_extent : Vector(N, T);
}


aabb_To_Corners :: (aabb : AABB(3, float)) -> [8] float3
{
	res : [8] float3;

	for 0..8-1
	{
		x_factor := ifx it&1 then 1.0 else -1.0;
		y_factor := ifx it&2 then 1.0 else -1.0;
		z_factor := ifx it&4 then 1.0 else -1.0;
		offset := float3.{
			aabb.half_extent.x * x_factor,
			aabb.half_extent.y * y_factor,
			aabb.half_extent.z * z_factor,
		};
		res[it] = offset + aabb.center;
	}
	return res;
}


#import "Vector";
#import "Math";
