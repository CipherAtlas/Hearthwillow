extends Node

@onready var world: Node3D = get_parent()
@onready var life: Node = world.get_node("VillageLife")
@onready var surface: Node = world.get_node("WorldSurface")
@onready var crumbs_mesh: MultiMeshInstance3D = $Crumbs

var age := 0.0
var elapsed := 0.0
var flight := true
var flight_count := 0
var meal_age := -1.0
var queued := false
var served := false
var status := "flying"
var previous_status := ""
var parts: Array[Dictionary] = []
var landings: PackedVector3Array = []
var scales: PackedVector3Array = []
var curves: Array[PackedVector3Array] = []
const CLEARING := Vector2(-37,4)

func matrix(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[4],values[5],values[6]),Vector3(values[8],values[9],values[10])),Vector3(values[12],values[13],values[14]))

func _ready() -> void:
	var data: Dictionary = surface.data.birds
	for point: Array in data.landings: landings.append(Vector3(point[0],point[1],point[2]))
	for scale: Array in data.scales: scales.append(Vector3(scale[0],scale[1],scale[2]))
	for curve: Array in data.curves:
		var samples := PackedVector3Array()
		for point: Array in curve: samples.append(Vector3(point[0],point[1],point[2]))
		curves.append(samples)
	var bounds := AABB(landings[0],Vector3.ZERO)
	for landing: Vector3 in landings:
		bounds = bounds.expand(landing)
		for curve: PackedVector3Array in curves:
			for point: Vector3 in curve: bounds = bounds.expand(landing+point)
	bounds = bounds.grow(8)
	for record: Dictionary in data.parts:
		for node: Node in world.get_node("Village/Scenery").get_children():
			if node is MultiMeshInstance3D and ("White dove flock_"+str(record.name)+"_") in str(node.name):
				node.multimesh = node.multimesh.duplicate()
				node.custom_aabb = bounds
				parts.append({"node":node,"base":matrix(record.transform),"pivot":matrix(record.pivot),"name":record.name})
	crumbs_mesh.multimesh = crumbs_mesh.multimesh.duplicate()
	crumbs_mesh.hide()

func curve_point(t: float) -> Vector3:
	var curve := curves[flight_count%curves.size()]
	var at := clampf(t,0,1)*(curve.size()-1)
	var index := mini(floori(at),curve.size()-2)
	return curve[index].lerp(curve[index+1],at-index)

func flight_position(index: int, seconds: float) -> Vector3:
	var t := clampf(seconds/30,0,1)
	var spread := pow(sin(t*PI),2)
	var pattern := flight_count%curves.size()
	var row := index/2
	var side := 1 if index%2 else -1
	var lateral: float = side*row*.65 if pattern == 0 else (index%4-1.5)*1.4 if pattern == 1 else side*2.2
	var result := curve_point(t)+landings[index]
	result.x += spread*(lateral+sin(t*PI*4+index*.7)*.45*(0.0 if world.get_node("HUD/Menus").reduced_motion else 1.0))
	result.z += spread*(-row*.5 if pattern == 0 else -floori(index/4.0)*1.5 if pattern == 1 else (row-2.5)*.85)
	result.y += spread*(index%3)*.65
	return result

func feed() -> bool:
	if queued or served or life.crumbs == 0: return false
	queued = true
	if not flight: start_meal()
	life.say("White doves","The crumbs are ready for their next landing." if flight else "Coo coo~ (Thank you~)")
	world.get_node("VillageSound").animal_call("dove",Vector3(CLEARING.x,.5,CLEARING.y),true)
	return true

func start_meal() -> void:
	queued = false
	served = true
	meal_age = 0

func _process(delta: float) -> void:
	age += delta
	elapsed += delta
	if flight and age >= 30:
		flight = false; age = 0
	if not flight and queued and age >= .4: start_meal()
	if meal_age >= 0: meal_age += delta
	if not flight and (meal_age >= 10 if served else age >= 18):
		flight = true; age = 0; meal_age = -1; served = false; flight_count += 1
	status = "happy" if meal_age >= 4 else "eating" if meal_age >= 0 else "crumbs" if queued else "flying" if flight else "sad" if age >= 6 else "waiting"
	if status != previous_status and status in ["happy","sad"]:
		life.say("White doves","Coo coo :(" if status == "sad" else "Coo coo~ (Thank you~)",4)
	previous_status = status
	var sadness := 1.0 if status == "sad" else 0.0
	var reduced: bool = world.get_node("HUD/Menus").reduced_motion
	var motion := 0.0 if reduced else 1.0
	for i in landings.size():
		var point := flight_position(i,age) if flight else landings[i]
		var angles := Vector3.ZERO
		if flight:
			var heading := flight_position(i,age+.03)-point
			angles.y = atan2(heading.x,heading.z)
			angles.z = -.09*sin(age/30*TAU)*motion
			angles.x = -.06*heading.y*motion
		else:
			angles.y = atan2(CLEARING.x-point.x,CLEARING.y-point.z)
			angles.x = sadness*.1
			point.y += absf(sin((meal_age-4)*5+i))*.1 if status == "happy" else sin(elapsed*2+i)*.009-sadness*.025
			angles.z = sin((meal_age-4)*6+i)*.07 if status == "happy" else 0.0
		if not flight and reduced:
			point.y = landings[i].y
			angles.z = 0.0
		var root := Transform3D(Basis.from_euler(angles,EULER_ORDER_XYZ).scaled(scales[i]),point)
		for part: Dictionary in parts:
			var rotation := Vector3.ZERO
			if "Head" in part.name:
				rotation.x = sadness*(.4+sin(elapsed*1.8+i)*.035*motion)+(.27+sin(elapsed*6+i)*.24 if status == "eating" and not reduced else 0)
				rotation.z = sadness*sin(elapsed*1.2+i)*.06*motion
			elif "Wing" in part.name:
				var flap := sin(elapsed*(10 if flight else 13)+i)*(.65 if flight else .3)*motion
				rotation.z = (-1 if "Right" in part.name else 1)*(flap if flight else .65+flap if status == "happy" else 1.12+sadness*.27)
			var transform: Transform3D = root*part.pivot*Transform3D(Basis.from_euler(rotation,EULER_ORDER_XYZ),Vector3.ZERO)*part.pivot.affine_inverse()*part.base
			part.node.multimesh.set_instance_transform(i,transform)
	crumbs_mesh.visible = queued or served and meal_age < 7
	if crumbs_mesh.visible:
		var portion := maxf(0,(7-meal_age)/5) if meal_age > 2 else 1.0
		for i in crumbs_mesh.multimesh.instance_count:
			var angle := i*2.399
			var radius := .95*sqrt((i+.5)/(96*.65)) if i < 96*.65 else 1.12+(i%11)*.038
			var point := Vector3(CLEARING.x+cos(angle)*radius,.17+i%3*.009,CLEARING.y+sin(angle)*radius)
			crumbs_mesh.multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(i*.7,i*1.3,i*.4)).scaled(Vector3(.75+i%4*.16,.5+i%3*.17,.7+i%5*.12)*portion),point))
