extends Control

@onready var world: Node = get_parent().get_parent()
@onready var life: Node = world.get_node("VillageLife")
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var actors: Node = world.get_node("Village/Actors")
@onready var camera: Camera3D = world.get_node("CameraRig/Pitch/CameraBoom/Camera3D")
@onready var panels: Array[PanelContainer] = [$Resident0,$Resident1]
@onready var animal: PanelContainer = $Animal
var elapsed := 0.0
var messages: Dictionary = {}
var ambient_due: Dictionary = {}
var ambient_indices: Dictionary = {}
var slots: Array[CharacterBody3D] = [null,null]
var animal_actor: CharacterBody3D
var animal_point := Vector3.ZERO
var animal_until := 0.0
var animal_opacity := 0.0
var visibility_cache: Dictionary = {}
var sight_due := 0.0
var panel_states: Array[String] = ["",""]

func say(speaker: String, text: String, seconds: float) -> void:
	var actor: CharacterBody3D
	for candidate: CharacterBody3D in actors.get_children():
		if life.actor_name(candidate) == speaker:
			actor = candidate
			break
	if actor and actor.actor_kind == "resident":
		messages[actor.actor_id] = {"text":text,"until":elapsed+seconds}
		ambient_due[actor.actor_id] = elapsed+seconds+5+actors.get_children().find(actor)*1.3
	else:
		animal_actor = actor
		animal_point = actor.position+Vector3(0,1,0) if actor else Vector3(-37,1.8,4) if speaker == "White doves" else player.position+Vector3(0,1.8,0)
		var animal_text := animal.get_node("Content/Line") as Label
		animal_text.text = text
		animal_text.custom_minimum_size.x = minf(234,animal_text.get_theme_font("font").get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x)
		animal_until = elapsed+seconds

func activate(slot: int, action: String) -> void:
	if player.controls_blocked or world.get_node("FocusCottage").inside or player.activity_locked or not slots[slot] or life.nearest != slots[slot]: return
	if action == "Companion" and slots[slot].actor_id == "rowan":
		world.get_node("VillageRace").invite()
		return
	var event := InputEventAction.new()
	event.action = {"Talk":"talk","Companion":"companion","Bread":"bread"}[action]
	event.pressed = true
	life._unhandled_input(event)

func anchor(actor: CharacterBody3D) -> Vector3:
	var origin := actor.get_global_transform_interpolated().origin
	if actor.actor_kind == "resident": return origin+Vector3(0,2.12*actor.scale.y,0)
	return actor.bone_world("Head")+Vector3(0,.4 if actor.actor_kind == "cow" else .2,0)

func in_sight(id: String, point: Vector3) -> bool:
	if camera.is_position_behind(point): return false
	var screen := camera.unproject_position(point)
	if not Rect2(Vector2.ZERO,size).has_point(screen): return false
	if not visibility_cache.has(id):
		var query := PhysicsRayQueryParameters3D.create(camera.global_position,point,2)
		visibility_cache[id] = camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	return visibility_cache[id]

func place(panel: PanelContainer, point: Vector3, placed: Array[Rect2], relocate: bool) -> bool:
	var screen := camera.unproject_position(point)
	if screen.y < 24 or screen.y > size.y-24: return false
	var width := panel.size.x
	var height := panel.size.y
	var preferred := screen-Vector2(width*.5,height+14)
	var candidates: Array[Vector2] = [preferred]
	if relocate:
		candidates.append_array([Vector2(screen.x+20,preferred.y),Vector2(screen.x-width-20,preferred.y),Vector2(preferred.x,screen.y+18),preferred-Vector2(0,height+12)])
	var blocked: Array[Rect2] = []
	for path: String in ["HUD/Actions","HUD/VillageMap","HUD/Interaction","QuietPlaces/UI/Journal","QuietPlaces/UI/Kind","QuietPlaces/UI/Breathe"]:
		var control := world.get_node_or_null(path) as Control
		if control and control.visible: blocked.append(control.get_global_rect())
	if relocate:
		for rect: Rect2 in blocked+placed:
			if Rect2(preferred,panel.size).grow(8).intersects(rect):
				candidates.append_array([Vector2(rect.end.x+12,preferred.y),Vector2(rect.position.x-width-12,preferred.y),Vector2(preferred.x,rect.position.y-height-20),Vector2(preferred.x,rect.end.y+12)])
	for candidate: Vector2 in candidates:
		candidate.x = clampf(candidate.x,12,size.x-width-12)
		candidate.y = clampf(candidate.y,12,size.y-height-20)
		var rect := Rect2(candidate,panel.size+Vector2(0,8))
		var overlaps := false
		for other: Rect2 in blocked+placed:
			if rect.grow(8).intersects(other): overlaps = true; break
		if overlaps: continue
		panel.position = candidate
		var tail := panel.get_node_or_null("Tail") as Polygon2D
		if tail: tail.position = Vector2(clampf(screen.x-candidate.x,16,width-16),height)
		placed.append(rect)
		return true
	return false

func _process(delta: float) -> void:
	elapsed += delta
	camera = get_viewport().get_camera_3d()
	sight_due -= delta
	if sight_due <= 0:
		sight_due = .12
		visibility_cache.clear()
	for panel: PanelContainer in panels: panel.hide()
	animal.hide()
	if player.controls_blocked or world.get_node("FocusCottage").inside:
		animal_opacity = 0
		return
	var candidates: Array[CharacterBody3D] = []
	for actor: CharacterBody3D in actors.get_children():
		if actor.actor_kind != "resident" or player.position.distance_to(actor.position) >= 15: continue
		if not in_sight(actor.actor_id,anchor(actor)): continue
		if elapsed >= float(ambient_due.get(actor.actor_id,actors.get_children().find(actor)*2)):
			var lines: Array = actor.profile.get("ambient",[])
			if not lines.is_empty() and actor.chatting <= 0 and not actor.following:
				var index: int = ambient_indices.get(actor.actor_id,0)%lines.size()
				ambient_indices[actor.actor_id] = index+1
				messages[actor.actor_id] = {"text":life.localized(lines[index]),"until":elapsed+5}
				ambient_due[actor.actor_id] = elapsed+10+actors.get_children().find(actor)*1.3
		if actor == life.nearest or elapsed < float(messages.get(actor.actor_id,{}).get("until",0)): candidates.append(actor)
	candidates.sort_custom(func(a: CharacterBody3D,b: CharacterBody3D):
		if (a == life.nearest) != (b == life.nearest): return a == life.nearest
		if (a.chatting > 0) != (b.chatting > 0): return a.chatting > 0
		return player.position.distance_squared_to(a.position) < player.position.distance_squared_to(b.position))
	var placed: Array[Rect2] = []
	var slot := 0
	for actor: CharacterBody3D in candidates:
		if slot == 2: break
		var panel := panels[slot]
		var can_chat: bool = actor == life.nearest and player.position.distance_to(actor.position) < 4.5
		var active: bool = elapsed < float(messages.get(actor.actor_id,{}).get("until",0))
		var compact := can_chat and not active
		var state: String = str(world.get_node("HUD/Menus").language)+actor.actor_id+str(can_chat)+str(compact)+str(actor.following)+str(messages.get(actor.actor_id,{}).get("text",""))
		if state != panel_states[slot]:
			panel_states[slot] = state
			configure(panel,actor,can_chat,compact)
		slots[slot] = actor
		panel.visible = place(panel,anchor(actor),placed,can_chat)
		if panel.visible: slot += 1
	var pond: Node = world.get_node("PondLife")
	var pond_reply: Dictionary = pond.nearest_reply(camera,player.position)
	if not pond_reply.is_empty():
		animal_actor = null; animal_point = pond_reply.point; animal_until = elapsed+.12
		var label: Label = animal.get_node("Content/Line")
		label.text = pond_reply.text
		label.custom_minimum_size.x = minf(234,label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x)
	if elapsed < animal_until:
		var point := anchor(animal_actor) if is_instance_valid(animal_actor) else animal_point
		if player.position.distance_to(point) <= 10 and in_sight("animal",point):
			animal.size = animal.get_combined_minimum_size()
			animal.visible = place(animal,point,placed,true)
			animal_opacity = lerpf(animal_opacity,1.0,1-exp(-16*delta))
			animal.modulate.a = animal_opacity
	else: animal_opacity = 0


func configure(panel: PanelContainer, actor: CharacterBody3D, can_chat: bool, compact: bool) -> void:
	var text := panel.get_node("Content/Line") as Label
	text.text = str(messages.get(actor.actor_id,{}).get("text",life.localized(actor.profile.greeting)))
	text.visible = not compact
	var name_label := panel.get_node("Content/Footer/Name") as Label
	name_label.text = life.actor_name(actor)
	name_label.add_theme_color_override("font_color",Color(actor.profile.color))
	panel.get_node("Content/Footer/Talk").visible = can_chat
	panel.get_node("Content/Actions").visible = can_chat and not compact and actor.actor_id in ["pip","maple","moss","luma","wren","rowan"]
	panel.get_node("Content/Actions/Bread").visible = actor.actor_id in ["maple","wren"]
	panel.get_node("Content/Actions/Companion/Row/Label").text = "See you later" if actor.following else "Walk with me"
	panel.get_node("Content/Actions/Bread/Row/Label").text = "Ask for sourdough crumbs" if actor.actor_id == "wren" else "Ask for bread crumbs"
	var menus: Node = world.get_node("HUD/Menus")
	panel.get_node("Content/Footer/Talk/Row/Label").text = menus.tr_pair("Chat","話す")
	panel.get_node("Content/Actions/Companion/Row/Label").text = menus.tr_pair("Race me","競走しよう") if actor.actor_id == "rowan" else menus.tr_pair("See you later","またね") if actor.following else menus.tr_pair("Walk with me","一緒に散歩する")
	panel.get_node("Content/Actions/Bread/Row/Label").text = menus.tr_pair("Ask for sourdough crumbs","サワードウのパンくずをもらう") if actor.actor_id == "wren" else menus.tr_pair("Ask for bread crumbs","パンくずをもらう")
	panel.get_node("Content/Footer/Talk/Row/Key/Text").text = menus.key_name("talk")
	panel.get_node("Content/Actions/Companion/Row/Key/Text").text = menus.key_name("companion")
	panel.get_node("Content/Actions/Bread/Row/Key/Text").text = menus.key_name("bread")
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	style.content_margin_left = 12 if compact else 18
	style.content_margin_right = 7 if compact else 18
	style.content_margin_top = 4 if compact else 17
	style.content_margin_bottom = 4 if compact else 10
	panel.add_theme_stylebox_override("panel",style)
	panel.custom_minimum_size.x = 0 if compact else 290
	panel.get_node("Content/Footer").custom_minimum_size.y = 44 if compact else 54
	panel.size = panel.get_combined_minimum_size()
