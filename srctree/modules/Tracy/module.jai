#scope_export

AppInfo :: (message : string) #expand #no_debug #no_context
{
	___tracy_emit_message_appinfo(message.data, message.count);
}

TimeZone :: ($loc := #caller_location) #expand
{
	tracy_loc :: #run loc_to_tracy(loc);
	ctx := ___tracy_emit_zone_begin(*tracy_loc, 1);
	`defer ___tracy_emit_zone_end(ctx);
}


Frame ::() #expand #no_debug #no_context
{
	___tracy_emit_frame_mark("<=UNINIT=>");
}









#scope_file

loc_to_tracy :: ($loc := #caller_location) -> ___tracy_source_location_data
{
	using r := ___tracy_source_location_data.{};

	return r;
}

#load "tracy_bindings.jai";
Jai :: #import "Compiler";
