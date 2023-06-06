#scope_export



rotation_Matrix :: (quat : Quaternion) -> float4x4
{
	s  := 1;

	is := quat.x * quat.x;
	js := quat.y * quat.y;
	ks := quat.z * quat.z;
	rs := quat.w * quat.w;

	ij := quat.x * quat.y;
	ik := quat.x * quat.z;
	ir := quat.x * quat.w;
	jk := quat.y * quat.z;
	jr := quat.y * quat.w;
	kr := quat.z * quat.w;


	res : float4x4 = identity(4, float);
	res.data[0][0] = 1 - 2 * s * (js + ks);
	res.data[1][1] = 1 - 2 * s * (is + ks);
	res.data[2][2] = 1 - 2 * s * (is + js);

	res.data[0][1] = 2 * s * (ij - kr);
	res.data[0][2] = 2 * s * (ik + jr);

	res.data[1][0] = 2 * s * (ij + kr);
	res.data[1][2] = 2 * s * (jk - ir);

	res.data[2][0] = 2 * s * (ik - jr);
	res.data[2][1] = 2 * s * (jk + ir);

	
	
	return res;
}

rotation_Around_Axis :: (axis : float3, angle : float) -> Quaternion
{
	
	axis_norm := normalize(axis, .{0,1,0});
	factor := sin(angle/ 2);
	q : Quaternion;
	q.x = axis_norm.x * factor;
	q.y = axis_norm.y * factor;
	q.z = axis_norm.z * factor;
	q.w = cos(angle / 2);
	normalize_or_identity(*q);

	return q;
}



#import "Math";
#import "Matrix";
#import "Vector";
