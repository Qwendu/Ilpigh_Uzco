#import "Bindings_Generator";
#import "Basic";


main :: () 
{
	using options := Generate_Bindings_Options.{};

	array_add(*libpaths, ".");
	array_add(*libnames, "TracyProfiler");
	array_add(*include_paths, 
			"public", 
			"public/tracy",
			"public/client",
	);
	array_add(*system_include_paths, GENERATOR_DEFAULT_SYSTEM_INCLUDE_PATH);
	array_add(*source_files, "public/tracy/TracyC.h");
	array_add(*extra_clang_arguments, 
		"-DTRACY_ENABLE",
		//"-DTRACY_MANUAL_LIFETIME",
	);
	array_add(*system_types_to_include, 
		"size_t",
	);

	strip_flags = xx 0;
	
	generate_bindings(options, "tracy_bindings.jai");
}

#run main();
