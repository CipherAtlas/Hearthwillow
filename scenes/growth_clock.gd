extends Node3D

@export var bed_id: String
var elapsed := 0.0
var last_seconds := -1
@onready var activities: Node = get_parent().get_parent()

func _process(delta: float) -> void:
	elapsed -= delta
	if elapsed > 0: return
	elapsed = .1
	var bed: Dictionary = activities.beds.get(bed_id,{})
	visible = bed.get("stage","") == "growing"
	if not visible:
		last_seconds = -1
		return
	var duration: float = activities.growth_duration(bed_id,bed.crop)
	var remaining := maxi(0,ceili(float(bed.watered)+duration-activities.now()))
	visible = remaining > 0
	if remaining == last_seconds: return
	last_seconds = remaining
	$Time.text = "%d:%02d"%[floori(remaining/60.0),remaining%60]
	$Face.material_override.set_shader_parameter("progress",clampf(1.0-(float(bed.watered)+duration-activities.now())/duration,0,1))
