@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for mesh: Node in scene.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh: continue
		for i in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(i)
			if arrays[Mesh.ARRAY_COLOR] == null: continue
			var material: Material = mesh.mesh.surface_get_material(i)
			if material is StandardMaterial3D:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
	return scene
