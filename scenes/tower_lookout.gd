extends Node3D

@export var walk_radius := 3.05
@export var platform_height := 11.4
@onready var world: Node = get_parent()
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var rig: Node3D = world.get_node("CameraRig")
@onready var menus: Node = world.get_node("HUD/Menus")
var inside := false
var nearby := false
var yaw := 0.0
var pitch := .28

func enter() -> bool:
	if not nearby or player.controls_blocked or player.activity_locked or player.mount: return false
	inside = true
	player.activity_locked = true
	player.velocity = Vector3.ZERO
	player.jump_buffer = 0
	player.visual.hide()
	player.position = to_global(Vector3(0,platform_height,2.7))
	player.reset_physics_interpolation()
	yaw = atan2(player.position.x,player.position.z); pitch = .28
	$Camera.make_current()
	rig.capture_mouse()
	return true

func leave() -> void:
	if not inside: return
	inside = false
	player.activity_locked = false
	player.visual.show()
	player.position = world.get_node("WorldSurface").recovery_spot(Vector2($Entrance.global_position.x,$Entrance.global_position.z))
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	rig.desired_yaw = yaw; rig.desired_pitch = .22
	rig.global_position = player.position+Vector3(0,1.35,0)
	rig.camera.make_current()
	rig.release_mouse()
	menus.sync_blocking()

func _process(_delta: float) -> void:
	nearby = player.position.distance_to($Entrance.global_position)<3.5 and not player.activity_locked and not player.mount
	var visible_controls: bool = (inside or nearby) and not menus.is_open() and not world.get_node("HUD/VillageMap").expanded
	$UI/Controls.visible = visible_controls
	$UI/Controls/Content/Heading.text = menus.tr_pair("Watchtower lookout","見張り塔の展望台")
	$UI/Controls/Content/Help.visible = inside
	$UI/Controls/Content/Help.text = menus.tr_pair("WASD / arrows to walk · Mouse to look · Home/End turn, PgUp/PgDn tilt","WASD / 矢印で歩く · マウスで見る · Home/Endで回転、PgUp/PgDnで上下を見る")
	var button: Button = $UI/Controls/Content/Toggle
	button.get_node("Row/Text").text = menus.tr_pair("Come down","降りる") if inside else menus.tr_pair("Go up to the lookout","展望台へ上がる")
	button.set_key(menus.key_name("interact"))
	if inside:
		$Camera.global_position = player.position+Vector3(0,1.35,0)
		$Camera.rotation = Vector3(-pitch,yaw,0)

func _physics_process(delta: float) -> void:
	if not inside or player.controls_blocked: return
	yaw -= (Input.get_action_strength("look_right")-Input.get_action_strength("look_left"))*delta*1.25
	pitch = clampf(pitch+(Input.get_action_strength("look_down")-Input.get_action_strength("look_up"))*delta,-.85,1.35)
	var axes := Input.get_vector("move_left","move_right","move_forward","move_back")
	var direction := Vector3(axes.x,0,axes.y).rotated(Vector3.UP,yaw)
	var local := to_local(player.position+direction*delta*(3.5 if Input.is_action_pressed("dash") else 2.2))
	var point := Vector2(local.x,local.z).limit_length(walk_radius)
	player.position = to_global(Vector3(point.x,platform_height,point.y))
	player.velocity = Vector3.ZERO

func toggle() -> void:
	if inside: leave()
	else: enter()

func _input(event: InputEvent) -> void:
	if menus.is_open() or world.get_node("HUD/VillageMap").expanded or event.is_echo(): return
	if inside:
		if event.is_action_pressed("interact") or event.is_action_pressed("release_mouse") or event.is_action_pressed("unstuck"):
			leave(); get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
			yaw -= event.screen_relative.x*rig.sensitivity
			pitch = clampf(pitch+event.screen_relative.y*rig.sensitivity,-.85,1.35)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			rig.capture_mouse(); get_viewport().set_input_as_handled()
	elif nearby and not player.controls_blocked and event.is_action_pressed("interact"):
		enter(); get_viewport().set_input_as_handled()
