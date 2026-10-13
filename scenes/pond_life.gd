extends Node3D

@onready var world: Node = get_parent()
@onready var surface: Node = world.get_node("WorldSurface")
@onready var menus: Node = world.get_node("HUD/Menus")
@onready var life: Node = world.get_node("VillageLife")
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var quiet: Node = world.get_node("QuietPlaces")
@onready var controls: PanelContainer = $UI/Feeding
@export var feeding_radius := 2.8
var control_state := ""
var elapsed := 0.0
var feed_at := -100.0
var celebrated := true
var reply := ""
var reply_until := 0.0
var pond_item: Dictionary = {}
var dock_item: Dictionary = {}
var animations: Array[AnimationPlayer] = []
var fish_jumping: Array[bool] = []
var splash_at := -100.0
var next_splash_sound := 0.0
var splash_position := Vector3.ZERO

func _ready() -> void:
	var ponds: Array = surface.placements.get("pond",[])
	var docks: Array = surface.placements.get("dock",[])
	if not ponds.is_empty(): pond_item = ponds[0]
	if not docks.is_empty(): dock_item = docks[0]
	for bird: Node3D in $Birds.get_children():
		var players := bird.find_children("*","AnimationPlayer",true,false)
		var animator: AnimationPlayer = players[0] if not players.is_empty() else null
		animations.append(animator)
		if animator:
			for clip: String in animator.get_animation_list():
				if clip.split("/")[-1]=="swim":
					animator.play(clip); animator.seek(int(bird.name.to_int())*.3,true); break
	for i in $Fish.get_child_count(): fish_jumping.append(false)

func point(original: Vector3) -> Vector3:
	return surface.item_transform(pond_item)*(original-Vector3(-27,0,-14)) if not pond_item.is_empty() else original

func dock_point(original: Vector3) -> Vector3:
	return surface.item_transform(dock_item)*(original-Vector3(-21.65,0,-5.5)) if not dock_item.is_empty() else original

func meal(index: int) -> Vector3:
	var radius := 1+sqrt(maxf(0,index-3))*.38
	return dock_point(Vector3(-25+cos(index*2.4)*radius,-.3,-9+sin(index*2.4)*radius*.6))

func swim(index: int, time: float) -> Vector3:
	var swan := index<3
	var family := index-3 if index<7 else floori((index-7)/2.0)
	var lag := 0.0 if index<7 else .16+(index-7)%2*.15
	var phase := index*2.1 if swan else family*1.57+.7-lag
	var angle := time*(.055+index*.007 if swan else .09+family*.007)+phase+sin(time*.12+phase)*.045
	var radius := .54+index*.085 if swan else .36+family*.065+(0.0 if index<7 else -.025 if (index-7)%2 else .025)
	var orbit := point(Vector3(-27+cos(angle)*9*radius,-.3,-14+sin(angle)*12*radius))
	var age := time-feed_at
	if swan or age<0 or age>=17: return orbit
	return orbit.lerp(meal(index),smoothstep(0,4,age)*(1-smoothstep(11,17,age)))

func can_feed_here() -> bool:
	if player.controls_blocked or player.mount or world.get_node("FocusCottage").inside: return false
	if player.activity_locked and quiet.active!="breathe": return false
	return player.position.distance_to(dock_point(Vector3(-23.2,.24,-5.5))) <= feeding_radius

func feeding_status() -> String:
	if not reply.is_empty(): return reply
	if life.crumbs<=0: return menus.tr_pair("Ask Maple or Wren for crumbs first.","先にメープルかレンにパンくずをもらってください。")
	var remaining := ceili(11-(elapsed-feed_at))
	if remaining>0: return menus.tr_pair("The ducks are eating. Feed again in %ds.","アヒルたちは食事中です。あと%d秒。")%remaining
	return ""

func refresh_controls() -> void:
	controls.visible = can_feed_here() and quiet.active.is_empty()
	if not controls.visible:
		control_state = ""
		return
	var status := feeding_status()
	var ready: bool = life.crumbs>0 and elapsed-feed_at>=11
	var key: String = menus.key_name("talk")
	var state := str(menus.language)+str(ready)+key+status
	if state==control_state: return
	control_state = state
	$UI/Feeding/Content/Feed.set_key(key)
	$UI/Feeding/Content/Feed/Row/Text.text = menus.tr_pair("Feed the ducks","アヒルたちにパンくずをあげる")
	$UI/Feeding/Content/Feed.set_enabled(ready)
	$UI/Feeding/Content/Status.text = status
	$UI/Feeding/Content/Status.visible = not status.is_empty()
	controls.reset_size()

func _input(event: InputEvent) -> void:
	if event.is_echo() or not quiet.active.is_empty() or not can_feed_here(): return
	if event.is_action_pressed("talk"):
		feed()
		$UI/Feeding/Content/Feed.flash()
		get_viewport().set_input_as_handled()

func feed() -> bool:
	if not can_feed_here(): return false
	if life.crumbs<=0:
		reply = menus.tr_pair("Ask Maple or Wren for crumbs first.","先にメープルかレンにパンくずをもらってください。"); reply_until = elapsed+5; return false
	if elapsed-feed_at<11:
		reply = menus.tr_pair("The ducks are enjoying their crumbs. Give them a moment.","アヒルたちはパンくずを食べています。少し待ってください。"); reply_until = elapsed+5; return false
	# The browser's crumbPouch is reusable; pond feeds do not spend a pouch.
	feed_at = elapsed; celebrated = false; reply = ""; reply_until = elapsed+11
	world.get_node("VillageSound").garden_effect("crumbs",player.position)
	return true

func nearest_reply(camera: Camera3D, listener: Vector3) -> Dictionary:
	if elapsed-feed_at<7 or elapsed-feed_at>=11: return {}
	var nearest := 100.0
	var result := {}
	for i in $Replies.get_child_count():
		var cue: Node3D = $Replies.get_child(i)
		var distance := listener.distance_squared_to(cue.position)
		if distance>=nearest or camera.is_position_behind(cue.position): continue
		var screen := camera.unproject_position(cue.position)
		if not get_viewport().get_visible_rect().grow(-24).has_point(screen): continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position,cue.position,2)
		if not camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		nearest = distance
		result = {"id":"pond-"+str(i),"point":cue.position,"text":menus.tr_pair("Honk honk~ (Thank you~)","ホンクホンク〜（ありがとう〜）") if i<3 else menus.tr_pair("Quack quack~ (Thank you~)","クワックワッ〜（ありがとう〜）")}
	return result

func _process(delta: float) -> void:
	elapsed += delta
	refresh_controls()
	var reduced: bool = menus.reduced_motion
	var t := 0.0 if reduced else elapsed
	var age := elapsed-feed_at
	if elapsed>reply_until: reply = ""
	if not celebrated and age>=7:
		celebrated = true
		if age<11:
			var position: Vector3 = $Birds.get_child(3).position
			world.get_node("VillageSound").animal_call("duck",position,true)
	for i in $Birds.get_child_count():
		var bird: Node3D = $Birds.get_child(i)
		var target := swim(i,elapsed)
		var before := swim(i,elapsed-.005); var after := swim(i,elapsed+.005)
		var heading := atan2(after.x-before.x,after.z-before.z)
		bird.rotation.y = lerp_angle(bird.rotation.y,heading,1-exp(-delta*5)) if not reduced else heading
		bird.position = target
		bird.position.y += .015-([.16,.1,.06][0 if i<3 else 1 if i<7 else 2])+sin(t*2+i*1.3)*(.0 if reduced else .022)
		var happy_age := age-7-(i-3)*.16
		var happy := i>=3 and happy_age>=0 and happy_age<3.1
		var joy := sin(clampf(happy_age/3.1,0,1)*PI) if happy and not reduced else 0.0
		bird.position.y += absf(sin(happy_age*5))*joy*.13
		bird.rotation.z = sin(happy_age*7)*joy*.09
		if animations[i]:
			var animator: AnimationPlayer = animations[i]
			var clip := "idle" if reduced else "swim"
			if animator.current_animation!=clip:
				animator.play(clip)
				if reduced: animator.seek(0,true)
			animator.speed_scale = 0 if reduced else 1
		var heart: Label3D = $Hearts.get_child(i)
		heart.visible = happy
		heart.position = bird.position+Vector3(0,.85+(0.0 if reduced else maxf(0,happy_age)*.2),0)
		heart.scale = Vector3.ONE*(.3 if reduced else minf(1,minf(happy_age*5,(3.1-happy_age)*3))*.4)
		var cue: Node3D = $Replies.get_child(i)
		cue.visible = age>=7 and age<11
		cue.position = bird.position+Vector3(0,1.05,0)

		var ripple: Node3D = $Ripples.get_child(i)
		ripple.position = Vector3(bird.position.x,point(Vector3(-27,-.268,-14)).y,bird.position.z)
		ripple.rotation.y = bird.rotation.y
		ripple.scale = Vector3(.8,1,1.1) if i<3 else Vector3(.48,1,.65)
	for i in $Fish.get_child_count():
		var fish: Node3D = $Fish.get_child(i)
		var angle := t*.15+i*1.57; var cycle := fmod(t+i*4.8,22)
		var leap := sin(cycle/1.7*PI) if not reduced and cycle<1.7 else 0.0
		var radius := .35+i%4*.11
		fish.position = point(Vector3(-27+cos(angle)*9*radius,-.375+leap*1.25,-14+sin(angle)*12*radius))
		fish.rotation = Vector3(-cos(cycle/1.7*PI)*.72 if leap>0 else 0,atan2(-sin(angle),cos(angle)*1.45)+deg_to_rad(float(pond_item.get("rotation",[0,0,0])[1])),0)
		var tail: Node3D = fish.find_child("FishTail",true,false)
		if tail: tail.rotation.y = sin(t*9+i)*(.0 if reduced else .35)
		if fish_jumping[i] and leap==0 and not reduced:
			splash_at = elapsed; splash_position = fish.position
			if elapsed>=next_splash_sound:
				next_splash_sound = elapsed+3
				world.get_node("VillageSound").garden_effect("splash",fish.position)
		fish_jumping[i] = leap>0
	$Crumbs.visible = age>=0 and age<7
	for i in $Crumbs.get_child_count():
		var crumb: Node3D = $Crumbs.get_child(i)
		var f := clampf(age/1.2-i*.016,0,1)
		crumb.position = dock_point(Vector3(-23.2,1.1,-5.5)).lerp(meal(3+i%12)+Vector3(0,.04,0),f)+Vector3(0,sin(f*PI)*.65,0)
		crumb.scale = Vector3.ONE*(maxf(0,1-(age-4)/3) if age>4 else 1.0)
	for i in 6:
		var ripple: Node3D = $Splash.get_child(i)
		var splash_age := elapsed-splash_at
		ripple.visible = splash_age>=0 and splash_age<1.8 and not reduced
		ripple.position = Vector3(splash_position.x,point(Vector3(-27,-.265,-14)).y,splash_position.z)
		ripple.scale = Vector3.ONE*(.15+splash_age*(.6+i*.15))
