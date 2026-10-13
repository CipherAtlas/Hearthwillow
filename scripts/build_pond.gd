extends RefCounted

var root: Node3D

func add(parent: Node, node: Node, node_name: String) -> Node:
	node.name = node_name; parent.add_child(node); node.owner = root
	return node

func build() -> Dictionary:
	if FileAccess.file_exists("res://scenes/pond_life.tscn"): return {"changed":false}
	root = Node3D.new(); root.name = "PondLife"
	root.set_script(load("res://scenes/pond_life.gd"))
	for node_name: String in ["Birds","Fish","Ripples","Splash","Hearts","Replies","Crumbs"]: add(root,Node3D.new(),node_name)
	var ring := TorusMesh.new(); ring.inner_radius = .92; ring.outer_radius = 1; ring.rings = 40; ring.ring_segments = 6
	var water := StandardMaterial3D.new(); water.albedo_color = Color("d2eee2"); water.albedo_color.a = .34
	water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; ring.material = water
	for i in 15:
		var species := "swan" if i<3 else "duck" if i<7 else "duckling"
		var bird: Node3D = load("res://assets/animals/"+species+".glb").instantiate()
		add(root.get_node("Birds"),bird,str(i))
		var heart := Label3D.new(); heart.text = "♥"; heart.font_size = 64; heart.pixel_size = .006; heart.modulate = Color("ff9aab")
		heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED; heart.visible = false
		add(root.get_node("Hearts"),heart,str(i))
		var cue := Marker3D.new(); cue.visible = false
		add(root.get_node("Replies"),cue,str(i))
	for i in 21:
		var ripple := MeshInstance3D.new(); ripple.mesh = ring; ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ripple.scale.y = .01
		add(root.get_node("Ripples" if i<15 else "Splash"),ripple,str(i if i<15 else i-15))
	for i in 8:
		var fish: Node3D = load("res://assets/quiet/fish.tscn").instantiate()
		fish.scale = Vector3.ONE*(.85+i%4*.08)
		add(root.get_node("Fish"),fish,str(i))
	var crumb_mesh := SphereMesh.new(); crumb_mesh.radius = .036; crumb_mesh.height = .072; crumb_mesh.radial_segments = 6; crumb_mesh.rings = 2
	var bread := StandardMaterial3D.new(); bread.albedo_color = Color("ecc88b"); bread.roughness = 1; crumb_mesh.material = bread
	for i in 18:
		var crumb := MeshInstance3D.new(); crumb.mesh = crumb_mesh
		add(root.get_node("Crumbs"),crumb,str(i))
	var packed := PackedScene.new(); packed.pack(root)
	var error := ResourceSaver.save(packed,"res://scenes/pond_life.tscn")
	root.free(); return {"changed":true,"error":error}
