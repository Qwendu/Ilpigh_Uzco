#scope_export


Static_Auto_Array :: struct(capacity : int, type : Type)
{
	count : int;
	data  : [capacity] type;
}


array_add :: (using arr : *$Arr/Static_Auto_Array, el : Arr.type)
{
	if count >= Arr.capacity
	{
		log_error("Exceeded capactiy of array, it is %", Arr.capacity);
		return;
	}
	data[count] = el;
	count += 1;
}

array_add_c_call :: (using arr : *$Arr/Static_Auto_Array, el : Arr.type) #c_call
{
	if count >= Arr.capacity
	{
		return;
	}
	data[count] = el;
	count += 1;
}

array_add :: (using arr : *$Arr/Static_Auto_Array) -> *Arr.type, int
{
	if count >= Arr.capacity
	{
		log_error("Exceeded capactiy of array, it is %", Arr.capacity);
		return null, -1;
	}
	idx := count;
	ptr := *data[count];
	count += 1;
	return ptr, count;
}

operator *[] :: (using arr : *$Arr/Static_Auto_Array, index : int) -> *Arr.type
{
	return *data[index];
}

for_expansion :: (arr : $Arr/Static_Auto_Array, code : Code, flags : For_Flags) #expand
{
	rev :: cast(bool) flags & .REVERSE;
	ptr :: cast(bool) flags & .POINTER;
	#if rev
	{
		for < idx : arr.count-1..0
		{
			#if ptr  `it := *arr.data[idx];
			else     `it :=  arr.data[idx];
			`it_index := idx;
			#insert code;
		}
	}else{
		for < idx : arr.count-1..0
		{
			#if ptr  `it := *arr.data[idx];
			else     `it :=  arr.data[idx];
			`it_index := idx;
			#insert code;
		}
	}
}


#scope_file
#import "Basic";
