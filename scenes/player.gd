extends CharacterBody3D

signal step_taken(surface: String)
signal jumped
signal landed

@export var walk_speed: float = 2.6
@export var glide_speed: float = 4.5
@export var dash_speed: float = 6.0
@export var gravity: float = 12.0
@export var jump_speed: float = 5.0
@export var turning_speed: float = 14.0
@export var acceleration: float = 16.0

@onready var visual: Node3D = $SpiritVisual
@onready var left_fin: Node3D = $SpiritVisual/Spirit/SpiritFinL
@onready var right_fin: Node3D = $SpiritVisual/Spirit/SpiritFinR
@onready var surface: Node = get_parent().get_node("WorldSurface")
@onready var camera_rig: Node3D = get_parent().get_node("CameraRig")

var race_countdown := false
var activity_locked := false
var mount: CharacterBody3D
var horse_speed := 0.0
var saddle_height := 0.0
var gliding := false
var controls_blocked := false
var gait := "idle"
var jump_buffer := 0.0
var coyote_time := 0.0
var elapsed := 0.0
var step_distance := 0.0
var grounded_last_frame := false

func _ready() -> void:
	position = surface.recovery_spot(Vector2(.3,20))
	visual.rotation.y = PI

func _unhandled_input(event: InputEvent) -> void:
	if controls_blocked or activity_locked: return
	if event.is_action_pressed("glide") and not mount: gliding = not gliding
	if event.is_action_pressed("jump") and not mount: jump_buffer = .12
	if event.is_action_pressed("unstuck"):
		if mount: ride_or_dismount(mount)
		position = surface.recovery_spot(Vector2(position.x,position.z))
		velocity = Vector3.ZERO
		reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	elapsed += delta
	if activity_locked: return
	if mount:
		move_horse(delta)
		return
	jump_buffer = maxf(0,jump_buffer-delta)
	if is_on_floor(): coyote_time = .12
	else: coyote_time = maxf(0,coyote_time-delta)
	var axes := Vector2.ZERO if controls_blocked else Input.get_vector("move_left","move_right","move_forward","move_back")
	var direction := Vector3(axes.x,0,axes.y).rotated(Vector3.UP,camera_rig.rotation.y)
	var speed := dash_speed if Input.is_action_pressed("dash") else glide_speed if gliding else walk_speed
	var target := direction*speed
	velocity.x = move_toward(velocity.x,target.x,acceleration*delta)
	velocity.z = move_toward(velocity.z,target.z,acceleration*delta)
	var point := Vector2(position.x,position.z)
	var destination := point+Vector2(velocity.x,velocity.z)*delta
	if not surface.can_enter(destination):
		if not surface.can_enter(point+Vector2(velocity.x*delta,0)): velocity.x = 0
		if not surface.can_enter(point+Vector2(0,velocity.z*delta)): velocity.z = 0
		if not surface.can_enter(point+Vector2(velocity.x,velocity.z)*delta):
			velocity.x = 0
			velocity.z = 0
	if jump_buffer > 0 and coyote_time > 0 and not controls_blocked:
		velocity.y = jump_speed
		jump_buffer = 0
		coyote_time = 0
		jumped.emit()
	else:
		velocity.y -= gravity*delta
	var before := position
	move_and_slide()
	if position.y < -15 or absf(position.x) > 321 or absf(position.z) > 321:
		position = surface.recovery_spot(point)
		velocity = Vector3.ZERO
		reset_physics_interpolation()
	var horizontal_speed := Vector2(velocity.x,velocity.z).length()
	gait = "air" if not is_on_floor() else "idle" if horizontal_speed < .1 else "dash" if speed == dash_speed else "glide" if gliding else "walk"
	if direction.length_squared() > .01:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(direction.x,direction.z),1-exp(-turning_speed*delta))
	visual.position.y = .62+sin(elapsed*2.8)*.065
	visual.rotation.x = lerpf(visual.rotation.x,horizontal_speed*.022,1-exp(-8*delta))
	visual.rotation.z = sin(elapsed*1.7)*.035
	left_fin.rotation.z = sin(elapsed*(8 if horizontal_speed > .1 else 3))*.18
	right_fin.rotation.z = sin(elapsed*(8 if horizontal_speed > .1 else 3)+PI)*.18
	if is_on_floor():
		step_distance += Vector2(position.x-before.x,position.z-before.z).length()
		if step_distance >= .9:
			step_distance = 0
			step_taken.emit(surface.contact_surface(Vector2(position.x,position.z)))
		if not grounded_last_frame: landed.emit()
	grounded_last_frame = is_on_floor()


func ride_or_dismount(horse: CharacterBody3D) -> void:
	step_distance = 0
	if mount:
		var heading: float = mount.rotation.y
		var side := Vector2(cos(heading),-sin(heading))
		var point := Vector2(position.x,position.z)
		var spot: Vector3 = surface.recovery_spot(point+side*1.4)
		mount.ridden = false
		mount.velocity = Vector3.ZERO
		mount = null
		position = spot
		velocity = Vector3.ZERO
		visual.position = Vector3(0,.62,0)
		saddle_height = 0
	else:
		if horse.action != "idle": return
		mount = horse
		horse.ridden = true
		horse_speed = 0
		position = horse.position
		visual.rotation.y = horse.rotation.y
		saddle_height = horse.bone_world("HorseSeat").y-horse.position.y if horse.skeleton else 1.65
		visual.position.y = saddle_height
		camera_rig.desired_yaw = horse.rotation.y+PI
		get_parent().get_node("VillageLife").say(get_parent().get_node("VillageLife").actor_name(horse),"Neigh~ (Let’s go for a gentle ride~)",4)
	reset_physics_interpolation()

func horse_clear(point: Vector2, heading: float) -> bool:
	if not mount: return false
	var ground: float = surface.floor_at(point)
	var horse_scale: float = mount.scale.x
	for along: float in [-.65,0,.65]:
		for side: float in [-.25,.25]:
			var offset := Vector2(sin(heading)*along+cos(heading)*side,cos(heading)*along-sin(heading)*side)*horse_scale
			if absf(surface.floor_at(point+offset)-ground) > .55*horse_scale or not surface.clear_at(point+offset): return false
	return true

func move_horse(delta: float) -> void:
	var horse: CharacterBody3D = mount
	if not horse: return
	var axes := Vector2.ZERO if controls_blocked else Input.get_vector("move_left","move_right","move_forward","move_back")
	var braking := controls_blocked or race_countdown or Input.is_action_pressed("jump")
	var forward := -axes.y
	var target := 0.0 if braking else forward*(1.8 if forward < 0 else 9.0 if Input.is_action_pressed("dash") else 4.5)
	var response := 18.0 if braking else 9.0 if is_zero_approx(target) else 8.0
	horse_speed = move_toward(horse_speed,target,response*delta)
	var heading: float = horse.rotation.y
	var turn := 0.0 if braking else -axes.x*(2.4-minf(1,absf(horse_speed)/9)*.9)*delta
	var point := Vector2(position.x,position.z)
	if horse_clear(point,heading+turn): heading += turn
	var destination := point+Vector2(sin(heading),cos(heading))*horse_speed*delta
	var distance := point.distance_to(destination)
	var rise: float = absf(surface.floor_at(destination)-surface.floor_at(point))
	if horse_clear(destination,heading) and rise <= maxf(distance*.85+.003,.12*horse.scale.x):
		position = Vector3(destination.x,surface.floor_at(destination)+.03,destination.y)
	else: horse_speed = 0
	if mount!=horse: return
	velocity = Vector3(sin(heading)*horse_speed,0,cos(heading)*horse_speed)
	horse.position = position
	horse.rotation.y = heading
	horse.velocity = velocity
	horse.distance_walked += point.distance_to(Vector2(position.x,position.z))
	visual.rotation.y = heading
	visual.rotation.x = -.05-absf(horse_speed)*.008
	visual.rotation.z = 0
	visual.position.y = saddle_height
	left_fin.rotation.z = sin(elapsed*3)*.08
	right_fin.rotation.z = sin(elapsed*3+PI)*.08
	gait = "canter" if absf(horse_speed)>6 else "trot" if absf(horse_speed)>3.2 else "ride"
	step_distance += point.distance_to(Vector2(position.x,position.z))
	var stride := 1.8 if absf(horse_speed) < 3.2 else 2.9 if absf(horse_speed) < 5.7 else 3.8
	var hoof_spacing := stride * horse.scale.z / (4.0 if absf(horse_speed) < 3.2 else 2.0)
	if step_distance > hoof_spacing and absf(horse_speed) > .2:
		step_distance = 0
		step_taken.emit(surface.contact_surface(Vector2(position.x,position.z)))
