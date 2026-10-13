extends Node3D

@onready var world: Node = get_parent()
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var rig: Node3D = world.get_node("CameraRig")
@onready var menus: Control = world.get_node("HUD/Menus")
@onready var surface: Node = world.get_node("WorldSurface")
@onready var camera: Camera3D = $Camera
@onready var controls: PanelContainer = $UI/Session
var inside := false
var minutes := 25
var break_minutes := 5
var intention := ""
var remaining := 1500
var running := false
var done := false
var mode := "focus"
var deadline := 0.0
var return_position := Vector3.ZERO
var return_rotation := Vector3.ZERO
var return_view := Vector3.ZERO
var orbit := Vector2.ZERO
var applied_orbit := Vector2.ZERO
var next_tick := 0.0
var window_due := 0.0
var next_save := 0.0
var loading := false
var actors_processing: Dictionary = {}
var actors_visibility: Dictionary = {}
var controls_collapsed := false
var options_open := false
var steam: Array[MeshInstance3D] = []
var bridge_view := Vector3(-10.5339,1.05,3)
const SAVE := "user://focus-session.cfg"

func _ready() -> void:
	load_session()
	for item: Dictionary in surface.placements.get("bridge",[]):
		if item.id=="bridge": bridge_view = Vector3(item.position[0],item.position[1]+1.05,item.position[2])
	for node: Node in $Room.find_children("*steam*","MeshInstance3D",true,false):
		steam.append(node)
		var steam_material: StandardMaterial3D = node.get_active_material(0).duplicate()
		steam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		node.set_surface_override_material(0,steam_material)
	$Window.world_3d = get_viewport().world_3d
	$Window/Camera.look_at(bridge_view)
	$Room.hide(); $Desk.hide(); $Cat.hide(); $Flame.hide()
	$UI/Session.hide(); $UI/Leave.hide(); $UI/Enter.hide(); $UI/Pet.hide()
	var pane: MeshInstance3D = $Room.find_child("BridgeView",true,false)
	var material := pane.get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_texture = $Window.get_texture()
	material.uv1_scale.y = -1
	material.uv1_offset.y = 1
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pane.set_surface_override_material(0,material)
	refresh()

func now() -> float:
	return Time.get_unix_time_from_system()

func entry_point() -> Vector2:
	var map: Control = world.get_node("HUD/VillageMap")
	for landmark: Dictionary in map.landmarks:
		if landmark.id == "focus": return Vector2(landmark.point[0],landmark.point[1])
	return Vector2(5.1,11)

func enter() -> bool:
	if inside or player.controls_blocked or not menus.entered: return false
	if world.get_node("VillageSeating").occupied(): world.get_node("VillageSeating").leave()
	world.get_node("VillageRace").cancel()
	if player.mount: player.ride_or_dismount(player.mount)
	return_position = player.position; return_rotation = player.visual.rotation
	return_view = Vector3(rig.desired_yaw,rig.desired_pitch,rig.distance)
	inside = true; player.activity_locked = true
	player.position = global_position+Vector3(-1.4,.68-.62,-.7)
	player.visual.position = Vector3(0,.62,0)
	player.visual.rotation = Vector3(.07,PI,0)
	player.velocity = Vector3.ZERO; player.jump_buffer = 0
	player.reset_physics_interpolation()
	$Room.show(); $Desk.show(); $Cat.show(); $Flame.show()
	$Cat.active = true
	orbit = Vector2.ZERO; applied_orbit = Vector2.ZERO
	camera.position = Vector3(.3,2.9,3.45)
	camera.look_at(global_position+Vector3(-.15,1.2,-1.65))
	camera.make_current()
	rig.set_process(false)
	for actor: Node3D in world.get_node("Village/Actors").get_children():
		actors_processing[actor.name] = actor.is_physics_processing()
		actors_visibility[actor.name] = actor.visible
		actor.set_physics_process(false); actor.hide()
	for node: GeometryInstance3D in player.find_children("*","GeometryInstance3D",true,false): node.layers = 4
	world.get_node("HUD/Speech").hide()
	world.get_node("VillageLife").context.hide()
	world.get_node("VillageActivities").panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Window.render_target_update_mode = SubViewport.UPDATE_ONCE
	world.get_node("VillageSound").fire.position = global_position+Vector3(2.7,.82,-3.38)
	world.get_node("VillageSound").birds.stop()
	world.get_node("VillageSound").soundtrack_countdown = 0
	world.get_node("HUD/VillageMap").show()
	menus.sync_blocking()
	world.get_node("HUD/Wordmark").text = menus.tr_pair("Focus cottage","集中のコテージ")
	refresh()
	return true

func leave() -> void:
	if not inside: return
	inside = false; player.activity_locked = false
	player.position = surface.recovery_spot(Vector2(return_position.x,return_position.z))
	player.velocity = Vector3.ZERO; player.visual.rotation = return_rotation
	player.visual.position = Vector3(0,.62,0)
	player.reset_physics_interpolation()
	for node: GeometryInstance3D in player.find_children("*","GeometryInstance3D",true,false): node.layers = 1
	$Room.hide(); $Desk.hide(); $Cat.hide(); $Flame.hide(); $Cat.active = false
	for actor: Node3D in world.get_node("Village/Actors").get_children():
		actor.visible = actors_visibility.get(actor.name,true)
		actor.set_physics_process(actors_processing.get(actor.name,true))
	rig.desired_yaw = return_view.x; rig.desired_pitch = return_view.y; rig.distance = return_view.z
	rig.global_position = player.position+Vector3(0,1.35,0)
	rig.camera.make_current(); rig.set_process(true)
	world.get_node("VillageSound").fire.position = Vector3(-5.8,.8,-19)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menus.sync_blocking()
	world.get_node("HUD/Wordmark").text = "Hearthwillow"
	save_session(); refresh()

func _process(delta: float) -> void:
	next_tick -= delta
	if next_tick<=0:
		next_tick = .25
		if running:
			remaining = maxi(0,ceili(deadline-now()))
			if remaining==0:
				running = false; done = true; deadline = 0
				save_session()
				var sound: Node = world.get_node("VillageSound")
				if sound.enabled and sound.master_level>0 and sound.effects_level>0:
					$Chime.volume_db = linear_to_db(sound.master_level*sound.effects_level*.65)
					$Chime.play()
		refresh()
	if not inside: return
	var time := Time.get_ticks_msec()/1000.0
	for index in steam.size():
		var phase := fposmod(time*.42+index/3.0,1.0)
		steam[index].position.x = (index-1)*.055+sin(time*1.3+index*2.2)*.015
		steam[index].position.y = .265+phase*.18
		steam[index].scale = Vector3(1+phase*.28,.72+phase*.42,1+phase*.28)
		steam[index].get_active_material(0).albedo_color.a = .6*sin(PI*phase)
	applied_orbit = applied_orbit.lerp(orbit,1-exp(-12*delta))
	var look := Vector3(-.15,1.2,-1.65)
	var offset := Vector3(.45,1.7,5.1).rotated(Vector3.UP,applied_orbit.x)
	offset.y += applied_orbit.y*2.5
	var destination := look+offset
	destination = destination.clamp(Vector3(-3.5,.6,-3.45),Vector3(3.5,3.9,3.5))
	camera.position = camera.position.lerp(destination,1-exp(-7*delta))
	camera.look_at(global_position+look)
	window_due -= delta
	if window_due<=0:
		window_due = .2
		$Window/Camera.position = Vector3(1.6+clampf((camera.position.x-1.3)*.24,-.8,.8),4.2+clampf((camera.position.y-2.65)*.18,-.35,.35),10.5+clampf((camera.position.z-2.5)*.2,-.6,.6))
		$Window/Camera.look_at(bridge_view)
		$Window.render_target_update_mode = SubViewport.UPDATE_ONCE
	var progress := clampf(1-float(remaining)/((minutes if mode=="focus" else break_minutes)*60),0,1)
	$Desk/Hourglass/Top.scale.y = maxf(.03,1-progress)
	$Desk/Hourglass/Bottom.scale.y = maxf(.03,progress)
	$Desk/Hourglass/Stream.visible = running
	$Desk/Quill.rotation.z = sin(Time.get_ticks_msec()/1000.0*3)*.065 if running and not menus.auto_low else 0.0
	next_save -= delta
	if running and next_save<=0: next_save = 5; save_session()

func toggle_timer() -> void:
	if running:
		remaining = maxi(0,ceili(deadline-now())); deadline = 0; running = false
	else:
		if remaining<=0: remaining = (minutes if mode=="focus" else break_minutes)*60
		deadline = now()+remaining; running = true; done = false; options_open = false
	save_session(); refresh()

func reset_timer() -> void:
	deadline = 0; running = false; done = false
	remaining = (minutes if mode=="focus" else break_minutes)*60
	save_session(); refresh()

func set_duration(value: float, rest := -1) -> void:
	if loading: return
	minutes = clampi(int(value),1,180)
	if rest>=0: break_minutes = clampi(rest,1,60)
	if not running:
		remaining = minutes*60; mode = "focus"; done = false
	save_session(); refresh()

func take_break() -> void:
	mode = "break" if mode=="focus" else "focus"
	reset_timer()

func set_intention(value: String) -> void:
	if loading: return
	intention = value.left(100)
	save_session()

func toggle_controls() -> void:
	controls_collapsed = not controls_collapsed
	refresh()

func toggle_options() -> void:
	options_open = not options_open
	refresh()

func refresh() -> void:
	if not is_node_ready(): return
	var show_controls: bool = inside and not menus.is_open() and not world.get_node("HUD/VillageMap").expanded
	controls.visible = show_controls and not controls_collapsed
	$UI/Hide.visible = show_controls
	$UI/Hide.get_node("Row/Label").text = menus.tr_pair("Show controls","操作を表示") if controls_collapsed else menus.tr_pair("Hide controls","操作を隠す")
	$UI/Leave.visible = show_controls
	$UI/Pet.visible = show_controls and $Cat.state=="ask"
	$UI/Enter.visible = not inside and not player.mount and not player.activity_locked and not player.controls_blocked and Vector2(player.position.x,player.position.z).distance_to(entry_point())<3 and not world.get_node("VillageSeating").owns_context()
	if not inside: return
	loading = true
	var content: VBoxContainer = controls.get_node("Content")
	content.get_node("Title").text = menus.tr_pair("Session complete","セッション完了") if done else menus.tr_pair("Break","休憩") if mode=="break" else menus.tr_pair("Focus","集中")
	content.get_node("Clock").text = "%02d:%02d"%[floori(remaining/60.0),remaining%60]
	content.get_node("Clock").visible = not done
	content.get_node("Intention").text = intention
	content.get_node("Intention").visible = not intention.is_empty() and not done
	content.get_node("Presets").visible = not running and not done
	for index in 3:
		var preset: Array = [[25,5],[50,10],[10,2]][index]
		var button: Button = content.get_node("Presets/Preset%d"%index)
		button.get_node("Row/Label").text = menus.tr_pair("%d min focus · %d rest","%d 分集中 · %d 分休憩")%preset
		if minutes==preset[0] and break_minutes==preset[1]: button.add_theme_stylebox_override("normal",load("res://scenes/interaction_expanded.tres"))
		else: button.remove_theme_stylebox_override("normal")
	content.get_node("Actions/Begin/Row/Label").text = menus.tr_pair("Pause","一時停止") if running else menus.tr_pair("Begin again","もう一度始める") if done else menus.tr_pair("Begin","始める") if remaining==(minutes if mode=="focus" else break_minutes)*60 else menus.tr_pair("Resume","再開")
	content.get_node("Break").visible = done
	content.get_node("Break/Row/Label").text = menus.tr_pair("Take a break","休憩する") if mode=="focus" else menus.tr_pair("Back to focus","集中に戻る")
	content.get_node("Options").visible = not running
	content.get_node("Fields").visible = not running and options_open
	content.get_node("Fields/Minutes").value = minutes
	var intention_edit: LineEdit = content.get_node("Fields/Intention")
	if not intention_edit.has_focus(): intention_edit.text = intention
	loading = false
	controls.size = Vector2(320,controls.get_combined_minimum_size().y)
	controls.position = Vector2(get_viewport().get_visible_rect().size.x-340,get_viewport().get_visible_rect().size.y-78-controls.size.y)

func _input(event: InputEvent) -> void:
	if event.is_echo() or player.controls_blocked: return
	if not inside:
		if $UI/Enter.visible and event.is_action_pressed("interact"): enter(); get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		orbit.x -= event.screen_relative.x*rig.sensitivity
		orbit.y = clampf(orbit.y+event.screen_relative.y*rig.sensitivity,-.3,.3)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("release_mouse"):
		leave(); get_viewport().set_input_as_handled(); return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit or focused is SpinBox: return
	var handled := true
	if event.is_action_pressed("toggle_activity"): toggle_controls()
	elif event.is_action_pressed("jump"): toggle_timer()
	elif event.is_action_pressed("unstuck"): reset_timer()
	elif event.is_action_pressed("bread") and done: take_break()
	elif event.is_action_pressed("interact") and $Cat.state=="ask": $Cat.pet()
	elif not running and not done and event.is_action_pressed("activity_1"): set_duration(25,5)
	elif not running and not done and event.is_action_pressed("activity_2"): set_duration(50,10)
	elif not running and not done and event.is_action_pressed("activity_3"): set_duration(10,2)
	else: handled = false
	if handled: get_viewport().set_input_as_handled()

func save_session() -> void:
	var config := ConfigFile.new()
	for key: String in ["minutes","break_minutes","intention","remaining","running","done","mode","deadline"]: config.set_value("session",key,get(key))
	var error := config.save(SAVE+".tmp")
	if error==OK: error = DirAccess.rename_absolute(SAVE+".tmp",SAVE)
	if error!=OK: push_warning("Could not save focus session.")

func load_session() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE)!=OK: return
	var value: Variant = config.get_value("session","minutes",25)
	if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)): minutes = clampi(int(value),1,180)
	value = config.get_value("session","break_minutes",5)
	if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)): break_minutes = clampi(int(value),1,60)
	value = config.get_value("session","intention","")
	intention = value.left(100) if value is String else ""
	mode = "break" if config.get_value("session","mode","focus")=="break" else "focus"
	value = config.get_value("session","remaining",(minutes if mode=="focus" else break_minutes)*60)
	remaining = clampi(int(value),0,10800) if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) else minutes*60
	value = config.get_value("session","deadline",0)
	deadline = float(value) if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) else 0.0
	done = config.get_value("session","done",false)==true
	running = deadline>now()
	if running:
		deadline = minf(deadline,now()+10800)
		remaining = clampi(ceili(deadline-now()),0,10800)
	elif deadline>0: remaining = 0; done = true; deadline = 0
