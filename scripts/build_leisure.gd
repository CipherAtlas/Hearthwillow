extends RefCounted

var main: Node3D
var owner_root: Node
var theme: Theme = load("res://scenes/interaction_theme.tres")
var outfit: Font = load("res://assets/fonts/Outfit.tres")
var key_font: Font = load("res://assets/fonts/Keycap.tres")
var title_font: Font = load("res://assets/fonts/Georgia.tres")

func add(parent: Node, child: Node, name_text: String) -> Node:
	child.name = name_text
	parent.add_child(child)
	child.owner = owner_root
	return child

func own(root: Node) -> void:
	for child: Node in root.get_children():
		child.owner = owner_root
		child.scene_file_path = ""
		own(child)

func model(parent: Node, file: String, name_text: String) -> Node3D:
	var root: Node3D = load(file).instantiate()
	root.scene_file_path = ""
	add(parent,root,name_text)
	own(root)
	return root

func label(parent: Node, name_text: String, text: String, font_size := 14, title := false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font",title_font if title else outfit)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("fff2d9"))
	add(parent,node,name_text)
	return node

func button(parent: Node, name_text: String, text: String, key: String, action: String, target: Object, method: String, args: Array = []) -> Button:
	var node := Button.new()
	node.custom_minimum_size.y = 44
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.theme = theme
	node.set_script(load("res://scenes/interaction_button.gd"))
	node.action = action
	add(parent,node,name_text)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 7; row.offset_right = -7
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",7)
	add(node,row,"Row")
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.custom_minimum_size = Vector2(24,24)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_theme_stylebox_override("panel",load("res://scenes/interaction_keycap.tres"))
	cap.visible = not key.is_empty()
	add(row,cap,"Key")
	var key_label := label(cap,"Text",key,12)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_override("font",key_font)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := label(row,"Label",text,13)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var callable := Callable(target,method)
	if not args.is_empty(): callable = callable.bindv(args)
	node.pressed.connect(callable,Object.CONNECT_PERSIST)
	return node

func panel(parent: Node, name_text: String, width: float) -> PanelContainer:
	var root := PanelContainer.new()
	root.theme = theme
	root.custom_minimum_size.x = width
	root.material = load("res://assets/ui/context_blur.tres")
	add(parent,root,name_text)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	add(root,content,"Content")
	return root

func layer(root: Node, value: int) -> void:
	if root is VisualInstance3D: root.layers = value
	if root is Light3D: root.light_cull_mask = value
	for child: Node in root.get_children(): layer(child,value)

func pack(root: Node, file: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(root)==OK)
	assert(ResourceSaver.save(packed,file)==OK)
	root.free()
	var saved: PackedScene = ResourceLoader.load(file,"",ResourceLoader.CACHE_MODE_REPLACE)
	var instance := saved.instantiate()
	main.add_child(instance)
	instance.owner = main

func build(_editor: EditorInterface, scene: Node3D) -> Dictionary:
	main = scene
	if main.has_node("VillageSeating") or main.has_node("VillageRace") or main.has_node("FocusCottage"):
		return {"error":"Authored leisure scenes already exist; edit them directly."}
	var seat := Node3D.new()
	seat.name = "VillageSeating"
	seat.set_script(load("res://scenes/village_seating.gd"))
	owner_root = seat
	var swings := add(seat,Node3D.new(),"Swings")
	for id: String in ["sunrise-meadow-swings","pasture-meadow-swings-2"]:
		var imported: Node3D = load("res://assets/rest/"+id+".glb").instantiate()
		var swing: Node3D = imported.get_child(0)
		imported.remove_child(swing); imported.free()
		add(swings,swing,id); own(swing)
		for index in 2:
			var pivot: Node3D = swing.get_node("Pivot%d"%index)
			pivot.get_child(2).name = "Carrier"
		var anchor := Marker3D.new(); anchor.position.y = 1.6
		add(swing,anchor,"ViewAnchor")
	var canvas := add(seat,CanvasLayer.new(),"UI")
	var card := panel(canvas,"Controls",320)
	var content := card.get_node("Content")
	label(content,"Title","Meadow swings",16)
	button(content,"Sit","Sit on the bench","E","interact",seat,"activate",[0])
	var row := add(content,HBoxContainer.new(),"Row")
	row.add_theme_constant_override("separation",8)
	button(row,"Action0","Left swing","E","interact",seat,"activate",[1])
	button(row,"Action1","Right swing","","",seat,"activate",[2])
	var extra := add(content,HBoxContainer.new(),"Extra")
	var brake := button(extra,"Brake","Brake","Space","jump",seat,"activate",[3]); brake.hold_action = true
	button(extra,"Off","Get off","Esc","release_mouse",seat,"activate",[4])
	button(content,"Stand","Stand up","Esc","release_mouse",seat,"activate",[4])
	button(content,"Feed","Scatter sourdough crumbs","F","talk",seat,"activate",[5])
	pack(seat,"res://scenes/seating.tscn")
	var race := Node3D.new(); race.name = "VillageRace"; owner_root = race
	race.set_script(load("res://scenes/village_race.gd"))
	var guide := add(race,Node3D.new(),"Guide")
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("f8edb5a8"); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.no_depth_test = false
	for side in [-1,1]:
		var post := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(.08,2.9,.08); mesh.material = mat; post.mesh = mesh; post.position = Vector3(side*4.2,1.45,0); add(guide,post,"Post%d"%side)
	var ribbon := MeshInstance3D.new(); var ribbon_mesh := BoxMesh.new(); ribbon_mesh.size = Vector3(8.4,.08,.08); ribbon_mesh.material = mat; ribbon.mesh = ribbon_mesh; ribbon.position.y = 2.9; add(guide,ribbon,"Ribbon")
	model(race,"res://assets/animals/horse-grey.glb","Rival")
	var rider := add(race,Node3D.new(),"Rider")
	var rowan: Node = main.get_node("Village/Actors/rowan")
	var pose := rowan.get_node("Pose").duplicate(0)
	add(rider,pose,"Pose"); own(pose); pose.position.y = 1.6
	var ui := add(race,CanvasLayer.new(),"UI")
	var hud := panel(ui,"Progress",300)
	hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hud.offset_left = 810; hud.offset_right = 1110; hud.offset_top = 24; hud.offset_bottom = 220
	var progress := hud.get_node("Content")
	label(progress,"Title","Race Rowan",16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(progress,"Clock","1:30",40).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(progress,"Statistics","0 / 8 flags · Lap 0.0s",12).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for who: String in ["You","Rowan"]:
		var r := add(progress,HBoxContainer.new(),who)
		label(r,"Label",who,12).custom_minimum_size.x = 50
		var bar := ProgressBar.new(); bar.max_value = 8; bar.show_percentage = false; bar.custom_minimum_size = Vector2(160,8); bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new(); fill.bg_color = Color("fff2d9"); fill.set_corner_radius_all(4)
		var background := StyleBoxFlat.new(); background.bg_color = Color("fff2d033"); background.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill",fill); bar.add_theme_stylebox_override("background",background)
		add(r,bar,"Bar")
	label(progress,"Gate","Next gate",12).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cancel := button(ui,"Cancel","Leave race","F","talk",race,"cancel")
	cancel.position = Vector2(1738,1008); cancel.size = Vector2(162,44)
	pack(race,"res://scenes/race.tscn")
	var cottage := Node3D.new(); cottage.name = "FocusCottage"; cottage.position.x = 1000; owner_root = cottage
	cottage.set_script(load("res://scenes/focus_cottage.gd"))
	var room := model(cottage,"res://assets/rest/focus-room.glb","Room")
	var desk := model(cottage,"res://assets/rest/focus-desk.glb","Desk")
	for name_text: String in ["Hourglass","Quill"]:
		var piece: Node3D = desk.find_child(name_text,true,false)
		var transform: Transform3D = desk.get_child(0).transform*piece.transform
		piece.get_parent().remove_child(piece); desk.add_child(piece); piece.transform = transform; piece.owner = cottage; own(piece)
	layer(room,4); layer(desk,4)
	var cat := add(cottage,Node3D.new(),"Cat"); cat.set_script(load("res://scenes/cottage_cat.gd"))
	model(cat,"res://assets/rest/cat.glb","Model")
	var speech := Label3D.new(); speech.font = title_font; speech.font_size = 28; speech.pixel_size = .007; speech.modulate = Color("453426"); speech.outline_size = 8; speech.outline_modulate = Color("fff4e6"); speech.position = Vector3(0,.85,0); speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add(cat,speech,"Speech"); layer(cat,4)
	var flame := MeshInstance3D.new(); flame.mesh = load("res://assets/village/meshes/surface_79.0_7.0.res"); flame.position = Vector3(2.7,.82,-3.38); flame.layers = 4; add(cottage,flame,"Flame")
	var firelight := OmniLight3D.new(); firelight.position = Vector3(2.7,2,-2.8); firelight.light_color = Color("ffb569"); firelight.light_energy = 1.5; firelight.omni_range = 12; firelight.light_cull_mask = 4; firelight.shadow_enabled = true; add(cottage,firelight,"Firelight")
	var camera := Camera3D.new(); camera.cull_mask = 4; camera.fov = 52; camera.near = .1
	var environment := Environment.new(); environment.background_mode = Environment.BG_COLOR; environment.background_color = Color("e9dfcb"); environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_color = Color("e8d4b8"); environment.ambient_light_energy = .65; environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	camera.environment = environment; add(cottage,camera,"Camera")
	var viewport := SubViewport.new(); viewport.size = Vector2i(400,345); viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED; add(cottage,viewport,"Window")
	var window_camera := Camera3D.new(); window_camera.position = Vector3(1.6,4.2,10.5); window_camera.cull_mask = 1; window_camera.fov = 58; window_camera.current = true; add(viewport,window_camera,"Camera")
	var focus_ui := add(cottage,CanvasLayer.new(),"UI")
	var session := panel(focus_ui,"Session",320)
	var style: StyleBoxFlat = theme.get_stylebox("panel","PanelContainer").duplicate(); style.bg_color = Color("1a362bc7"); style.content_margin_left = 18; style.content_margin_right = 18; style.content_margin_top = 18; style.content_margin_bottom = 18
	session.add_theme_stylebox_override("panel",style)
	var sc := session.get_node("Content")
	label(sc,"Title","Focus",21,true)
	label(sc,"Clock","25:00",56,true)
	var intention_label := label(sc,"Intention","",12); intention_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var presets := add(sc,VBoxContainer.new(),"Presets")
	for index in 3:
		var lengths: Array = [[25,5],[50,10],[10,2]][index]
		button(presets,"Preset%d"%index,"%d min focus · %d rest"%lengths,str(index+1),"activity_%d"%(index+1),cottage,"set_duration",lengths)
	var actions := add(sc,HBoxContainer.new(),"Actions")
	button(actions,"Begin","Begin","Space","jump",cottage,"toggle_timer")
	button(actions,"Reset","Reset","R","unstuck",cottage,"reset_timer")
	button(sc,"Break","Take a break","B","bread",cottage,"take_break")
	button(sc,"Options","Session settings","","",cottage,"toggle_options")
	var fields := add(sc,VBoxContainer.new(),"Fields")
	label(fields,"MinutesLabel","Focus minutes",12)
	var minutes_input := SpinBox.new(); minutes_input.min_value = 1; minutes_input.max_value = 180; minutes_input.value = 25; add(fields,minutes_input,"Minutes"); minutes_input.value_changed.connect(Callable(cottage,"set_duration"),Object.CONNECT_PERSIST)
	label(fields,"IntentionLabel","Your intention",12)
	var intention_edit := LineEdit.new(); intention_edit.max_length = 100; intention_edit.placeholder_text = "What would you like to give time to?"; add(fields,intention_edit,"Intention"); intention_edit.text_changed.connect(Callable(cottage,"set_intention"),Object.CONNECT_PERSIST)
	var leave := button(focus_ui,"Leave","Back to village","Esc","release_mouse",cottage,"leave"); leave.position = Vector2(1590,1010); leave.size = Vector2(184,44)
	var enter := button(focus_ui,"Enter","Enter focus cottage","E","interact",cottage,"enter"); enter.position = Vector2(1600,1010); enter.size = Vector2(300,44)
	var pet := button(focus_ui,"Pet","Pet the cat","E","interact",cat,"pet"); pet.position = Vector2(1400,960); pet.size = Vector2(180,44)
	pack(cottage,"res://scenes/focus_cottage.tscn")
	EditorInterface.save_scene()
	return {"seats":7,"swings":2,"race":8,"focus":true}
