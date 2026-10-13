@tool
extends EditorScript

func _run() -> void:
	var root := get_scene()
	var hud := root.get_node("HUD")
	var previous := hud.get_node("Speech")
	hud.remove_child(previous)
	previous.queue_free()
	var speech := Control.new()
	speech.name = "Speech"
	speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(speech)
	speech.owner = root
	speech.set_script(load("res://scenes/village_dialogue.gd"))
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia","Times New Roman"])
	var sans := FontVariation.new()
	sans.base_font = load("res://assets/fonts/Outfit.tres")
	sans.variation_opentype = {2003265652:400.0}
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo","monospace"])
	for i in 3:
		var animal := i == 2
		var panel := PanelContainer.new()
		panel.name = "Animal" if animal else "Resident"+str(i)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size.x = 0 if animal else 290
		var style := StyleBoxFlat.new()
		style.bg_color = Color("fff8ed") if animal else Color("293c33f7")
		style.border_color = Color("f6d6dc") if animal else Color("eadcbb52")
		style.set_border_width_all(1)
		style.set_corner_radius_all(20 if animal else 12)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 12 if animal else 17
		style.content_margin_bottom = 12 if animal else 10
		style.shadow_color = Color("253e3020") if animal else Color("17261f29")
		style.shadow_size = 14
		style.shadow_offset = Vector2(0,5 if animal else 4)
		panel.add_theme_stylebox_override("panel",style)
		speech.add_child(panel)
		panel.owner = root
		var column := VBoxContainer.new()
		column.name = "Content"
		column.add_theme_constant_override("separation",0)
		panel.add_child(column)
		column.owner = root
		var text := Label.new()
		text.name = "Line"
		text.custom_minimum_size.x = 234 if animal else 254
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if animal else HORIZONTAL_ALIGNMENT_LEFT
		text.add_theme_font_override("font",serif)
		text.add_theme_font_size_override("font_size",18)
		text.add_theme_color_override("font_color",Color("665058") if animal else Color("fff4dc"))
		text.add_theme_constant_override("line_spacing",4)
		column.add_child(text)
		text.owner = root
		if not animal:
			var footer := HBoxContainer.new()
			footer.name = "Footer"
			footer.custom_minimum_size.y = 54
			footer.alignment = BoxContainer.ALIGNMENT_END
			footer.add_theme_constant_override("separation",12)
			column.add_child(footer)
			footer.owner = root
			var name_label := Label.new()
			name_label.name = "Name"
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_font_override("font",sans)
			name_label.add_theme_font_size_override("font_size",14)
			footer.add_child(name_label)
			name_label.owner = root
			var actions := VBoxContainer.new()
			actions.name = "Actions"
			actions.add_theme_constant_override("separation",6)
			column.add_child(actions)
			actions.owner = root
			for action in ["Talk","Companion","Bread"]:
				var button := Button.new()
				button.name = action
				button.custom_minimum_size = Vector2(86,44)
				button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				var button_style := StyleBoxFlat.new()
				button_style.bg_color = Color("fff4dc12")
				button_style.border_color = Color("f5e8c88c")
				button_style.set_border_width_all(1)
				button_style.set_corner_radius_all(6 if action == "Talk" else 7)
				button_style.content_margin_left = 10
				button_style.content_margin_right = 10
				button.add_theme_stylebox_override("normal",button_style)
				var hover := button_style.duplicate()
				hover.bg_color = Color("fff4dc24")
				button.add_theme_stylebox_override("hover",hover)
				button.add_theme_stylebox_override("pressed",hover)
				var focus := button_style.duplicate()
				focus.bg_color = Color.TRANSPARENT
				focus.border_color = Color("fff4dc")
				focus.set_border_width_all(2)
				button.add_theme_stylebox_override("focus",focus)
				var parent: Node = footer if action == "Talk" else actions
				parent.add_child(button)
				button.owner = root
				var row := HBoxContainer.new()
				row.name = "Row"
				row.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				row.offset_left = 10
				row.offset_right = -10
				row.alignment = BoxContainer.ALIGNMENT_CENTER
				row.add_theme_constant_override("separation",10)
				button.add_child(row)
				row.owner = root
				var label := Label.new()
				label.name = "Label"
				label.text = "Chat" if action == "Talk" else "Walk with me" if action == "Companion" else "Ask for bread crumbs"
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				label.add_theme_font_override("font",sans)
				label.add_theme_font_size_override("font_size",13)
				label.add_theme_color_override("font_color",Color("fff4dc"))
				row.add_child(label)
				label.owner = root
				var key := PanelContainer.new()
				key.name = "Key"
				key.custom_minimum_size = Vector2(24,24)
				key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var key_style := StyleBoxFlat.new()
				key_style.bg_color = Color("fff4dc1f")
				key_style.border_color = Color("f5e8c8b3")
				key_style.set_border_width_all(1)
				key_style.set_corner_radius_all(4)
				key.add_theme_stylebox_override("panel",key_style)
				row.add_child(key)
				key.owner = root
				var key_text := Label.new()
				key_text.name = "Text"
				key_text.text = "F" if action == "Talk" else "C" if action == "Companion" else "B"
				key_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				key_text.add_theme_font_override("font",mono)
				key_text.add_theme_font_size_override("font_size",12)
				key_text.add_theme_color_override("font_color",Color("fff4dc"))
				key.add_child(key_text)
				key_text.owner = root
				button.pressed.connect(Callable(speech,"activate").bind(i,action),CONNECT_PERSIST)
			var tail := Polygon2D.new()
			tail.name = "Tail"
			tail.polygon = PackedVector2Array([Vector2(-5,0),Vector2(0,5),Vector2(5,0)])
			tail.color = Color("293c33")
			panel.add_child(tail)
			tail.owner = root
		panel.hide()
	get_editor_interface().save_scene()
