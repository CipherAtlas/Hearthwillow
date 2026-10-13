extends Node3D

@onready var world: Node = get_parent()
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var rig: Node3D = world.get_node("CameraRig")
@onready var surface: Node = world.get_node("WorldSurface")
@onready var menus: Control = world.get_node("HUD/Menus")
@onready var panel: Control = $UI/Controls
var benches: Array = []
var near_bench: Dictionary = {}
var near_swing: Node3D
var near_index := 0
var seated: Dictionary = {}
var seat_index := -1
var riding: Node3D
var swing_index := -1
var angles := {}
var speeds := {}
var scan_due := 0.0
var saved_view := Vector3.ZERO
var pulse_until := 0.0
var pulse := 0.0
var brake_until := 0.0
var pointer_start := Vector2.INF
var pointer_seat: Dictionary = {}
var picnic_basket_open := false
var facing_sign := 1.0
var facing_yaw := 0.0

func _ready() -> void:
	benches = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rest/rest-data.json")).benches
	for swing: Node3D in $Swings.get_children():
		for index in 2:
			var key := str(swing.name)+str(index)
			angles[key] = 0.0
			speeds[key] = 0.0

func occupied() -> bool:
	return not seated.is_empty() or riding != null

func owns_context() -> bool:
	return occupied() or not near_bench.is_empty() or near_swing != null

func seat_point(bench: Dictionary, index: int) -> Vector3:
	var count := int(bench.get("seatCount",2))
	var offset := (index-(count-1)/2.0)*float(bench.get("seatSpacing",.68)) if bench.has("seatCount") else (index*2-1)*float(bench.get("seatSpacing",.68))
	return Vector3(bench.x+cos(bench.facing)*offset,float(bench.seatHeight)-.62,bench.z-sin(bench.facing)*offset)

func scan() -> void:
	near_bench = {}
	near_swing = null
	if occupied() or player.mount or player.controls_blocked or player.activity_locked or world.get_node("FocusCottage").inside: return
	var point := Vector2(player.position.x,player.position.z)
	var best := 2.6
	for bench: Dictionary in benches:
		var gap := point.distance_to(Vector2(bench.x,bench.z))
		if gap < best and absf(player.position.y-(float(bench.seatHeight)-.7))<1.8:
			best = gap
			near_bench = bench
			seat_index = 0
			var distance := INF
			for index in int(bench.get("seatCount",2)):
				var candidate := seat_point(bench,index)
				var length := point.distance_squared_to(Vector2(candidate.x,candidate.z))
				if length < distance: distance = length; seat_index = index
	for swing: Node3D in $Swings.get_children():
		for index in 2:
			var candidate: Vector3 = swing.find_child("Pivot%d"%index,true,false).to_global(Vector3(0,-2.65,0))
			var gap := point.distance_to(Vector2(candidate.x,candidate.z))
			if gap < best and absf(candidate.y-player.position.y)<1.65:
				best = gap; near_swing = swing; near_index = index; near_bench = {}

func _process(delta: float) -> void:
	scan_due -= delta
	if scan_due <= 0:
		scan_due = .1
		scan()
	refresh_controls()

func _physics_process(delta: float) -> void:
	for swing: Node3D in $Swings.get_children():
		for index in 2:
			var key := str(swing.name)+str(index)
			var active := riding == swing and swing_index == index
			var direction := 0.0
			var braking := false
			if active and not player.controls_blocked:
				direction = Input.get_action_strength("move_forward")-Input.get_action_strength("move_back")
				if Time.get_ticks_msec()/1000.0<pulse_until: direction = pulse
				direction *= facing_sign
				braking = Input.is_action_pressed("jump") or Time.get_ticks_msec()/1000.0<brake_until
			var gravity := 9.81/(2.65*swing.scale.y)
			var angle: float = angles[key]
			var velocity: float = speeds[key]
			var damping := 4.2 if braking else .055 if active else .22
			velocity += (-gravity*sin(angle)+(0.0 if braking else direction)*1.65*cos(angle)-damping*velocity)*delta
			angle = clampf(angle+velocity*delta,-deg_to_rad(78),deg_to_rad(78))
			var limit := sqrt(maxf(0,2*(gravity*(1-cos(deg_to_rad(78)))-gravity*(1-cos(angle)))))
			velocity = clampf(velocity,-limit,limit)
			angles[key] = angle; speeds[key] = velocity
			var pivot: Node3D = swing.find_child("Pivot%d"%index,true,false)
			pivot.rotation.x = -angle
			pivot.get_node("Carrier").rotation.x = angle
			if active:
				player.position = pivot.to_global(Vector3(0,-2.65,0))-Vector3(0,.62,0)
				player.visual.rotation = Vector3(0,facing_yaw,0)
	if not seated.is_empty():
		player.position = seat_point(seated,seat_index)
	if occupied():
		player.velocity = Vector3.ZERO
		player.gait = "swing" if riding else "seated"
		player.visual.position = Vector3(0,.62,0)

func sit(id: String, index := -1) -> bool:
	scan()
	if occupied() or player.activity_locked or player.mount or player.controls_blocked: return false
	var bench: Dictionary = {}
	for candidate: Dictionary in benches:
		if candidate.id == id: bench = candidate; break
	if bench.is_empty() or Vector2(player.position.x-bench.x,player.position.z-bench.z).length()>4: return false
	var count := int(bench.get("seatCount",2))
	if index >= count or index < -1: return false
	seated = bench
	seat_index = seat_index if index == -1 else index
	facing_sign = approach_facing(seat_point(bench,seat_index),float(bench.facing)) if str(bench.id).begins_with("picnic") else 1.0
	facing_yaw = float(bench.facing)+(PI if facing_sign<0 else 0.0)
	lock_player()
	player.position = seat_point(bench,seat_index)
	player.visual.rotation = Vector3(0,facing_yaw,0)
	rig.desired_yaw = facing_yaw
	rig.desired_pitch = .4
	rig.distance = 3
	player.reset_physics_interpolation()
	return true

func ride(swing: Node3D, index: int) -> bool:
	if occupied() or player.activity_locked or player.mount or player.controls_blocked or index not in [0,1]: return false
	var point: Vector3 = swing.find_child("Pivot%d"%index,true,false).to_global(Vector3(0,-2.65,0))
	if player.position.distance_to(point)>2.9: return false
	facing_sign = approach_facing(point,swing.rotation.y)
	facing_yaw = swing.rotation.y+(PI if facing_sign<0 else 0.0)
	riding = swing; swing_index = index
	lock_player()
	rig.follow_anchor = swing.get_node("ViewAnchor")
	rig.desired_yaw = facing_yaw+1.1; rig.desired_pitch = .45; rig.distance = 7.3
	player.reset_physics_interpolation()
	return true

func approach_facing(point: Vector3, base_yaw: float) -> float:
	# Face into the seat from the side the visitor walked up to.
	var approach := Vector2(point.x-player.position.x,point.z-player.position.z)
	return -1.0 if approach.dot(Vector2(sin(base_yaw),cos(base_yaw)))<-.1 else 1.0

func can_turn() -> bool:
	return riding!=null or str(seated.get("id","")).begins_with("picnic")

func turn_around() -> bool:
	if not can_turn() or player.controls_blocked: return false
	facing_sign *= -1
	facing_yaw += PI
	player.visual.rotation.y = facing_yaw
	rig.desired_yaw = facing_yaw+(1.1 if riding else 0.0)
	pulse_until = 0
	for button: Node in panel.find_children("*","Button",true,false):
		if button.has_method("end_hold"): button.end_hold()
	player.reset_physics_interpolation()
	panel.get_node("Content/TurnAround").flash()
	refresh_controls()
	return true

func lock_player() -> void:
	saved_view = Vector3(rig.desired_yaw,rig.desired_pitch,rig.distance)
	player.activity_locked = true
	player.velocity = Vector3.ZERO
	player.jump_buffer = 0
	world.get_node("VillageLife").tricks_open = false
	menus.sync_blocking()

func leave() -> bool:
	if not occupied(): return false
	var candidates: Array[Vector2] = []
	if riding:
		for distance: float in [3.3,-3.3,4.0,-4.0]:
			var point: Vector3 = riding.to_global(Vector3(-.98 if swing_index == 0 else .98,0,distance))
			candidates.append(Vector2(point.x,point.z))
	else:
		var point := seat_point(seated,seat_index)
		for distance: float in [1.35,1.8,-1.35]:
			candidates.append(Vector2(point.x+sin(seated.facing)*distance,point.z+cos(seated.facing)*distance))
	var target := Vector2(player.position.x,player.position.z)
	for candidate: Vector2 in candidates:
		if surface.can_enter(candidate) and surface.clear_at(candidate): target = candidate; break
	player.position = surface.recovery_spot(target)
	player.velocity = Vector3.ZERO
	player.activity_locked = false
	player.visual.rotation.x = 0
	riding = null; swing_index = -1; seated = {}; pulse_until = 0; brake_until = 0; picnic_basket_open = false
	rig.follow_anchor = null
	rig.desired_yaw = saved_view.x; rig.desired_pitch = saved_view.y; rig.distance = saved_view.z
	player.reset_physics_interpolation()
	for button: Node in panel.find_children("*","Button",true,false):
		if button.has_method("end_hold"): button.end_hold()
	menus.sync_blocking()
	scan(); refresh_controls()
	return true

func toggle_basket() -> void:
	picnic_basket_open = not picnic_basket_open
	world.get_node("VillageActivities").refresh_context()
	refresh_controls()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		pulse_until = 0; brake_until = 0; pointer_start = Vector2.INF
		for button: Node in panel.find_children("*","Button",true,false):
			if button.has_method("end_hold"): button.end_hold()

func _unhandled_input(event: InputEvent) -> void:
	if player.controls_blocked or occupied() or player.mount or world.get_node("FocusCottage").inside: return
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT: return
	if event.pressed:
		pointer_seat = seat_at(event.position)
		pointer_start = event.position
		if not pointer_seat.is_empty(): get_viewport().set_input_as_handled()
		return
	var selected := pointer_seat
	pointer_seat = {}
	var start := pointer_start
	pointer_start = Vector2.INF
	if selected.is_empty() or start.distance_to(event.position)>6: return
	if sit(selected.id,selected.index): get_viewport().set_input_as_handled()

func pick_seat(screen: Vector2) -> bool:
	var selected := seat_at(screen)
	return sit(selected.id,selected.index) if not selected.is_empty() else false

func seat_at(screen: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var best := INF
	var chosen: Dictionary = {}
	var index := -1
	for bench: Dictionary in benches:
		if Vector2(player.position.x-bench.x,player.position.z-bench.z).length()>4: continue
		if absf(player.position.y-(float(bench.seatHeight)-.7))>1.8: continue
		var seat_transform := Transform3D(Basis(Vector3.UP,float(bench.facing)),Vector3(bench.x,0,bench.z))
		var inverse := seat_transform.affine_inverse()
		var low := Vector3(bench.hitBox.min[0],bench.hitBox.min[1],bench.hitBox.min[2])
		var high := Vector3(bench.hitBox.max[0],bench.hitBox.max[1],bench.hitBox.max[2])
		var hit: Variant = AABB(low,high-low).intersects_ray(inverse*from,inverse.basis*direction)
		if hit==null: continue
		var point: Vector3 = seat_transform*hit
		var distance := point.distance_to(from)
		if distance>=best: continue
		best = distance; chosen = bench
		var nearest := INF
		for candidate in int(bench.get("seatCount",2)):
			var gap := seat_point(bench,candidate).distance_squared_to(point)
			if gap<nearest: nearest = gap; index = candidate
	return {"id":str(chosen.id),"index":index} if not chosen.is_empty() else {}

func words(en: String, ja: String) -> String:
	return menus.tr_pair(en,ja)

func refresh_controls() -> void:
	panel.visible = not player.controls_blocked and owns_context() and not world.get_node("FocusCottage").inside and not picnic_basket_open
	if not panel.visible: return
	var swinging := riding != null or near_swing != null
	panel.get_node("Content/Title").text = words("Meadow swings","草原のブランコ") if swinging else ""
	panel.get_node("Content/Title").visible = swinging
	var row: Control = panel.get_node("Content/Row")
	var extra: Control = panel.get_node("Content/Extra")
	row.visible = swinging and (riding != null or near_swing != null)
	extra.visible = riding != null
	var picnic := str(seated.get("id",near_bench.get("id",""))).begins_with("picnic")
	panel.get_node("Content/Sit").visible = not swinging and seated.is_empty()
	panel.get_node("Content/Sit/Row/Label").text = words("Sit on cushion %d","クッション%dに座る")%(seat_index+1) if picnic else words("Sit on the bench","ベンチに座る")
	panel.get_node("Content/TurnAround").visible = can_turn()
	panel.get_node("Content/TurnAround/Row/Label").text = words("Turn around","向きを変える")
	var turn_events := InputMap.action_get_events("turn_seat")
	panel.get_node("Content/TurnAround").set_key(OS.get_keycode_string(turn_events[0].physical_keycode))
	panel.get_node("Content/Basket").visible = picnic
	panel.get_node("Content/Basket/Row/Label").text = words("Share & eat","料理を分ける・食べる") if not seated.is_empty() else words("Open picnic basket","ピクニックかごを開く")
	panel.get_node("Content/Eat").visible = picnic and not seated.is_empty() and world.get_node("VillageActivities").dishes.any(func(d: Dictionary): return d.mat==seated.id)
	panel.get_node("Content/Stand").visible = not seated.is_empty()
	panel.get_node("Content/Feed").visible = not seated.is_empty() and seated.get("birdClearing",false)
	if swinging:
		for index in 2:
			var button: Button = row.get_node("Action%d"%index)
			button.hold_action = riding != null
			button.action = ("move_forward" if index == 0 else "move_back") if riding else "interact" if near_index == index else ""
			button.set_key(menus.key_name(button.action) if not button.action.is_empty() else "")
			button.get_node("Row/Key").visible = not button.action.is_empty()
			button.get_node("Row/Label").text = words("Forward","前へ") if riding and index == 0 else words("Back","後ろへ") if riding else words("Left swing","左のブランコ") if index == 0 else words("Right swing","右のブランコ")
	panel.size = Vector2(320,panel.get_combined_minimum_size().y)
	panel.position = get_viewport().get_visible_rect().size-panel.size-Vector2(20,22)

func activate(index: int) -> void:
	if player.controls_blocked: return
	match index:
		0: sit(str(near_bench.get("id","")))
		1,2:
			if riding: pulse = 1.0 if index == 1 else -1.0; pulse_until = Time.get_ticks_msec()/1000.0+.3
			elif near_swing: ride(near_swing,index-1)
		3: brake_until = Time.get_ticks_msec()/1000.0+.5
		4: leave()
		5: world.get_node("VillageFlock").feed()
		6: toggle_basket()
		7: world.get_node("VillageActivities").activate(4)

func _input(event: InputEvent) -> void:
	if event.is_echo() or player.controls_blocked or world.get_node("FocusCottage").inside: return
	if picnic_basket_open:
		if event.is_action_pressed("release_mouse") or event.is_action_pressed("talk"):
			if event.is_action_pressed("release_mouse"): rig.release_mouse()
			toggle_basket(); get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("talk") and str(seated.get("id",near_bench.get("id",""))).begins_with("picnic"):
		toggle_basket(); get_viewport().set_input_as_handled(); return
	if occupied():
		if event.is_action_pressed("turn_seat") and can_turn():
			turn_around(); get_viewport().set_input_as_handled(); return
		if event.is_action_pressed("release_mouse") or event.is_action_pressed("interact"):
			if event.is_action_pressed("release_mouse"): rig.release_mouse()
			if event.is_action_pressed("interact") and not seated.is_empty() and str(seated.id).begins_with("picnic"):
				world.get_node("VillageActivities").activate(4); get_viewport().set_input_as_handled(); return
			leave(); get_viewport().set_input_as_handled()
		elif not seated.is_empty() and seated.get("birdClearing",false) and event.is_action_pressed("talk"):
			world.get_node("VillageFlock").feed(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		scan()
		if near_swing: ride(near_swing,near_index); get_viewport().set_input_as_handled()
		elif not near_bench.is_empty():
			sit(str(near_bench.id)); get_viewport().set_input_as_handled()
