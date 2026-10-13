extends RefCounted

var root: Node3D
var owner: Node3D
var surface: Node
var meshes: Dictionary = {}

func add(parent: Node, node: Node, node_name: String) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = owner
	return node

func label(parent: Node, name_text: String, text: String, size_value := 14) -> Label:
	var node := Label.new()
	node.text = text; node.add_theme_font_size_override("font_size",size_value)
	add(parent,node,name_text)
	return node

func button(parent: Node, name_text: String, text: String, method: String, args: Array = []) -> Button:
	var node := Button.new(); node.text = text; node.custom_minimum_size.y = 44
	add(parent,node,name_text)
	node.pressed.connect(Callable(root,method).bindv(args),Object.CONNECT_PERSIST)
	return node

func panel(parent: Node, name_text: String, width: float) -> VBoxContainer:
	var box := PanelContainer.new(); box.visible = false; box.custom_minimum_size.x = width
	add(parent,box,name_text)
	var content := VBoxContainer.new(); content.add_theme_constant_override("separation",8)
	add(box,content,"Content")
	return content

func build() -> Dictionary:
	# Saved scenes are canonical. This initializer must never replace subsequent
	# editor work (growth clocks, garden cards, native keycaps and shared resources).
	if FileAccess.file_exists("res://scenes/activities.tscn"):
		return {"saved_scene":"res://scenes/activities.tscn","changed":false}
	root = Node3D.new(); root.name = "VillageActivities"; owner = root
	root.set_script(load("res://scenes/village_activities.gd"))
	var crops := add(root,Node3D.new(),"Crops") as Node3D
	var kit: Node3D = load("res://assets/village/garden-pond.glb").instantiate()
	for crop: String in ["sprout","carrot","radish","mint","daisy","sunflower"]:
		var template: Node3D = kit.find_child(crop.capitalize(),true,false)
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in template.find_children('*','MeshInstance3D',true,false):
			tool.append_from(part.mesh,0,part.transform)
		var mesh: ArrayMesh = tool.commit()
		mesh.surface_set_material(0,load("res://assets/village/materials/material_69.tres"))
		var path := "res://assets/gameplay/"+crop+".res"
		ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS); mesh.take_over_path(path)
		meshes[crop] = mesh
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/village/world-data.json"))
	var positions := [[22.2,-10.0],[27.2,-10.0],[22.2,-5.5],[27.2,-5.5],[22.2,-1.0],[27.2,-1.0],[24.7,-12.7]]
	for i in 7:
		var crop: String = ["carrot","radish","carrot","radish","mint","daisy","sunflower"][i]
		var choices: Array = ["carrot","radish"] if i<4 else [crop]
		var bed := add(crops,Node3D.new(),"garden-%d"%i) as Node3D
		bed.position = Vector3(positions[i][0]-24,.13 if i==6 else .25,positions[i][1]+6)
		bed.set_meta("item_id","kitchen-garden"); bed.set_meta("half_width",4.95 if i==6 else 1.6)
		bed.set_meta("choices",choices); bed.set_meta("initial_crop",crop)
		bed.set_meta("initial_stage",["grown","grown","empty","empty","sprout","grown","grown"][i])
		for model: String in choices+["sprout"]: crop_batch(bed,model,13 if i==6 else 20 if i==5 else 9,false,i)
	for item: Dictionary in data.items:
		if item.asset not in ["farm-row","town-garden-bed"]: continue
		var bed := add(crops,Node3D.new(),item.id) as Node3D; bed.position.y = .19
		var crop: String = "carrot" if str(item.id).begins_with("farm-1") else "radish" if str(item.id).begins_with("farm-2") else "mint"
		var row := int(str(item.id).get_slice("-row-",1))
		var choices: Array = [crop] if item.asset == "farm-row" else ["carrot","radish","mint"]
		bed.set_meta("half_width",8.0 if item.asset == "farm-row" else 1.6)
		bed.set_meta("base_scale_y",item.scale[1]); bed.set_meta("choices",choices)
		bed.set_meta("title",crop.capitalize()+" Farm - Row "+str(row))
		bed.set_meta("initial_crop",crop); bed.set_meta("initial_stage","grown" if row in [1,2] else "sprout" if row==3 else "empty")
		for model: String in choices+["sprout"]: crop_batch(bed,model,28,true,0)
	var kitchens := add(root,Node3D.new(),"Kitchens")
	var served := add(root,Node3D.new(),"Served")
	for item: Dictionary in data.items:
		if item.asset not in ["garden-kitchen","picnic-mat"]: continue
		var anchor := add(kitchens if item.asset == "garden-kitchen" else served,Node3D.new(),item.id) as Node3D
		anchor.position = Vector3(item.position[0],item.position[1],item.position[2])
		anchor.rotation.y = deg_to_rad(item.rotation[1]); anchor.scale = Vector3(item.scale[0],item.scale[1],item.scale[2])
		if item.asset == "garden-kitchen":
			for recipe: String in ["gardenSoup","crispSalad","bakedApples","roastRoots"]:
				var visual: Node3D = load("res://assets/gameplay/"+recipe+"-cooking.glb").instantiate(); visual.visible = false
				add(anchor,visual,recipe)
		else:
			for index in 4:
				var slot := add(anchor,Node3D.new(),"Slot%d"%index) as Node3D
				slot.position = Vector3(-.9+(index%2)*1.8,.08,-.8+floori(index/2.0)*1.1)
				for recipe: String in ["gardenSoup","crispSalad","bakedApples","roastRoots"]:
					var dish: Node3D = load("res://assets/gameplay/"+recipe+".glb").instantiate(); dish.visible = false
					add(slot,dish,recipe)
	var can_source: Node3D = kit.find_child("WateringCan",true,false).duplicate()
	add(root,can_source,"WateringCan"); can_source.visible = false
	for child: Node in can_source.find_children("*","",true,false): child.owner = owner
	var drops := GPUParticles3D.new(); drops.amount = 40; drops.lifetime = .8; drops.emitting = false
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0,-1,0); process_material.spread = 18
	process_material.initial_velocity_min = .5; process_material.initial_velocity_max = 1.5
	process_material.gravity = Vector3(0,-3,0); process_material.scale_min = .5; process_material.scale_max = 1
	drops.process_material = process_material
	var drop_mesh := SphereMesh.new(); drop_mesh.radius = .018; drop_mesh.height = .07
	var drop_mat := StandardMaterial3D.new(); drop_mat.albedo_color = Color("a5d7de"); drop_mat.roughness = .2
	drop_mesh.material = drop_mat; drops.draw_pass_1 = drop_mesh
	add(root,drops,"WaterDrops")
	var ui := add(root,CanvasLayer.new(),"UI") as CanvasLayer; ui.layer = 4
	var controls := panel(ui,"Context",380)
	label(controls,"Title","Kitchen garden",16); label(controls,"Status","")
	var actions := add(controls,VBoxContainer.new(),"Actions")
	for index in 8:
		var btn := button(actions,"Action%d"%index,"","activate",[index]); btn.visible = false
		var row := add(btn,HBoxContainer.new(),"Row") as HBoxContainer
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 9; row.offset_right = -9; row.offset_top = 6; row.offset_bottom = -6
		row.add_theme_constant_override("separation",8)
		var key := add(row,PanelContainer.new(),"Key") as PanelContainer
		key.custom_minimum_size = Vector2(26,26); key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key_text := label(key,"Text","E",12); key_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; key_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text := label(row,"Text","Action",13); text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.custom_minimum_size.y = 60
	var hud := panel(ui,"Cooking",330)
	(hud.get_parent() as Control).position = Vector2(795,82)
	label(hud,"Title","Preparing",15); label(hud,"Recipe","Garden soup",13)
	var progress := ProgressBar.new(); progress.show_percentage = false; progress.custom_minimum_size.y = 6
	add(hud,progress,"Progress"); button(hud,"Pack","E   Pack into basket","activate",[4])
	var garden := panel(ui,"Garden",380)
	(garden.get_parent() as Control).position = Vector2(1522,280)
	label(garden,"Title","Kitchen garden",24)
	var bed_buttons := add(garden,VBoxContainer.new(),"Beds")
	for i in 7: button(bed_buttons,"Bed%d"%i,"Bed %d"%(i+1),"select_garden",[i])
	label(garden,"Inventory",""); button(garden,"Close","Esc   Back","close_garden")
	for control: Control in [controls.get_parent(),hud.get_parent(),garden.get_parent()]:
		control.theme = load("res://scenes/village_theme.tres")
		control.add_theme_font_override("font",load("res://assets/fonts/Outfit.tres"))
	var packed := PackedScene.new(); packed.pack(root)
	var error := ResourceSaver.save(packed,"res://scenes/activities.tscn")
	var result := {"beds":crops.get_child_count(),"kitchens":kitchens.get_child_count(),"mats":served.get_child_count(),"error":error}
	kit.free(); root.free()
	return result

func crop_batch(bed: Node3D, crop: String, count_value: int, farm: bool, index: int) -> void:
	var multi := MultiMesh.new(); multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = meshes[crop]; multi.instance_count = count_value
	for i in count_value:
		var point := Vector3.ZERO; var scale_value := 1.0
		if farm: point = Vector3(-7.25+floori(i/2.0)*(14.5/13),0,(i%2-.5)*.57)
		elif index==6: point = Vector3(-4.62+i*.77,0,sin(i*1.5)*.08); scale_value = .9+(i%3)*.09
		elif index==5: point = Vector3(-1.24+(i%5)*.62,0,.9-floori(i/5.0)*.55); scale_value = .75+(i%3)*.08
		else: point = Vector3((i%3-1)*.92,0,(floori(i/3.0)-1)*.7)
		multi.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(0,sin(i*7.3)*.3,0)).scaled(Vector3.ONE*scale_value),point))
	var instance := MultiMeshInstance3D.new(); instance.multimesh = multi; instance.visible = false
	add(bed,instance,crop)
