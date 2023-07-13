String_By_Line :: struct {data : string;};

for_expansion :: (by_line : String_By_Line, body : Code, flags : For_Flags) #expand
{
	assert(!(flags & .REVERSE));
	assert(!(flags & .POINTER));
	remainder := by_line.data;
	`it : string;
	`it_index : int;
	found : bool = true;
	while found
	{
		found, it, remainder = split_from_left(remainder, #char "\n");
		defer it_index += 1;
		#insert body;
	}
}



#scope_file

#import "Basic";
#import "String";
