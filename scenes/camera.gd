extends Node3D

@export var sensitivity: float = .0022
@export var follow_speed: float = 7.0
@export var orbit_speed: float = 12.0
@export var zoom_speed: float = 8.0
@export var collision_recovery_speed: float = 6.0
@export var distance: float = 3.8
@export var pitch: float = .15
@export var collision_shape: SphereShape3D
@export var collision_margin: float = .18
@export var collision_mask: int = 3

@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var pivot: Node3D = $Pitch
@onready var arm: Node3D = $Pitch/CameraBoom
@onready var camera: Camera3D = $Pitch/CameraBoom/Camera3D

var follow_anchor: Node3D
var controls_blocked := false
var mouse_released := false
var desired_yaw: float
var desired_pitch: float
var applied_yaw: float
var visible_distance: float
var smoothed_distance: float
var title_screen := false
var title_time := 0.0
var query := PhysicsShapeQueryParameters3D.new()
var avoidance_yaw := 0.0
var desired_avoidance := 0.0
var avoidance_check := 0.0

func _ready() -> void:
	position = player.position+Vector3(0,1.35,0)
	pivot.rotation.x = -pitch
	desired_yaw = rotation.y
	applied_yaw = rotation.y
	desired_pitch = pitch
	visible_distance = distance
	smoothed_distance = distance
	query.shape = collision_shape
	query.collision_mask = collision_mask
	query.exclude = [player.get_rid()]
	query.margin = .02

func capture_mouse() -> void:
	mouse_released = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func release_mouse() -> void:
	mouse_released = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		var menus: Control = get_parent().get_node("HUD/Menus")
		if menus.is_node_ready(): menus.sync_blocking()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		release_mouse()
		get_viewport().set_input_as_handled()
	if controls_blocked: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			capture_mouse()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(2.2,distance-.35)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(12,distance+.35)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		desired_yaw -= event.screen_relative.x*sensitivity
		desired_pitch = clampf(desired_pitch+event.screen_relative.y*sensitivity,-.55,1.05)

func _process(delta: float) -> void:
	if title_screen:
		title_time += delta
		camera.global_position = Vector3(27+sin(title_time*.055)*4,19+sin(title_time*.07)*.6,42+cos(title_time*.055)*2)
		camera.look_at(Vector3(-4,2,-13))
		return
	camera.rotation = Vector3.ZERO
	# A playtest or explicit viewpoint reset may change the rig directly.
	if not is_equal_approx(rotation.y,applied_yaw): desired_yaw = rotation.y
	rotation.y = lerp_angle(rotation.y,desired_yaw,1-exp(-orbit_speed*delta))
	applied_yaw = rotation.y
	pitch = lerpf(pitch,desired_pitch,1-exp(-orbit_speed*delta))
	var target := player.get_global_transform_interpolated().origin+Vector3(0,1.35+(player.saddle_height-.62 if player.mount else 0)+maxf(0,-sin(pitch))*2.4,0)
	if follow_anchor: target = follow_anchor.get_global_transform_interpolated().origin
	global_position = global_position.lerp(target,1-exp(-follow_speed*delta))
	smoothed_distance = lerpf(smoothed_distance,distance,1-exp(-zoom_speed*delta))
	# Keep a useful third-person distance near walls instead of zooming into
	# the spirit's head. Hold the chosen side until the requested view clears.
	avoidance_check -= delta
	if avoidance_check <= 0:
		avoidance_check = .1
		var original := clear_distance(0)
		if original >= minf(2.8,smoothed_distance-.2):
			desired_avoidance = 0
		else:
			var best := -INF
			var previous := desired_avoidance
			for angle: float in [previous,0.0,.55,-.55,1.1,-1.1,1.65,-1.65]:
				var score := clear_distance(angle)-absf(angle)*.3-absf(angle-previous)*.15
				if score > best:
					best = score
					desired_avoidance = angle
	avoidance_yaw = lerp_angle(avoidance_yaw,desired_avoidance,1-exp(-5*delta))
	pivot.rotation = Vector3(-pitch,avoidance_yaw,0)
	# Sweep from the rendered pivot, so orbit/follow cannot move through a wall
	# between physics ticks. Contract immediately; ease back out after occlusion.
	query.transform = pivot.global_transform
	query.motion = pivot.global_basis.z*smoothed_distance
	var hit := get_world_3d().direct_space_state.cast_motion(query)
	var safe_distance := maxf(.08,smoothed_distance*hit[0]-collision_margin)
	visible_distance = minf(safe_distance,lerpf(visible_distance,safe_distance,1-exp(-collision_recovery_speed*delta)))
	camera.position = Vector3(0,0,visible_distance)

func clear_distance(angle: float) -> float:
	var view_basis := global_basis*Basis.from_euler(Vector3(-pitch,angle,0))
	query.transform = Transform3D(view_basis,global_position)
	query.motion = view_basis.z*smoothed_distance
	var hit := get_world_3d().direct_space_state.cast_motion(query)
	return maxf(.08,smoothed_distance*hit[0]-collision_margin)
