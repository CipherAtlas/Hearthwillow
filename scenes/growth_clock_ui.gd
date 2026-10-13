extends Control

@export var bed_id: String
var countdown := 0.0
var progress := 0.0
var text := ""
const FONT = preload("res://assets/fonts/Outfit.tres")

func _process(delta: float) -> void:
	countdown -= delta
	if countdown > 0: return
	countdown = .1
	var activities: Node = get_tree().current_scene.get_node("VillageActivities")
	var bed: Dictionary = activities.beds.get(bed_id,{})
	visible = bed.get("stage","") == "growing"
	if not visible: return
	var duration: float = activities.growth_duration(bed_id,bed.crop)
	var seconds := maxi(0,ceili(float(bed.watered)+duration-activities.now()))
	var next := "%d:%02d"%[floori(seconds/60.0),seconds%60]
	if next == text: return
	text = next
	progress = clampf(1.0-(float(bed.watered)+duration-activities.now())/duration,0,1)
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2(28,28),24,0,TAU,96,Color("eee5c833"),3,true)
	if progress > 0:
		draw_arc(Vector2(28,28),24,-PI/2,-PI/2+TAU*progress,96,Color("b6c6a5"),3,true)
		draw_circle(Vector2(28,4),1.5,Color("b6c6a5"),true,-1,true)
		draw_circle(Vector2(28,28)+Vector2(sin(TAU*progress),-cos(TAU*progress))*24,1.5,Color("b6c6a5"),true,-1,true)
	var width := FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_string(FONT,Vector2((56-width)*.5,32),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e0e6cf"))
