extends Node3D

@onready var cottage: Node3D = get_parent()
@onready var model: Node3D = $Model
@onready var bubble: PanelContainer = cottage.get_node("UI/AnimalBubble")
var active := false
var state := "nap"
var age := 0.0
var duration := 14.0
var elapsed := 0.0
var visits := 0
var strolls := 0
var target := Vector3.ZERO
var origin := Vector3.ZERO
var destination := "floor"
var animator: AnimationPlayer
var clips: Dictionary = {}
const BED := Vector3(.5,.12,-.3)
const DESK := Vector3(-.48,1.08,-1.69)
const LANDING := Vector3(1.55,0,-1.15)

func _ready() -> void:
	position = BED; rotation.y = -.85
	var animators := model.find_children("*","AnimationPlayer",true,false)
	if not animators.is_empty():
		animator = animators[0]
		for clip: String in animator.get_animation_list(): clips[clip.split("/")[-1]] = clip
	bubble.hide()

func begin(next: String, time: float) -> void:
	state = next; age = 0; duration = time; origin = position

func pet() -> bool:
	if not active or state!="ask" or cottage.player.controls_blocked: return false
	begin("pet",3.2)
	cottage.world.get_node("VillageSound").animal_call("cat",global_position,true,"cottage-cat")
	return true

func _process(delta: float) -> void:
	if not active or cottage.player.controls_blocked: bubble.hide(); return
	age += delta; elapsed += delta
	var reduced: bool = cottage.menus.pages.get_node("Experience/ReducedMotion").button_pressed if cottage.menus.pages.get_node_or_null("Experience/ReducedMotion") else false
	if state=="walk":
		position = position.move_toward(target,delta*.48)
		var heading := atan2(target.x-position.x,target.z-position.z)
		rotation.y = lerp_angle(rotation.y,heading,1-exp(-7*delta))
		if position.distance_to(target)<.025:
			if destination=="desk": position = LANDING; begin("up",1.1)
			elif destination=="bed": position = BED; rotation.y = -.85; begin("nap",45)
			else: begin("rest",3)
			destination = "floor"
	elif state in ["up","down"]:
		var progress := clampf(age/duration,0,1)
		position = origin.lerp(DESK if state=="up" else LANDING,smoothstep(0,1,progress))
		position.y += sin(PI*progress)*.42
		rotation.y = -.7
		if progress>=1: begin("ask" if state=="up" else "rest",24 if state=="up" else 10)
	elif age>=duration:
		match state:
			"nap": begin("stretch",3.8)
			"stretch": begin("rest",3)
			"pet": begin("ask",16)
			"ask": visits += 1; begin("down",.9)
			_:
				destination = "desk" if visits==0 or strolls>=3 else "bed" if strolls==2 else "floor"
				target = DESK if destination=="desk" and reduced else LANDING if destination=="desk" else BED if destination=="bed" else [Vector3(1.6,0,-1.15),Vector3(2.4,0,-1.1),Vector3(2.3,0,.7),Vector3(1.55,0,.75)][strolls%4]
				strolls = 0 if destination=="desk" else strolls+1
				begin("walk",0)
	if reduced and state not in ["nap","ask","pet"]:
		position = DESK; rotation.y = -.7; begin("ask",30)
	var clip := "idle" if state=="rest" else state
	if animator and clips.has(clip) and animator.current_animation!=clips[clip]: animator.play(clips[clip],.12)
	bubble.visible = state=="pet" or state=="ask" and age<3
	bubble.get_node("Content/Line").text = cottage.menus.tr_pair("Purr purr~ (That feels lovely~)","ゴロゴロ〜（気持ちいいにゃ〜）") if state=="pet" else cottage.menus.tr_pair("Mrrp~ (A little company~)","にゃ〜（そばにいてほしいにゃ〜）")
	if bubble.visible:
		var point := get_global_transform_interpolated().origin+Vector3(0,.85,0)
		if cottage.camera.is_position_behind(point): bubble.hide()
		else:
			bubble.size = bubble.get_combined_minimum_size()
			bubble.position = (cottage.camera.unproject_position(point)-Vector2(bubble.size.x*.5,bubble.size.y+14)).clamp(Vector2(16,85),get_viewport().get_visible_rect().size-bubble.size-Vector2(350,80))
	cottage.player.left_fin.rotation.z = sin(age*7)*.12 if state=="pet" else -.08
