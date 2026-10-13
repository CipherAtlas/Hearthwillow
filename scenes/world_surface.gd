extends Node

var data: Dictionary
var heights: PackedFloat32Array
var bridge_heights: Array[PackedFloat32Array] = []
var obstacle_cells: Dictionary = {}
var placements: Dictionary = {}
var river_cells: Dictionary = {}

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/village/world-data.json"))
	heights = FileAccess.get_file_as_bytes("res://assets/village/floor-heights.bin").to_float32_array()
	for i in data.bridge_floors.size():
		bridge_heights.append(FileAccess.get_file_as_bytes("res://assets/village/bridge-floor-%d.bin" % i).to_float32_array())
	for item: Dictionary in data.items:
		if not placements.has(item.asset): placements[item.asset] = []
		placements[item.asset].append(item)
	for river: Dictionary in data.rivers:
		var radius := float(river.width)*.5+.32
		for i in river.spine.size()-1:
			var a := Vector2(river.spine[i][0],river.spine[i][1])
			var b := Vector2(river.spine[i+1][0],river.spine[i+1][1])
			var minimum := a.min(b)-Vector2.ONE*radius
			var maximum := a.max(b)+Vector2.ONE*radius
			for z in range(floori(minimum.y/8),floori(maximum.y/8)+1):
				for x in range(floori(minimum.x/8),floori(maximum.x/8)+1):
					var key := Vector2i(x,z)
					if not river_cells.has(key): river_cells[key] = []
					river_cells[key].append({"a":a,"b":b,"radius":radius})
	for collider: Dictionary in data.colliders:
		var radius := maxf(collider.w, collider.d) * .75 + .5
		for z in range(floori((collider.z-radius)/8), floori((collider.z+radius)/8)+1):
			for x in range(floori((collider.x-radius)/8), floori((collider.x+radius)/8)+1):
				var key := Vector2i(x,z)
				if not obstacle_cells.has(key): obstacle_cells[key] = []
				obstacle_cells[key].append(collider)

func sampled_floor(values: PackedFloat32Array, width: int, x: float, z: float) -> float:
	x = clampf(x,0,width-1.001)
	z = clampf(z,0,width-1.001)
	var ix := floori(x)
	var iz := floori(z)
	return lerpf(lerpf(values[iz*width+ix],values[iz*width+ix+1],x-ix),lerpf(values[(iz+1)*width+ix],values[(iz+1)*width+ix+1],x-ix),z-iz)

func local_point(item: Dictionary, point: Vector2) -> Vector2:
	var offset := point-Vector2(item.position[0],item.position[2])
	return offset.rotated(deg_to_rad(item.rotation[1])) / Vector2(item.scale[0],item.scale[2])

func world_point(item: Dictionary, point := Vector2.ZERO) -> Vector2:
	return Vector2(item.position[0],item.position[2])+(point*Vector2(item.scale[0],item.scale[2])).rotated(-deg_to_rad(item.rotation[1]))

func item_transform(item: Dictionary) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(item.rotation[0]),deg_to_rad(item.rotation[1]),deg_to_rad(item.rotation[2]))).scaled(Vector3(item.scale[0],item.scale[1],item.scale[2])),Vector3(item.position[0],item.position[1],item.position[2]))

func route_distance(point: Vector2, route: Dictionary) -> float:
	return point.distance_to(closest_route_point(point,route))

func closest_route_point(point: Vector2, route: Dictionary) -> Vector2:
	var distance := INF
	var nearest := point
	for i in route.spine.size()-1:
		var a := Vector2(route.spine[i][0],route.spine[i][1])
		var b := Vector2(route.spine[i+1][0],route.spine[i+1][1])
		var candidate := Geometry2D.get_closest_point_to_segment(point,a,b)
		var gap := point.distance_squared_to(candidate)
		if gap < distance:
			distance = gap
			nearest = candidate
	return nearest

func on_bridge(point: Vector2) -> bool:
	for item: Dictionary in placements.get("bridge",[]):
		var local := local_point(item,point)
		if absf(local.x) <= 6.0 and absf(local.y) <= 1.73: return true
	return false

func floor_at(point: Vector2) -> float:
	if on_bridge(point):
		for i in data.bridge_floors.size():
			var patch: Dictionary = data.bridge_floors[i]
			var x := (point.x-float(patch.x))/float(patch.step)
			var z := (point.y-float(patch.z))/float(patch.step)
			if x >= 0 and z >= 0 and x < patch.width-1 and z < patch.width-1:
				return sampled_floor(bridge_heights[i],int(patch.width),x,z)
	return sampled_floor(heights,641,point.x+320,point.y+320)

func river_contains(point: Vector2) -> bool:
	for segment: Dictionary in river_cells.get(Vector2i(floori(point.x/8),floori(point.y/8)),[]):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b)) < segment.radius: return true
	return false

func can_enter(point: Vector2) -> bool:
	if absf(point.x) > 319 or absf(point.y) > 319: return false
	if river_contains(point) and not on_bridge(point): return false
	var on_dock := false
	for item: Dictionary in placements.get("dock",[]):
		var local := local_point(item,point)
		on_dock = on_dock or (absf(local.x) < 2.75 and absf(local.y) < 1.1)
	if not on_dock:
		for item: Dictionary in placements.get("pond",[]):
			if (local_point(item,point)/Vector2(9,12)).length() < 1.035: return false
	return true

func clear_at(point: Vector2) -> bool:
	if not can_enter(point): return false
	var floor_height := floor_at(point)
	for collider: Dictionary in obstacle_cells.get(Vector2i(floori(point.x/8),floori(point.y/8)),[]):
		if floor_height >= float(collider.get("top",8)) or floor_height+1.8 <= float(collider.get("bottom",-1)): continue
		var local := (point-Vector2(collider.x,collider.z)).rotated(float(collider.get("yaw",0)))
		var dx := maxf(absf(local.x)-float(collider.w)*.5,0)
		var dz := maxf(absf(local.y)-float(collider.d)*.5,0)
		if dx*dx+dz*dz < .32*.32: return false
	return true

func contact_surface(point: Vector2) -> String:
	for item: Dictionary in placements.get("dock",[])+placements.get("hearth",[]):
		var local := local_point(item,point)
		if item.asset == "dock" and absf(local.x) < 2.75 and absf(local.y) < 1.1: return "wood"
		if item.asset == "hearth" and local.length() < 3.6: return "stone"
	if on_bridge(point): return "stone"
	var shoulder := false
	for path: Dictionary in data.paths:
		var bounds: Array = path.bounds
		if point.x < bounds[0]-.7 or point.x > bounds[2]+.7 or point.y < bounds[1]-.7 or point.y > bounds[3]+.7: continue
		var gap := route_distance(point,path)
		if gap < float(path.width)*.5: return "stone"
		shoulder = shoulder or gap < float(path.width)*.5+.65
	return "soil" if shoulder else "grass"

func recovery_spot(origin: Vector2) -> Vector3:
	if clear_at(origin): return Vector3(origin.x,floor_at(origin)+.03,origin.y)
	for radius in range(1,13):
		for step in 24:
			var point := origin+Vector2.from_angle(float(step)*TAU/24)*float(radius)
			if clear_at(point): return Vector3(point.x,floor_at(point)+.03,point.y)
	return Vector3(.3,floor_at(Vector2(.3,20))+.03,20)
