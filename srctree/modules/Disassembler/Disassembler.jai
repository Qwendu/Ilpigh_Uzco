#scope_export
#module_parameters(ENABLE :bool = false);

Plugin :: struct
{
	using #as plug : Jai.Metaprogram_Plugin;

	procedures_to_disassemble : [..] Disassembled_Procedure;
}

Disassembled_Procedure :: struct
{
	name : string;
	symbol_name : string;
	file_of_definition : string;
	runtime_address : int;
	binary : [] u8;
	disassembled : [] Zydis.DisassembledInstruction;
}



get_plugin :: (w : Workspace) -> *Jai.Metaprogram_Plugin
{
	plug := New(Plugin);
	plug.workspace = w;
	plug.message = xx message;
	plug.finish = xx finish;

	return plug;
}




#scope_file


finish :: (using plugin : *Plugin)
{
	for * proc : procedures_to_disassemble
	{
		if proc.binary.data
		{
			log("Function % [%]:", proc.name, proc.symbol_name);
			log("'Runtime address' = 0x%", formatInt(proc.runtime_address, base=16));
			continue_disassembly := true;
			{
				str : [] u8;
				str.data  = proc.binary.data;
				str.count = proc.binary.count;
				disassembled_up_to := proc.runtime_address;
				highest_jump_to    := proc.runtime_address;
				instr_idx := 0;
				while true
				{
					defer if disassembled_up_to - proc.runtime_address >= proc.binary.count  break;
					succ, instr := Zydis.DisassembleIntel(.LONG_64, xx disassembled_up_to, str);
					if succ != 0 && succ != 0x100000
					{
						log("Failed to disassemble instruction at offset +% [%]. Stopping disassembly of function %.", disassembled_up_to, formatInt(succ, base=16), proc.name);
						proc.binary.count = 0;
						continue_disassembly = false;
						break;
					}

					meta := instr.info.meta;

					// TODO: recognize jumps
					is_jump, jump_address := is_Jump(instr);
					if is_jump
					{
						highest_jump_to = max(jump_address, highest_jump_to);
					}

					instr_idx += 1;
					disassembled_up_to += instr.info.length;
					str.data           += instr.info.length;
					str.count          -= instr.info.length;


					if meta.category == .RET
					{
						if highest_jump_to < disassembled_up_to
						{
							log("Found return of function at +% [% instructions]", disassembled_up_to - proc.runtime_address, instr_idx);
							proc.binary.count = disassembled_up_to;
							proc.disassembled = NewArray(instr_idx, Zydis.DisassembledInstruction);
							break;
						}
					}
				}
			}

			if !continue_disassembly  continue;

			{
				addr := proc.runtime_address;
				data := proc.binary;
				for * instr : proc.disassembled
				{
					_, instr.* = Zydis.DisassembleIntel(.LONG_64, xx addr, data);
					addr       += instr.info.length;
					data.data  += instr.info.length;
					data.count -= instr.info.length;
				}
				for instr : proc.disassembled
				{
					log("%: %", formatInt(instr.runtime_address,base=16), to_string(instr.text));
				}
			}
		}else{
			log_error("Could not find a binary for procedure %. Skipping", proc.name);
		}
	}
}

message :: (using plugin : *Plugin, msg : *Jai.Message)
{
	#if ENABLE
	{
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
				
				for coff_file_name : postcomp.compiler_generated_object_files
				{
					success, coff := parse_coff_file(coff_file_name);
					if !success  {
						log("Failed to load %", coff_file_name);
						continue;
					}
					
					for sym, sym_idx : coff.symbols
					{
						if sym.storage_class != .EXTERNAL  continue;

						symbol_name, found_symbol := get_symbol_name(coff, sym_idx);
						if !found_symbol  continue;
						disasm, index := should_disassemble(plugin, symbol_name);
						if disasm 
						{
							proc := *plugin.procedures_to_disassemble[index];
							if proc.symbol_name && proc.symbol_name != symbol_name
							{
								log_error("Procedure % has multiple definitions, at least \n[1]: %\n[2]: %\nChoosing [2]", proc.name, proc.symbol_name, symbol_name);
							}
							proc.symbol_name        = symbol_name;
							proc.file_of_definition = coff_file_name;
							if sym.section_number == 0
							{
							}else{
								section           := sym.section_number - 1;
								section_ptr       := *coff.section_headers[section];
								offset_in_section := sym.value;
								section_data := get_section_data(coff, section);
								proc.binary.data  = cast(*u8)(section_data.data + offset_in_section);
								proc.binary.count = section_data.count - offset_in_section;
								proc.runtime_address = section_ptr.virtual_address + offset_in_section;
							}
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

is_Jump :: (instr : Zydis.DisassembledInstruction) -> bool, int
{
	if instr.info.mnemonic ==
	{
	case .JB   ; #through;
	case .JBE  ; #through;
	case .JCXZ ; #through;
	case .JECXZ; #through;
	case .JKNZD; #through;
	case .JKZD ; #through;
	case .JL   ; #through;
	case .JLE  ; #through;
	case .JMP  ; #through;
	case .JNB  ; #through;
	case .JNBE ; #through;
	case .JNL  ; #through;
	case .JNLE ; #through;
	case .JNO  ; #through;
	case .JNP  ; #through;
	case .JNS  ; #through;
	case .JNZ  ; #through;
	case .JO   ; #through;
	case .JP   ; #through;
	case .JRCXZ; #through;
	case .JS   ; #through;
	case .JZ   ; 

	case;
		return false, 0;
	}
	assert(instr.info.operand_count_visible == 1, "Jumps have one address operand");
	op := instr.operands[0];

	if op.type == .REGISTER
	{
		log_error("Jumpig using a register as a base at +%, we dont know how far we jump", instr.runtime_address);
	}

	if op.type == .IMMEDIATE
	{
		if op.imm.is_relative
		{
			return true, (cast(s64)instr.runtime_address) + instr.info.length + op.imm.value.s;
		}else{
			assert(false, "Hardcoding immediate jumps?");
			return true, op.imm.value.s;
		}
	}
	
	
	

	return true, 0;
}


Jai :: #import "Compiler";
#import "Basic";
#import "Process";
#import "executable_formats";
#import "String";
Zydis :: #import,dir "jai-zydis";
