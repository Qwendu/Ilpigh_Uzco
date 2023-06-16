#scope_export


AVector :: struct(dim : int, T : Type)
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
		xy : AVector(2, T);
	#place y;
		yz : AVector(2, T);
	}
	#if dim >= 4
	{
	#place x;
		xyz : AVector(3, T);
	#place y;
		yzw : AVector(3, T);
	}
}


dot :: (a : $V/AVector, b : V) -> V.T #expand
{
	
	res : V.T;
	#if V.dim == 4 && V.T == float32
	{
		#asm
		{
			movaps  a_v : vec, a;
			dpps a_v, b, 0xF1;
			movss [*res], a_v;
		}
	}else{
		for a.data  
		{
			res += a.data[it_index] * b.data[it_index];
		}

	}
	return res;
}


operator + :: (a : $V/AVector, b : V) -> V #symmetric #expand
{
	r := a;
	#if V.dim == 4 && V.T == s32
	{
		#asm
		{
			paddd r, b;
		}
	}else{
		#assert false;
	}
	return r;
}


operator - :: (a : $V/AVector, b : V) -> V #expand
{
	r := a;
	#if V.dim == 4 && V.T == s32
	{
		#asm
		{
			psubd r, b;
		}
	}else{
		#assert false;
	}
	return r;
}

operator * :: (a : $V/AVector, b : V.T) -> V #symmetric #expand
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

operator / :: (a : $V/AVector, b : V.T) -> V #expand
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

operator [] :: (a : $V/AVector, idx : int) -> V.T
{
	return a.data[idx];
}


length :: (a : $V/AVector) -> V.T
{
	discriminant : V.T;
	for a.data  discriminant += it * it;
	return sqrt(discriminant);
}

length_Squared :: (a : $V/AVector) -> V.T
{
	discriminant : V.T;
	for a.data  discriminant += it * it;
	return discriminant;
}

cross :: (a : AVector(3,float), b : AVector(3, float)) -> AVector(3, float)
{
	r : type_of(a);
	r.x = a.y * b.z - a.z * b.y;
	r.y = a.z * b.x - a.x * b.z;
	r.z = a.x * b.y - a.y * b.x;
	return r;
}


normalize :: (a : $V/AVector, fallback : V) -> V
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
