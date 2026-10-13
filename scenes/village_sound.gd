extends Node

@export var music_level: float = .15
@export var world_level: float = .54
@export var master_level: float = .5
@export var effects_level: float = .75
@export var walking_gain: float = .25
@export var riding_gain: float = .18
@export var contact_interval: float = .22

@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var surface: Node = get_parent().get_node("WorldSurface")
@onready var music: AudioStreamPlayer = $Music
@onready var wind: AudioStreamPlayer = $Wind
@onready var rain: AudioStreamPlayer = $Rain
@onready var stream: AudioStreamPlayer3D = $Stream
@onready var fire: AudioStreamPlayer3D = $Fire
@onready var footsteps: AudioStreamPlayer = $Footsteps
@onready var birds: AudioStreamPlayer3D = $Birds
@onready var button: Button = get_parent().get_node("HUD/Actions/Buttons/Sound")

var enabled := false
var bird_countdown := 9.0
var last_step := -1
var last_contact_time := -1.0
var stream_countdown := 0.0
var last_animal_call := -10.0
@onready var shelter_filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index("Outdoor"),0)
var rain_level := .12
var fire_level := .35
var soundtrack := 0
var current_track := 1
var soundtrack_countdown := 0.0
var music_fade := 1.0
@onready var music_next: AudioStreamPlayer = $MusicNext

func _ready() -> void:
	for voice in [music,music_next,wind,rain,stream,fire]:
		voice.stream = voice.stream.duplicate()
		if voice.stream is AudioStreamWAV:
			voice.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			voice.stream.loop_end = int(voice.stream.get_length()*voice.stream.mix_rate)
		else: voice.stream.loop = true
	music.volume_db = linear_to_db(music_level*1.2*master_level*.65)
	music_next.volume_db = -80
	wind.volume_db = linear_to_db(.0225*world_level*master_level*.65)
	rain.volume_db = linear_to_db(rain_level*world_level*master_level*.65)
	stream.volume_db = linear_to_db(.65*world_level*master_level*.65)
	fire.volume_db = linear_to_db(fire_level*1.2*world_level*master_level*.65)
	birds.volume_db = linear_to_db(world_level*master_level*.65)

func toggle_sound() -> void:
	enabled = not enabled
	button.text = "Sound: on · O" if enabled else "Sound: off · O"
	for voice in [music,wind,rain,stream,fire]:
		if enabled: voice.play()
		else: voice.stop()
	if not enabled:
		music_next.stop()
		music_fade = 1
		footsteps.stop()
		birds.stop()
		$Animals.stop()
		$Garden.stop()
		get_parent().get_node("FocusCottage/Chime").stop()

func garden_effect(kind: String, point: Vector3) -> void:
	if not enabled or master_level <= 0 or effects_level <= 0 or player.position.distance_to(point)>23: return
	var file := "res://assets/audio/garden-"+kind+".wav"
	if not ResourceLoader.exists(file): return
	var voice: AudioStreamPlayer3D = $Garden
	voice.stream = load(file)
	voice.position = point
	voice.pitch_scale = randf_range(.96,1.04)
	voice.volume_db = linear_to_db(.28*effects_level*master_level*.65)
	voice.play()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_sound"): toggle_sound()

func _process(delta: float) -> void:
	if not enabled: return
	music_fade = minf(1,music_fade+delta*.5)
	var music_gain := music_level*1.2*master_level*.65
	music.volume_db = linear_to_db(maxf(.00001,music_gain*music_fade))
	music_next.volume_db = linear_to_db(maxf(.00001,music_gain*(1-music_fade)))
	if music_fade >= 1 and music_next.playing: music_next.stop()
	soundtrack_countdown -= delta
	if soundtrack_countdown <= 0:
		soundtrack_countdown = 1
		update_soundtrack()
	var time := Time.get_ticks_msec()/1000.0
	var sheltered: bool = get_parent().get_node("FocusCottage").inside
	var shelter := .13 if sheltered else 1.0
	var weather: Vector3 = get_parent().get_node("HUD/Menus").weather_blend
	shelter_filter.cutoff_hz = lerpf(shelter_filter.cutoff_hz,950.0 if sheltered else lerpf(6500,3500,weather.x),1-exp(-delta/.7))
	var hearth: Dictionary = surface.placements.get("hearth",[{}])[0]
	fire.position = get_parent().get_node("FocusCottage/Flame").global_position if sheltered else Vector3(hearth.position[0],.5,hearth.position[2])
	rain.volume_db = lerpf(rain.volume_db,linear_to_db(maxf(.00001,(rain_level+weather.x*.55)*world_level*master_level*.65*shelter)),1-exp(-delta/.7))
	stream.volume_db = lerpf(stream.volume_db,linear_to_db(maxf(.00001,.65*world_level*master_level*.65*shelter)),1-exp(-delta/.6))
	var strength := .22+(sin(time*.23)*.5+.5)*.18+pow(maxf(0,sin(time*.61-.7)),3)*.34
	wind.volume_db = lerpf(wind.volume_db,linear_to_db(maxf(.00001,(.012+strength*.035)*world_level*master_level*.65*shelter)),1-exp(-delta/.35))
	bird_countdown -= delta
	if bird_countdown <= 0 and not sheltered and weather.length_squared()<.05:
		bird_countdown = randf_range(7,17)
		birds.position = player.position+Vector3(randf_range(-7,7),6,-10)
		birds.stream = load("res://assets/audio/bird_%d.wav" % randi_range(0,3))
		birds.play()
	stream_countdown -= delta
	if stream_countdown > 0: return
	stream_countdown = .1
	# Reposition the source at 10 Hz; the listener itself still updates every frame.
	var point := Vector2(player.position.x,player.position.z)
	var nearest := Vector2(-11,point.y)
	var best := INF
	for river: Dictionary in surface.data.rivers:
		var candidate: Vector2 = surface.closest_route_point(point,river)
		var gap := candidate.distance_squared_to(point)
		if gap < best:
			best = gap
			nearest = candidate
	stream.position = Vector3(nearest.x,surface.floor_at(nearest),nearest.y)

func animal_call(kind: String, point: Vector3, happy: bool, actor_id := "") -> void:
	if not enabled: return
	var now := Time.get_ticks_msec()/1000.0
	if now-last_animal_call < (.8 if happy else 6.0): return
	var clip: String = "purr" if kind=="cat" and happy else {"puppy-mochi":"mochi-yip","puppy-kiko":"kiko-yip","puppy-biscuit":"biscuit-yip","puppy-cloud":"cloud-yip"}.get(actor_id,kind)
	var file := "res://assets/audio/"+clip+".mp3"
	if not ResourceLoader.exists(file): return
	var voice: AudioStreamPlayer3D = $Animals
	voice.position = point+Vector3(0,.8,0)
	voice.stream = load(file)
	var level: float = {"cow":.9,"sheep":.8,"lamb":.7,"hedgehog":.45,"owl":.8,"horse":.85,"dog":.26,"dove":.7}.get(kind,.5)
	voice.volume_db = linear_to_db(level*1.35*(1.0 if happy else .7)*effects_level*master_level*.65)
	voice.pitch_scale = randf_range(.97,1.03)
	voice.play()
	last_animal_call = now

func on_step(kind: String) -> void:
	var speed := Vector2(player.velocity.x,player.velocity.z).length()
	var now := Time.get_ticks_msec()/1000.0
	if speed < .2 or player.controls_blocked or player.activity_locked or now-last_contact_time < contact_interval: return
	last_contact_time = now
	play_contact(kind, (.25+minf(speed,7)*.022)*riding_gain if player.mount else (.16+speed*.016)*walking_gain, player.mount != null)

func on_jump() -> void:
	play_contact(surface.contact_surface(Vector2(player.position.x,player.position.z)),.11*walking_gain)

func on_land() -> void:
	play_contact(surface.contact_surface(Vector2(player.position.x,player.position.z)),.3*walking_gain)

func play_contact(kind: String, level: float, riding := false) -> void:
	if not enabled or master_level <= 0 or effects_level <= 0: return
	var variants := 4 if riding else 6
	var variant := randi_range(0,variants-1)
	if variant == last_step: variant = (variant+1)%variants
	last_step = variant
	footsteps.stream = load("res://assets/audio/%s_%s_%d.wav" % ["hoof" if riding else "step",kind,variant])
	footsteps.volume_db = linear_to_db(level*effects_level*master_level*.65)
	footsteps.pitch_scale = randf_range(.96,1.04)
	footsteps.play()

func apply_mix(mix: Dictionary) -> void:
	music_level = float(mix.music)
	world_level = float(mix.world)
	effects_level = float(mix.effects)
	master_level = float(mix.master)
	rain_level = float(mix.rain)
	fire_level = float(mix.fire)
	get_parent().get_node("FocusCottage/Chime").volume_db = linear_to_db(maxf(.00001,effects_level*master_level*.65))
	var shelter := .13 if get_parent().get_node("FocusCottage").inside else 1.0
	var weather: Vector3 = get_parent().get_node("HUD/Menus").weather_blend
	rain.volume_db = linear_to_db(maxf(.00001,(rain_level+weather.x*.55)*world_level*master_level*.65*shelter))
	stream.volume_db = linear_to_db(maxf(.00001,.65*world_level*master_level*.65*shelter))
	fire.volume_db = linear_to_db(maxf(.00001,fire_level*1.2*world_level*master_level*.65))
	birds.volume_db = linear_to_db(maxf(.00001,world_level*master_level*.65))
	music.volume_db = linear_to_db(maxf(.00001,music_level*1.2*master_level*.65*music_fade))
	music_next.volume_db = linear_to_db(maxf(.00001,music_level*1.2*master_level*.65*(1-music_fade)))
	wind.volume_db = linear_to_db(maxf(.00001,.0225*world_level*master_level*.65*shelter))
	footsteps.volume_db = minf(footsteps.volume_db,linear_to_db(maxf(.00001,effects_level*master_level*.65)))
	$Animals.volume_db = minf($Animals.volume_db,linear_to_db(maxf(.00001,effects_level*master_level*.65)))

func update_soundtrack() -> void:
	var desired := soundtrack
	if desired == 0:
		var menus: Node = get_parent().get_node("HUD/Menus")
		desired = 3 if get_parent().get_node("FocusCottage").inside or menus.weather_blend.length() > .4 else 1
		for item: Dictionary in surface.data.items:
			if item.asset not in ["hearth","pond","garden-kitchen"]: continue
			var gap := Vector2(player.position.x-item.position[0],player.position.z-item.position[2]).length()
			if gap < (8 if item.asset == "hearth" else 12):
				desired = 4 if item.asset == "hearth" else 2
				break
	if desired == current_track: return
	music_next.stop()
	music_next.stream = music.stream
	music_next.play(music.get_playback_position())
	var recording: AudioStreamMP3 = load("res://assets/audio/quiet-village-%d.mp3"%desired).duplicate()
	recording.loop = true
	music.stream = recording
	music.volume_db = -80
	music_next.volume_db = linear_to_db(maxf(.00001,music_level*1.2*master_level*.65))
	music.play()
	current_track = desired
	music_fade = 0
