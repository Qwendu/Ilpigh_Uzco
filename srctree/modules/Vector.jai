#scope_export


Vector :: struct(dim : int, T : Type)
{
	x : T;
	#assert dim >= 2 ;
	#if dim >= 2  y : T;
	#if dim >= 3  z : T;
	#if dim >= 4  w : T;
	
	#place x;
	data : [dim] T;
	
	#if dim >= 3
	{
	#place x;
		xy : Vector(2, T);
	#place y;
		yz : Vector(2, T);
	}
	#if dim >= 4
	{
	#place x;
		xyz : Vector(3, T);
	#place y;
		yzw : Vector(3, T);
	}
}


int2   :: Vector(2, int);
float2 :: Vector(2, float);

int3   :: Vector(3, int);
float3 :: Vector(3, float);

int4   :: Vector(4, int);
float4 :: Vector(4, float);

dot :: (a : $V/Vector, b : V) -> V.T
{
	res : V.T;
	for a.data  
	{
		res += a.data[it_index] * b.data[it_index];
	}
	return res;
}


operator + :: (a : $V/Vector, b : V) -> V #symmetric
{
	r := a;
	#insert #run -> string
	{
		builder : String_Builder;
		for 0..V.dim-1
		{
			print_to_builder(*builder, "\tr.data[%] += b.data[%];\n", it, it);
		}
		insert :=  builder_to_string(*builder);
		return insert;
	};
	return r;
}


operator - :: (a : $V/Vector, b : V) -> V
{
	r := a;
	#insert #run -> string
	{
		builder : String_Builder;
		for 0..V.dim-1
		{
			print_to_builder(*builder, "\tr.data[%] -= b.data[%];\n", it, it);
		}
		insert :=  builder_to_string(*builder);
		return insert;
	};
	return r;
}

operator * :: (a : $V/Vector, b : V.T) -> V #symmetric
{	
	r := a;
	#insert #run -> string
	{
		builder : String_Builder;
		for 0..V.dim-1
		{
			print_to_builder(*builder, "\tr.data[%] *= b;\n", it);
		}
		insert :=  builder_to_string(*builder);
		return insert;
	};
	return r;
}

operator / :: (a : $V/Vector, b : V.T) -> V
{
	r := a;
	#insert #run -> string
	{
		builder : String_Builder;
		for 0..V.dim-1
		{
			print_to_builder(*builder, "\tr.data[%] /= b;\n", it);
		}
		insert :=  builder_to_string(*builder);
		return insert;
	};
	return r;
}

operator [] :: (a : $V/Vector, idx : int) -> V.T
{
	return a.data[idx];
}


length :: (a : $V/Vector) -> V.T
{
	discriminant : V.T;
	for a.data  discriminant += it * it;
	return sqrt(discriminant);
}

length_Squared :: (a : $V/Vector) -> V.T
{
	discriminant : V.T;
	for a.data  discriminant += it * it;
	return discriminant;
}

cross :: (a : float3, b : float3) -> float3
{
	r : float3;
	r.x = a.y * b.z - a.z * b.y;
	r.y = a.z * b.x - a.x * b.z;
	r.z = a.x * b.y - a.y * b.x;
	return r;
}


normalize :: (a : $V/Vector, fallback : V) -> V
{
	len_squared := length_Squared(a);
	if len_squared < 0.0001  return fallback;
	len := sqrt(len_squared);
	r := a;
	r *= 1/len;
	return r;
}

#scope_file
#import "Basic";

#import "Math";
