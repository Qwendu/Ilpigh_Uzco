//
// This file was auto-generated using the following command:
//
// jai ./generate.jai
//



TRACY_ENABLE :: 1;
TRACY_HAS_CALLSTACK :: 1;


size_t :: u64;

___tracy_set_thread_name :: (name: *u8) -> void #foreign tracyprofiler;

___tracy_source_location_data :: struct {
    name:     *u8;
    function: *u8;
    file:     *u8;
    line:     u32;
    color:    u32;
}
#run {
    instance: ___tracy_source_location_data;
    assert(((cast(*void)(*instance.name)) - cast(*void)(*instance)) == 0, "___tracy_source_location_data.name has unexpected offset % instead of 0", ((cast(*void)(*instance.name)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_source_location_data.name)) == 8, "___tracy_source_location_data.name has unexpected size % instead of 8", size_of(type_of(___tracy_source_location_data.name)));
    assert(((cast(*void)(*instance.function)) - cast(*void)(*instance)) == 8, "___tracy_source_location_data.function has unexpected offset % instead of 8", ((cast(*void)(*instance.function)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_source_location_data.function)) == 8, "___tracy_source_location_data.function has unexpected size % instead of 8", size_of(type_of(___tracy_source_location_data.function)));
    assert(((cast(*void)(*instance.file)) - cast(*void)(*instance)) == 16, "___tracy_source_location_data.file has unexpected offset % instead of 16", ((cast(*void)(*instance.file)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_source_location_data.file)) == 8, "___tracy_source_location_data.file has unexpected size % instead of 8", size_of(type_of(___tracy_source_location_data.file)));
    assert(((cast(*void)(*instance.line)) - cast(*void)(*instance)) == 24, "___tracy_source_location_data.line has unexpected offset % instead of 24", ((cast(*void)(*instance.line)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_source_location_data.line)) == 4, "___tracy_source_location_data.line has unexpected size % instead of 4", size_of(type_of(___tracy_source_location_data.line)));
    assert(((cast(*void)(*instance.color)) - cast(*void)(*instance)) == 28, "___tracy_source_location_data.color has unexpected offset % instead of 28", ((cast(*void)(*instance.color)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_source_location_data.color)) == 4, "___tracy_source_location_data.color has unexpected size % instead of 4", size_of(type_of(___tracy_source_location_data.color)));
    assert(size_of(___tracy_source_location_data) == 32, "___tracy_source_location_data has size % instead of 32", size_of(___tracy_source_location_data));
}

___tracy_c_zone_context :: struct {
    id:     u32;
    active: s32;
}
#run {
    instance: ___tracy_c_zone_context;
    assert(((cast(*void)(*instance.id)) - cast(*void)(*instance)) == 0, "___tracy_c_zone_context.id has unexpected offset % instead of 0", ((cast(*void)(*instance.id)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_c_zone_context.id)) == 4, "___tracy_c_zone_context.id has unexpected size % instead of 4", size_of(type_of(___tracy_c_zone_context.id)));
    assert(((cast(*void)(*instance.active)) - cast(*void)(*instance)) == 4, "___tracy_c_zone_context.active has unexpected offset % instead of 4", ((cast(*void)(*instance.active)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_c_zone_context.active)) == 4, "___tracy_c_zone_context.active has unexpected size % instead of 4", size_of(type_of(___tracy_c_zone_context.active)));
    assert(size_of(___tracy_c_zone_context) == 8, "___tracy_c_zone_context has size % instead of 8", size_of(___tracy_c_zone_context));
}

___tracy_gpu_time_data :: struct {
    gpuTime:  s64;
    queryId:  u16;
    _context: u8;
}
#run {
    instance: ___tracy_gpu_time_data;
    assert(((cast(*void)(*instance.gpuTime)) - cast(*void)(*instance)) == 0, "___tracy_gpu_time_data.gpuTime has unexpected offset % instead of 0", ((cast(*void)(*instance.gpuTime)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_time_data.gpuTime)) == 8, "___tracy_gpu_time_data.gpuTime has unexpected size % instead of 8", size_of(type_of(___tracy_gpu_time_data.gpuTime)));
    assert(((cast(*void)(*instance.queryId)) - cast(*void)(*instance)) == 8, "___tracy_gpu_time_data.queryId has unexpected offset % instead of 8", ((cast(*void)(*instance.queryId)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_time_data.queryId)) == 2, "___tracy_gpu_time_data.queryId has unexpected size % instead of 2", size_of(type_of(___tracy_gpu_time_data.queryId)));
    assert(((cast(*void)(*instance._context)) - cast(*void)(*instance)) == 10, "___tracy_gpu_time_data._context has unexpected offset % instead of 10", ((cast(*void)(*instance._context)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_time_data._context)) == 1, "___tracy_gpu_time_data._context has unexpected size % instead of 1", size_of(type_of(___tracy_gpu_time_data._context)));
    assert(size_of(___tracy_gpu_time_data) == 16, "___tracy_gpu_time_data has size % instead of 16", size_of(___tracy_gpu_time_data));
}

___tracy_gpu_zone_begin_data :: struct {
    srcloc:   u64;
    queryId:  u16;
    _context: u8;
}
#run {
    instance: ___tracy_gpu_zone_begin_data;
    assert(((cast(*void)(*instance.srcloc)) - cast(*void)(*instance)) == 0, "___tracy_gpu_zone_begin_data.srcloc has unexpected offset % instead of 0", ((cast(*void)(*instance.srcloc)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_zone_begin_data.srcloc)) == 8, "___tracy_gpu_zone_begin_data.srcloc has unexpected size % instead of 8", size_of(type_of(___tracy_gpu_zone_begin_data.srcloc)));
    assert(((cast(*void)(*instance.queryId)) - cast(*void)(*instance)) == 8, "___tracy_gpu_zone_begin_data.queryId has unexpected offset % instead of 8", ((cast(*void)(*instance.queryId)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_zone_begin_data.queryId)) == 2, "___tracy_gpu_zone_begin_data.queryId has unexpected size % instead of 2", size_of(type_of(___tracy_gpu_zone_begin_data.queryId)));
    assert(((cast(*void)(*instance._context)) - cast(*void)(*instance)) == 10, "___tracy_gpu_zone_begin_data._context has unexpected offset % instead of 10", ((cast(*void)(*instance._context)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_zone_begin_data._context)) == 1, "___tracy_gpu_zone_begin_data._context has unexpected size % instead of 1", size_of(type_of(___tracy_gpu_zone_begin_data._context)));
    assert(size_of(___tracy_gpu_zone_begin_data) == 16, "___tracy_gpu_zone_begin_data has size % instead of 16", size_of(___tracy_gpu_zone_begin_data));
}

___tracy_gpu_zone_begin_callstack_data :: struct {
    srcloc:   u64;
    depth:    s32;
    queryId:  u16;
    _context: u8;
}
#run {
    instance: ___tracy_gpu_zone_begin_callstack_data;
    assert(((cast(*void)(*instance.srcloc)) - cast(*void)(*instance)) == 0, "___tracy_gpu_zone_begin_callstack_data.srcloc has unexpected offset % instead of 0", ((cast(*void)(*instance.srcloc)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_zone_begin_callstack_data.srcloc)) == 8, "___tracy_gpu_zone_begin_callstack_data.srcloc has unexpected size % instead of 8", size_of(type_of(___tracy_gpu_zone_begin_callstack_data.srcloc)));
    assert(((cast(*void)(*instance.depth)) - cast(*void)(*instance)) == 8, "___tracy_gpu_zone_begin_callstack_data.depth has unexpected offset % instead of 8", ((cast(*void)(*instance.depth)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_zone_begin_callstack_data.depth)) == 4, "___tracy_gpu_zone_begin_callstack_data.depth has unexpected size % instead of 4", size_of(type_of(___tracy_gpu_zone_begin_callstack_data.depth)));
    assert(((cast(*void)(*instance.queryId)) - cast(*void)(*instance)) == 12, "___tracy_gpu_zone_begin_callstack_data.queryId has unexpected offset % instead of 12", ((cast(*void)(*instance.queryId)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_zone_begin_callstack_data.queryId)) == 2, "___tracy_gpu_zone_begin_callstack_data.queryId has unexpected size % instead of 2", size_of(type_of(___tracy_gpu_zone_begin_callstack_data.queryId)));
    assert(((cast(*void)(*instance._context)) - cast(*void)(*instance)) == 14, "___tracy_gpu_zone_begin_callstack_data._context has unexpected offset % instead of 14", ((cast(*void)(*instance._context)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_zone_begin_callstack_data._context)) == 1, "___tracy_gpu_zone_begin_callstack_data._context has unexpected size % instead of 1", size_of(type_of(___tracy_gpu_zone_begin_callstack_data._context)));
    assert(size_of(___tracy_gpu_zone_begin_callstack_data) == 16, "___tracy_gpu_zone_begin_callstack_data has size % instead of 16", size_of(___tracy_gpu_zone_begin_callstack_data));
}

___tracy_gpu_zone_end_data :: struct {
    queryId:  u16;
    _context: u8;
}
#run {
    instance: ___tracy_gpu_zone_end_data;
    assert(((cast(*void)(*instance.queryId)) - cast(*void)(*instance)) == 0, "___tracy_gpu_zone_end_data.queryId has unexpected offset % instead of 0", ((cast(*void)(*instance.queryId)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_zone_end_data.queryId)) == 2, "___tracy_gpu_zone_end_data.queryId has unexpected size % instead of 2", size_of(type_of(___tracy_gpu_zone_end_data.queryId)));
    assert(((cast(*void)(*instance._context)) - cast(*void)(*instance)) == 2, "___tracy_gpu_zone_end_data._context has unexpected offset % instead of 2", ((cast(*void)(*instance._context)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_zone_end_data._context)) == 1, "___tracy_gpu_zone_end_data._context has unexpected size % instead of 1", size_of(type_of(___tracy_gpu_zone_end_data._context)));
    assert(size_of(___tracy_gpu_zone_end_data) == 4, "___tracy_gpu_zone_end_data has size % instead of 4", size_of(___tracy_gpu_zone_end_data));
}

___tracy_gpu_new_context_data :: struct {
    gpuTime:  s64;
    period:   float;
    _context: u8;
    flags:    u8;
    type:     u8;
}
#run {
    instance: ___tracy_gpu_new_context_data;
    assert(((cast(*void)(*instance.gpuTime)) - cast(*void)(*instance)) == 0, "___tracy_gpu_new_context_data.gpuTime has unexpected offset % instead of 0", ((cast(*void)(*instance.gpuTime)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_new_context_data.gpuTime)) == 8, "___tracy_gpu_new_context_data.gpuTime has unexpected size % instead of 8", size_of(type_of(___tracy_gpu_new_context_data.gpuTime)));
    assert(((cast(*void)(*instance.period)) - cast(*void)(*instance)) == 8, "___tracy_gpu_new_context_data.period has unexpected offset % instead of 8", ((cast(*void)(*instance.period)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_new_context_data.period)) == 4, "___tracy_gpu_new_context_data.period has unexpected size % instead of 4", size_of(type_of(___tracy_gpu_new_context_data.period)));
    assert(((cast(*void)(*instance._context)) - cast(*void)(*instance)) == 12, "___tracy_gpu_new_context_data._context has unexpected offset % instead of 12", ((cast(*void)(*instance._context)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_new_context_data._context)) == 1, "___tracy_gpu_new_context_data._context has unexpected size % instead of 1", size_of(type_of(___tracy_gpu_new_context_data._context)));
    assert(((cast(*void)(*instance.flags)) - cast(*void)(*instance)) == 13, "___tracy_gpu_new_context_data.flags has unexpected offset % instead of 13", ((cast(*void)(*instance.flags)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_new_context_data.flags)) == 1, "___tracy_gpu_new_context_data.flags has unexpected size % instead of 1", size_of(type_of(___tracy_gpu_new_context_data.flags)));
    assert(((cast(*void)(*instance.type)) - cast(*void)(*instance)) == 14, "___tracy_gpu_new_context_data.type has unexpected offset % instead of 14", ((cast(*void)(*instance.type)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_new_context_data.type)) == 1, "___tracy_gpu_new_context_data.type has unexpected size % instead of 1", size_of(type_of(___tracy_gpu_new_context_data.type)));
    assert(size_of(___tracy_gpu_new_context_data) == 16, "___tracy_gpu_new_context_data has size % instead of 16", size_of(___tracy_gpu_new_context_data));
}

___tracy_gpu_context_name_data :: struct {
    _context: u8;
    name:     *u8;
    len:      u16;
}
#run {
    instance: ___tracy_gpu_context_name_data;
    assert(((cast(*void)(*instance._context)) - cast(*void)(*instance)) == 0, "___tracy_gpu_context_name_data._context has unexpected offset % instead of 0", ((cast(*void)(*instance._context)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_context_name_data._context)) == 1, "___tracy_gpu_context_name_data._context has unexpected size % instead of 1", size_of(type_of(___tracy_gpu_context_name_data._context)));
    assert(((cast(*void)(*instance.name)) - cast(*void)(*instance)) == 8, "___tracy_gpu_context_name_data.name has unexpected offset % instead of 8", ((cast(*void)(*instance.name)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_context_name_data.name)) == 8, "___tracy_gpu_context_name_data.name has unexpected size % instead of 8", size_of(type_of(___tracy_gpu_context_name_data.name)));
    assert(((cast(*void)(*instance.len)) - cast(*void)(*instance)) == 16, "___tracy_gpu_context_name_data.len has unexpected offset % instead of 16", ((cast(*void)(*instance.len)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_context_name_data.len)) == 2, "___tracy_gpu_context_name_data.len has unexpected size % instead of 2", size_of(type_of(___tracy_gpu_context_name_data.len)));
    assert(size_of(___tracy_gpu_context_name_data) == 24, "___tracy_gpu_context_name_data has size % instead of 24", size_of(___tracy_gpu_context_name_data));
}

___tracy_gpu_calibration_data :: struct {
    gpuTime:  s64;
    cpuDelta: s64;
    _context: u8;
}
#run {
    instance: ___tracy_gpu_calibration_data;
    assert(((cast(*void)(*instance.gpuTime)) - cast(*void)(*instance)) == 0, "___tracy_gpu_calibration_data.gpuTime has unexpected offset % instead of 0", ((cast(*void)(*instance.gpuTime)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_calibration_data.gpuTime)) == 8, "___tracy_gpu_calibration_data.gpuTime has unexpected size % instead of 8", size_of(type_of(___tracy_gpu_calibration_data.gpuTime)));
    assert(((cast(*void)(*instance.cpuDelta)) - cast(*void)(*instance)) == 8, "___tracy_gpu_calibration_data.cpuDelta has unexpected offset % instead of 8", ((cast(*void)(*instance.cpuDelta)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_calibration_data.cpuDelta)) == 8, "___tracy_gpu_calibration_data.cpuDelta has unexpected size % instead of 8", size_of(type_of(___tracy_gpu_calibration_data.cpuDelta)));
    assert(((cast(*void)(*instance._context)) - cast(*void)(*instance)) == 16, "___tracy_gpu_calibration_data._context has unexpected offset % instead of 16", ((cast(*void)(*instance._context)) - cast(*void)(*instance)));
    assert(size_of(type_of(___tracy_gpu_calibration_data._context)) == 1, "___tracy_gpu_calibration_data._context has unexpected size % instead of 1", size_of(type_of(___tracy_gpu_calibration_data._context)));
    assert(size_of(___tracy_gpu_calibration_data) == 24, "___tracy_gpu_calibration_data has size % instead of 24", size_of(___tracy_gpu_calibration_data));
}

// Some containers don't support storing const types.
// This struct, as visible to user, is immutable, so treat it as if const was declared here.
TracyCZoneCtx :: ___tracy_c_zone_context;

___tracy_alloc_srcloc :: (line: u32, source: *u8, sourceSz: size_t, function: *u8, functionSz: size_t) -> u64 #foreign tracyprofiler;
___tracy_alloc_srcloc_name :: (line: u32, source: *u8, sourceSz: size_t, function: *u8, functionSz: size_t, name: *u8, nameSz: size_t) -> u64 #foreign tracyprofiler;

___tracy_emit_zone_begin :: (srcloc: *___tracy_source_location_data, active: s32) -> TracyCZoneCtx #foreign tracyprofiler;
___tracy_emit_zone_begin_callstack :: (srcloc: *___tracy_source_location_data, depth: s32, active: s32) -> TracyCZoneCtx #foreign tracyprofiler;
___tracy_emit_zone_begin_alloc :: (srcloc: u64, active: s32) -> TracyCZoneCtx #foreign tracyprofiler;
___tracy_emit_zone_begin_alloc_callstack :: (srcloc: u64, depth: s32, active: s32) -> TracyCZoneCtx #foreign tracyprofiler;
___tracy_emit_zone_end :: (ctx: TracyCZoneCtx) -> void #foreign tracyprofiler;
___tracy_emit_zone_text :: (ctx: TracyCZoneCtx, txt: *u8, size: size_t) -> void #foreign tracyprofiler;
___tracy_emit_zone_name :: (ctx: TracyCZoneCtx, txt: *u8, size: size_t) -> void #foreign tracyprofiler;
___tracy_emit_zone_color :: (ctx: TracyCZoneCtx, color: u32) -> void #foreign tracyprofiler;
___tracy_emit_zone_value :: (ctx: TracyCZoneCtx, value: u64) -> void #foreign tracyprofiler;

___tracy_emit_gpu_zone_begin :: (unknown0: ___tracy_gpu_zone_begin_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_zone_begin_callstack :: (unknown0: ___tracy_gpu_zone_begin_callstack_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_zone_begin_alloc :: (unknown0: ___tracy_gpu_zone_begin_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_zone_begin_alloc_callstack :: (unknown0: ___tracy_gpu_zone_begin_callstack_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_zone_end :: (data: ___tracy_gpu_zone_end_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_time :: (unknown0: ___tracy_gpu_time_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_new_context :: (unknown0: ___tracy_gpu_new_context_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_context_name :: (unknown0: ___tracy_gpu_context_name_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_calibration :: (unknown0: ___tracy_gpu_calibration_data) -> void #foreign tracyprofiler;

___tracy_emit_gpu_zone_begin_serial :: (unknown0: ___tracy_gpu_zone_begin_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_zone_begin_callstack_serial :: (unknown0: ___tracy_gpu_zone_begin_callstack_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_zone_begin_alloc_serial :: (unknown0: ___tracy_gpu_zone_begin_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_zone_begin_alloc_callstack_serial :: (unknown0: ___tracy_gpu_zone_begin_callstack_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_zone_end_serial :: (data: ___tracy_gpu_zone_end_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_time_serial :: (unknown0: ___tracy_gpu_time_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_new_context_serial :: (unknown0: ___tracy_gpu_new_context_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_context_name_serial :: (unknown0: ___tracy_gpu_context_name_data) -> void #foreign tracyprofiler;
___tracy_emit_gpu_calibration_serial :: (unknown0: ___tracy_gpu_calibration_data) -> void #foreign tracyprofiler;

___tracy_connected :: () -> s32 #foreign tracyprofiler;

___tracy_emit_memory_alloc :: (ptr: *void, size: size_t, secure: s32) -> void #foreign tracyprofiler;
___tracy_emit_memory_alloc_callstack :: (ptr: *void, size: size_t, depth: s32, secure: s32) -> void #foreign tracyprofiler;
___tracy_emit_memory_free :: (ptr: *void, secure: s32) -> void #foreign tracyprofiler;
___tracy_emit_memory_free_callstack :: (ptr: *void, depth: s32, secure: s32) -> void #foreign tracyprofiler;
___tracy_emit_memory_alloc_named :: (ptr: *void, size: size_t, secure: s32, name: *u8) -> void #foreign tracyprofiler;
___tracy_emit_memory_alloc_callstack_named :: (ptr: *void, size: size_t, depth: s32, secure: s32, name: *u8) -> void #foreign tracyprofiler;
___tracy_emit_memory_free_named :: (ptr: *void, secure: s32, name: *u8) -> void #foreign tracyprofiler;
___tracy_emit_memory_free_callstack_named :: (ptr: *void, depth: s32, secure: s32, name: *u8) -> void #foreign tracyprofiler;

___tracy_emit_message :: (txt: *u8, size: size_t, callstack: s32) -> void #foreign tracyprofiler;
___tracy_emit_messageL :: (txt: *u8, callstack: s32) -> void #foreign tracyprofiler;
___tracy_emit_messageC :: (txt: *u8, size: size_t, color: u32, callstack: s32) -> void #foreign tracyprofiler;
___tracy_emit_messageLC :: (txt: *u8, color: u32, callstack: s32) -> void #foreign tracyprofiler;

___tracy_emit_frame_mark :: (name: *u8) -> void #foreign tracyprofiler;
___tracy_emit_frame_mark_start :: (name: *u8) -> void #foreign tracyprofiler;
___tracy_emit_frame_mark_end :: (name: *u8) -> void #foreign tracyprofiler;
___tracy_emit_frame_image :: (image: *void, w: u16, h: u16, offset: u8, flip: s32) -> void #foreign tracyprofiler;

___tracy_emit_plot :: (name: *u8, val: float64) -> void #foreign tracyprofiler;
___tracy_emit_plot_float :: (name: *u8, val: float) -> void #foreign tracyprofiler;
___tracy_emit_plot_int :: (name: *u8, val: s64) -> void #foreign tracyprofiler;
___tracy_emit_message_appinfo :: (txt: *u8, size: size_t) -> void #foreign tracyprofiler;

#scope_file

#import "Basic"; // For assert

tracyprofiler :: #library "./TracyProfiler";
