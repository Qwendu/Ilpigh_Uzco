#scope_export

Mutex  :: struct(T : Type)
{
	lock : int;
	padding : [#run padding_Needed_To_Multiple(size_of(int), target_cpu.cache.cache_line_size)] u8;
	data : T;
}


create :: (m : *Mutex($T))
{
	m.lock = platform.mutex_create();
}

acquire :: (mutex : *$M/Mutex, loc := #caller_location) -> *M.T  #expand
{
	//print("Acquiring % in %\n", mutex, loc);
	platform.mutex_acquire(mutex.lock);
	return *mutex.data;
}

release :: (mutex : *$M/Mutex, loc := #caller_location)  #expand
{
	//print("Releasing % in %\n", mutex, loc);
	platform.mutex_release(mutex.lock);
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
#import "Platform_Interface";
