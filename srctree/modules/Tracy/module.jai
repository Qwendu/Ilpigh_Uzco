#scope_export
#module_parameters(ENABLE := false);

AppInfo :: (message : string) #expand #no_debug #no_context
{
	#if ENABLE
	{
		___tracy_emit_message_appinfo(message.data, message.count);
	}
}

TimeZone :: ($name : string = "", $loc := #caller_location) #expand
{
	#if ENABLE
	{
		`function_name :: #procedure_name();
		tracy_loc :: #run loc_to_tracy(name,loc, function_name);
		ctx := ___tracy_emit_zone_begin(*tracy_loc, 1);
		`defer ___tracy_emit_zone_end(ctx);
	}
}


Frame :: ($frame_name : string = "<UNINITIALIZED>") #expand #no_debug #no_context
{
	#if ENABLE
	{
		DATA :: #run add_To_Data_Segment(frame_name);
		___tracy_emit_frame_mark_start(DATA);
		`defer ___tracy_emit_frame_mark_end(DATA);
	}
}

NameThread :: ($thread_name : string) #expand #no_debug #no_context
{
	#if ENABLE
	{
		___tracy_set_thread_name(#run add_To_Data_Segment(thread_name));
	}
}


Plot :: ($name : string = "<DEFAULT_PLOT>", value : float64) #expand #no_debug #no_context
{
	#if ENABLE
	{
		___tracy_emit_plot(name, value);
	}
}

Plot :: ($name : string = "<DEFAULT_PLOT>", value : float32) #expand #no_debug #no_context
{
	#if ENABLE
	{
		___tracy_emit_plot_float(name, value);
	}
}

Plot :: ($name : string = "<DEFAULT_PLOT>", value : int) #expand #no_debug #no_context
{
	#if ENABLE
	{
		___tracy_emit_plot_int(name, value);
	}
}


Message :: ($message : string) #expand #no_debug #no_context
{
	#if ENABLE
	{
		___tracy_emit_message(#run add_To_Data_Segment(message), message.count, 0);
	}
}









#scope_file

#if ENABLE
{

	Tracy_SEGMENT_CREATED : bool = false;
	Tracy_SEGMENT : *Jai.Data_Segment = null; // Only available at compile time

	loc_to_tracy :: (name : string, loc : Source_Code_Location, procedure_name : string) -> ___tracy_source_location_data
	{
		r := ___tracy_source_location_data.{};
		r.name = add_To_Data_Segment(name);
		r.file = add_To_Data_Segment(loc.fully_pathed_filename);
		r.function = add_To_Data_Segment(procedure_name);;
		r.line = xx loc.line_number;
		
		return r;
	}

	add_To_Data_Segment :: (str : string) -> *u8
	{
		if #compile_time
		{
			if !Tracy_SEGMENT_CREATED
			{
				Tracy_SEGMENT = Jai.add_data_segment("TRACY_SEGMENT", characteristics = .READ);
				Tracy_SEGMENT_CREATED = true;
			}

		}
		in_data := Jai.add_global_data(xx sprint("%\0", str), .USER_SEGMENT, Tracy_SEGMENT);
		return in_data.data;
	}

	#load "tracy_bindings.jai";
}

Jai :: #import "Compiler";
