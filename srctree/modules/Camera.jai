#scope_export


Camera :: struct
{
	position : float3;
	rotation : Quaternion;
	fov : float  = 90;
	near : float = 0.1;
	far  : float = 20;
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
	top    := tan(fov/360 * PI) * near;
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
	rotation : float4x4 = rotation_Matrix(cam.rotation);

	position := identity(4, float);
	position.row_vectors[0].w = -cam.position.x;
	position.row_vectors[1].w = -cam.position.y;
	position.row_vectors[2].w = -cam.position.z;

	// At first, put camera into the center of the world
	// Then rotate everything around the camera
	return rotation * position;
}

camera_To_World_Rotation :: (cam : *Camera) -> float4x4
{
	res : float4x4 = rotation_Matrix(inverse(cam.rotation));
	return res;
}


Cube_Camera :: struct
{

}


#import "Vector";
#import "Matrix";
#import "Math";
#import "Quaternion";
