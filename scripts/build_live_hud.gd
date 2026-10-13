extends RefCounted

var root: Node
var sans: FontVariation
var serif: SystemFont

func attach(parent: Node, child: Node, title: String) -> Node:
	child.name = title
	parent.add_child(child)
	child.owner = root
	return child

func label(parent: Node, title: String, text: String, font_size := 12) -> Label:
	var node := Label.new()
	attach(parent,node,title)
	node.text = text
	node.add_theme_font_override("font",sans)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("ede5cf"))
	return node

func box(color: String, border: String, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func key(parent: Node, title: String, value: String) -> PanelContainer:
	var panel := PanelContainer.new()
	attach(parent,panel,title)
	panel.custom_minimum_size = Vector2(26,26)
	var style := box("fff2d01a","fff2d080",4)
	style.content_margin_left = 4; style.content_margin_right = 4
	panel.add_theme_stylebox_override("panel",style)
	var text := label(panel,"Text",value)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel

func button(parent: Node, title: String, text: String) -> Button:
	var node := Button.new()
	attach(parent,node,title)
	node.text = text
	node.custom_minimum_size = Vector2(80,44)
	node.add_theme_font_override("font",sans)
	node.add_theme_font_size_override("font_size",13)
	node.add_theme_stylebox_override("normal",box("17392bb8","fff2d059",12))
	node.add_theme_stylebox_override("hover",box("254b3ce0","fff2d099",12))
	node.add_theme_stylebox_override("focus",box("254b3ce0","fff2d0",12))
	return node

func build(editor: EditorInterface, scene: Node) -> String:
	root = scene
	sans = FontVariation.new()
	sans.base_font = load("res://assets/fonts/Outfit.tres")
	sans.variation_opentype = {2003265652:400.0}
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia","Hiragino Mincho ProN"])
	var hud := scene.get_node("HUD")
	var hints := scene.get_node("HUD/Hints") as PanelContainer
	for child: Node in hints.get_children():
		hints.remove_child(child); child.free()
	hints.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hints.position = Vector2(36,1024)
	hints.size = Vector2(780,26)
	var row := HBoxContainer.new()
	attach(hints,row,"Row")
	row.add_theme_constant_override("separation",14)
	for group: Array in [["Move","Move",["move_forward","move_left","move_back","move_right"],["W","A","S","D"]],["Run","Hold to run",["dash"],["Shift"]],["Interact","Interact",["interact"],["E"]],["Recover","Recover",["unstuck"],["R"]],["Focus","Focus next button",["focus"],["Tab"]]]:
		var section := HBoxContainer.new()
		attach(row,section,group[0])
		section.add_theme_constant_override("separation",4)
		for i in group[2].size(): key(section,group[2][i],group[3][i])
		label(section,"Caption",group[1])
	label(row,"Look","Click to look · Esc to release")
	var actions := scene.get_node("HUD/Actions") as Control
	actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	actions.offset_left = -204; actions.offset_right = -36
	actions.offset_top = 28; actions.offset_bottom = 72
	var buttons := actions.get_node("Buttons") as HBoxContainer
	buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buttons.add_theme_constant_override("separation",8)
	buttons.get_node("Sound").hide()
	buttons.get_node("Map").hide()
	var settings := buttons.get_node("Settings") as Button
	settings.custom_minimum_size = Vector2(80,44)
	settings.text = ""
	for kind: String in ["normal","hover","focus"]:
		settings.add_theme_stylebox_override(kind,box("17392bb8" if kind == "normal" else "254b3ce0","fff2d059" if kind == "normal" else "fff2d099",12))
	var inventory := button(buttons,"Inventory","")
	buttons.move_child(inventory,2)
	for pair: Array in [[settings,"GearSix",",","toggle_settings"],[inventory,"Basket","I","toggle_inventory"]]:
		var content := HBoxContainer.new()
		attach(pair[0],content,"Content")
		content.position = Vector2(12,8)
		content.size = Vector2(56,28)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation",8)
		key(content,"Key",pair[2])
		var icon := TextureRect.new()
		attach(content,icon,"Icon")
		icon.texture = load("res://assets/ui/"+pair[1]+".svg")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(20,20)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory.connect("pressed",Callable(scene.get_node("HUD/Menus"),"open_inventory"),CONNECT_PERSIST)
	var wordmark := button(hud,"Wordmark","Hearthwillow")
	wordmark.position = Vector2(36,28)
	wordmark.add_theme_font_override("font",serif)
	wordmark.add_theme_font_size_override("font_size",36)
	for kind: String in ["normal","hover","pressed","focus"]: wordmark.add_theme_stylebox_override(kind,StyleBoxEmpty.new())
	wordmark.connect("pressed",Callable(scene.get_node("HUD/Menus"),"close_menu"),CONNECT_PERSIST)
	var map := scene.get_node("HUD/VillageMap") as Control
	map.theme = scene.get_node("HUD/Menus").theme
	map.clip_contents = true
	map.z_index = 20
	var large := Control.new()
	attach(map,large,"Expanded")
	large.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	large.mouse_filter = Control.MOUSE_FILTER_IGNORE
	large.hide()
	var title := label(large,"Title","Hearthwillow",30)
	title.position = Vector2(28,24)
	title.add_theme_font_override("font",serif)
	title.add_theme_color_override("font_color",Color("315646"))
	var close := button(large,"Close","Esc   Back   ⌫   ×")
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -190; close.offset_top = 18; close.offset_right = -24; close.offset_bottom = 62
	close.connect("pressed",Callable(map,"toggle_map"),CONNECT_PERSIST)
	var markers := Control.new()
	attach(large,markers,"Markers")
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/village/map-destinations.json"))
	for i in data.destinations.size():
		var item: Dictionary = data.destinations[i]
		var marker := button(markers,"Marker%d"%i,"")
		marker.custom_minimum_size = Vector2(44,44)
		marker.size = Vector2(44,44)
		marker.icon = load("res://assets/ui/"+str(item.icon)+".svg")
		marker.add_theme_constant_override("icon_max_width",22)
		marker.add_theme_color_override("icon_normal_color",Color("315646"))
		marker.add_theme_stylebox_override("normal",box("f4f0dfe8","f9f3dc",22))
		marker.add_theme_stylebox_override("hover",box("315646","fff5d8",22))
		marker.add_theme_stylebox_override("focus",box("315646","fff5d8",22))
		marker.connect("pressed",Callable(map,"travel").bind(i),CONNECT_PERSIST)
		marker.connect("focus_entered",Callable(map,"select_destination").bind(i),CONNECT_PERSIST)
		marker.connect("mouse_entered",Callable(map,"select_destination").bind(i),CONNECT_PERSIST)
		var caption := PanelContainer.new()
		attach(markers,caption,"Label%d"%i)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := box("fff9e9f2","fff9e9",5)
		style.content_margin_left = 8; style.content_margin_right = 8
		style.content_margin_top = 3; style.content_margin_bottom = 3
		caption.add_theme_stylebox_override("panel",style)
		var text := label(caption,"Text",item.name,13)
		text.add_theme_color_override("font_color",Color("244c39"))
	var footer := PanelContainer.new()
	attach(large,footer,"Footer")
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(28,986)
	footer.size = Vector2(336,70)
	var footer_style := box("17392bdb","fff2d059",12)
	footer_style.content_margin_left = 18; footer_style.content_margin_right = 14
	footer_style.content_margin_top = 12; footer_style.content_margin_bottom = 12
	footer.add_theme_stylebox_override("panel",footer_style)
	var footer_row := HBoxContainer.new()
	attach(footer,footer_row,"Row")
	footer_row.add_theme_constant_override("separation",24)
	var selected := label(footer_row,"Selected","Focus cottage",23)
	selected.add_theme_font_override("font",serif)
	var go := button(footer_row,"Go","↵   Go here   ↗")
	go.connect("pressed",Callable(map,"travel_selected"),CONNECT_PERSIST)
	var help := PanelContainer.new()
	attach(large,help,"Help")
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	help.offset_left = -540; help.offset_right = -28
	help.offset_top = -70; help.offset_bottom = -24
	var help_style := box("17392bc9","fff2d059",8)
	help_style.content_margin_left = 12; help_style.content_margin_right = 12
	help_style.content_margin_top = 10; help_style.content_margin_bottom = 10
	help.add_theme_stylebox_override("panel",help_style)
	label(help,"Text","◆ You     ● Residents     W A S D  Choose a place     M  Close map")
	editor.save_scene()
	return "Saved the live site's HUD structure and 17 map destinations."
