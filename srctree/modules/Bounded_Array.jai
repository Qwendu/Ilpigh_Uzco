#scope_export


Bounded_Array :: struct(T : Type, bound : int)
{
	used : int;
	#as data : [bound] T;
}


add :: (arr : *$B/Bounded_Array, t : B.T, loc := #caller_location)
{
	if arr.used < arr.data.count
	{
		arr.data[arr.used] = t;
		arr.used += 1;
	}else{
		log_error("Bounded_Array at %:% is over full, dropping elements...", loc.fully_pathed_filename, loc.line_number);
	}
}

operator [] :: (arr : $B/Bounded_Array, idx : int) -> B.T #expand
{
	return arr.data[idx];
}

operator *[] :: (arr : $B/Bounded_Array, idx : int) -> *B.T #expand
{
	return *arr.data[idx];
}

for_expansion :: (arr : $B/Bounded_Array, body : Code, flags : For_Flags) #expand
{
	for i : 0..arr.used-1
	{
		`it_index : int;
		if flags & .REVERSE  it_index = arr.used - i - 1;
		else                 it_index = i;
		#if flags & .POINTER
		{
			`it := *arr.data[it_index];
		}else{
			`it :=  arr.data[it_index];
		}
		#insert body;
	}
}


#scope_file

#import "Basic";
