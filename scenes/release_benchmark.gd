extends Node

# Opt-in native-release measurement; ordinary play never runs this harness.
var enabled := false
var clock := 0.0
var last_tick: int
var stage := -1
var samples: Array[float] = []
var cpu_samples: Array[float] = []
var physics_samples: Array[float] = []
var draw_samples: Array[float] = []
var results: Array[Dictionary] = []
var duration := 30.0
var output := "user://benchmark.json"
var travelled := 0.0
var previous_position := Vector3.ZERO
var movement_action := ""
var cases := [
	{"name":"entrance day","point":Vector2(.3,20),"yaw":0.0,"weather":1},
	{"name":"village night","point":Vector2(10,-20),"yaw":.8,"weather":3},
	{"name":"western bridge day","point":Vector2(-19,11),"yaw":1.3,"weather":1},
	{"name":"pond day","point":Vector2(-16,-18),"yaw":1.2,"weather":1},
	{"name":"pond rain","point":Vector2(-16,-18),"yaw":1.2,"weather":4},
	{"name":"hill picnic day","point":Vector2(-96,-20),"yaw":1.2,"weather":1},
	{"name":"walking village day","point":Vector2(.3,20),"yaw":0.0,"weather":1,"move":"walk"},
	{"name":"walking village night","point":Vector2(.3,20),"yaw":0.0,"weather":3,"move":"walk"},
	{"name":"horse canter day","point":Vector2(83,37),"yaw":0.0,"weather":1,"move":"horse"},
	{"name":"horse canter night","point":Vector2(83,37),"yaw":0.0,"weather":3,"move":"horse"},
	{"name":"hearth night","place":"music","weather":3},
	{"name":"tea day","place":"mood","weather":1},
	{"name":"garden day","place":"garden","weather":1},
	{"name":"birds day","place":"birds","weather":1},
	{"name":"lookout night","place":"tower","weather":3},
	{"name":"cottage rain","place":"focus","weather":4}
]
@onready var world: Node3D = get_parent()

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	enabled = "--benchmark" in args
	for arg: String in args:
		if arg.begins_with("--benchmark-output="): output = arg.trim_prefix("--benchmark-output=")
		if arg.begins_with("--benchmark-seconds="): duration = maxf(5,float(arg.trim_prefix("--benchmark-seconds=")))
	set_process(false)
	if enabled:
		await world.ready
		var menus: Node = world.get_node("HUD/Menus")
		menus.enter_game(false)
		menus.graphics = 0; menus.reduced_motion = false; menus.language = 0
		menus.apply_graphics(); menus.apply_language()
		var sound: Node = world.get_node("VillageSound")
		if not sound.enabled: sound.toggle_sound()
		last_tick = Time.get_ticks_usec()
		change_stage()
		set_process(true)

func change_stage() -> void:
	Input.action_release("move_forward"); Input.action_release("move_back"); Input.action_release("dash")
	movement_action = ""
	stage += 1; clock = 0; travelled = 0
	samples.clear(); cpu_samples.clear(); physics_samples.clear(); draw_samples.clear()
	if stage == cases.size():
		finish(); return
	world.get_node("QuietPlaces").leave()
	world.get_node("TowerLookout").leave()
	world.get_node("FocusCottage").leave()
	var player: CharacterBody3D = world.get_node("Player")
	if player.mount: player.ride_or_dismount(player.mount)
	var config: Dictionary = cases[stage]
	var menus: Node = world.get_node("HUD/Menus")
	menus.weather = config.weather
	menus.weather_blend = Vector3(1,0,0) if config.weather==4 else Vector3(0,0,1) if config.weather==3 else Vector3.ZERO
	var point: Vector2 = config.get("point",Vector2(.3,20))
	world.get_node("HUD/VillageMap").travel_point(point)
	var rig: Node3D = world.get_node("CameraRig")
	rig.rotation.y = config.get("yaw",0.0); rig.desired_yaw = rig.rotation.y; rig.applied_yaw = rig.rotation.y
	rig.desired_pitch = .15; rig.distance = 5
	var place: String = config.get("place","")
	if place in ["music","mood","garden","birds"]:
		var quiet: Node = world.get_node("QuietPlaces")
		player.position = quiet.entry_point(place)
		if not quiet.enter(place): fail("Cannot enter "+place); return
	elif place=="focus":
		if not world.get_node("FocusCottage").enter(): fail("Cannot enter cottage"); return
	elif place=="tower":
		var tower: Node = world.get_node("TowerLookout")
		player.position = tower.get_node("Entrance").global_position
		tower.nearby = true
		if not tower.enter(): fail("Cannot enter lookout"); return
	if config.get("move","")=="horse":
		var horse: CharacterBody3D = world.get_node("Village/Actors/horse-juniper")
		horse.position = player.position; horse.rotation.y = 0
		player.ride_or_dismount(horse)
		if not player.mount: fail("Cannot mount benchmark horse"); return
	previous_position = player.position
	last_tick = Time.get_ticks_usec()
	print("BENCHMARK_STAGE ",config.name)

func _process(delta: float) -> void:
	if stage>=cases.size(): return
	var tick := Time.get_ticks_usec()
	var frame_ms: float = (tick-last_tick)/1000.0
	last_tick = tick; clock += delta
	var config: Dictionary = cases[stage]
	var player: CharacterBody3D = world.get_node("Player")
	var rig: Node3D = world.get_node("CameraRig")
	travelled += player.position.distance_to(previous_position); previous_position = player.position
	if config.has("move"):
		var action := "move_forward" if fmod(clock,10)<5 else "move_back"
		if action!=movement_action:
			if not movement_action.is_empty(): Input.action_release(movement_action)
			Input.action_press(action); movement_action = action
		if config.move=="horse": Input.action_press("dash")
	elif not config.has("place"):
		rig.desired_yaw += delta*.13
	if clock>5:
		samples.append(frame_ms)
		cpu_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		draw_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if clock>=duration+5:
		if samples.is_empty(): fail("No measured frames"); return
		var sorted := samples.duplicate(); sorted.sort()
		results.append({"view":config.name,"weather":config.weather,"frames":samples.size(),"fps":1000.0/average(samples),"average_ms":average(samples),"p95_ms":sorted[int((sorted.size()-1)*.95)],"p99_ms":sorted[int((sorted.size()-1)*.99)],"worst_ms":sorted.back(),"average_process_ms":average(cpu_samples),"average_physics_ms":average(physics_samples),"average_draw_calls":average(draw_samples),"travelled_metres":travelled,"movement_verified":not config.has("move") or travelled>5,"player_position":str(player.position),"camera_position":str(get_viewport().get_camera_3d().global_position)})
		change_stage()

func average(values: Array[float]) -> float:
	var total := 0.0
	for value in values: total += value
	return total/values.size()

func finish() -> void:
	set_process(false)
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"release":not OS.has_feature("debug"),"render_size":str(get_viewport().get_texture().get_size()),"vsync":DisplayServer.window_get_vsync_mode(),"graphics":"High, MSAA 4x, sun shadows enabled","sound_enabled":world.get_node("VillageSound").enabled,"reduced_motion":false,"warmup_seconds_each":5,"measured_seconds_each":duration,"scenarios":results}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if not file: fail("Cannot write benchmark report: "+str(FileAccess.get_open_error())); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("BENCHMARK ",JSON.stringify(report))
	get_tree().quit()

func fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
