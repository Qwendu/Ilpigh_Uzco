#scope_export

Mutex  :: struct(T : Type)
{
	lock : int;
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

#import "Atomics";
#import "Sync";
#import "Basic";
