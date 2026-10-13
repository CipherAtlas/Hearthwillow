extends Button

@export var action := ""
@export var hold_action := false
@export var keycap_size := 24.0
var feedback: Tween
var pointer_holding := false
var last_key := ""

func _ready() -> void:
	pressed.connect(flash)
	button_down.connect(begin_hold)
	button_up.connect(end_hold)
	visibility_changed.connect(release_hidden)
	if has_node("Row/Key/Text"):
		set_key(get_node("Row/Key/Text").text)

func set_key(value: String) -> void:
	if value == last_key:
		custom_minimum_size.x = get_node("Row").get_combined_minimum_size().x+14.0
		return
	last_key = value
	var cap := get_node("Row/Key") as PanelContainer
	var label := cap.get_node("Text") as Label
	label.text = value
	var wide := value.length() > 1
	var style := cap.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.content_margin_left = 8.0 if wide else 0.0
	style.content_margin_right = 8.0 if wide else 0.0
	cap.add_theme_stylebox_override("panel",style)
	cap.custom_minimum_size.x = maxf(26.0,label.get_theme_font("font").get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+16.0) if wide else keycap_size
	custom_minimum_size.x = get_node("Row").get_combined_minimum_size().x+14.0

func set_enabled(value: bool) -> void:
	if disabled == not value: return
	disabled = not value
	if feedback: feedback.kill()
	modulate = Color.WHITE if value else Color(1,1,1,.5)

func flash() -> void:
	if disabled: return
	if feedback: feedback.kill()
	modulate = Color(1.16,1.16,1.16)
	feedback = create_tween()
	var menus := get_tree().current_scene.get_node_or_null("HUD/Menus")
	if menus and menus.reduced_motion:
		feedback.tween_interval(.16)
		feedback.tween_callback(func(): modulate = Color.WHITE)
	else: feedback.tween_property(self,"modulate",Color.WHITE,.16)

func begin_hold() -> void:
	if hold_action and not disabled and not action.is_empty():
		pointer_holding = true
		Input.action_press(action)

func end_hold() -> void:
	if pointer_holding:
		Input.action_release(action)
		pointer_holding = false

func release_hidden() -> void:
	if not is_visible_in_tree(): end_hold()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: end_hold()

func _exit_tree() -> void:
	end_hold()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and not disabled and not action.is_empty() and event.is_action_pressed(action) and not event.is_echo():
		flash()
