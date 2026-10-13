extends Node

# Opt-in native-release measurement; ordinary play never runs this harness.
var enabled := false
var clock := 0.0
var last_tick: int
var stage := -1
var samples: Array[float] = []
var results: Array[Dictionary] = []
var duration := 12.0
var output := "user://benchmark.json"
var viewpoints := [[.3,20.0,0.0],[10.0,-20.0,.8],[-19.0,11.0,1.3],[-16.0,-18.0,1.2],[-96.0,-20.0,1.2]]

@onready var world: Node3D = get_parent()

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	enabled = "--benchmark" in args
	for arg: String in args:
		if arg.begins_with("--benchmark-output="): output = arg.trim_prefix("--benchmark-output=")
		if arg.begins_with("--benchmark-seconds="): duration = float(arg.trim_prefix("--benchmark-seconds="))
	set_process(enabled)
	if enabled:
		world.get_node("HUD/Menus").enter_game(false)
		world.get_node("VillageSound").toggle_sound()
		last_tick = Time.get_ticks_usec()
		change_stage()

func change_stage() -> void:
	stage += 1
	clock = 0.0
	samples.clear()
	if stage == viewpoints.size():
		var report := {"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "release": not OS.has_feature("debug"), "render_size": str(get_viewport().get_texture().get_size()), "vsync": DisplayServer.window_get_vsync_mode(), "warmup_seconds_each": 3, "measured_seconds_each": duration, "scenarios": results}
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report,"\t"))
		print("BENCHMARK ",JSON.stringify(report))
		get_tree().quit()
		return
	var view: Array = viewpoints[stage]
	var player: CharacterBody3D = world.get_node("Player")
	player.position = Vector3(view[0],world.get_node("WorldSurface").floor_at(Vector2(view[0],view[1]))+.03,view[1])
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	world.get_node("CameraRig").rotation.y = view[2]
	world.get_node("CameraRig").position = player.position+Vector3(0,1.35,0)
	world.get_node("CameraRig").distance = 5.0

func _process(delta: float) -> void:
	var tick := Time.get_ticks_usec()
	var frame_ms: float = (tick-last_tick)/1000.0
	last_tick = tick
	clock += delta
	var rig: Node3D = world.get_node("CameraRig")
	rig.rotation.y += delta*.13
	if clock > 3.0: samples.append(frame_ms)
	if clock >= duration+3.0:
		var sorted := samples.duplicate()
		sorted.sort()
		var total := 0.0
		for value: float in samples: total += value
		results.append({"player_position":str(world.get_node("Player").position), "camera_position":str(world.get_node("CameraRig/Pitch/CameraBoom/Camera3D").global_position), "view": ["entrance","village","western bridge","pond","hill picnic"][stage], "frames": samples.size(), "fps": samples.size()*1000.0/total, "average_ms": total/samples.size(), "p95_ms": sorted[int((sorted.size()-1)*.95)], "p99_ms": sorted[int((sorted.size()-1)*.99)], "worst_ms": sorted.back(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "process_ms": Performance.get_monitor(Performance.TIME_PROCESS)*1000, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000})
		change_stage()
