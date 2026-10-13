extends Control

@onready var world: Node = get_parent().get_parent()
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var rig: Node3D = world.get_node("CameraRig")
@onready var sound: Node = world.get_node("VillageSound")
@onready var map: Control = world.get_node("HUD/VillageMap")
@onready var pages: VBoxContainer = $Settings/Content/Scroll/Pages
var entered := false
var current_menu := ""
var language := 0
var weather := 1
var graphics := 0
var skip_guide := false
var reduced_motion := false
var sensitivity := 1.0
var mix := {"music":.15,"world":.54,"effects":.75,"rain":.12,"fire":.35,"master":.5}
var soundtrack := 0
var bindings: Dictionary = {}
var defaults: Dictionary = {}
var rebinding := ""
var pending_key := 0
var conflict := ""
var weather_blend := Vector3.ZERO
var update_time := 0.0
var loading := true
var auto_low := false
var auto_time := 0.0
var auto_slow := 0.0
var english_labels: Dictionary = {}
const JAPANESE := {
	"Reduce motion":"動きを減らす", "Sound balance":"音量バランス", "Reset sound":"リセット", "Turn sound on":"音をオンにする", "Turn sound off":"音をオフにする", "Soundtrack":"サウンドトラック", "Recorded music by Holizna.":"録音音楽：Holizna。", "Music":"音楽", "World":"世界", "Effects":"効果音", "Rain":"雨", "Fire":"火", "Volume":"音量", "Reset keys":"キーをリセット", "Village guide":"村のガイド", "Read the village guide":"村のガイドを読む", "E   Continue":"E   続ける", "Esc   Back":"Esc   戻る", "Esc   Back   ⌫":"Esc   戻る   ⌫", "Move forward":"前に移動", "Move left":"左に移動", "Move back":"後ろに移動", "Move right":"右に移動", "Hold to run / canter":"走る・駈歩", "Jump / brake":"ジャンプ・ブレーキ", "Glide":"滑る", "Recover":"復帰", "Interact":"調べる", "Talk / feed":"会話・餌をあげる", "Walk with a resident":"村人と散歩", "Crumbs / forage":"パンくず・採集", "Walk with a dog":"犬と散歩", "Dog home":"犬を帰す", "Dog sit":"おすわり", "Dog dance":"ダンス", "Dog spin":"回る", "Dog bow":"おじぎ", "Dog wave":"手を振る", "Dog roll":"転がる", "Map":"地図", "Sound":"音", "Settings":"設定", "Language":"言語", "Credits":"クレジット"
}
const PREFS := "user://preferences.cfg"

func _ready() -> void:
	for control: Node in find_children("*","",true,false):
		if (control is Label or control is Button) and not control is OptionButton:
			english_labels[control.get_path()] = control.text
	for row: Node in pages.get_node("Controls/Bindings").get_children():
		var action := str(row.name)
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				defaults[action] = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				break
	bindings = defaults.duplicate()
	load_preferences()
	refresh_fields()
	loading = false
	apply_preferences()
	rig.title_screen = true
	sync_blocking()
	$Starter/Content/Menu/Enter.grab_focus()

func is_open() -> bool:
	return not entered or not current_menu.is_empty()

func sync_blocking() -> void:
	var was_blocked: bool = player.controls_blocked
	player.controls_blocked = is_open() or map.expanded
	rig.controls_blocked = player.controls_blocked
	world.get_node("HUD/Actions").visible = entered and not map.expanded
	world.get_node("HUD/Wordmark").visible = entered and not map.expanded
	world.get_node("HUD/Hints").visible = entered and not map.expanded and not player.activity_locked
	map.visible = entered
	world.get_node("FocusCottage").refresh()
	var pointer_activity: bool = world.get_node("FocusCottage").inside or not world.get_node("QuietPlaces").active.is_empty()
	if player.controls_blocked or pointer_activity:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif was_blocked or not rig.mouse_released:
		rig.capture_mouse()

func enter_game(show_guide := true) -> void:
	entered = true
	$Starter.hide()
	rig.title_screen = false
	rig.camera.rotation = Vector3.ZERO
	rig.global_position = player.get_global_transform_interpolated().origin+Vector3(0,1.35,0)
	rig.camera.position = Vector3(0,0,rig.visible_distance)
	close_menu()
	if show_guide and not skip_guide: open_guide()

func open_settings() -> void:
	open_menu("Settings")
	set_tab(0)

func open_sound() -> void:
	open_menu("Settings")
	set_tab(1)

func open_language() -> void:
	open_menu("Language")

func open_inventory() -> void:
	var life: Node = world.get_node("VillageLife")
	$Inventory/Content/Text.text = world.get_node("VillageActivities").inventory_text(true)+"\n\n"+tr_pair("Bread crumbs","パンくず")+"   "+str(life.crumbs)+"\n"+tr_pair("Owl treats","フクロウのおやつ")+"   "+str(life.owl_treats)
	open_menu("Inventory")

func open_credits() -> void:
	open_menu("Credits")

func open_guide() -> void:
	open_menu("Guide")

func open_menu(menu: String) -> void:
	if map.expanded: map.toggle_map()
	for node_name: String in ["Settings","Guide","Language","Credits","Inventory"]: get_node(node_name).hide()
	current_menu = menu
	get_node(menu).show()
	$Dim.show()
	sync_blocking()
	var first: Control = get_node(menu+"/Content").find_child("Close",true,false) as Control
	if first: first.grab_focus()
	else: get_node(menu+"/Content/Back").grab_focus()

func close_menu() -> void:
	for node_name: String in ["Settings","Guide","Language","Credits","Inventory"]: get_node(node_name).hide()
	current_menu = ""
	rebinding = ""; conflict = ""
	$Dim.hide()
	sync_blocking()
	if not entered: $Starter/Content/Menu/Enter.grab_focus()

func set_tab(index: int) -> void:
	for i in 3:
		pages.get_child(i).visible = i == index
	$Settings/Content/Scroll.scroll_vertical = 0
	for i in 3:
		var button := $Settings/Content/Tabs.get_child(i) as Button
		button.set_pressed_no_signal(i == index)
	call_deferred("fit_settings")

func fit_settings() -> void:
	var index := 0 if pages.get_node("Experience").visible else 1 if pages.get_node("Sound").visible else 2
	$Settings.size.y = [700,870,1040][index]
	$Settings.position = Vector2(size.x-420-(20.0 if entered else size.x*.07),20.0 if entered else (size.y-$Settings.size.y)*.5)

func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	# Activity handlers may consume Escape before the camera receives it.
	if entered and not player.controls_blocked and event.is_action_pressed("release_mouse"):
		rig.release_mouse()
	var quiet := world.get_node_or_null("QuietPlaces")
	if quiet and quiet.active=="gratitude" and current_menu.is_empty():
		var focused := get_viewport().gui_get_focus_owner()
		if focused is TextEdit or focused is LineEdit: return
	if not rebinding.is_empty() and event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ESCAPE,KEY_BACKSPACE]:
			rebinding = ""; conflict = ""; pages.get_node("Controls/Status").text = ""
		elif event.keycode in [KEY_ENTER,KEY_TAB,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
			pages.get_node("Controls/Status").text = "That key is reserved for menu navigation."
		else:
			accept_binding(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_inventory"):
		if current_menu == "Inventory": close_menu()
		else: open_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_settings"):
		if current_menu == "Settings": close_menu()
		else: open_settings()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_sound"):
		if current_menu == "Settings" and pages.get_node("Sound").visible: close_menu()
		else: open_sound()
		get_viewport().set_input_as_handled()
	elif is_open() and (event.is_action_pressed("release_mouse") or event.is_action_pressed("menu_back")):
		close_menu()
		get_viewport().set_input_as_handled()
	elif not entered and current_menu.is_empty() and (event.is_action_pressed("interact") or event.is_action_pressed("menu_accept")):
		enter_game()
		get_viewport().set_input_as_handled()
	elif current_menu == "Guide" and (event.is_action_pressed("interact") or event.is_action_pressed("menu_accept")):
		close_menu()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	save_preferences()

func set_weather(index: int) -> void:
	weather = index
	save_preferences()

func set_graphics(index: int) -> void:
	graphics = index
	apply_graphics()
	save_preferences()

func apply_graphics() -> void:
	var low := graphics == 1 or (graphics == 2 and auto_low)
	world.get_node("Sun").shadow_enabled = not low
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_4X

func set_language(index: int) -> void:
	language = index
	apply_language()
	refresh_hints()
	world.get_node("HUD/Speech").panel_states.fill("")
	save_preferences()

func choose_language(index: int) -> void:
	set_language(index)
	close_menu()

func apply_language() -> void:
	for path: NodePath in english_labels:
		var control: Node = get_node(path)
		var original: String = english_labels[path]
		control.text = str(JAPANESE.get(original,original)) if language == 1 else original
	var ja := language == 1
	$Starter/Content/Title.text = "ハースウィロー" if ja else "Hearthwillow"
	$Starter/Content/Menu/Enter.text = "ハースウィローに入る" if ja else "Enter Hearthwillow"
	$Starter/Content/Menu/Language.text = "言語                         日本語" if ja else "Language                         English"
	$Starter/Content/Menu/Settings.text = "設定" if ja else "Settings"
	$Settings/Content/Heading/Title.text = "設定" if ja else "Settings"
	for i in 3: $Settings/Content/Tabs.get_child(i).text = ["体験","サウンド","操作"][i] if ja else ["Experience","Sound","Controls"][i]
	$Settings/Content/FooterRow/Footer.text = "変更はこの端末に保存されます。" if ja else "Changes save on this device."
	pages.get_node("Experience/WeatherLabel").text = "時間と天気" if ja else "Time & weather"
	pages.get_node("Experience/GraphicsLabel").text = "画質" if ja else "Graphics"
	pages.get_node("Experience/LanguageLabel").text = "言語" if ja else "Language"
	pages.get_node("Experience/SkipGuide").text = "チュートリアルを表示しない" if ja else "Don't show tutorial"
	var choices := [["Experience/Weather",["Follow local time","Golden hour","Blue hour","Night","Rain"],["現地時間に合わせる","夕暮れ","薄暮","夜","雨"]],["Experience/Graphics",["Detailed","Low power","Automatic"],["高画質","省電力","自動"]],["Sound/Soundtrack",["Follow the scenery","Village paths","Pond & tea garden","Quiet cottage","By the hearth"],["景色に合わせる","村の小道","池と茶園","静かな家","炉のそば"]]]
	for choice: Array in choices:
		var option := pages.get_node(choice[0]) as OptionButton
		for index in option.item_count: option.set_item_text(index,choice[2][index] if ja else choice[1][index])
	refresh_hints()
	refresh_fields()
	set_sensitivity(sensitivity)

func set_skip_guide(value: bool) -> void:
	skip_guide = value
	save_preferences()

func set_sensitivity(value: float) -> void:
	sensitivity = value
	rig.sensitivity = .0022*value
	pages.get_node("Controls/SensitivityLabel").text = tr_pair("Mouse sensitivity","マウス感度")+"   "+str(roundi(value*100))+"%"
	save_preferences()

func set_mix(value: float, channel: String) -> void:
	mix[channel] = value
	pages.get_node("Sound/"+channel.capitalize()+"Row/Value").text = str(roundi(value*100))+"%"
	sound.apply_mix(mix)
	save_preferences()

func set_soundtrack(index: int) -> void:
	soundtrack = index
	sound.soundtrack = index
	save_preferences()

func toggle_audio() -> void:
	sound.toggle_sound()
	refresh_audio_label()

func reset_sound() -> void:
	mix = {"music":.15,"world":.54,"effects":.75,"rain":.12,"fire":.35,"master":.5}
	soundtrack = 0
	refresh_fields()
	sound.apply_mix(mix)
	sound.soundtrack = 0
	save_preferences()

func begin_rebind(action: String) -> void:
	rebinding = action
	conflict = ""
	pending_key = 0
	pages.get_node("Controls/Status").text = "Press a replacement key. Escape cancels."

func accept_binding(key: int) -> void:
	if key == pending_key and not conflict.is_empty():
		bindings[conflict] = bindings[rebinding]
	else:
		for action: String in bindings:
			if action != rebinding and bindings[action] == key:
				pending_key = key
				conflict = action
				pages.get_node("Controls/Status").text = "Used by "+action.replace("_"," ")+". Press the same key again to swap."
				return
	bindings[rebinding] = key
	apply_bindings()
	rebinding = ""; conflict = ""; pending_key = 0
	pages.get_node("Controls/Status").text = "Key saved."
	save_preferences()

func reset_keys() -> void:
	bindings = defaults.duplicate()
	apply_bindings()
	save_preferences()

func apply_bindings() -> void:
	for action: String in bindings:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				if key not in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: InputMap.action_erase_event(action,event)
		var event := InputEventKey.new()
		event.physical_keycode = int(bindings[action]) as Key
		InputMap.action_add_event(action,event)
		pages.get_node("Controls/Bindings/"+action+"/Key").text = key_name(action)
	refresh_hints()
	world.get_node("HUD/Speech").panel_states.fill("")

func key_name(action: String) -> String:
	var key: int = int(bindings.get(action,0))
	return "," if key == KEY_COMMA else OS.get_keycode_string(key)

func tr_pair(en: String, ja: String) -> String:
	return ja if language == 1 else en

func refresh_audio_label() -> void:
	pages.get_node("Sound/Toggle").text = tr_pair("Turn sound off","音をオフにする") if sound.enabled else tr_pair("Turn sound on","音をオンにする")
	world.get_node("HUD/Actions/Buttons/Sound").text = tr_pair("Sound: on","音：オン") if sound.enabled else tr_pair("Sound: off","音：オフ")
	world.get_node("HUD/Actions/Buttons/Sound").text += " · "+key_name("toggle_sound")

func refresh_hints() -> void:
	var movement := key_name("move_forward")+" "+key_name("move_left")+" "+key_name("move_back")+" "+key_name("move_right")
	$Starter/Hint.text = movement+"   "+tr_pair("Move","移動")+"       "+tr_pair("Mouse to look","マウスで見回す")+"       "+key_name("interact")+"   "+tr_pair("Interact","調べる")
	for group: Array in [["Move",["move_forward","move_left","move_back","move_right"],"Move","移動"],["Run",["dash"],"Hold to run","長押しで走る"],["Interact",["interact"],"Interact","調べる"],["Recover",["unstuck"],"Recover","復帰"]]:
		for action: String in group[1]: world.get_node("HUD/Hints/Row/"+group[0]+"/"+action+"/Text").text = key_name(action)
		world.get_node("HUD/Hints/Row/"+group[0]+"/Caption").text = tr_pair(group[2],group[3])
	world.get_node("HUD/Hints/Row/Focus/Caption").text = tr_pair("Focus next button","次のボタンへ")
	world.get_node("HUD/Hints/Row/Look").text = tr_pair("Mouse to look · Esc to release","マウスで見回す · Escで解除")
	world.get_node("HUD/Actions/Buttons/Map").text = tr_pair("Map","地図")+" · "+key_name("toggle_map")
	world.get_node("HUD/Actions/Buttons/Settings").text = ""
	world.get_node("HUD/Actions/Buttons/Settings/Content/Key/Text").text = key_name("toggle_settings")
	refresh_audio_label()
	$Guide/Content/Text.text = tr_pair("Move","移動")+"\n"+movement+" "+tr_pair("to move. Mouse look starts automatically. Escape releases the pointer; click the view to resume.","で移動。マウスでそのまま見回せます。Escでポインターを解除し、画面をクリックして戻ります。")+"\n\n"+tr_pair("Village map","村の地図")+"\n"+key_name("toggle_map")+" "+tr_pair("opens the map. Drag to pan; scroll to zoom.","で地図を開きます。ドラッグで移動、スクロールでズーム。")+"\n\n"+tr_pair("Conversations","会話")+"\n"+key_name("talk")+" "+tr_pair("talks to a nearby villager or feeds an animal.","で村人と話す・動物に餌をあげる。")+" "+key_name("companion")+" "+tr_pair("invites a walking companion.","で一緒に散歩。")+" "+key_name("interact")+" "+tr_pair("pets an animal or mounts a horse.","で動物をなでる・馬に乗る。")+"\n\n"+tr_pair("Settings","設定")+"\n"+key_name("toggle_settings")+" "+tr_pair("opens Settings.","で設定を開きます。")+" "+key_name("toggle_sound")+" "+tr_pair("opens Sound. Escape leaves menus.","で音の設定。Escで戻ります。")

func refresh_fields() -> void:
	for pair: Array in [["Experience/Weather",weather],["Experience/Graphics",graphics],["Experience/Language",language],["Sound/Soundtrack",soundtrack]]:
		pages.get_node(pair[0]).select(pair[1])
	pages.get_node("Experience/SkipGuide").set_pressed_no_signal(skip_guide)
	pages.get_node("Experience/ReducedMotion").set_pressed_no_signal(reduced_motion)
	pages.get_node("Controls/Sensitivity").set_value_no_signal(sensitivity)
	for channel: String in mix:
		pages.get_node("Sound/"+channel.capitalize()+"Row/Slider").set_value_no_signal(mix[channel])
		pages.get_node("Sound/"+channel.capitalize()+"Row/Value").text = str(roundi(mix[channel]*100))+"%"

func apply_preferences() -> void:
	apply_bindings()
	apply_graphics()
	apply_language()
	set_sensitivity(sensitivity)
	sound.apply_mix(mix)
	sound.soundtrack = soundtrack

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(PREFS) != OK: return
	language = clampi(int(config.get_value("experience","language",0)),0,1)
	weather = clampi(int(config.get_value("experience","weather",1)),0,4)
	graphics = clampi(int(config.get_value("experience","graphics",0)),0,2)
	skip_guide = bool(config.get_value("experience","skip_guide",false))
	reduced_motion = bool(config.get_value("experience","reduced_motion",false))
	sensitivity = clampf(float(config.get_value("controls","sensitivity",1.0)),.25,2)
	soundtrack = clampi(int(config.get_value("sound","soundtrack",0)),0,4)
	for channel: String in mix: mix[channel] = clampf(float(config.get_value("sound",channel,mix[channel])),0,1)
	for action: String in bindings: bindings[action] = int(config.get_value("keys",action,bindings[action]))

func save_preferences() -> void:
	if loading: return
	var config := ConfigFile.new()
	config.set_value("experience","language",language)
	config.set_value("experience","weather",weather)
	config.set_value("experience","graphics",graphics)
	config.set_value("experience","skip_guide",skip_guide)
	config.set_value("experience","reduced_motion",reduced_motion)
	config.set_value("controls","sensitivity",sensitivity)
	config.set_value("sound","soundtrack",soundtrack)
	for channel: String in mix: config.set_value("sound",channel,mix[channel])
	for action: String in bindings: config.set_value("keys",action,bindings[action])
	var result := config.save(PREFS)
	if result != OK: pages.get_node("Controls/Status").text = "Settings could not be saved."

func _process(delta: float) -> void:
	if graphics == 2 and entered and current_menu.is_empty():
		auto_time += delta
		if delta > .012: auto_slow += delta
		if auto_time >= 8:
			var next_low := auto_slow > 2 if not auto_low else auto_slow > .5
			if next_low != auto_low:
				auto_low = next_low
				apply_graphics()
			auto_time = 0; auto_slow = 0
	var selected := weather
	if selected == 0:
		var hour: int = Time.get_time_dict_from_system().hour
		selected = 3 if hour < 6 or hour >= 20 else 2 if hour >= 17 else 1
	var target := Vector3(float(selected == 4),float(selected == 2),float(selected == 3))
	weather_blend = weather_blend.lerp(target,1-exp(-delta*1.2))
	if weather_blend.distance_squared_to(target) < .000001: weather_blend = target
	world.get_node("VillageLighting").set_weather(weather_blend)
	var sky: ShaderMaterial = world.get_node("WorldEnvironment").environment.sky.sky_material
	sky.set_shader_parameter("rain",weather_blend.x)
	sky.set_shader_parameter("dusk",weather_blend.y)
	sky.set_shader_parameter("night",weather_blend.z)
	var sun := world.get_node("Sun") as DirectionalLight3D
	sun.light_energy = (1.15-weather_blend.y*.98-weather_blend.x*.94)*(1-weather_blend.z)+.025*weather_blend.z
	sun.light_color = Color("ffe5b2").lerp(Color("efa885"),weather_blend.y).lerp(Color("cedbe2"),weather_blend.x).lerp(Color("b3c8ed"),weather_blend.z)
	var environment: Environment = world.get_node("WorldEnvironment").environment
	environment.ambient_light_energy = .45*(1-weather_blend.z)+.09*weather_blend.z
	environment.ambient_light_color = Color("bfd8ef").lerp(Color("7b97d0"),weather_blend.y).lerp(Color("b3c6cf"),weather_blend.x).lerp(Color("6882b9"),weather_blend.z)
	environment.fog_light_color = Color("bfd9da").lerp(Color("8894bf"),weather_blend.y).lerp(Color("a3b8bd"),weather_blend.x).lerp(Color("172544"),weather_blend.z)
	environment.fog_density = .0046+weather_blend.x*.005+weather_blend.y*.001+weather_blend.z*.0007
	environment.tonemap_exposure = 1.02+weather_blend.y*.06-weather_blend.z*.08
	var rain := world.get_node("WeatherRain") as GPUParticles3D
	rain.position = player.position+Vector3(0,8,0)
	rain.emitting = selected == 4
	update_time -= delta
	if update_time <= 0:
		update_time = .5
		pages.get_node("Experience/Performance").text = str(roundi(Engine.get_frames_per_second()))+" FPS   ·   1920 × 1080"
