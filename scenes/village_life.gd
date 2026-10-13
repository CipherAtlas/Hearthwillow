extends Node

@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var surface: Node = get_parent().get_node("WorldSurface")
@onready var actors: Node3D = get_parent().get_node("Village/Actors")
@onready var context: PanelContainer = get_parent().get_node("HUD/Interaction")
@onready var speech: Control = get_parent().get_node("HUD/Speech")
@onready var sound: Node = get_parent().get_node("VillageSound")

var navigation := AStarGrid2D.new()
var nav_meta: Dictionary
var nearest: CharacterBody3D
var talk_indices: Dictionary = {}
var greeted: Dictionary = {}
var scan_time := 0.0
var apples := 0
var owl_treats := 0
var crumbs := 0
var forage_cooldowns: Dictionary = {}
var nearby_object: Dictionary = {}
var nearby_tree: Dictionary = {}
var planned_frame := -1
var tricks_open := false
var controls_dog := ""
var context_slots := 0
var companion_single_file := false
var companion_open_time := 0.0
var companion_trail: PackedVector2Array = []
var companion_followers: Array[Node] = []

func _ready() -> void:
	nav_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/village/navigation.json"))
	navigation.region = Rect2i(0,0,nav_meta.width,nav_meta.height)
	navigation.cell_size = Vector2.ONE*float(nav_meta.step)
	navigation.offset = Vector2(nav_meta.min[0],nav_meta.min[1])
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	var cells := FileAccess.get_file_as_bytes("res://assets/village/navigation.bin")
	for z in int(nav_meta.height):
		for x in int(nav_meta.width):
			if cells[z*int(nav_meta.width)+x] == 0: navigation.set_point_solid(Vector2i(x,z))
	context.hide()
	context.get_node("Text").hide()
	speech.hide()

func line_clear(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(1,ceili(from.distance_to(to)/.25))
	for i in range(1,steps+1):
		var point := from.lerp(to,float(i)/steps)
		var cell := Vector2i(((point-navigation.offset)/navigation.cell_size).round())
		if navigation.is_in_boundsv(cell):
			if navigation.is_point_solid(cell): return false
		elif not surface.clear_at(point): return false
	return true

func closest_cell(point: Vector2) -> Vector2i:
	var center: Vector2i = Vector2i(((point-navigation.offset)/navigation.cell_size).round())
	if navigation.is_in_boundsv(center) and not navigation.is_point_solid(center):
		return center
	var best := Vector2i(-1,-1)
	var distance := INF
	for z in range(-3,4):
		for x in range(-3,4):
			var cell := center+Vector2i(x,z)
			if not navigation.is_in_boundsv(cell) or navigation.is_point_solid(cell): continue
			var candidate := navigation.get_point_position(cell)
			var gap := point.distance_squared_to(candidate)
			if gap < distance and line_clear(point,candidate): best = cell; distance = gap
	return best

func path_to(from: Vector2, to: Vector2) -> PackedVector2Array:
	if line_clear(from,to): return PackedVector2Array([to])
	var start := closest_cell(from)
	var end := closest_cell(to)
	if start.x < 0 or end.x < 0: return []
	var raw := navigation.get_point_path(start,end)
	var result: PackedVector2Array = []
	var origin := from
	var index := 0
	while index < raw.size():
		var far := index
		var candidate := mini(index+32,raw.size()-1)
		while candidate > index:
			if line_clear(origin,raw[candidate]): far = candidate; break
			candidate = index+floori((candidate-index)/2.0)
		result.append(raw[far]); origin = raw[far]; index = far+1
	if not result.is_empty() and line_clear(result[-1],to): result.append(to)
	return result

func move_actor(actor: CharacterBody3D, delta: float) -> void:
	var places: Node = get_parent().get_node("QuietPlaces")
	if actor.actor_kind=="resident" and places.participant_returns.has(actor.actor_id) and not places.active.is_empty():
		var participants: Array = places.participant_returns.keys()
		var slot := 3 if places.active=="mood" and actor.actor_id=="luma" else participants.find(actor.actor_id)
		var slots: Array = places.companion_stages[places.active]
		var location: Array = slots[mini(slot,slots.size()-1)]
		actor.position = places.placed_point(places.active,Vector3(location[0],location[1],location[2]))
		actor.velocity = Vector3.ZERO
		var look: Vector3 = places.player.position if places.active=="mood" and actor.actor_id=="luma" else places.base_look
		actor.rotation.y = atan2(look.x-actor.position.x,look.z-actor.position.z)
		return
	var point := Vector2(actor.position.x,actor.position.z)
	var player_point := Vector2(player.position.x,player.position.z)
	var target: Vector2 = actor.route[actor.waypoint]
	var moving: bool = actor.pause <= 0 and actor.chatting <= 0 and actor.action == "idle" and actor.actor_kind != "owl"
	var speed := 2.6*.43 if actor.actor_kind == "resident" else .65
	if actor.following:
		var followers: Array = actors.get_children().filter(func(other: Node): return other.following)
		var slot := followers.find(actor)
		var heading: float = player.visual.rotation.y
		var resident_slot := companion_followers.find(actor)
		var offset := Vector2((1 if slot%2 == 0 else -1)*(.8+floori(slot/2.0)*.35),-1.7-floori(slot/2.0)*.6).rotated(-heading)
		target = companion_target(resident_slot) if actor.actor_kind=="resident" and resident_slot>=0 else player_point+offset
		if actor.actor_kind=="resident" and point.distance_to(player_point)<2.5:
			var segment := target-point
			var along := clampf((player_point-point).dot(segment)/maxf(.001,segment.length_squared()),0,1)
			if (point+segment*along).distance_to(player_point)<.82:
				var from_angle := atan2(point.x-player_point.x,point.y-player_point.y)
				var to_angle := atan2(target.x-player_point.x,target.y-player_point.y)
				var around := from_angle+clampf(wrapf(to_angle-from_angle,-PI,PI),-.45,.45)
				target = player_point+Vector2(sin(around),cos(around))*1.05
		moving = moving and point.distance_to(target) > (.08 if actor.actor_kind=="resident" else .25)
		speed = minf(6,maxf(1.2,Vector2(player.velocity.x,player.velocity.z).length()+point.distance_to(target)))
	else:
		moving = moving and actor.route.size() > 1 and point.distance_to(player_point) > 1.2
		if point.distance_to(target) < .3:
			var pauses: Array = actor.profile.get("pauses",[])
			actor.pause = float(pauses[actor.waypoint]) if actor.waypoint < pauses.size() else 4.5 if actor.waypoint == 0 or actor.waypoint == floori(actor.route.size()/2.0) else 0.0
			actor.waypoint = (actor.waypoint+1)%actor.route.size()
			actor.path.clear()
	if moving and actor.replan <= 0 and (actor.following or actor.path.is_empty()) and planned_frame != Engine.get_physics_frames():
		planned_frame = Engine.get_physics_frames()
		actor.path = path_to(point,target)
		actor.replan = .55 if actor.following else 2.0
	if not actor.path.is_empty() and point.distance_to(actor.path[0]) < .18: actor.path.remove_at(0)
	var direction := Vector2.ZERO
	if moving and not actor.path.is_empty(): direction = point.direction_to(actor.path[0])
	var next := point+direction*speed*delta
	if direction != Vector2.ZERO and not surface.clear_at(next):
		direction = Vector2.ZERO
		actor.replan = 0
	actor.velocity.x = direction.x*speed
	actor.velocity.z = direction.y*speed
	if actor.actor_kind == "owl": actor.velocity.y = 0
	else: actor.velocity.y -= 12*delta
	if actor.actor_kind != "owl" and (direction != Vector2.ZERO or not actor.is_on_floor()): actor.move_and_slide()
	else: actor.velocity.y = 0
	actor.distance_walked += point.distance_to(Vector2(actor.position.x,actor.position.z))
	if direction.length_squared() > .01 or actor.chatting > 0 or actor.action == "pet":
		var look: Vector2 = player_point-point if actor.chatting > 0 or actor.action == "pet" else direction
		actor.rotation.y = lerp_angle(actor.rotation.y,atan2(look.x,look.y),1-exp(-delta*4))
	elif actor.actor_kind=="resident" and actor.following:
		actor.rotation.y = lerp_angle(actor.rotation.y,player.visual.rotation.y,1-exp(-delta*8))

func say(speaker: String, text: String, seconds := 6.0) -> void:
	speech.say(speaker,text,seconds)
	speech.show()

func _process(delta: float) -> void:
	context.size = Vector2(320,context.get_combined_minimum_size().y)
	context.position = get_viewport().get_visible_rect().size-context.size-Vector2(20,22)
	var quiet_activity: String = get_parent().get_node("QuietPlaces").active
	speech.visible = not player.controls_blocked and (not player.activity_locked or quiet_activity in ["breathe","mood","birds"])
	if not quiet_activity.is_empty():
		context.hide(); return
	if player.controls_blocked or get_parent().get_node("TowerLookout").inside or get_parent().get_node("VillageSeating").owns_context() or get_parent().get_node("FocusCottage").inside:
		context.hide()
		speech.hide()
		return
	if get_parent().get_node("PondLife").can_feed_here():
		nearest = null
		context.hide()
		return
	scan_time -= delta
	if scan_time > 0: return
	scan_time = .12
	nearest = null
	var distance := 4.5
	var from := player.position+Vector3(0,1,0)
	for actor: CharacterBody3D in actors.get_children():
		var gap := player.position.distance_to(actor.position)
		if gap < distance:
			var query := PhysicsRayQueryParameters3D.create(from,actor.position+Vector3(0,1,0),2)
			if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
			nearest = actor; distance = gap
		if actor.actor_kind == "resident" and gap > 7: greeted.erase(actor.actor_id)
	if player.mount:
		context.get_node("Dog").hide()
		context.show()
		refresh_context_controls()
		return
	nearby_object = {}
	var near_flock := Vector2(player.position.x+37,player.position.z-4).length() < 7
	nearby_tree = {}
	for item: Dictionary in surface.placements.get("apple-tree",[]):
		if Vector2(player.position.x-item.position[0],player.position.z-item.position[2]).length() < 4:
			nearby_tree = item; break
	if nearest:
		var speaker: String = actor_name(nearest)
		if nearest.actor_kind == "resident":
			if distance < 2.5 and not greeted.has(nearest.actor_id):
				greeted[nearest.actor_id] = true
				nearest.chatting = 4
				say(speaker,localized(nearest.profile.greeting),5)
		context.visible = nearest.actor_kind != "resident"
	else:
		for item: Dictionary in surface.data.items:
			if item.asset not in ["apple-tree","owl-feeding-perch"]: continue
			var gap := Vector2(player.position.x-item.position[0],player.position.z-item.position[2]).length()
			if gap < 4:
				nearby_object = item
				context.show()
				break
		if nearby_object.is_empty(): context.hide()
	if not nearby_tree.is_empty() or near_flock: context.show()
	refresh_dog_controls()
	refresh_context_controls()

func refresh_dog_controls() -> void:
	var card := context.get_node("Dog") as Control
	var show_dog: bool = context.visible and nearest != null and nearest.actor_kind == "dog"
	card.visible = show_dog
	if not show_dog:
		tricks_open = false
		controls_dog = ""
		return
	if controls_dog != nearest.actor_id: tricks_open = false
	controls_dog = nearest.actor_id
	var menus: Node = get_parent().get_node("HUD/Menus")
	card.get_node("Heading/Info/Name").text = actor_name(nearest)
	card.get_node("Heading/Info/Status").text = menus.tr_pair("Walking with you","一緒にお散歩中") if nearest.following else menus.tr_pair({"puppy-mochi":"corgi","puppy-kiko":"Shiba Inu","puppy-biscuit":"beagle","puppy-cloud":"Samoyed"}.get(nearest.actor_id,"Little friend"),"小さなお友だち")
	card.get_node("Main/Walk/Row/Text").text = menus.tr_pair("Home","おうちへ") if nearest.following else menus.tr_pair("Walk","お散歩")
	card.get_node("Tricks").visible = tricks_open
	card.get_node("Divider").visible = tricks_open
	card.get_node("Heading/Close").visible = tricks_open
	var toggle := card.get_node("Main/Toggle") as Button
	if tricks_open: toggle.add_theme_stylebox_override("normal",load("res://scenes/interaction_expanded.tres"))
	else: toggle.remove_theme_stylebox_override("normal")
	card.get_node("Main/Toggle/Row/Caret").flip_v = tricks_open
	var followers := actors.get_children().filter(func(actor): return actor.actor_kind == "dog" and actor.following)
	card.get_node("Home").visible = not followers.is_empty()
	card.get_node("Home/Row/Text").text = menus.tr_pair("Send "+actor_name(followers[0])+" home" if followers.size()==1 else "Send all %d dogs home"%followers.size(),"犬たちを元の場所に戻す") if not followers.is_empty() else ""
	for pair: Array in [["Main/Pet","Pet","なでる"],["Main/Toggle","Tricks","芸"],["Tricks/Sit","Sit","おすわり"],["Tricks/Dance","Dance","ダンス"],["Tricks/Spin","Spin","まわって"],["Tricks/Bow","Bow","おじぎ"],["Tricks/Wave","Wave","おてて"],["Tricks/Roll","Roll over","ごろん"]]:
		card.get_node(pair[0]+"/Row/Text").text = menus.tr_pair(pair[1],pair[2])
	for button: Button in card.find_children("*","Button",true,false):
		if not button.has_node("Row"): continue
		var action: String = button.get_meta("action")
		button.set_key(menus.key_name(action))

func context_action(slot: int, label: String, action: String, held := false) -> void:
	context_slots = maxi(context_slots,slot+1)
	var button := context.get_node("Generic/Actions/Action%d"%slot) as Button
	button.show()
	button.action = action
	button.hold_action = held
	button.get_node("Row/Text").text = label
	button.set_key(get_parent().get_node("HUD/Menus").key_name(action))

func refresh_context_controls() -> void:
	var generic := context.get_node("Generic") as Control
	generic.visible = context.visible and (player.mount != null or not nearest or nearest.actor_kind != "dog")
	if not generic.visible: return
	context_slots = 0
	generic.get_node("Directions").visible = player.mount != null
	var title := generic.get_node("Title") as Label
	var menus: Node = get_parent().get_node("HUD/Menus")
	if player.mount:
		title.text = actor_name(player.mount)
		for button in generic.get_node("Directions").get_children(): button.set_key(menus.key_name(button.action))
		context_action(0,menus.tr_pair("Canter","駆け足"),"dash",true)
		context_action(1,menus.tr_pair("Brake","止まる"),"jump",true)
		context_action(2,menus.tr_pair("Dismount","降りる"),"interact")
		if get_parent().get_node("VillageRace").active(): context_action(3,menus.tr_pair("Leave race","レースをやめる"),"talk")
		hide_unused_context_actions()
		return
	var slot := 0
	title.text = actor_name(nearest) if nearest else menus.tr_pair("Apple tree","リンゴの木") if not nearby_tree.is_empty() else menus.tr_pair("White doves","白いハト") if Vector2(player.position.x+37,player.position.z-4).length()<7 else menus.tr_pair("Owl grove","フクロウの林")
	if nearest and nearest.actor_kind != "resident":
		context_action(slot,menus.tr_pair("Ride","乗る") if nearest.actor_kind == "horse" else menus.tr_pair("Pet","なでる"),"interact"); slot += 1
		var feed_label: String = menus.tr_pair("Feed a treat","おやつをあげる")+" · "+str(owl_treats) if nearest.actor_kind == "owl" else menus.tr_pair("Feed hay","干し草をあげる") if nearest.actor_kind == "horse" else menus.tr_pair("Feed an apple","リンゴをあげる")+" · "+str(apples)
		context_action(slot,feed_label,"talk"); slot += 1
		if nearest.actor_kind == "owl": context_action(slot,menus.tr_pair("Take owl treats","フクロウのおやつを取る"),"bread"); slot += 1
	elif not nearby_object.is_empty():
		context_action(slot,menus.tr_pair("Pick an apple","リンゴを摘む") if nearby_object.asset == "apple-tree" else menus.tr_pair("Take owl treats","フクロウのおやつを取る"),"interact"); slot += 1
	if not nearby_tree.is_empty(): context_action(slot,menus.tr_pair("Pick an apple","リンゴを摘む"),"bread"); slot += 1
	elif Vector2(player.position.x+37,player.position.z-4).length()<7:
		context_action(slot,menus.tr_pair("Scatter crumbs","パンくずをまく")+" · "+str(crumbs) if crumbs>0 else menus.tr_pair("Find Maple or Wren for crumbs","メープルかレンにパンくずをもらう"),"bread")

	hide_unused_context_actions()

func hide_unused_context_actions() -> void:
	for index in 8:
		if index >= context_slots: context.get_node("Generic/Actions/Action%d"%index).hide()

func activate_context_control(slot: int) -> void:
	if player.controls_blocked or player.activity_locked: return
	if player.mount and slot==3 and get_parent().get_node("VillageRace").active():
		get_parent().get_node("VillageRace").cancel(); return
	var button := context.get_node("Generic/Actions/Action%d"%slot) as Button
	if not button.is_visible_in_tree() or button.disabled or button.hold_action: return
	var event := InputEventAction.new()
	event.action = button.action
	event.pressed = true
	_unhandled_input(event)
	refresh_context_controls()

func activate_animal_control(action: String) -> void:
	if player.controls_blocked or not nearest or nearest.actor_kind != "dog": return
	if action == "puppy_tricks":
		tricks_open = not tricks_open
		refresh_dog_controls()
		return
	if action == "puppy_home":
		for actor: CharacterBody3D in actors.get_children():
			if actor.actor_kind == "dog" and actor.following:
				actor.following = false; actor.waypoint = 0; actor.pause = 0; actor.replan = 0; actor.path.clear()
		refresh_dog_controls()
		return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_unhandled_input(event)
	refresh_dog_controls()

func _input(event: InputEvent) -> void:
	if tricks_open and event.is_action_pressed("release_mouse"):
		tricks_open = false
		refresh_dog_controls()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()

func actor_name(actor: CharacterBody3D) -> String:
	var title: Variant = actor.profile.get("name",actor.actor_id)
	return localized(title) if title is Dictionary else str(title)

func localized(text: Dictionary) -> String:
	return str(text.get("ja",text.get("en",""))) if get_parent().get_node("HUD/Menus").language == 1 else str(text.get("en",""))

func _unhandled_input(event: InputEvent) -> void:
	if player.controls_blocked or player.activity_locked or get_parent().get_node("VillageSeating").owns_context() or event.is_echo(): return
	if nearest and nearest.actor_kind == "dog" and event.is_action_pressed("puppy_tricks"):
		activate_animal_control("puppy_tricks")
		get_viewport().set_input_as_handled()
		return
	if player.mount:
		if event.is_action_pressed("interact"): player.ride_or_dismount(player.mount)
		return
	if event.is_action_pressed("bread") and Vector2(player.position.x+37,player.position.z-4).length() < 7:
		if crumbs == 0 and nearest and nearest.actor_id in ["maple","wren"]:
			crumbs += 1; say(actor_name(nearest),"Here, some sourdough crumbs. Scatter a little and watch their wings!")
		elif not get_parent().get_node("VillageFlock").feed(): say("White doves","Ask Maple or Wren for crumbs." if crumbs == 0 else "They already have a meal waiting.",3)
	elif event.is_action_pressed("bread") and not nearby_tree.is_empty():
		pick_apple(nearby_tree)
	elif nearest and event.is_action_pressed("talk"):
		if nearest.actor_kind == "resident":
			var lines: Array = nearest.profile.chat
			var index: int = talk_indices.get(nearest.actor_id,0)%lines.size()
			talk_indices[nearest.actor_id] = index+1
			nearest.chatting = 6
			say(actor_name(nearest),localized(lines[index]))
			if nearest.actor_id == "wren": crumbs += 1
		else: feed(nearest)
		get_viewport().set_input_as_handled()
	elif nearest and event.is_action_pressed("companion") and nearest.actor_id in ["pip","maple","moss","luma","wren"]:
		nearest.following = not nearest.following
		nearest.pause = 0; nearest.chatting = 0; nearest.replan = 0; nearest.path.clear()
		if not nearest.following: resume_route(nearest)
		say(actor_name(nearest),"A little company? I'd love that." if nearest.following else "See you around. I'll be right here in the village.")
	elif nearest and event.is_action_pressed("puppy_follow") and nearest.actor_kind == "dog":
		nearest.following = not nearest.following; nearest.pause = 0; nearest.replan = 0; nearest.path.clear()
		if not nearest.following: resume_route(nearest)
		say(actor_name(nearest),"Woof~ (I’ll walk with you~)" if nearest.following else "Woof~ (See you soon~)")
	elif nearest and event.is_action_pressed("puppy_home") and nearest.actor_kind == "dog":
		activate_animal_control("puppy_home")
		say(actor_name(nearest),"Woof~ (Time to head home~)")
	elif nearest and event.is_action_pressed("bread") and nearest.actor_kind == "owl":
		owl_treats += 3
		say("Owl grove","Three little treats for the owls.",3)
	elif nearest and event.is_action_pressed("bread") and nearest.actor_id in ["maple","wren"]:
		crumbs += 1
		say(actor_name(nearest),localized(nearest.profile.chat[0]) if nearest.actor_id == "wren" else "For the little duckies! This little pouch always has a few more.")
	elif event.is_action_pressed("interact"):
		if nearest and nearest.actor_kind == "horse":
			player.ride_or_dismount(nearest)
		elif nearest and nearest.actor_kind != "resident" and nearest.action == "idle":
			nearest.start_action("pet",6)
			say(actor_name(nearest),animal_line(nearest.actor_kind,false))
			sound.animal_call(nearest.actor_kind,nearest.position,true,nearest.actor_id)
		elif not nearby_object.is_empty():
			if nearby_object.asset == "apple-tree":
				pick_apple(nearby_object)
			else:
				owl_treats += 3; say("Owl grove","Three little treats for the owls.",3)
		get_viewport().set_input_as_handled()
	elif nearest and nearest.actor_kind == "dog":
		for trick: String in ["sit","dance","spin","bow","wave","roll"]:
			if event.is_action_pressed("puppy_"+trick):
				nearest.start_action(trick,{"sit":7.0,"dance":5.2,"spin":3.2,"bow":3.8,"wave":4.2,"roll":4.6}[trick])
				say(actor_name(nearest),"Woof~ (Look what I can do~)",3)
				break

func resume_route(actor: CharacterBody3D) -> void:
	var point := Vector2(actor.position.x,actor.position.z)
	var closest := 0
	for i in actor.route.size():
		if point.distance_squared_to(actor.route[i]) < point.distance_squared_to(actor.route[closest]): closest = i
	actor.waypoint = closest

func pick_apple(item: Dictionary) -> void:
	var now := Time.get_ticks_msec()/1000.0
	if now >= float(forage_cooldowns.get(item.id,0)):
		apples += 1; forage_cooldowns[item.id] = now+60
		say("Apple tree","A ripe apple for a pasture friend. Apples: "+str(apples),3)
	else: say("Apple tree","Let this tree rest a little.",3)

func animal_line(kind: String, thanks: bool) -> String:
	var species_call: String = {"cow":"Moo moo~","sheep":"Meeeh mee~","lamb":"Baa baa~","hedgehog":"Snuffle snuffle~","owl":"Hoot hoot~","horse":"Neigh~","dog":"Woof woof~"}.get(kind,"Hello~")
	if kind == "hedgehog": return "Snuffle~ (Thank you~)" if thanks else "Snuffle snuffle~ (A little cuddle~)"
	if kind == "lamb" and not thanks: return "Baa baa~ (More cuddles~)"
	if kind == "owl": return "Hoot hoot~ (Thank you~)" if thanks else "Hoot hoot~"
	return species_call+(" (Thank you~)" if thanks else " (That feels lovely~)")

func feed(actor: CharacterBody3D) -> void:
	if actor.action != "idle": return
	if actor.actor_kind == "owl":
		if owl_treats == 0: say(actor_name(actor),"Find a little treat at the owl perch.",3); return
		owl_treats -= 1
	elif actor.actor_kind != "horse":
		if apples == 0: say(actor_name(actor),"Pick an apple from the village trees first.",3); return
		apples -= 1
	actor.start_action("eat",8)
	say(actor_name(actor),animal_line(actor.actor_kind,true))
	sound.animal_call(actor.actor_kind,actor.position,true,actor.actor_id)

func _physics_process(delta: float) -> void:
	companion_followers = actors.get_children().filter(func(actor: Node): return actor.actor_kind=="resident" and actor.following)
	if companion_followers.is_empty():
		companion_trail.clear(); companion_single_file = false; return
	var point := Vector2(player.position.x,player.position.z)
	if companion_trail.is_empty() or point.distance_to(companion_trail[0])>2:
		companion_trail = PackedVector2Array([point]); companion_single_file = false
	elif point.distance_to(companion_trail[0])>.1:
		companion_trail.insert(0,point)
		if companion_trail.size()>90: companion_trail.resize(90)
	var heading: float = player.visual.rotation.y
	var open := true
	for side: float in [-1.0,1.0]:
		for ahead: float in [0.0,.5,1.0]:
			var start := point+Vector2(sin(heading),cos(heading))*ahead
			if not line_clear(start,start+Vector2(cos(heading),-sin(heading))*side*1.12): open = false
	if not open: companion_single_file = true; companion_open_time = 0
	elif companion_single_file:
		companion_open_time += delta
		if companion_open_time>.8: companion_single_file = false
	pose_companion_hands()

func companion_target(slot: int) -> Vector2:
	var point := Vector2(player.position.x,player.position.z)
	var heading: float = player.visual.rotation.y
	if not companion_single_file:
		var side := (-1.0 if slot%2==0 else 1.0)*1.05 if slot<4 else 0.0
		return point+Vector2(cos(heading),-sin(heading))*side-Vector2(sin(heading),cos(heading))*floori(slot/2.0)*1.25
	var remaining := .85*(slot+1)
	for trail_point: Vector2 in companion_trail:
		var gap := point.distance_to(trail_point)
		if gap>=remaining: return point.move_toward(trail_point,remaining)
		remaining -= gap; point = trail_point
	var behind := point-Vector2(sin(heading),cos(heading))*remaining
	return behind if line_clear(point,behind) else point

func pose_companion_hands() -> void:
	if player.activity_locked or player.controls_blocked or player.mount or companion_single_file or not player.is_on_floor(): return
	for slot in mini(2,companion_followers.size()):
		var actor: Node3D = companion_followers[slot]
		var side := -1.0 if slot==0 else 1.0
		var offset: Vector3 = player.visual.to_local(actor.global_position)
		if absf(offset.x-side*1.05)>.14 or absf(offset.z)>.16 or cos(actor.rotation.y-player.visual.rotation.y)<.94: continue
		var a: Node3D = player.left_fin if slot==0 else player.right_fin
		var b: Node3D
		for fin: Node3D in actor.fin_nodes:
			if str(fin.get_meta("part","")).begins_with("SpiritFinR" if slot==0 else "SpiritFinL"): b = fin; break
		if not b: continue
		var meeting := (a.global_position+b.global_position)*.5+Vector3(0,.025,0)
		for pair: Array in [[a,side],[b,-side]]:
			var fin: Node3D = pair[0]
			var sign_value: float = pair[1]
			var shoulder := fin.position-Vector3(sign_value*.1,0,0)
			var end: Vector3 = fin.get_parent().to_local(meeting)
			var arm := end-shoulder
			if arm.length()>.39 or arm.length()<.001: continue
			fin.position = (shoulder+end)*.5
			fin.scale.x *= arm.length()/.27
			fin.quaternion = Quaternion(Vector3.RIGHT,arm.normalized()*sign_value)
