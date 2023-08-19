#scope_export

Mutex  :: struct(T : Type)
{
	lock : int;
	padding : [#run padding_Needed_To_Multiple(size_of(int), target_cpu.cache.cache_line_size)] u8;
	data : T;
}


acquire :: (mutex : *$M/Mutex, loc := #caller_location) -> *M.T  #expand
{
	//print("Acquiring % in %\n", mutex, loc);
	while !compare_and_swap(dest = *mutex.lock, old = 0, new = 1)
	{}
	return *mutex.data;
}

release :: (mutex : *$M/Mutex, loc := #caller_location)  #expand
{
	//print("Releasing % in %\n", mutex, loc);
	while !compare_and_swap(dest = *mutex.lock, old = 1, new = 0)
	{}
}

for_expansion :: (m : *Mutex($T), body : Code, flags : For_Flags)
{
	t := acquire(m);
	for_expansion(t, body, flags);
	release(m);
}

#import "Atomics";
#import "Sync";
#import "Basic";
#import "Machine";
