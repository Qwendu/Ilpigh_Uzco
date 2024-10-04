#scope_export
// WARNING: Everything in this file assumes single threading.
//   All in here is intended to be run when the program crashed, everything
//   might be in invalid state, which is why we use a special allocator (which
//   is statically allocated), and we should not rely on synchronization primitives.

append_And_Write :: (str : string) #expand
{
	append(`builder, str);
	#if Config.COMPILATION_MODE == .DEVELOPEMENT
	{
		write_string(str);
	}
}

create_Diagnostic_Context :: ($name : string, builder : *String_Builder) -> Context #c_call
{
	ctx : Context;
	ctx.logger = xx (message : string, builder : *String_Builder, info : Log_Info)
	{
		for String_By_Line.{message}
		{
			append_And_Write("DIAG::");
			append_And_Write(name);
			append_And_Write(": ");
			append_And_Write(it);
			append_And_Write("\n");
		}
	};
	ctx.logger_data = builder;
	ctx.allocator = allocator_For_Diagnostics;
	return ctx;
}



#scope_file


allocator_For_Diagnostics := Allocator.{proc = reserve_Allocator, data = null};

reserve_Allocator : Allocator_Proc : (mode : Allocator_Mode, size : s64, old_size : s64, old_memory : *void, allocator_data : *void) -> *void
{
	if mode ==
	{
	case .ALLOCATE;
		if arena.count + size >= arena.capacity  return null;
		base := arena.count;
		arena.count += size;
		ptr := *arena[base];
		return ptr;

	case .RESIZE;
		new_ptr := reserve_Allocator(.RESIZE, size, 0, null, null);
		if new_ptr 
		{
			memcpy(old_memory, new_ptr, old_size);
			return new_ptr;
		}
		return null;

	case .SHUTDOWN;
		arena.count = 0;
	case .IS_THIS_YOURS;
		if *arena[0] <= old_memory && old_memory < *arena[arena.capacity]  return xx 1;
		return null;
	case;
		return null;
	}

	return null;
}


arena : Static_Auto_Array(#run Mebi(100), u8);



#import "Basic";
#import "Logging_Utils";
#import "Memory";
#import "Static_Auto_Array";
Config :: #import "Config";
