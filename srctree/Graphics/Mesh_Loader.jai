#scope_export

get_Mesh_ID :: (mesh_path : Mesh_Path) -> Mesh_ID
{
	{
		map := acquire(*Mesh_Manager.mesh_path_id_map);
		defer  release(*Mesh_Manager.mesh_path_id_map);
		for map.*
		{
			if it.path == mesh_path  return it.id;
		}
	}
	return register_Mesh(mesh_path);
}
#scope_module

get_Mesh :: (mesh_id : Mesh_ID) -> *Mesh
{
	if mesh_id < 0  return null;
	
	loaded_meshes := acquire(*Mesh_Manager.loaded_meshes);
	defer release(*Mesh_Manager.loaded_meshes);
	return get(loaded_meshes, cast(int) mesh_id);
}

register_Mesh :: (path : Mesh_Path) -> Mesh_ID
{
	log("Registering Mesh '%'", path);
	id : Mesh_ID;
	{
		loaded_meshes := acquire(*Mesh_Manager.loaded_meshes);
		defer            release(*Mesh_Manager.loaded_meshes);
		id = cast(Mesh_ID) get_Slot(loaded_meshes);
	}
	{
		map := acquire(*Mesh_Manager.mesh_path_id_map);
		defer  release(*Mesh_Manager.mesh_path_id_map);
		array_add(map, .{id = id, path = path});
	}
	return id;
}


set_Mesh :: (mesh_id : Mesh_ID, mesh : Mesh)
{
	loaded_meshes := acquire(*Mesh_Manager.loaded_meshes);
	defer            release(*Mesh_Manager.loaded_meshes);
	set(loaded_meshes, cast(int) mesh_id, mesh);
}


Mesh_ID   :: #type,distinct int;
Mesh_Path :: #type,distinct string;

#scope_file

Mesh_Manager : struct
{
	loaded_meshes    : Mutex(PredicatedAutoArray(Mesh));
	mesh_path_id_map : Mutex([..] struct {path : Mesh_Path; id : Mesh_ID;});
};
