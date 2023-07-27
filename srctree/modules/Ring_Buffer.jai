#scope_export

Ring_Buffer_Mode :: enum_flags
{
	NONE               :: 0x00;
	WRITER_INVALIDATES :: 0x01;
	ASSERT_ON_EMPTY_READ :: 0x02;
	ASSERT_ON_FULL_WRITE :: 0x04;
}

Ring_Buffer :: struct(type : Type, capacity : int, mode : Ring_Buffer_Mode)
{
	reader : int;
	writer : int;
	buffer : [capacity] type;
}


append :: (using ring : *$Ring/Ring_Buffer, el : Ring.type)
{
	#if mode & .WRITER_INVALIDATES
	{
		if next_index(writer) == reader
		{
			reader += 1;
		}
	}else{
		if next_index(writer) == reader
		{
			log_error("Ring Buffer could not write value! Skipping");
			#if mode & .ASSERT_ON_FULL_WRITE
			{
				assert(false, "Tried writing to a full buffer");
			}
			return;
		}
	}
	buffer[writer] = el;
	writer = next_index(writer);
}


read :: (using ring : *$Ring/Ring_Buffer) -> Ring.type
{

	if reader == writer 
	{
		log_error("Ring Buffer could not read value, there is none!");
		#if mode & .ASSERT_ON_EMPTY_READ
		{
			assert(false, "Tried reading from an empty buffer!");
		}
	}
	#if mode & .WRITER_INVALIDATES
	{
		return buffer[reader];
	}else{
		val := buffer[reader];
		read = next_index(reader);
		return val;
	}
}

#scope_file

next_index :: (n : int) -> int #expand
{
	return (n + 1) % `capacity;
}


#import "Basic";
