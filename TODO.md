# House Rules

- [ ] Add Annotation Assertions like ``@"assert(buffer.count == allocated.width * allocated.height)"`` 

- [ ] Refactor windows input from if statements to a simple table lookup!
- [ ] Figure out how to stop all threads and load from a dump folder


# Systems
- [ ] Mesh Loader
- [ ] Hot Swapping
- [ ] Rendering
	- [x] Triangle Rasterization
	- [x] Jai Shaders
	- [ ] Font Rendering
- [ ] Add custom context for the platform layer
- [ ] Memory Allocators for Graphics Subsystem
	- [x] Large Page support
	- [ ] Arena Allocators
- [ ] Load Meshes
- [ ] Physics
	- [x] Line Drawing for Debugging
	- [ ] Primitives
		- [x] Spheres
		- [ ] Tetraeder
- [ ] Succeeding to Fail
	- [ ] http://msinilo.pl/blog2/post/p269/
	- [ ] On Error Create Save File feature
		- [x] physics state from X seconds before crash, dumped to file
		- [ ] render  state from X seconds before crash, dumped to file
	- [ ] Load Save file feature
	- [ ] Windows Error Reporting
	- [ ] Mail Dialog for Crashes in Release
	- [ ] Recovery Mode for Release which records extra data for crash dumps 
- [ ] Metaprogram
	- [x] Disassembling procedures
	- [ ] Analysis of disassembled procedures
	- [ ] Analysis of procedures
	- [ ] Pre/Post-Conditions assert(...) and defer assert(...) respectively static analysis
