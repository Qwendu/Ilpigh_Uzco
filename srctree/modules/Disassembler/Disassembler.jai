#scope_export
#module_parameters(ENABLE :bool = false);

Plugin :: struct
{
	using #as plug : Jai.Metaprogram_Plugin;

	procedures_to_disassemble : [..] struct { name : string; data : [] u8;};

}




get_plugin :: (w : Workspace) -> *Jai.Metaprogram_Plugin
{
	plug := New(Plugin);
	plug.workspace = w;
	plug.message = message;

	return plug;
}




#scope_file

message :: (plugin_ : *Jai.Metaprogram_Plugin, msg : *Jai.Message)
{
	#if ENABLE
	{
		plugin := cast(*Plugin)plugin_;
		using plugin;
		if msg.kind == .TYPECHECKED
		{
			typechecked := cast(*Jai.Message_Typechecked)msg;

			for typechecked.declarations
			{
				for note : it.expression.notes
				{
					if note.text == "Disassemble"
					{
						array_add(*procedures_to_disassemble, .{name = it.expression.name});
						break it;
					}

				}

			}
		}
		if msg.kind == .PHASE
		{
			for complete: 0..0
			{
				postcomp := cast(*Jai.Message_Phase)msg;
				if postcomp.phase != .POST_WRITE_EXECUTABLE  break;
				
				build_options := Jai.get_build_options(plugin.workspace);
				
				log("Executable name = %", postcomp.executable_name);
				
				//o_file := postcomp.compiler_generated_object_files[postcomp.compiler_generated_object_files.count - 1];
				for postcomp.compiler_generated_object_files
				{
			
					//o_file := join(build_options.output_path, postcomp.executable_name, separator = "/");
					o_file := it;
					success, coff := parse_coff_file(o_file);
					if !success  {
						log("Failed to load %", o_file);
						continue;
					}
					log("File = %", it);
					
					for coff.symbols
					{
						if it.storage_class != .EXTERNAL  continue;

						symbol_name, found_symbol := get_symbol_name(coff, it_index);
						if !found_symbol  continue;
						disasm, index := should_disassemble(plugin, symbol_name);
						if disasm 
						{
							proc := *plugin.procedures_to_disassemble[index];
							if it.section_number == 0
							{
							}else{
								section           := it.section_number - 1;
								offset_in_section := it.value;
								section_data := get_section_data(coff, section);
								log("section  % (%)", section, get_section_name(coff.section_headers[section]));
								log("offset in section = %", offset_in_section);
								log("Length of section = %", section_data.count);


								proc.data.data += cast(int)section_data.data + offset_in_section;
							}
							log("\t\tSymbol % '%' [%]", it_index, symbol_name, it.storage_class);
							
						}
					}
				}
				for plugin.procedures_to_disassemble
				{
					if it.data.data
					{
						log("data of proc % is here %", it.name, it.data.data);
						str : [] u8;
						str.data = it.data.data;
						str.count = 2000;
						for 0..20
						{
							succ, instr := Zydis.DisassembleIntel(.LONG_64, 0, str);
							log("% [%]", to_string(instr.text), succ);
							str.data += instr.info.length;
							str.count -= instr.info.length;
						}
					}
				}
				
			}
		}


		
	}
}

should_disassemble :: (plugin : *Plugin, name : string) -> bool, int
{
	for plugin.procedures_to_disassemble
	{
		if starts_with(name, it.name)
		{
			return true, it_index;
		}
	}
	return false, -1;
}


Jai :: #import "Compiler";
#import "Basic";
#import "Process";
#import "executable_formats";
#import "String";
Zydis :: #import,dir "jai-zydis";
