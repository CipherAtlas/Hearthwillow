extends CharacterBody3D

@export var actor_id := ""
@export var actor_kind := "resident"
@export var profile: Dictionary = {}
@onready var pose: Node3D = $Pose
@onready var surface: Node = get_parent().get_parent().get_parent().get_node("WorldSurface")
@onready var life: Node = get_parent().get_parent().get_parent().get_node("VillageLife")

var ridden := false
var following := false
var returning := false
var waypoint := 1
var pause := 0.0
var chatting := 0.0
var action := "idle"
var action_age := 0.0
var action_duration := 0.0
var elapsed := 0.0
var distance_walked := 0.0
var route: PackedVector2Array = []
var path: PackedVector2Array = []
var replan := 0.0
var home := Vector2.ZERO
var height_offset := 0.0
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var clips: Dictionary = {}
var fin_nodes: Array[Node3D] = []
var fin_bases: Array[Transform3D] = []

func _ready() -> void:
	if profile.is_empty():
		for resident: Dictionary in surface.data.actors:
			if resident.id == actor_id: profile = resident; break
	for point: Array in profile.get("route",[]): route.append(Vector2(point[0],point[1]))
	home = Vector2(position.x,position.z)
	if route.is_empty(): route.append(home)
	waypoint = 1 if route.size() > 1 else 0
	pause = float(profile.get("phase",0))*1.2
	if actor_kind == "owl": height_offset = position.y-surface.floor_at(home)
	var skeletons := find_children("*","Skeleton3D",true,false)
	if not skeletons.is_empty(): skeleton = skeletons[0]
	var animators := find_children("*","AnimationPlayer",true,false)
	if not animators.is_empty():
		animation_player = animators[0]
		for clip: String in animation_player.get_animation_list(): clips[clip.split("/")[-1]] = clip
	for child: Node in pose.get_children():
		if child is Node3D and str(child.get_meta("part","")).begins_with("SpiritFin"):
			fin_nodes.append(child)
			fin_bases.append(child.transform)
	position.y = surface.floor_at(home)+height_offset+.03
	reset_physics_interpolation()

func bone_world(bone_name: String) -> Vector3:
	var index := skeleton.find_bone(bone_name) if skeleton else -1
	return skeleton.get_global_transform_interpolated()*skeleton.get_bone_global_pose(index).origin if index >= 0 else get_global_transform_interpolated().origin+Vector3(0,1.1,0)

func start_action(next: String, duration: float) -> void:
	action = next
	action_age = 0
	action_duration = duration
	path.clear()

func _physics_process(delta: float) -> void:
	elapsed += delta
	chatting = maxf(0,chatting-delta)
	pause = maxf(0,pause-delta)
	replan -= delta
	action_age += delta
	if action != "idle" and action_age >= action_duration: action = "idle"
	if not ridden: life.move_actor(self,delta)
	var speed := Vector2(velocity.x,velocity.z).length()
	if actor_kind == "resident":
		var phase: float = profile.get("phase",0)
		pose.position.y = sin(elapsed*2.5+phase)*.065
		pose.rotation.x = speed*.035
		pose.rotation.z = sin(elapsed*1.6+phase)*.035
		for i in fin_nodes.size():
			fin_nodes[i].transform = fin_bases[i]
			fin_nodes[i].rotate_object_local(Vector3.BACK,sin((elapsed+phase)*(8 if speed > .1 else 3)+i*PI)*.18)
	elif animation_player:
		var clip := "canter" if ridden and speed > 6 else "trot" if ridden and speed > 3.2 else "feed" if actor_kind == "owl" and action == "eat" else action if action != "idle" else "walk" if speed > .1 else "idle"
		if not clips.has(clip): clip = "pet" if action != "idle" else "idle"
		if clips.has(clip) and animation_player.current_animation != clips[clip]: animation_player.play(clips[clip],.15)
	elif actor_kind == "hedgehog":
		pose.rotation.z = sin(action_age*2.2)*.065 if action == "pet" else sin(elapsed*2)*.015

