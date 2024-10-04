Forward Rendering
Font Rendering
Radiance Cascades
Inverted Z (0 being far, 1 being close) to counter-act precision issues



Sphere mesh
Lines are in World Space
Simplify Shaders
All Meshes have one Color only
update on Changed annotation "@UpdateOnChanged(Struct,Hash)" -> Hash the structs text, when it changes, error on annotations to make sure they are kept in sync


Memory Allocators
House rule metaprograms
Hot Swapping
Platform Layer context
State Save files http://msinilo.pl/blog2/post/p269/
Add Annotation Assertions like ``@"assert(buffer.count == allocated.width * allocated.height)"`` 
Figure out how to stop all threads and load from a dump folder
Windows Error Reporting
Mail Dialog for Crashes
Metaprogram Analysis of disassembled procedures
Metaprogram Analysis of procedures
Metaprogram Pre/Post-Conditions assert(...) and defer assert(...) respectively static analysis
Metaprogram Thread Specific Reachability


Blender live communication (model in blender is 1:1 in game)

Compile Time Generated logging macros log("{foo}"); instead of log("%", foo);
Volumetric Rendering

Semantic Reading functions like "clear_array", "reset_array", etc



# Hierarchical Precision
dt = 2^-7 = 128 ticks per second
fixedpoint 7.17 -> ulp = 2^-17
ulp_vel = smallest velocity such that one physics update moves the object = ulp/dt = 2^-10 ~ 1 mm per second is the slowest an object can move
velocities actually only need 10 precision bits



