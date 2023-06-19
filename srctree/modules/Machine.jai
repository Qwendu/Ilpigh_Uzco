#scope_export

Cache_Properties :: struct
{
	Cache_Level :: struct
	{
		size_in_bytes : int;
		mode : enum {WRITE_THROUGH; WRITE_BACK;} = .WRITE_BACK;
	};
	cache_line_size : int;
	levels : [] Cache_Level;
};

CACHE_LINE_SIZE :: 64;

CPU :: struct
{
	base_clock : int;
	number_of_cores : int;
	number_of_threads : int;
	cache : Cache_Properties;
};


amd_ryzen_7_1700 :: CPU.
{
	base_clock = #run Giga(3),
	number_of_cores = 8,
	number_of_threads = 16,
	cache = .{
		cache_line_size = 64,
		levels = .[
			.{
				size_in_bytes = #run Kibi(768),
			},
			.{
				size_in_bytes = #run Mebi(4),
			},
			.{
				size_in_bytes = #run Mebi(16),
			}
		]
	}
};


target_cpu :: amd_ryzen_7_1700; // TODO integrate this assignment into the build system


padding_Needed_To_Multiple :: (to_pad : int, multiple : int) -> int
{
	return multiple - ifx (to_pad % multiple) else multiple;
}



Giga :: (n: int) -> int #expand
{
	return Mega(n) * 1000;
}

Mega :: (n: int) -> int #expand
{
	return Kilo(n) * 1000;
}

Kilo :: (n: int) -> int #expand
{
	return n * 1000;
}

#import "Basic";
#import "Memory";
