extends Node3D

@export var countdown_seconds := 3.0
@export var lap_limit := 90.0
@export var rival_seconds := 34.0
@onready var world: Node = get_parent()
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var surface: Node = world.get_node("WorldSurface")
@onready var menus: Control = world.get_node("HUD/Menus")
@onready var rowan: CharacterBody3D = world.get_node("Village/Actors/rowan")
@onready var hud: PanelContainer = $UI/Progress
var track: Dictionary = {}
var phase := ""
var result := ""
var go_at := 0.0
var until := 0.0
var next_checkpoint := 1
var elapsed := 0.0
var finished_at := 0.0
var race_horse: CharacterBody3D
var previous := Vector2.ZERO
var rowan_processing := true
var rowan_visible := true
var rowan_staged := false
var rival_animator: AnimationPlayer
var rival_clips: Dictionary = {}

func _ready() -> void:
	for item: Dictionary in surface.placements.get("horse-racetrack",[]): track = item; break
	var animators := $Rival.find_children("*","AnimationPlayer",true,false)
	if not animators.is_empty():
		rival_animator = animators[0]
		for clip: String in rival_animator.get_animation_list(): rival_clips[clip.split("/")[-1]] = clip
	hud.hide()
	$Guide.hide(); $Rival.hide()

func now() -> float:
	return Time.get_ticks_msec()/1000.0

func active() -> bool:
	return phase in ["countdown","racing"]

func point(index: float, lane := 0.0) -> Vector2:
	var angle := PI*.5+index*TAU/8
	return surface.world_point(track,Vector2((24+lane)*cos(angle),(14+lane)*sin(angle)))

func can_invite() -> bool:
	return not track.is_empty() and not active() and not player.mount and not player.activity_locked and not player.controls_blocked and rowan.chatting>0 and player.position.distance_to(rowan.position)<4.5

func invite() -> bool:
	if not can_invite(): return false
	var horse: CharacterBody3D
	for actor: CharacterBody3D in world.get_node("Village/Actors").get_children():
		if actor.actor_kind == "horse" and not actor.ridden and actor.action == "idle" and actor.position.distance_to(rowan.position)<14:
			horse = actor; break
	if not horse:
		world.get_node("VillageLife").say("Rowan",menus.tr_pair("The horses are busy. Let's wait for one to be free.","馬たちは忙しいね。少し待とう。"),4)
		return false
	for index in 48:
		var destination := point(index/6.0)
		if not surface.can_enter(destination) or not surface.clear_at(destination):
			world.get_node("VillageLife").say("Rowan",menus.tr_pair("This track needs clear ground before racing.","コースを片づけてから競走しよう。"),4)
			return false
	clear()
	var start := point(0)
	world.get_node("HUD/VillageMap").travel_point(start)
	horse.position = player.position
	var heading := atan2(point(.01).x-start.x,point(.01).y-start.y)
	horse.rotation.y = heading; horse.velocity = Vector3.ZERO
	player.ride_or_dismount(horse)
	player.camera_rig.desired_yaw = heading+PI
	race_horse = horse; previous = start
	phase = "countdown"; result = ""; next_checkpoint = 1; elapsed = 0
	go_at = now()+countdown_seconds; until = go_at+lap_limit
	player.race_countdown = true
	rowan_processing = rowan.is_physics_processing(); rowan_visible = rowan.visible
	rowan.set_physics_process(false); rowan.hide(); rowan_staged = true
	refresh()
	return true

func _physics_process(_delta: float) -> void:
	if not active(): return
	if player.mount != race_horse or player.activity_locked or world.get_node("FocusCottage").inside or now()>=until:
		cancel(); return
	if now()<go_at: return
	phase = "racing"; player.race_countdown = false
	elapsed = now()-go_at
	var current := Vector2(player.position.x,player.position.z)
	var gate := point(next_checkpoint)
	# Swept proximity preserves the source gate radius without missing fast crossings.
	var closest := Geometry2D.get_closest_point_to_segment(gate,previous,current)
	if closest.distance_to(gate)<6.2*minf(track.scale[0],track.scale[2]) and previous.distance_to(current)<3:
		next_checkpoint += 1
		if next_checkpoint>8:
			finished_at = now(); elapsed = finished_at-go_at
			result = "tie" if absf(elapsed-rival_seconds)<.12 else "visitor" if elapsed<rival_seconds else "rival"
			phase = "finished"; until = now()+30
	previous = current

func _process(_delta: float) -> void:
	if phase in ["finished","cancelled"] and now()>=until: clear()
	refresh()

func refresh() -> void:
	var visible_race: bool = not phase.is_empty() and not world.get_node("FocusCottage").inside and menus.entered and not world.get_node("HUD/VillageMap").expanded
	hud.visible = visible_race
	$Guide.visible = active()
	$Rival.visible = phase in ["countdown","racing","finished"] and now()<go_at+rival_seconds
	if $Rival.visible:
		var progress := clampf((now()-go_at)/rival_seconds,0,1)
		var location := point(progress*8,-1.4)
		var next := point(progress*8+.001,-1.4)
		$Rival.position = Vector3(location.x,surface.floor_at(location)+.03,location.y)
		$Rival.rotation.y = atan2(next.x-location.x,next.y-location.y)
		var clip := "trot" if phase!="countdown" else "idle"
		if rival_animator and rival_clips.has(clip) and rival_animator.current_animation!=rival_clips[clip]: rival_animator.play(rival_clips[clip],.15)
		if has_node("Rider"): $Rider.global_transform = $Rival.global_transform
	$Rider.visible = $Rival.visible
	if rowan_staged and not $Rival.visible: restore_rowan()
	if active():
		var gate := point(next_checkpoint)
		var next := point(next_checkpoint+.01)
		$Guide.position = Vector3(gate.x,surface.floor_at(gate)+.025,gate.y)
		$Guide.rotation.y = atan2(next.x-gate.x,next.y-gate.y)
		$Guide.scale = Vector3.ONE*minf(track.scale[0],track.scale[2])
	if not visible_race: return
	var text: VBoxContainer = hud.get_node("Content")
	text.get_node("Title").text = menus.tr_pair("Ready for your lap?","準備はいい？") if phase=="countdown" else menus.tr_pair("Race ended","レース終了") if phase=="cancelled" else menus.tr_pair("You won!","あなたの勝ち！") if phase=="finished" and result=="visitor" else menus.tr_pair("A tie!","引き分け！") if phase=="finished" and result=="tie" else menus.tr_pair("Lap complete!","ゴール！") if phase=="finished" else menus.tr_pair("Race Rowan","ローワンと競走")
	text.get_node("Clock").visible = phase!="cancelled"
	var seconds := maxi(0,ceili(until-now()))
	text.get_node("Clock").text = str(maxi(1,ceili(go_at-now()))) if phase=="countdown" else "%d:%02d"%[floori(seconds/60.0),seconds%60] if phase=="racing" else "%.1fs"%elapsed
	var running := phase in ["racing","finished"]
	for name_text: String in ["Statistics","Positions","Gate"]: text.get_node(name_text).visible = running
	text.get_node("Clock").add_theme_font_size_override("font_size",52 if phase=="countdown" else 32)
	text.get_node("Statistics").text = menus.tr_pair("%d / 8 flags    ·    Lap %.1fs","%d / 8 旗    ·    ラップ %.1fs")%[mini(8,next_checkpoint-1),elapsed]
	text.get_node("Positions/You/Label").text = menus.tr_pair("You","あなた")
	text.get_node("Positions/You/Bar").value = mini(8,next_checkpoint-1)
	text.get_node("Positions/Rowan/Bar").value = clampf((now()-go_at)/rival_seconds,0,1)*8
	text.get_node("Gate").text = menus.tr_pair("Next gate %dm","次の旗まで%dm")%roundi(Vector2(player.position.x,player.position.z).distance_to(point(next_checkpoint)))
	text.get_node("Gate").visible = phase=="racing"

func cancel() -> void:
	if not active(): return
	phase = "cancelled"; result = ""; until = now()+8
	player.race_countdown = false
	restore_rowan()
	$Guide.hide(); $Rival.hide(); $Rider.hide()

func restore_rowan() -> void:
	if not rowan_staged: return
	rowan_staged = false
	rowan.visible = rowan_visible; rowan.set_physics_process(rowan_processing)
	rowan.chatting = 0

func clear() -> void:
	if not phase.is_empty(): restore_rowan()
	phase = ""; result = ""; race_horse = null
	player.race_countdown = false
	hud.hide(); $Guide.hide(); $Rival.hide(); $Rider.hide()

func _input(event: InputEvent) -> void:
	if event.is_echo() or player.controls_blocked: return
	if active() and event.is_action_pressed("talk"):
		cancel(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("companion") and can_invite():
		invite(); get_viewport().set_input_as_handled()
