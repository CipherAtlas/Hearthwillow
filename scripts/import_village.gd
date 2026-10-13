extends SceneTree

const ASSETS := "res://assets/village/"
var manifest: Dictionary
var binary: PackedByteArray
var materials: Array[Material] = []
var geometries: Array[ArrayMesh] = []

func _init() -> void:
	call_deferred("convert")

func read_floats(record: Dictionary) -> PackedFloat32Array:
	return binary.slice(int(record.offset), int(record.offset) + int(record.bytes)).to_float32_array()

func read_ints(record: Dictionary) -> PackedInt32Array:
	return binary.slice(int(record.offset), int(record.offset) + int(record.bytes)).to_int32_array()

func color_from(values: Array) -> Color:
	return Color(values[0], values[1], values[2], values[3] if values.size() > 3 else 1.0)

func vector_from(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func transform_from(values: PackedFloat32Array, offset: int) -> Transform3D:
	return Transform3D(Basis(Vector3(values[offset], values[offset+1], values[offset+2]), Vector3(values[offset+4], values[offset+5], values[offset+6]), Vector3(values[offset+8], values[offset+9], values[offset+10])), Vector3(values[offset+12], values[offset+13], values[offset+14]))

func save_resource(resource: Resource, path: String) -> void:
	resource.take_over_path(path)
	var result := ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_COMPRESS)
	assert(result == OK, "Could not save " + path)

func make_material(data: Dictionary, index: int) -> Material:
	var material: Material
	if str(data.shaderKey).contains("garden-breeze") or data.has("fragmentShader") or str(data.shaderKey).contains("village-water-soft-joined") or str(data.shaderKey).contains("village-wind-") or str(data.shaderKey).contains("village-surface-") or str(data.shaderKey).contains("village-path-shoulder") or str(data.shaderKey).contains("village-painted-meadow"):
		var shader_material := ShaderMaterial.new()
		if data.has("fragmentShader"):
			shader_material.shader = load("res://assets/shaders/original_%d.gdshader" % index)
			for key in data.uniforms:
				if key == "time": continue
				var value: Variant = data.uniforms[key]
				if value is Array:
					value = Vector2(value[0],value[1]) if value.size() == 2 else vector_from(value)
				shader_material.set_shader_parameter(key,value)
		elif str(data.shaderKey).contains("village-water-soft-joined"):
			shader_material.shader = load("res://assets/shaders/water.gdshader")
			shader_material.set_shader_parameter("pond", str(data.shaderKey).contains("true"))
		elif str(data.shaderKey).contains("garden-breeze"):
			shader_material.shader = load("res://assets/shaders/garden_breeze.gdshader")
		elif str(data.shaderKey).contains("village-wind-"):
			shader_material.shader = load("res://assets/shaders/foliage.gdshader")
			var parts: PackedStringArray = str(data.shaderKey).split("-")
			shader_material.set_shader_parameter("sway", float(parts[2]))
			shader_material.set_shader_parameter("tree", parts[3].begins_with("true"))
			shader_material.set_shader_parameter("tint", color_from(data.color).linear_to_srgb())
			shader_material.set_shader_parameter("vertex_colors", bool(data.vertexColors))
			if data.map != null:
				shader_material.set_shader_parameter("has_texture", true)
				shader_material.set_shader_parameter("surface_texture", load(ASSETS + manifest.textures[int(data.map)].name))
		else:
			shader_material.shader = load("res://assets/shaders/surface.gdshader")
			shader_material.set_shader_parameter("tint", color_from(data.color).linear_to_srgb())
			shader_material.set_shader_parameter("vertex_colors", bool(data.vertexColors))
			shader_material.set_shader_parameter("surface_roughness", float(data.roughness))
			shader_material.set_shader_parameter("foot_shade", str(data.shaderKey).contains("Material-true"))
			shader_material.set_shader_parameter("surface_mode", 1 if str(data.shaderKey).contains("painted-meadow") else 2 if str(data.shaderKey).contains("path-shoulder") else 0)
			shader_material.set_shader_parameter("shoulder_texture", load(ASSETS + "texture_0.png"))
			if data.map != null:
				var texture: Dictionary = manifest.textures[int(data.map)]
				shader_material.set_shader_parameter("has_texture", true)
				shader_material.set_shader_parameter("surface_texture", load(ASSETS + texture.name))
				shader_material.set_shader_parameter("uv_scale", Vector2(texture.repeat[0], texture.repeat[1]*(-1 if texture.flipY else 1)))
				shader_material.set_shader_parameter("uv_offset", Vector2(texture.offset[0],texture.offset[1]+(1 if texture.flipY else 0)))
		material = shader_material
	else:
		var standard := StandardMaterial3D.new()
		standard.albedo_color = color_from(data.color).linear_to_srgb()
		standard.albedo_color.a = float(data.opacity)
		standard.roughness = float(data.roughness)
		standard.metallic = float(data.metalness)
		standard.vertex_color_use_as_albedo = bool(data.vertexColors)
		standard.vertex_color_is_srgb = false
		if bool(data.doubleSided): standard.cull_mode = BaseMaterial3D.CULL_DISABLED
		if bool(data.get("unshaded", false)): standard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if float(data.alphaTest) > 0.0:
			standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			standard.alpha_scissor_threshold = float(data.alphaTest)
		elif bool(data.transparent): standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var emission := color_from(data.emissive)
		if emission.r + emission.g + emission.b > 0.0:
			standard.emission_enabled = true
			standard.emission = emission.linear_to_srgb()
			standard.emission_energy_multiplier = float(data.emissionEnergy)
		if data.map != null:
			var texture: Dictionary = manifest.textures[int(data.map)]
			standard.albedo_texture = load(ASSETS + texture.name)
			standard.uv1_scale = Vector3(texture.repeat[0], texture.repeat[1] * (-1.0 if bool(texture.flipY) else 1.0), 1)
			standard.uv1_offset = Vector3(texture.offset[0], texture.offset[1] + (1.0 if bool(texture.flipY) else 0.0), 0)
			standard.texture_repeat = not bool(texture.clamp)
		material = standard
	material.resource_name = str(data.name) if str(data.name) != "" else "Village material %d" % index
	save_resource(material, ASSETS + "materials/material_%d.tres" % index)
	return material

func make_geometry(data: Dictionary, index: int) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var attributes: Dictionary = data.attributes
	var points := PackedVector3Array()
	var raw := read_floats(attributes.position)
	points.resize(raw.size()/3)
	for i in points.size(): points[i] = Vector3(raw[i*3], raw[i*3+1], raw[i*3+2])
	arrays[Mesh.ARRAY_VERTEX] = points
	if attributes.has("normal"):
		raw = read_floats(attributes.normal)
		var normals := PackedVector3Array()
		normals.resize(raw.size()/3)
		for i in normals.size(): normals[i] = Vector3(raw[i*3], raw[i*3+1], raw[i*3+2])
		arrays[Mesh.ARRAY_NORMAL] = normals
	for entry in [["uv", Mesh.ARRAY_TEX_UV], ["uv2", Mesh.ARRAY_TEX_UV2]]:
		if attributes.has(entry[0]):
			raw = read_floats(attributes[entry[0]])
			var uvs := PackedVector2Array()
			uvs.resize(raw.size()/2)
			for i in uvs.size(): uvs[i] = Vector2(raw[i*2], raw[i*2+1])
			arrays[entry[1]] = uvs
	if attributes.has("color"):
		raw = read_floats(attributes.color)
		var colors := PackedColorArray()
		colors.resize(raw.size()/4)
		for i in colors.size(): colors[i] = Color(raw[i*4], raw[i*4+1], raw[i*4+2], raw[i*4+3])
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = read_ints(data.indices)
	var mesh := ArrayMesh.new()
	var lods := {}
	if points.size() == 24 and arrays[Mesh.ARRAY_INDEX].size() == 54:
		var distant := PackedInt32Array()
		for blade in 3:
			var base := blade*8
			distant.append_array(PackedInt32Array([base,base+1,base+6,base+1,base+7,base+6]))
		lods[.12] = distant
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays,[],lods)
	save_resource(mesh, ASSETS + "meshes/geometry_%d.res" % index)
	return mesh

func attach(parent: Node, node: Node, owner: Node) -> void:
	parent.add_child(node)
	node.owner = owner

func add_animal(parent: Node3D, owner: Node3D, id: String, kind: String, model_path: String, point: Vector3, yaw: float, size: Vector3, title: String, route: Array) -> void:
	var actor := CharacterBody3D.new()
	actor.name = id
	actor.script = load("res://scenes/village_actor.gd")
	actor.actor_id = id; actor.actor_kind = kind
	actor.profile = {"id":id,"name":title,"route":route}
	actor.position = point; actor.rotation.y = yaw; actor.scale = size
	actor.collision_layer = 8; actor.collision_mask = 3; actor.floor_snap_length = .3
	attach(parent,actor,owner)
	var pose := Node3D.new(); pose.name = "Pose"
	attach(actor,pose,owner)
	var model: Node3D = load(model_path).instantiate()
	if kind == "hedgehog":
		var template: Node3D = model.find_child("Hedgehog",true,false)
		assert(template != null,"Original hedgehog must exist in town-kit")
		var isolated: Node3D = template.duplicate()
		model.free(); model = isolated
	model.name = "Model"
	attach(pose,model,owner)
	if kind == "hedgehog":
		for child: Node in model.find_children("*","",true,false): child.owner = owner
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .5 if kind in ["cow","horse"] else .25
	capsule.height = 2.4 if kind == "horse" else 1.7 if kind == "cow" else .7
	collision.shape = capsule; collision.position.y = capsule.height*.5
	attach(actor,collision,owner)

func merge_static_geometry(scenery: Node3D, owner: Node3D) -> void:
	var groups := {}
	for instance: Node in scenery.get_children():
		if not instance is MeshInstance3D or not instance.mesh is ArrayMesh: continue
		var material: Material = instance.mesh.surface_get_material(0)
		if not material is StandardMaterial3D or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var index: int = instance.get_meta("source_index",-1)
		if index < 0: continue
		var cell := Vector3i(floori(instance.position.x/24),floori(instance.position.y/24),floori(instance.position.z/24))
		var key := "%s_%d_%d_%d_%d" % [manifest.meshes[index].material,cell.x,cell.y,cell.z,instance.cast_shadow]
		if not groups.has(key): groups[key] = []
		groups[key].append(instance)
	var merged_count := 0
	for key: String in groups:
		var group: Array = groups[key]
		if group.size() < 2: continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var material: StandardMaterial3D = group[0].mesh.surface_get_material(0).duplicate()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = false
		for instance: MeshInstance3D in group:
			var arrays: Array = instance.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			if colors.is_empty():
				colors.resize(vertices.size()); colors.fill(Color.WHITE)
			var data: Dictionary = manifest.meshes[int(instance.get_meta("source_index"))]
			if data.colors != null:
				var raw := read_floats(data.colors)
				var tint := Color(raw[0],raw[1],raw[2],raw[3])
				for i in colors.size(): colors[i] *= tint
			arrays[Mesh.ARRAY_COLOR] = colors
			if arrays[Mesh.ARRAY_TEX_UV] == null:
				var uvs := PackedVector2Array(); uvs.resize(vertices.size()); arrays[Mesh.ARRAY_TEX_UV] = uvs
			var source := ArrayMesh.new()
			source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			tool.append_from(source,0,instance.transform)
		var importer := ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,tool.commit_to_arrays(),[],{},material)
		importer.generate_lods(60,0,[])
		var mesh := importer.get_mesh()
		save_resource(material,ASSETS+"materials/merged_%s.tres" % key)
		save_resource(mesh,ASSETS+"meshes/merged_%s.res" % key)
		var merged := MeshInstance3D.new()
		merged.name = "Static_cell_"+key
		merged.mesh = mesh; merged.cast_shadow = group[0].cast_shadow
		attach(scenery,merged,owner)
		for instance: MeshInstance3D in group: instance.free()
		merged_count += group.size()-1
	print("Merged static opaque meshes: ",merged_count," fewer geometry nodes")

func floor_collision(parent: Node, owner: Node, heights: PackedFloat32Array, width: int, origin_x: float, origin_z: float, step: float, label: String) -> void:
	var faces := PackedVector3Array()
	faces.resize((width-1)*(width-1)*6)
	var at := 0
	for z in width-1:
		for x in width-1:
			var a := Vector3(origin_x+x*step, heights[z*width+x], origin_z+z*step)
			var b := Vector3(a.x+step, heights[z*width+x+1], a.z)
			var c := Vector3(a.x, heights[(z+1)*width+x], a.z+step)
			var d := Vector3(b.x, heights[(z+1)*width+x+1], c.z)
			faces[at]=a; faces[at+1]=b; faces[at+2]=c; faces[at+3]=b; faces[at+4]=d; faces[at+5]=c
			at += 6
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	attach(parent, body, owner)
	var shape := CollisionShape3D.new()
	var collision := ConcavePolygonShape3D.new()
	collision.backface_collision = true
	collision.set_faces(faces)
	save_resource(collision, ASSETS + "collisions/" + label + ".res")
	shape.shape = collision
	attach(body, shape, owner)

func convert() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Scene conversion requires a real renderer to retain MultiMesh transforms; omit --headless.")
		quit(1)
		return
	manifest = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "manifest.json"))
	binary = FileAccess.get_file_as_bytes(ASSETS + "geometry.bin")
	for folder in ["materials", "meshes", "instances", "collisions"]: DirAccess.make_dir_recursive_absolute(ASSETS + folder)
	for i in manifest.materials.size(): materials.append(make_material(manifest.materials[i], i))
	for i in manifest.geometries.size(): geometries.append(make_geometry(manifest.geometries[i], i))
	var village := Node3D.new()
	village.name = "Village"
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	attach(village, scenery, village)
	var actors := Node3D.new()
	actors.name = "Actors"
	attach(village,actors,village)
	var resident_nodes := {}
	for actor: Dictionary in manifest.actors:
		var resident := CharacterBody3D.new()
		resident.name = actor.id
		resident.script = load("res://scenes/village_actor.gd")
		resident.actor_id = actor.id
		resident.actor_kind = "resident"
		resident.transform = transform_from(PackedFloat32Array(actor.transform),0)
		resident.collision_layer = 8
		resident.collision_mask = 3
		resident.floor_snap_length = .25
		attach(actors,resident,village)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .3; capsule.height = 1.65
		shape.shape = capsule
		shape.position.y = .825
		attach(resident,shape,village)
		var pose := Node3D.new()
		pose.name = "Pose"
		attach(resident,pose,village)
		resident_nodes[actor.id] = resident
	var puppy_routes := {"corgi":[[0,0],[7,2],[16,6],[10,9],[2,6],[-6,2],[-4,-1]],"shiba":[[0,0],[-3.2,-1],[-4.2,-1.7],[-9,-4.2],[-5,-8.7],[1,-8.7],[2,-3.2]],"beagle":[[0,0],[-6,-1.5],[-9,-1.5],[-3,-2],[6,0],[11,0],[11,-3],[10.7,-7.5],[11,0],[4,0]],"samoyed":[[0,0],[2,-2],[-.2,-3],[-1.5,4],[-1.8,7],[-2.2,14],[.4,13],[1.1,5]]}
	for puppy: Dictionary in manifest.layout.puppies:
		var route := []
		for offset: Array in puppy_routes[puppy.breed]:
			var delta := Vector2(offset[0],offset[1]).rotated(-float(puppy.yaw))
			route.append([puppy.x+delta.x,puppy.z+delta.y])
		add_animal(actors,village,puppy.id,"dog","res://assets/animals/dog-%s.glb" % puppy.breed,Vector3(puppy.x,puppy.y,puppy.z),puppy.yaw,vector_from(puppy.scale),puppy.name,route)
	var models := {"cow-highland":"highland-copper","cow-highland-girl":"highland-flower","sheep":"sheep","lamb":"lamb","owl-brown":"owl","hedgehog":"farm-props"}
	for item: Dictionary in manifest.layout.items:
		if not item.visible or not models.has(item.asset): continue
		var kind: String = "cow" if str(item.asset).begins_with("cow") else "owl" if item.asset == "owl-brown" else item.asset
		var route := [[item.position[0],item.position[2]]]
		if kind != "owl": route.append_array([[item.position[0]-2,item.position[2]+1],[item.position[0]+1.8,item.position[2]+2.3]])
		add_animal(actors,village,item.id,kind,"res://assets/animals/%s.glb" % models[item.asset],vector_from(item.position),deg_to_rad(item.rotation[1]),vector_from(item.scale),item.get("name",item.id),route)
	for horse: Dictionary in manifest.layout.horses:
		add_animal(actors,village,horse.id,"horse","res://assets/animals/horse-%s.glb" % horse.coat,Vector3(horse.x,horse.y,horse.z),horse.yaw,vector_from(horse.scale),horse.name,[[horse.x,horse.z]])
	var used_meshes: Dictionary = {}
	for i in manifest.meshes.size():
		var data: Dictionary = manifest.meshes[i]
		if data.get("actor") != null and str(data.actor).begins_with("puppy-"): continue
		var key := "%s_%s" % [data.geometry, data.material]
		if not used_meshes.has(key):
			var mesh: ArrayMesh = geometries[int(data.geometry)].duplicate()
			mesh.surface_set_material(0, materials[int(data.material)])
			save_resource(mesh, ASSETS + "meshes/surface_" + key + ".res")
			used_meshes[key] = mesh
		var transforms := read_floats(data.transforms)
		var colors := read_floats(data.colors) if data.colors != null else PackedFloat32Array()
		var instance: GeometryInstance3D
		if int(data.count) > 1:
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_colors = not colors.is_empty()
			multi.mesh = used_meshes[key]
			multi.instance_count = int(data.count)
			for n in int(data.count):
				multi.set_instance_transform(n, transform_from(transforms, n*16))
				if multi.use_colors: multi.set_instance_color(n, Color(colors[n*4], colors[n*4+1], colors[n*4+2], colors[n*4+3]))
			save_resource(multi, ASSETS + "instances/batch_%d.res" % i)
			var batch_node := MultiMeshInstance3D.new()
			batch_node.multimesh = multi
			instance = batch_node
		else:
			var mesh_node := MeshInstance3D.new()
			mesh_node.mesh = used_meshes[key]
			mesh_node.transform = transform_from(transforms, 0)
			if not colors.is_empty():
				var override_material: Material = materials[int(data.material)].duplicate()
				var instance_color := Color(colors[0], colors[1], colors[2], colors[3])
				if override_material is StandardMaterial3D: override_material.albedo_color *= instance_color.linear_to_srgb()
				elif override_material is ShaderMaterial and str(manifest.materials[int(data.material)].shaderKey).contains("village-wind-"): override_material.set_shader_parameter("tint", (color_from(manifest.materials[int(data.material)].color) * instance_color).linear_to_srgb())
				mesh_node.material_override = override_material
			instance = mesh_node
		if str(data.name).begins_with("White dove flock"):
			instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		instance.name = "%s_%04d" % [str(data.name).replace("/", "_").replace(".", "_"), i]
		instance.set_meta("source_name", data.name)
		instance.set_meta("source_index",i)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(data.castShadow) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if data.get("actor") != null:
			var resident: CharacterBody3D = resident_nodes[data.actor]
			instance.transform = resident.transform.affine_inverse()*instance.transform
			instance.set_meta("part",data.part)
			attach(resident.get_node("Pose"),instance,village)
		else: attach(scenery, instance, village)
	merge_static_geometry(scenery,village)
	for i in manifest.points.size():
		var data: Dictionary = manifest.points[i]
		var seeds := read_floats(data.seeds)
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		for n in seeds.size()/3:
			var seed := Vector3(seeds[n*3],seeds[n*3+1],seeds[n*3+2])
			for uv in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				vertices.append(seed)
				uvs.append(uv)
			indices.append_array(PackedInt32Array([n*4,n*4+2,n*4+1,n*4+1,n*4+2,n*4+3]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,materials[int(data.material)])
		save_resource(mesh,ASSETS+"meshes/points_%d.res" % i)
		var effect := MeshInstance3D.new()
		effect.name = str(data.name).replace(" ","_")
		effect.mesh = mesh
		effect.transform = transform_from(PackedFloat32Array(data.transform),0)
		effect.custom_aabb = AABB(Vector3(-8,-4,-8),Vector3(16,24,16))
		effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attach(scenery,effect,village)
	var physics := Node3D.new()
	physics.name = "Collisions"
	attach(village, physics, village)
	for i in manifest.colliders.size():
		var c: Dictionary = manifest.colliders[i]
		var bottom := float(c.get("bottom", -1))
		var top := float(c.get("top", 8))
		var body := StaticBody3D.new()
		body.name = "Obstacle_%04d" % i
		body.position = Vector3(c.x, (bottom+top)*.5, c.z)
		body.rotation.y = float(c.get("yaw", 0))
		body.collision_layer = 2
		attach(physics, body, village)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(.01,c.w), maxf(.01,top-bottom), maxf(.01,c.d))
		shape.shape = box
		attach(body, shape, village)
	var floor_data := read_floats(manifest.floorHeights)
	# Tile the ground collision so broad-phase queries do not test the whole valley.
	for tz in 20:
		for tx in 20:
			var heights := PackedFloat32Array()
			heights.resize(17*17)
			for z in 17:
				for x in 17: heights[z*17+x] = floor_data[(tz*32+z*2)*641+tx*32+x*2]
			floor_collision(physics, village, heights, 17, -320+tx*32, -320+tz*32, 2, "Ground_%02d_%02d" % [tx,tz])
	for i in manifest.bridgeFloors.size():
		var patch: Dictionary = manifest.bridgeFloors[i]
		floor_collision(physics, village, read_floats(patch.heights), int(patch.width), patch.x, patch.z, patch.step, "Bridge_floor_%d" % i)
		var patch_file := FileAccess.open(ASSETS + "bridge-floor-%d.bin" % i, FileAccess.WRITE)
		patch_file.store_buffer(read_floats(patch.heights).to_byte_array())
	var scene := PackedScene.new()
	assert(scene.pack(village) == OK)
	save_resource(scene, "res://scenes/village.tscn")
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://assets/shaders/village_sky.gdshader")
	for key in manifest.sky.uniforms:
		if key == "time": continue
		var value: Variant = manifest.sky.uniforms[key]
		sky_material.set_shader_parameter(key, vector_from(value) if value is Array else value)
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	save_resource(sky, "res://assets/village/sky.tres")
	var map_data := {"birds":manifest.birds,"actors":manifest.actors,"paths": manifest.paths, "rivers": manifest.rivers, "buildings": manifest.buildings, "items": [], "colliders": manifest.colliders, "bounds": manifest.bounds, "source": manifest.source, "spawn": manifest.spawn, "spirit_scale": manifest.spiritScale, "bridge_floors": manifest.bridgeFloors}
	for item in manifest.layout.items:
		if item.visible: map_data.items.append({"id":item.id,"asset":item.asset,"name":item.get("name",item.id),"position":item.position,"rotation":item.rotation,"scale":item.scale})
	var map_file := FileAccess.open("res://assets/village/world-data.json", FileAccess.WRITE)
	map_file.store_string(JSON.stringify(map_data))
	var floor_file := FileAccess.open("res://assets/village/floor-heights.bin", FileAccess.WRITE)
	floor_file.store_buffer(floor_data.to_byte_array())
	var allowed_file := FileAccess.open("res://assets/village/allowed-ground.bin", FileAccess.WRITE)
	allowed_file.store_buffer(binary.slice(int(manifest.allowedGround.offset), int(manifest.allowedGround.offset)+int(manifest.allowedGround.bytes)))
	print("Converted %d scene meshes, %d source obstacles and four detailed bridge floors." % [manifest.meshes.size(),manifest.colliders.size()])
	village.free()
	used_meshes.clear()
	geometries.clear()
	materials.clear()
	call_deferred("finish")

func finish() -> void:
	# Let rendering resources release after conversion's local references leave scope.
	await process_frame
	await process_frame
	quit()
