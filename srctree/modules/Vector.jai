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


operator + :: (a : $V/Vector, b : V) -> V
{
	r := a;
	for r.data  r.data[it_index] += b.data[it_index];
	return r;
}

operator - :: (a : $V/Vector, b : V) -> V
{
	r := a;
	for r.data  r.data[it_index] -= b.data[it_index];
	return r;
}

operator * :: (a : $V/Vector, b : V.T) -> V #symmetric
{	
	r := a;
	for r.data  r.data[it_index] *= b;
	return r;
}

operator [] :: (a : $V/Vector, idx : int) -> V.T
{
	return a.data[idx];
}
