#scope_export


Matrix :: struct(Rows : int, Cols : int, T : Type)
{
	data : [Rows][Cols] T;
	#place data;
	row_vectors : [Rows] Vector(Cols, T);
};


float4x4 :: Matrix(4,4,float);
float3x3 :: Matrix(3,3,float);

identity :: ($N : int, $T : Type) -> Matrix(N,N, T) #expand #no_debug
{
	r : Matrix(N,N, T) = .{};
	for 0..N-1  r.data[it][it] = cast(T) 1;
	return r;
}

operator * :: (mat : $M/Matrix, v : Vector(M.Cols, M.T)) -> Vector(M.Rows, M.T)
{
	v :Vector(M.Rows, M.T);
	for row: 0..mat.Rows-1
	{
		for col: 0..mat.Cols-1
		{
			v.data[row] += mat.data[row][col] * v.data[col];
		}
	}
	return v;
}

operator * :: (a : Matrix($N, $K, $T), b : Matrix(K, $M, T)) -> Matrix(N, M, T)
{
	res :Matrix(N, M, T) = .{};
	for row: 0..N-1
	{
		for col: 0..M-1
		{
			for k: 0..K-1
			{
				res.data[row][col] += a.data[row][k] * b.data[k][col];
			}
		}
	}
	return res;
}

affine_Transform :: (mat : Matrix($N, N, $T), v : Vector(N-1, T)) -> Vector(N, T)
{
	res : Vector(N, T);
	for row: 0..N-1
	{
		for col : 0..N-2
		{
			res.data[row] += mat.data[row][col] * v.data[col];
		}
		res.data[row] += mat.data[row][N-1];
	}
	return res;
}

add_Offset :: (mat : *float4x4, pos : float3)
{
	mat.row_vectors[0].w += pos.x;
	mat.row_vectors[1].w += pos.y;
	mat.row_vectors[2].w += pos.z;
}

add_Offset :: (mat : float4x4, pos : float3) -> float4x4 #must
{
	res := mat;
	res.row_vectors[0].w += pos.x;
	res.row_vectors[1].w += pos.y;
	res.row_vectors[2].w += pos.z;
	return res;
}

#scope_file





#import "Vector";
