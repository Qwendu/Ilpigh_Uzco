#scope_export


Camera :: struct
{
	world_to_camera : float4x4;
	projection      : float4x4;

	position : float3;
}




projection_Matrix :: (
	fov    : float,
	aspect : float,
	near   : float,
	far    : float
) -> float4x4
{
	//
	// From: https://www.scratchapixel.com/lessons/3d-basic-rendering/perspective-and-orthographic-projection-matrix/opengl-perspective-projection-matrix.html
	//
	res : float4x4;
	top    := tan(fov/2) * near;
	bottom := -top;
	right  := top * aspect;
	left   := -right;

	return projection_Matrix(left = left, right = right, top = top, bottom = bottom, near = near, far = far);
}

projection_Matrix :: (
	left   : float,
	right  : float,
	top    : float,
	bottom : float,
	near   : float,
	far    : float) -> float4x4
{
	res := float4x4.{};

	res.data[0][0] =      2 * near   / (right - left);
	res.data[0][2] = (right + left)  / (right - left);
	res.data[1][1] =      2 * near   / (top - bottom);
	res.data[1][2] = (top + bottom)  / (top - bottom);
	res.data[2][2] = -(far + near)   / (far - near);
	res.data[2][3] = -2 * far * near / (far - near);
	
	res.data[3][2] = -1;
	return res;
}

project_Point :: (mat : float4x4, vec : float3) -> float4 
{
	r := affine_Transform(mat, vec);
	r.x /= r.w;
	r.y /= r.w;
	r.z /= r.w;
	return r;
}

world_To_Camera :: (cam : *Camera) -> float4x4
{
	r : float4x4;
	r.data[0][0] = 1;
	r.data[1][1] = 1;
	r.data[2][2] = 1;
	r.data[3][3] = 1;

	r.data[0][3] = -dot(r.row_vectors[0].xyz, cam.position);
	r.data[1][3] = -dot(r.row_vectors[1].xyz, cam.position);
	r.data[2][3] = -dot(r.row_vectors[2].xyz, cam.position);
	return r;
}



#import "Vector";
#import "Matrix";
#import "Math";
