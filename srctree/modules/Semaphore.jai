#scope_export

Semaphore :: struct
{
	semaphore : int;
}

create :: (s : *Semaphore, count : int)
{
	s.semaphore = semaphore_create(count);
}

acquire :: (s : *Semaphore)
{
	platform.semaphore_acquire(s.semaphore);
}

release :: (s : *Semaphore)
{
	platform.semaphore_release(s.semaphore);
}

#scope_file
#import "Platform_Interface";
