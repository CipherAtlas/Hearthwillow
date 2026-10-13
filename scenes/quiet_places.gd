extends Node3D

@onready var world: Node = get_parent()
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var rig: Node3D = world.get_node("CameraRig")
@onready var menus: Node = world.get_node("HUD/Menus")
@onready var surface: Node = world.get_node("WorldSurface")
@onready var journal: PanelContainer = $UI/Journal
@onready var pond: Node3D = world.get_node("PondLife")
var active := ""
var nearby := ""
var return_position := Vector3.ZERO
var return_view := Vector3.ZERO
var orbit := Vector2.ZERO
var base_camera := Vector3.ZERO
var base_look := Vector3.ZERO
var saved_visual := Transform3D.IDENTITY
var saved_left := Transform3D.IDENTITY
var saved_right := Transform3D.IDENTITY
var notes: Dictionary = {}
var note_index := 0
var kept_index := -1
var note_read_failed := false
var note_saved := false
var elapsed := 0.0
var entered_at := 0.0
var moment_at := -100.0
var moment := ""
var pattern := 0
var breathing := false
var breath_elapsed := 0.0
var breath_amount := 0.0
var breath_phase := 0
var breath_left := 4.0
var collapsed := false
const TIMES := [[4.0,4.0,6.0,0.0],[4.0,4.0,4.0,4.0],[4.0,7.0,8.0,0.0]]
@export var kind_save_path := "user://kind-note.cfg"
const STAGES := {
	"gratitude":{"actor":Vector3(-18.2,.05,6.6),"yaw":-PI/2,"camera":Vector3(-16.5,2.8,7.7),"look":Vector3(-19.1,1.2,6.5)},
	"compliment":{"actor":Vector3(3.05,.05,.35),"yaw":PI,"camera":Vector3(5.2,2.4,-3.2),"look":Vector3(3,1.25,-.4)},
	"breathe":{"actor":Vector3(-23,.24,-5.5),"yaw":PI,"camera":Vector3(-18.5,3.7,-2),"look":Vector3(-26,.5,-9)}
}

func words(en: String, ja: String) -> String:
	return menus.tr_pair(en,ja)

func _ready() -> void:
	notes = JSON.parse_string(FileAccess.get_file_as_string("res://assets/quiet/kind-notes.json"))
	load_kind_note()
	$Ritual/Quill.position = Vector3(-19.2,1.03,6.09)
	$Ritual/Quill.rotation.y = PI/2
	$Ritual/Page.position = Vector3(-19.25,1.02,6.35)
	refresh()

func load_kind_note() -> bool:
	note_read_failed = false; kept_index = -1; note_saved = false
	note_index = int(Time.get_unix_time_from_system()/86400)%notes.en.size()
	var config := ConfigFile.new()
	if FileAccess.file_exists(kind_save_path):
		if config.load(kind_save_path)==OK:
			kept_index = notes.en.find(config.get_value("note","text",""))
			if kept_index>=0: note_index = kept_index; note_saved = true
		else:
			note_read_failed = true
			$UI/Kind/Content/Status.text = words("Saved note could not be read. Stored data was not changed.","保存済みのメモを読み込めませんでした。データは変更していません。")
	return not note_read_failed

func placed_point(id: String, original: Vector3) -> Vector3:
	var asset := "dock" if id=="breathe" else "postbox" if id=="compliment" else ""
	var origin := Vector3(-21.65,0,-5.5) if id=="breathe" else Vector3(3,0,-1)
	if asset.is_empty(): return original
	var items: Array = surface.placements.get(asset,[])
	if items.is_empty(): return original
	return surface.item_transform(items[0])*(original-origin)

func entry_point(id: String) -> Vector3:
	return placed_point(id,Vector3(-19.5,0,8) if id=="gratitude" else Vector3(2.8,0,0) if id=="compliment" else Vector3(-23.2,.24,-5.5))

func scan() -> void:
	nearby = ""
	if not active.is_empty() or player.controls_blocked or player.activity_locked or player.mount or world.get_node("FocusCottage").inside: return
	var best := 2.8
	for id: String in STAGES:
		var gap := player.position.distance_to(entry_point(id))
		if gap<best: best = gap; nearby = id

func enter(id: String) -> bool:
	if not STAGES.has(id) or menus.is_open() or world.get_node("HUD/VillageMap").expanded or player.mount or not active.is_empty(): return false
	if world.get_node("FocusCottage").inside or world.get_node("VillageSeating").occupied(): return false
	if player.position.distance_to(entry_point(id))>4: return false
	return_position = player.position; return_view = Vector3(rig.desired_yaw,rig.desired_pitch,rig.distance)
	saved_visual = player.visual.transform; saved_left = player.left_fin.transform; saved_right = player.right_fin.transform
	active = id; entered_at = elapsed; orbit = Vector2.ZERO; collapsed = false; breathing = false; breath_elapsed = 0; breath_amount = 0
	player.activity_locked = true; player.velocity = Vector3.ZERO; player.jump_buffer = 0; player.gliding = false
	player.position = placed_point(id,STAGES[id].actor)
	player.visual.rotation = Vector3(0,STAGES[id].yaw,0)
	if id!="gratitude":
		var asset := "dock" if id=="breathe" else "postbox"
		var items: Array = surface.placements.get(asset,[])
		if not items.is_empty(): player.visual.rotation.y += deg_to_rad(items[0].rotation[1])
	player.reset_physics_interpolation()
	var camera_point: Vector3 = STAGES[id].camera
	var look_point: Vector3 = STAGES[id].look
	if id=="breathe":
		camera_point += Vector3(-4.9,.7,2.5)
		look_point.x += 4.5
	base_camera = placed_point(id,camera_point); base_look = placed_point(id,look_point)
	$Camera.position = base_camera; $Camera.look_at(base_look); $Camera.make_current()
	$Letter.visible = id=="compliment"
	$Rings.visible = id=="breathe"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menus.sync_blocking()
	if id=="gratitude":
		journal.view = "write"; journal.selected = -1; journal.removing = false
		journal.refresh(); journal.editor.call_deferred("grab_focus")
	elif id=="compliment": $UI/Kind/Content/Another.call_deferred("grab_focus")
	else: $UI/Breathe/Content/Toggle.call_deferred("grab_focus")
	refresh()
	return true

func leave() -> void:
	if active.is_empty(): return
	active = ""; breathing = false; collapsed = false
	journal.get_node("Import").hide(); journal.get_node("Export").hide()
	player.activity_locked = false; player.position = return_position; player.velocity = Vector3.ZERO
	player.visual.transform = saved_visual; player.left_fin.transform = saved_left; player.right_fin.transform = saved_right
	player.reset_physics_interpolation()
	rig.desired_yaw = return_view.x; rig.desired_pitch = return_view.y; rig.distance = return_view.z
	rig.camera.make_current(); $Letter.hide(); $Rings.hide(); $Ritual/Page.hide()
	menus.sync_blocking(); refresh()

func another_note() -> void:
	if active!="compliment": return
	note_index = (note_index+1)%notes.en.size(); note_saved = false
	set_moment("letter"); refresh()

func keep_kind_note() -> bool:
	if active!="compliment" or note_read_failed: return false
	var config := ConfigFile.new(); config.set_value("note","text",notes.en[note_index])
	var error := config.save(kind_save_path+".tmp")
	if error==OK: error = DirAccess.rename_absolute(kind_save_path+".tmp",kind_save_path)
	if error!=OK:
		note_saved = false
		$UI/Kind/Content/Status.text = words("Could not keep this note.","メモを保存できませんでした。"); return false
	kept_index = note_index; note_saved = true; set_moment("keep"); refresh(); return true

func set_moment(kind: String) -> void:
	moment = kind; moment_at = elapsed

func toggle_breathing() -> void:
	if active!="breathe": return
	breathing = not breathing; $UI/Breathe/Content/Toggle.flash(); refresh()

func reset_breathing() -> void:
	breathing = false; breath_elapsed = 0; breath_amount = 0; refresh()

func set_pattern(index: int) -> void:
	pattern = clampi(index,0,2); reset_breathing()

func feed_pond() -> bool:
	return pond.feed()

func toggle_controls() -> void:
	collapsed = not collapsed; refresh()

func button_label(path: String, text: String, action: String) -> void:
	var button: Button = get_node(path)
	button.get_node("Row/Text").text = text
	button.action = action
	if not action.is_empty():
		var events := InputMap.action_get_events(action)
		button.set_key(menus.key_name(action) if menus.defaults.has(action) else OS.get_keycode_string(events[0].physical_keycode) if not events.is_empty() else "")

func refresh() -> void:
	if not is_node_ready(): return
	var available: bool = not menus.is_open() and not world.get_node("HUD/VillageMap").expanded
	$UI/Enter.visible = not nearby.is_empty() and available and active.is_empty()
	if not nearby.is_empty(): button_label("UI/Enter",words("Open your journal","日記を開く") if nearby=="gratitude" else words("Read a kind note","メモを読む") if nearby=="compliment" else words("Sit by the pond","池のそばに座る"),"interact")
	journal.visible = active=="gratitude" and available and not collapsed
	$UI/Kind.visible = active=="compliment" and available and not collapsed
	$UI/Breathe.visible = active=="breathe" and available and not collapsed
	$UI/Leave.visible = not active.is_empty() and available
	$UI/Collapse.visible = not active.is_empty() and active!="gratitude" and available
	button_label("UI/Leave",words("Leave","戻る"),"release_mouse")
	button_label("UI/Collapse",words("Show controls","操作を表示") if collapsed else words("Hide controls","操作を隠す"),"toggle_activity")
	$UI/Kind/Content/Heading.text = words("Your note","あなたへ。")
	$UI/Kind/Content/Note.text = "“"+str(notes.ja[note_index] if menus.language==1 else notes.en[note_index])+"”" if not notes.is_empty() else ""
	button_label("UI/Kind/Content/Another",words("Another note","もうひとつ"),"interact")
	button_label("UI/Kind/Content/Keep",words("Kept","残しました") if note_saved else words("Keep","残す"),"keep_note")
	$UI/Kind/Content/Keep.set_enabled(not note_read_failed)
	$UI/Breathe/Content/Heading.text = words("Breathe","深呼吸")
	button_label("UI/Breathe/Content/Toggle",words("Pause","一時停止") if breathing else words("Begin","始める"),"jump")
	button_label("UI/Breathe/Content/Reset",words("Reset","リセット"),"unstuck")
	for i in 3:
		var names := [words("Calm","ゆったり"),words("Box","ボックス"),words("Slow","ゆっくり")]
		var rhythm := ["4–4–6","4–4–4–4","4–7–8"]
		button_label("UI/Breathe/Content/Pattern%d"%i,names[i]+" · "+rhythm[i],"activity_%d"%(i+1))
		get_node("UI/Breathe/Content/Pattern%d"%i).set_pressed_no_signal(i==pattern)
	$UI/Breathe/Content/Feed.visible = true
	$UI/Breathe/Content/Feed.set_enabled(world.get_node("VillageLife").crumbs>0 and pond.elapsed-pond.feed_at>=11)
	button_label("UI/Breathe/Content/Feed",words("Feed the ducks","アヒルたちにパンくずをあげる"),"talk")
	$UI/Breathe/Content/Status.text = pond.feeding_status()
	$UI/Breathe/Content/Status.visible = not $UI/Breathe/Content/Status.text.is_empty()

func _process(delta: float) -> void:
	elapsed += delta; scan(); refresh()
	if active.is_empty(): return
	if breathing: breath_elapsed += delta
	var cycle: float = fmod(breath_elapsed,14.0 if pattern==0 else 16.0 if pattern==1 else 19.0)
	breath_phase = 0
	while breath_phase<3 and cycle>=float(TIMES[pattern][breath_phase]):
		cycle -= float(TIMES[pattern][breath_phase]); breath_phase += 1
	breath_left = float(TIMES[pattern][breath_phase])-cycle
	breath_amount = cycle/float(TIMES[pattern][0]) if breath_phase==0 else 1.0 if breath_phase==1 else 1-cycle/float(TIMES[pattern][2]) if breath_phase==2 else 0.0
	var orbit: Control = $UI/Breathe/Content/Orbit
	orbit.fraction = 1-cycle/maxf(.001,float(TIMES[pattern][breath_phase])) if breathing else 1.0
	orbit.queue_redraw()
	orbit.get_node("Phase").text = [words("Breathe in","吸って"),words("Hold","止めて"),words("Breathe out","吐いて"),words("Rest","止めて")][breath_phase] if breathing else words("Ready","準備完了")
	orbit.get_node("Count").text = str(ceili(breath_left)) if breathing else "~"
	animate_ritual()
	update_camera(delta)

func update_camera(delta: float) -> void:
	var offset := (base_camera-base_look).rotated(Vector3.UP,orbit.x)
	var horizontal := Vector2(offset.x,offset.z).length()
	var pitch := clampf(atan2(offset.y,horizontal)+orbit.y,.08,1.35)
	var distance := offset.length()
	var yaw := atan2(offset.x,offset.z)
	var goal := base_look+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	goal.y = maxf(goal.y,surface.floor_at(Vector2(goal.x,goal.z))+.35)
	$Camera.position = $Camera.position.lerp(goal,1.0 if menus.reduced_motion else 1-exp(-delta*9))
	$Camera.look_at(base_look)

func animate_ritual() -> void:
	var reduced: bool = menus.reduced_motion
	var t := 0.0 if reduced else elapsed
	var age := elapsed-moment_at
	var writing := active=="gratitude" and moment=="write" and age<1.8 and not reduced
	$Ritual/Quill.rotation.z = sin(t*15)*.12 if writing else 0
	$Ritual/Quill.position.z = 6.09-(sin(t*4)*.07 if writing else 0)
	var saving := active=="gratitude" and moment=="save" and age<1.4 and not reduced
	$Ritual/Page.visible = saving
	$Ritual/Page.position.y = 1.02+(sin(age/1.4*PI)*.38 if saving else 0)
	player.visual.position.y = .62+sin(t*1.7)*.025+(.12*breath_amount if active=="breathe" and breathing and not reduced else 0)
	player.visual.scale = saved_visual.basis.get_scale()*(1+.065*breath_amount if active=="breathe" and breathing and not reduced else 1.0)
	player.visual.rotation.x = -.06 if active=="compliment" else .07 if writing else 0.0
	player.visual.rotation.z = 0
	if active=="compliment":
		var opening := 1.0 if reduced else smoothstep(0,1.1,elapsed-entered_at)
		var keep := sin(minf(1,age/1.2)*PI) if moment=="keep" and not reduced else 0.0
		var turn := sin(minf(1,age/.85)*PI) if moment=="letter" and not reduced else 0.0
		$Letter.global_transform = Transform3D(Basis.from_euler(Vector3(0,player.visual.rotation.y,0)),player.position)
		$Letter.position += Vector3(0,.74+sin(t*1.7)*.012+opening*.04-keep*.035,0)
		$Letter.translate_object_local(Vector3(0,0,.42))
		$Letter/Model.rotation.x = -.22-keep*.12
		$Letter/Model.find_child("Flap",true,false).rotation.x = opening*PI*.86
		$Letter/Model.find_child("Sheet",true,false).position.y = opening*.13-turn*.07
		$Letter/Model.find_child("Sheet",true,false).rotation.z = -turn*.06
		for i in 2:
			var fin: Node3D = player.left_fin if i==0 else player.right_fin
			var side := -1.0 if i==0 else 1.0
			fin.position = Vector3(side*.31,.2-keep*.035,.35)/player.visual.scale.x
			fin.rotation = Vector3(0,-side*.3,-side*.18)
	for i in 3:
		var ring: Node3D = $Rings.get_child(i)
		ring.position = placed_point("breathe",Vector3(-25,-.24,-9))
		var ring_size := 1.2 if reduced else 1.05+(breath_amount*.75 if breathing else 0.0)+i*.36
		ring.scale = Vector3(ring_size,.01,ring_size)

func _input(event: InputEvent) -> void:
	if active.is_empty() or menus.is_open() or world.get_node("HUD/VillageMap").expanded or event.is_echo(): return
	if journal.get_node("Import").visible or journal.get_node("Export").visible: return
	if event.is_action_pressed("release_mouse"):
		leave(); get_viewport().set_input_as_handled(); return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		orbit.x -= event.screen_relative.x*rig.sensitivity
		orbit.y = clampf(orbit.y+event.screen_relative.y*rig.sensitivity,-.8,.9)
		get_viewport().set_input_as_handled(); return
	var focused := get_viewport().gui_get_focus_owner()
	if active=="gratitude":
		if event is InputEventKey and event.pressed and event.keycode==KEY_ENTER and (event.ctrl_pressed or event.meta_pressed) and not event.alt_pressed and not journal.editor.has_ime_text():
			journal.save_note(); journal.get_node("Content/Write/Save").flash(); get_viewport().set_input_as_handled()
		return
	if focused is LineEdit or focused is TextEdit: return
	var handled := true
	if event.is_action_pressed("toggle_activity"): toggle_controls()
	elif active=="compliment" and event.is_action_pressed("interact"): another_note(); $UI/Kind/Content/Another.flash()
	elif active=="compliment" and event.is_action_pressed("keep_note"): keep_kind_note(); $UI/Kind/Content/Keep.flash()
	elif active=="breathe" and event.is_action_pressed("jump"): toggle_breathing()
	elif active=="breathe" and event.is_action_pressed("unstuck"): reset_breathing(); $UI/Breathe/Content/Reset.flash()
	elif active=="breathe" and event.is_action_pressed("talk"): feed_pond(); $UI/Breathe/Content/Feed.flash()
	elif active=="breathe" and event.is_action_pressed("activity_1"): set_pattern(0)
	elif active=="breathe" and event.is_action_pressed("activity_2"): set_pattern(1)
	elif active=="breathe" and event.is_action_pressed("activity_3"): set_pattern(2)
	else: handled = false
	if handled: get_viewport().set_input_as_handled()

func enter_nearby() -> void:
	if not nearby.is_empty(): enter(nearby)

func _unhandled_input(event: InputEvent) -> void:
	if not active.is_empty() and not player.controls_blocked:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; get_viewport().set_input_as_handled()
		return
	if not nearby.is_empty() and event.is_action_pressed("interact"):
		enter(nearby); get_viewport().set_input_as_handled()
