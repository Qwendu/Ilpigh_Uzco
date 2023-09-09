#scope_export


Mesh :: struct
{
	vertices  : [] float3;
	triangles : [] int3;
	aabb : AABB(3, float);
	
	material : Material;
};

Mesh_Instance :: struct
{
	id : Mesh_ID;
	mesh_to_world : float4x4;
};

Mesh_ID   :: #type,distinct int;
Mesh_Path :: #type,distinct string;

generate_AABB_Of_Mesh :: (mesh : Mesh) -> AABB(3, float)
{
	res : AABB(3, float);
	aabb_min : float3 = mesh.vertices[0];
	aabb_max : float3 = mesh.vertices[0];

	for 1..mesh.vertices.count-1
	{
		v := mesh.vertices[it];
		aabb_min.x = min(aabb_min.x, v.x);
		aabb_min.y = min(aabb_min.y, v.y);
		aabb_min.z = min(aabb_min.z, v.z);

		aabb_max.x = max(aabb_max.x, v.x);
		aabb_max.y = max(aabb_max.y, v.y);
		aabb_max.z = max(aabb_max.z, v.z);
	}
	half_extent := (aabb_max - aabb_min) * 0.5;
	center := aabb_min + half_extent;
	
	return .{center = center, half_extent = half_extent};
}


#import "Vector";
#import "Matrix";
#import "Material";
#import "AABB";
#import "IUMath";



