#scope_export


AVector :: struct(dim : int, T : Type)
{
	x : T;
	#assert dim >= 2 ;
	#if dim >= 2  y : T;
	#if dim >= 3  z : T;
	#if dim >= 4  w : T;
	
	#place x;
	data : [dim] T = ---;
	
	#if dim >= 3
	{
	#place x;
		xy : AVector(2, T) = ---;
	#place y;
		yz : AVector(2, T) = ---;
	}
	#if dim >= 4
	{
	#place x;
		xyz : AVector(3, T) = ---;
	#place y;
		yzw : AVector(3, T) = ---;
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
	#if V.dim == 4 && V.T == float32
	{
		b_vec := V.{b,b,b,b};
		#asm
		{
			mulps r, b_vec;
		}
	}else{
		#assert false;
	}
	return r;
}

operator / :: (a : $V/AVector, b : V.T) -> V #expand
{
	r := a;
	#if V.T == float32
	{
		b_v := V.{b,b,b,b};
		#asm
		{
			divps r, b_v;
		}
	}else{
		#assert false;
	}
	return r;
}



convert :: (a : AVector($N, $T), $to : Type) -> AVector(N, to)
{
	#assert to == s32 || to == float32;
	#assert N == 4;
	#assert T == s32 || T == float32;
	res : AVector(N, to) = ---;
	#if T == float32 && to == s32
	{
		#asm
		{
			cvttps2dq res, a;
		}
	}else #if T == s32 && to == float32
	{
		#asm
		{
			cvtdq2ps res, a;
		}
	}else{
		#assert false;
	}
	return res;
}



clamp :: inline (v : $V/AVector, min : V, max : V) -> V
{
	res : V = v;
	#if V.dim == 4 && V.T == float32
	{
		#asm
		{
			maxps res, min;
			minps res, max;
		}
	}else{
		#assert false;
	}
	return res;
}

#scope_file
#import "Basic";

#import "Math";
#import "Vector";
