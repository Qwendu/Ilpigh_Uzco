#scope_export
#module_parameters(ENABLE :bool = false);

Plugin :: struct
{
	using #as plug : Jai.Metaprogram_Plugin;

	procedures_to_disassemble : [..] string;
}




get_plugin :: (w : Workspace) -> *Jai.Metaprogram_Plugin
{
	plug := New(Plugin);
	plug.workspace = w;
	plug.message = message;
	return plug;
}




#scope_file

message :: (plugin : *Jai.Metaprogram_Plugin, msg : *Jai.Message)
{
	#if ENABLE
	{
		using cast(*Plugin)plugin;
		if msg.kind == .TYPECHECKED
		{
			typechecked := cast(*Jai.Message_Typechecked)msg;

			for typechecked.declarations
			{
				for note : it.expression.notes
				{
					if note.text == "Disassemble"
					{
						array_add(*procedures_to_disassemble, it.expression.name);
						break it;
					}

				}

			}
		}
		if msg.kind == .PHASE
		{
			C := context;
			C.logger = quiet;
			push_context,defer_pop C;
			for complete: 0..0
			{
				postcomp := cast(*Jai.Message_Phase)msg;
				if postcomp.phase != .POST_WRITE_EXECUTABLE  break;
				
				print("Executable name = %\n", postcomp.executable_name);
				for postcomp.compiler_generated_object_files
				{
					succ, coff := parse_coff_file(it);
					for s, si: coff.symbols
					{
						symbol , succ := get_symbol_name(coff, si);
						if !succ  continue s;
						for procedures_to_disassemble
						{
							if starts_with(symbol, it)  print("% %\n", symbol, it);
						}
					}
				}
				
			}
		}
	}
}



quiet :: (msg : string, data : *void, info : Log_Info)
{


}
Jai :: #import "Compiler";
#import "Basic";
#import "Process";
#import "executable_formats";
#import "String";
