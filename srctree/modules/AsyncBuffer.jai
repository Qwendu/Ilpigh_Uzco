#scope_export

ASSERT_VALID_STATE :: true;
PRINT_VALID_STATES :: true;



AsyncBuffer :: struct(Element : Type)
{
	using pointers : PointersStruct; 
	// @Robustness @Efficiency We should probably pad for the cache line size in the Pointer Struct
	Padded_Element :: struct 
	{
		// #align CACHE_LINE_SIZE;
		element : Element;
	}
	buffers : [3] Padded_Element;
}


read :: (buffer : *$Buffer/AsyncBuffer) -> *Buffer.Element
{
	#if ASSERT_VALID_STATE  assert(valid(buffer.pointers), "We did not get a valid state as input!");
	old := atomic_read(*buffer.pointers.cr_cw_nr);
	while true 
	{
		next_pointers := next_read(PointersStruct.{cr_cw_nr = old});
		success : bool;
		success, old = compare_and_swap(*buffer.pointers.cr_cw_nr, old, next_pointers.cr_cw_nr);
		if success  break;
	}
	#if ASSERT_VALID_STATE  assert(valid(buffer.pointers), "We did not result in a valid state");
	return *buffer.buffers[atomic_read(*buffer.pointers).next_read].element;
}

write :: (buffer : *$Buffer/AsyncBuffer) -> *Buffer.Element
{
	#if ASSERT_VALID_STATE  assert(valid(buffer.pointers), "We did not get a valid state as input!");
	old := atomic_read(*buffer.pointers.cr_cw_nr);
	while true 
	{
		next_pointers := next_write(PointersStruct.{cr_cw_nr = old});
		success : bool;
		success, old = compare_and_swap(*buffer.pointers.cr_cw_nr, old, next_pointers.cr_cw_nr);
		if success  break;
	}
	if !valid(buffer.pointers)  print("buffer.pointers = %\n", buffer.pointers);
	#if ASSERT_VALID_STATE  assert(valid(buffer.pointers), "We did not result in a valid state");
	return *buffer.buffers[atomic_read(*buffer.pointers).next_read].element;
}

#scope_file


PointersStruct :: struct
{
	current_read  : u8 = 0;
	current_write : u8 = 1;
	next_read     : u8 = 2;
	#place current_read;
	cr_cw_nr      : u32 = ---; @Atomic
};
#assert size_of(PointersStruct) == 4;


next_read :: (pointers : PointersStruct) -> PointersStruct
{
	res := pointers;
	using pointers;
	if current_read == next_read  return res;
	else{
		res.current_read = next_read;
	}
	return res;
}

next_write :: (pointers : PointersStruct) -> PointersStruct
{
	res := pointers;
	using pointers;
	if current_read == next_read 
	{
		third_value : u8 = 10;
		for 0..2
		{
			if (it == current_read || it == current_write) 
			{
				continue;
			}
			third_value = cast(u8) it;
		}
		res.current_write = third_value;
		res.next_read     = current_write;
	}else{
		res.current_write = next_read;
		res.next_read     = current_write;
	}
	return res;
}

#if ASSERT_VALID_STATE
{
	#run 
	{
		a : AsyncBuffer([100] int);
		possible_states : [3 * 3 * 3] PointersStruct;
		for cr:0..2
		{
			for cw: 0..2
			{
				for nr: 0..2
				{
					idx :=  cr * 3 * 3 + cw * 3 + nr;
					possible_states[idx].current_read  = xx cr;
					possible_states[idx].current_write = xx cw;
					possible_states[idx].next_read     = xx nr;
				}
			}
		}


		#if PRINT_VALID_STATES  print("All Atomic reads\n");
		for possible_states
		{
			before := it;
			validity := valid(it);
			if !validity continue;
			a.pointers = it;
			read(*a);
			validity_after_read := valid(a.pointers);
			#if PRINT_VALID_STATES  print("read(%) -> % %\n", before, a.pointers, ifx validity_after_read then "Valid" else "INVALID");
		}

		#if PRINT_VALID_STATES  print("All Atomic writes\n");
		for possible_states
		{
			before := it;
			validity := valid(it);
			if !validity continue;
			a.pointers = it;
			write(*a);
			validity_after_read := valid(a.pointers);
			#if PRINT_VALID_STATES  print("write(%) -> % %\n", before, a.pointers, ifx validity_after_read then "Valid" else "INVALID");
		}
		
	}
}

valid :: (v : PointersStruct) -> bool
{
	values_are_in_range := true;
	values_are_in_range &= 
		   v.current_read == 0
		|| v.current_read == 1
		|| v.current_read == 2;
	values_are_in_range &= 
		   v.current_write == 0
		|| v.current_write == 1
		|| v.current_write == 2;
	values_are_in_range &= 
		   v.next_read == 0
		|| v.next_read == 1
		|| v.next_read == 2;

	return v.current_read != v.current_write && v.current_write != v.next_read && values_are_in_range;
}

#import "Atomics";
#import "Basic";
