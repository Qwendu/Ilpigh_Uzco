#scope_export

all_mutexes : Static_Auto_Array(100, HANDLE);

mutex_create :: () -> int #c_call
{
	handle := CreateMutexA(null, false, null);
	array_add_c_call(*all_mutexes, handle);
	return all_mutexes.count - 1;
}

mutex_acquire :: (mutex : int) #c_call
{
	WaitForSingleObject(all_mutexes.data[mutex], INFINITE);
}

mutex_release :: (mutex : int) #c_call
{
	ReleaseMutex(all_mutexes.data[mutex]);
}

CreateMutexA :: (security : *void, initially_owned : bool, name : *u8) -> HANDLE #foreign kernel;
ReleaseMutex :: (handle : HANDLE) -> s32 #foreign kernel;

#import "Static_Auto_Array";




