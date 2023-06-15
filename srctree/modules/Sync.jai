#scope_export

atomic_volatile_read :: (ptr : *$T) -> T #no_context
{
	res : T;
	#asm
	{
		mfence;
		mov res, [ptr];
	}
	return res;
}

atomic_volatile_write :: (ptr : *$T, val : T) #no_context
{
	#asm
	{
		mfence;
		mov [ptr], val;
	}
}
