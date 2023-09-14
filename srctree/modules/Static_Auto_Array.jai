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

ordered_insert_at :: (using arr : *$Arr/Static_Auto_Array, val : Arr.type, idx : int) 
{
	v : Arr.type;
	array_add(arr, v);
	for < arr.count-1..idx + 1
	{
		arr.data[it] = arr.data[it - 1];
	}
	arr.data[idx] = val;
}

to_view :: (using arr : *$Arr/Static_Auto_Array) -> [] Arr.type
{
	view : [] Arr.type;
	view.data  = arr.data.data;
	view.count = arr.count;
	return view;
}

operator *[] :: (using arr : *$Arr/Static_Auto_Array, index : int) -> *Arr.type
{
	assert(0 <= index);
	assert(index < arr.count);
	return *data[index];
}

for_expansion :: (arr : *$Arr/Static_Auto_Array, code : Code, flags : For_Flags) #expand
{
	view := to_view(arr);
	rev :: cast(bool) flags & .REVERSE;
	ptr :: cast(bool) flags & .POINTER;
	for *=ptr <=rev `it, `it_index : view
	{
		#insert code;
	}
}

resize :: (using arr : *$Arr/Static_Auto_Array, new_size : int)
{
	assert(new_size <= capacity);
	assert(new_size >= 0);
	arr.count = new_size;
}


#scope_file
#import "Basic";
