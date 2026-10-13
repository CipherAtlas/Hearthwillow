extends Control

@onready var world: Node3D = get_parent().get_parent()
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var camera_rig: Node3D = world.get_node("CameraRig")
@onready var menus: Control = world.get_node("HUD/Menus")
@onready var cottage: Node3D = world.get_node("FocusCottage")
@onready var visitor: Control = $Visitor
@onready var terrain: Control = $Terrain
@onready var landscape: TextureRect = $Terrain/Landscape
@onready var surface: Node = world.get_node("WorldSurface")
@onready var large: Control = $Expanded
var expanded := false
var zoom := 2.0
var zoom_factor := 1.0
var center := Vector2.ZERO
var dragging := false
var last_point := Vector2(INF, INF)
var last_heading := INF
var last_language := -1
var last_key := ""
var markers: Array[Button] = []
var captions: Array[PanelContainer] = []
var icons: Array[Texture2D] = []
var marker_layout_dirty := true
var layout_dirty := false
var selected := "Focus cottage"
var selected_index := 0
var landmarks: Array = []
var bounds: Dictionary
var label_boxes: Array[Rect2] = []
const INK := Color("315646")

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/village/map-destinations.json"))
	bounds = data.bounds
	landmarks = data.destinations
	center = Vector2(bounds.x+bounds.width*.5,bounds.z+bounds.height*.5)
	for index in landmarks.size():
		markers.append(large.get_node("Markers/Marker%d" % index))
		captions.append(large.get_node("Markers/Label%d" % index))
		icons.append(markers[index].icon)
	mini_layout()
	mouse_filter = Control.MOUSE_FILTER_STOP
	select_destination(0)
	refresh_layout()

func mini_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -402; offset_right = -212
	offset_top = 28; offset_bottom = 178

func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	if layout_dirty: refresh_layout()
	var key: String = menus.key_name("toggle_map")
	if menus.language != last_language or key != last_key:
		last_language = menus.language
		last_key = key
		refresh_text()
		marker_layout_dirty = true
		queue_redraw()
	var point := visitor_point()
	if point.distance_squared_to(last_point)*zoom*zoom >= .25:
		last_point = point
		if not expanded: refresh_layout()
		visitor.queue_redraw()
	var heading: float = camera_rig.rotation.y
	if is_inf(last_heading) or absf(angle_difference(last_heading, heading)) > .015:
		last_heading = heading
		visitor.queue_redraw()
	if expanded and marker_layout_dirty: update_markers()

func refresh_text() -> void:
	selected = destination_name(selected_index)
	large.get_node("Title").text = menus.tr_pair("Hearthwillow", "ハースウィロー")
	large.get_node("Footer/Row/Selected").text = selected
	large.get_node("Footer/Row/Go").text = "↵   "+menus.tr_pair("Go here", "ここへ行く")+"   ↗"
	large.get_node("Close").text = menus.key_name("toggle_map")+" / Esc   "+menus.tr_pair("Back", "戻る")
	large.get_node("Help/Text").text = menus.tr_pair("◆ You   ·   Drag to pan   ·   Scroll to zoom", "◆ あなた   ·   ドラッグで移動   ·   スクロールでズーム")
	large.get_node("Navigation").text = menus.key_name("move_forward")+" / "+menus.key_name("move_left")+" / "+menus.key_name("move_back")+" / "+menus.key_name("move_right")+"   "+menus.tr_pair("Choose a place", "場所を選ぶ")
	large.get_node("Zoom/In").tooltip_text = menus.tr_pair("Zoom in", "拡大")
	large.get_node("Zoom/Out").tooltip_text = menus.tr_pair("Zoom out", "縮小")
	large.get_node("Zoom/Reset").text = menus.tr_pair("Fit village", "村全体")
	for index in landmarks.size():
		var text := destination_name(index)
		markers[index].tooltip_text = text
		captions[index].get_node("Text").text = text
		captions[index].reset_size()

func content_rect() -> Rect2:
	return Rect2(Vector2(24, 110), size-Vector2(48, 224)) if expanded else Rect2(Vector2(4, 4), size-Vector2(8, 40))

func request_layout() -> void:
	# Anchor presets emit intermediate sizes before their final offsets are applied.
	layout_dirty = true

func refresh_layout() -> void:
	if bounds.is_empty(): return
	layout_dirty = false
	update_zoom()
	terrain.position = content_rect().position
	terrain.size = content_rect().size
	landscape.position = map_point(Vector2(bounds.x, bounds.z))-terrain.position
	landscape.size = Vector2(bounds.width, bounds.height)*zoom
	marker_layout_dirty = true
	if expanded and size.x>48 and size.y>224: update_markers()
	queue_redraw()
	visitor.queue_redraw()

func clamp_center() -> void:
	var half := content_rect().size/zoom*.5
	var low := Vector2(bounds.x, bounds.z)+half
	var high := Vector2(bounds.x+bounds.width, bounds.z+bounds.height)-half
	var middle := Vector2(bounds.x+bounds.width*.5, bounds.z+bounds.height*.5)
	center.x = clampf(center.x, low.x, high.x) if low.x < high.x else middle.x
	center.y = clampf(center.y, low.y, high.y) if low.y < high.y else middle.y

func change_zoom(multiplier: float, anchor: Vector2) -> void:
	var before := (anchor-content_rect().get_center())/zoom+center
	zoom_factor = clampf(zoom_factor*multiplier, 1, 4)
	update_zoom()
	center = before-(anchor-content_rect().get_center())/zoom
	clamp_center()
	refresh_layout()

func zoom_in() -> void:
	change_zoom(1.2, content_rect().get_center())

func zoom_out() -> void:
	change_zoom(1.0/1.2, content_rect().get_center())

func reset_view() -> void:
	zoom_factor = 1
	center = Vector2(bounds.x+bounds.width*.5, bounds.z+bounds.height*.5)
	refresh_layout()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		toggle_map()
		get_viewport().set_input_as_handled()
	elif expanded and (event.is_action_pressed("release_mouse") or event.is_action_pressed("menu_back")):
		toggle_map()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not expanded or event.is_echo(): return
	var direction := Vector2.ZERO
	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"): direction.y = -1
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"): direction.y = 1
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"): direction.x = -1
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"): direction.x = 1
	if direction == Vector2.ZERO: return
	var origin := Vector2(landmarks[selected_index].point[0],landmarks[selected_index].point[1])
	var best := INF
	var next := selected_index
	for index in landmarks.size():
		if index == selected_index: continue
		var offset := Vector2(landmarks[index].point[0],landmarks[index].point[1])-origin
		if offset.dot(direction) <= .1: continue
		var score := offset.length()+absf(offset.cross(direction))*1.8
		if score < best: best = score; next = index
	select_destination(next)
	markers[next].grab_focus()
	get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not expanded:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			toggle_map(); accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			change_zoom(1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed and content_rect().has_point(event.position)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		center -= event.relative/zoom
		clamp_center()
		refresh_layout()
		accept_event()

func toggle_map() -> void:
	expanded = not expanded
	dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if expanded:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center = Vector2(bounds.x+bounds.width*.5,bounds.z+bounds.height*.5)
		zoom_factor = 1
		large.show()
		refresh_text()
		refresh_layout()
		markers[selected_index].grab_focus()
	else:
		large.hide()
		mini_layout()
	menus.sync_blocking()
	refresh_layout()

func update_zoom() -> void:
	zoom = minf(content_rect().size.x/float(bounds.width), content_rect().size.y/float(bounds.height))*zoom_factor if expanded else size.x/56.0

func visitor_point() -> Vector2:
	var point: Vector3 = cottage.return_position if cottage.inside else player.position
	return Vector2(point.x, point.z)

func map_point(point: Vector2) -> Vector2:
	var origin := center if expanded else visitor_point()
	return content_rect().get_center()+(point-origin)*zoom

func destination_name(index: int) -> String:
	var item: Dictionary = landmarks[index]
	return str(item.get("japanese",item.name)) if menus.language == 1 else str(item.name)

func select_destination(index: int) -> void:
	if markers.is_empty(): return
	if selected_index == index and markers[index].button_pressed: return
	markers[selected_index].button_pressed = false
	selected_index = index
	markers[index].button_pressed = true
	refresh_text()
	if expanded:
		var point := Vector2(landmarks[index].point[0], landmarks[index].point[1])
		if not content_rect().grow(-48).has_point(map_point(point)):
			center = point
			clamp_center()
			refresh_layout()
	marker_layout_dirty = true

func travel_selected() -> void:
	travel(selected_index)

func travel(index: int) -> void:
	var item: Dictionary = landmarks[index]
	var target: Array = item.get("arrival",item.point)
	if world.get_node("FocusCottage").inside: world.get_node("FocusCottage").leave()
	world.get_node("QuietPlaces").leave()
	travel_point(Vector2(target[0],target[1]))
	if item.id == "focus": world.get_node("FocusCottage").enter()
	elif item.id in ["gratitude","compliment","breathe","music","birds"]: world.get_node("QuietPlaces").enter(item.id)
	elif item.id == "garden": world.get_node("VillageActivities").open_garden()

func travel_point(point: Vector2) -> void:
	world.get_node("QuietPlaces").leave()
	world.get_node("TowerLookout").leave()
	world.get_node("VillageActivities").close_garden()
	var arrival: Vector3 = surface.recovery_spot(point)
	if not surface.can_enter(Vector2(arrival.x,arrival.z)): return
	world.get_node("VillageRace").cancel()
	if world.get_node("VillageSeating").occupied(): world.get_node("VillageSeating").leave()
	if world.get_node("FocusCottage").inside: world.get_node("FocusCottage").leave()
	if player.mount: player.ride_or_dismount(player.mount)
	player.position = arrival
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	camera_rig.global_position = arrival+Vector3(0,1.35,0)
	camera_rig.avoidance_yaw = 0
	camera_rig.desired_avoidance = 0
	camera_rig.visible_distance = camera_rig.distance
	camera_rig.reset_physics_interpolation()
	if expanded: toggle_map()

func update_markers() -> void:
	marker_layout_dirty = false
	label_boxes.clear()
	if size.x<=48 or size.y<=224: marker_layout_dirty = true; return
	var area := content_rect().grow(-8)
	for index in landmarks.size():
		var point := map_point(Vector2(landmarks[index].point[0], landmarks[index].point[1]))
		markers[index].position = point-Vector2(22,22)
		markers[index].visible = area.encloses(Rect2(markers[index].position, Vector2(44,44)))
		captions[index].visible = false
		if markers[index].visible: label_boxes.append(Rect2(markers[index].position, Vector2(44,44)))
	var order: Array[int] = [selected_index]
	for index in landmarks.size():
		if index != selected_index: order.append(index)
	for index in order:
		if not markers[index].visible: continue
		var point := markers[index].position+Vector2(22,22)
		var caption := captions[index]
		var width := caption.size.x
		var height := caption.size.y
		for offset: Vector2 in [Vector2(-width*.5,-height-29),Vector2(29,-height*.5),Vector2(-width-29,-height*.5),Vector2(-width*.5,29),Vector2(-width*.5,-height-61),Vector2(-width-29,-height-29),Vector2(29,-height-29)]:
			var rect := Rect2(point+offset,caption.size)
			var overlap := false
			for existing: Rect2 in label_boxes:
				if rect.grow(3).intersects(existing): overlap = true; break
			if overlap or not area.encloses(rect): continue
			caption.position = rect.position
			caption.visible = true
			label_boxes.append(rect)
			break
	large.get_node("Zoom/Out").disabled = zoom_factor <= 1
	large.get_node("Zoom/In").disabled = zoom_factor >= 4

func _draw() -> void:
	if bounds.is_empty(): return
	var font := get_theme_default_font()
	var area := content_rect()
	if expanded:
		draw_rect(Rect2(Vector2(18,104),size-Vector2(36,212)), Color("315646"), false, 1, true)
		draw_line(Vector2(28,88),Vector2(size.x-28,88),Color("31564655"),1,true)
		draw_string(font,Vector2(size.x-62,140),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,15,INK)
		var scale_start := Vector2(42,area.end.y-24)
		draw_line(scale_start,scale_start+Vector2(20*zoom,0),INK,2,true)
		draw_line(scale_start-Vector2(0,4),scale_start+Vector2(0,4),INK,2,true)
		draw_line(scale_start+Vector2(20*zoom,-4),scale_start+Vector2(20*zoom,4),INK,2,true)
		draw_string(font,scale_start-Vector2(0,10),"20 m",HORIZONTAL_ALIGNMENT_LEFT,-1,13,INK)
	else:
		for index in landmarks.size():
			var point := map_point(Vector2(landmarks[index].point[0],landmarks[index].point[1]))
			if not area.grow(-9).has_point(point): continue
			draw_circle(point,9,Color("fff9e9"))
			draw_texture_rect(icons[index],Rect2(point-Vector2(6,6),Vector2(12,12)),false,INK)
		draw_rect(Rect2(Vector2.ZERO,size),INK,false,2)
		draw_rect(Rect2(0,size.y-32,size.x,32),INK)
		draw_string(font,Vector2(12,size.y-12),last_key+"   "+menus.tr_pair("Map","地図"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff8e8"))
		draw_string(font,Vector2(size.x-24,size.y-12),"↗",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff8e8"))
		draw_string(font,Vector2(size.x-28,20),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,12,INK)

func draw_visitor(canvas: Control) -> void:
	var point := map_point(visitor_point())
	if not content_rect().grow(-14).has_point(point): return
	var radius := 10.0 if expanded else 5.0
	canvas.draw_circle(point,radius+4,Color("fff9e9"))
	canvas.draw_colored_polygon(PackedVector2Array([point+Vector2(0,-radius),point+Vector2(radius,0),point+Vector2(0,radius),point+Vector2(-radius,0)]),Color("b17b29"))
	var heading := Vector2(-sin(camera_rig.rotation.y),-cos(camera_rig.rotation.y))
	canvas.draw_line(point+heading*(radius+5),point+heading*(radius+11),Color("805817"),2,true)
