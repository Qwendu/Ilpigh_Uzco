#scope_export

ASSERT_VALID_STATE :: false;
PRINT_VALID_STATES :: false;



Async_Buffer :: struct(Element : Type)
{
	using pointers : Pointers_Struct; 
	// @Robustness @Efficiency We should probably pad for the cache line size in the Pointer Struct
	Padded_Element :: struct 
	{
		// #align CACHE_LINE_SIZE;
		element : Element;
	}
	buffers : [3] Padded_Element;
}

Async_Buffer_End :: struct(Element : Type, side : enum {WRITER;READER;})
{
	ptr : *Async_Buffer(Element);
};

get_Ends :: (buf : *$Buffer/Async_Buffer) -> (reader : Async_Buffer_End(Buffer.Element, .READER), writer : Async_Buffer_End(Buffer.Element, .WRITER))
{
	return .{buf}, .{buf};
}


get_Read_Pointer :: (end : $Buffer/Async_Buffer_End) -> *Buffer.Element
{
	#if Buffer.side == .READER
	{
		buffer := end.ptr;
		old := atomic_read(*buffer.pointers.cr_cw_nr);
		#if ASSERT_VALID_STATE  assert(valid(Pointers_Struct.{cr_cw_nr = old})); // @HeisenBug
		while true 
		{
			next_pointers := next_read(Pointers_Struct.{cr_cw_nr = old});
			success : bool;
			success, old = compare_and_swap(*buffer.pointers.cr_cw_nr, old, next_pointers.cr_cw_nr);
			if success  break;
		}
		#if ASSERT_VALID_STATE  assert(valid(Pointers_Struct.{cr_cw_nr = atomic_read(*buffer.pointers.cr_cw_nr)}));
		return *buffer.buffers[atomic_read(*buffer.pointers).current_read].element;
	}else{
		// IF we are the writer then we do not advance in order to read!
		return *buffer.buffers[atomic_read(*buffer.pointers).current_read].element;
	}
}

get_Write_Pointer :: (end : $Buffer/Async_Buffer_End) -> *Buffer.Element
{
	#assert Buffer.side == .WRITER;
	buffer := end.ptr;
	old := atomic_read(*buffer.pointers.cr_cw_nr);
	#if ASSERT_VALID_STATE  assert(valid(Pointers_Struct.{cr_cw_nr = old}));
	while true 
	{
		next_pointers := next_write(Pointers_Struct.{cr_cw_nr = old});
		success : bool;
		success, old = compare_and_swap(*buffer.pointers.cr_cw_nr, old, next_pointers.cr_cw_nr);
		if success  break;
	}
	#if ASSERT_VALID_STATE  assert(valid(Pointers_Struct.{cr_cw_nr = atomic_read(*buffer.pointers.cr_cw_nr)}));
	return *buffer.buffers[atomic_read(*buffer.pointers).current_write].element;
}

#scope_file


Pointers_Struct :: struct
{
	current_read  : u8 = 0;
	current_write : u8 = 1;
	next_read     : u8 = 2;
	#place current_read;
	cr_cw_nr      : u32 = ---; @Atomic
};
#assert size_of(Pointers_Struct) == 4;


next_read :: (pointers : Pointers_Struct) -> Pointers_Struct
{
	res := pointers;
	using pointers;
	if current_read == next_read  return res;
	else{
		res.current_read = next_read;
	}
	return res;
}

next_write :: (pointers : Pointers_Struct) -> Pointers_Struct
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

#if PRINT_VALID_STATES
{
	#run 
	{
		buf : Async_Buffer(int);
		reader, writer := get_Ends(*buf);
		possible_states : [3 * 3 * 3] Pointers_Struct;
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
			buf.pointers = it;
			get_Read_Pointer(reader);
			validity_after_read := valid(buf.pointers);
			#if PRINT_VALID_STATES  print("read(%) -> % %\n", before, buf.pointers, ifx validity_after_read then "Valid" else "INVALID");
		}

		#if PRINT_VALID_STATES  print("All Atomic writes\n");
		for possible_states
		{
			before := it;
			validity := valid(it);
			if !validity continue;
			buf.pointers = it;
			get_Write_Pointer(writer);
			validity_after_read := valid(buf.pointers);
			#if PRINT_VALID_STATES  print("write(%) -> % %\n", before, buf.pointers, ifx validity_after_read then "Valid" else "INVALID");
		}
		
	}
}

valid :: (v : Pointers_Struct) -> bool
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

	#if !PRINT_VALID_STATES  assert(values_are_in_range, sprint("Values are not in range %\n", v));
	cur_read_diff := v.current_read != v.current_write;
	#if !PRINT_VALID_STATES  assert(cur_read_diff, sprint("current_read (%) != current_write (%) does not hold", v.current_read, v.current_write));
	nex_read_diff := v.next_read != v.current_write;
	#if !PRINT_VALID_STATES  assert(nex_read_diff, sprint("next_read (%) != current_write (%) does not hold"   , v.next_read,    v.current_write));

	return  cur_read_diff && nex_read_diff && values_are_in_range;
}

#import "Atomics";
#import "Basic";
