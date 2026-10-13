extends Node3D

@export var active_lamp_limit: int = 2
@export var lamp_update_interval: float = .1

@onready var world: Node3D = get_parent()
@onready var player: CharacterBody3D = world.get_node("Player")

var spirit_materials: Array[Dictionary] = []
var glass_materials: Array[StandardMaterial3D] = []
var water_materials: Array[ShaderMaterial] = []
var motion_materials: Array[ShaderMaterial] = []
var reduced_cached := -1
var coal_materials: Array[StandardMaterial3D] = []
var blend := Vector3(-1, -1, -1)
var lamp_countdown := 0.0
var active_lamps: Array[OmniLight3D] = []

func _ready() -> void:
	var seen := {}
	# Cache imported and merged materials once; weather never walks the scenery tree.
	for root: Node in [world.get_node("Village"), player, world.get_node("VillageActivities"), world.get_node("FocusCottage")]:
		for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
			var mesh: Mesh = node.multimesh.mesh if node is MultiMeshInstance3D else node.mesh if node is MeshInstance3D else null
			if not mesh: continue
			for index in mesh.get_surface_count():
				var material: Material = node.get_active_material(index) if node is MeshInstance3D else node.material_override if node.material_override else mesh.surface_get_material(index)
				if not material or seen.has(material): continue
				seen[material] = true
				if material is StandardMaterial3D:
					if material.resource_name == "Pearl white spirit":
						spirit_materials.append({"material":material, "color":material.albedo_color, "emission":material.emission, "energy":material.emission_energy_multiplier, "enabled":material.emission_enabled})
					elif material.resource_name == "Village material 31":
						material.emission_texture = material.albedo_texture
						material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
						glass_materials.append(material)
					elif material.resource_name == "Village material 42":
						coal_materials.append(material)
				elif material is ShaderMaterial:
					if material.shader.code.contains("uniform float motion_amount"): motion_materials.append(material)
					if material.shader.resource_path == "res://assets/shaders/water.gdshader": water_materials.append(material)

func set_weather(value: Vector3) -> void:
	if blend.distance_squared_to(value) < .000001: return
	blend = value
	var rain := blend.x
	var dusk := blend.y
	var night := blend.z
	var glow := Color("ffd58e")
	for entry: Dictionary in spirit_materials:
		var material: StandardMaterial3D = entry.material
		material.albedo_color = entry.color.lerp(glow, night * .32)
		material.emission = entry.emission.lerp(glow, night)
		material.emission_energy_multiplier = lerpf(entry.energy, .26, night)
		material.emission_enabled = entry.enabled or night > 0
	for material: StandardMaterial3D in glass_materials:
		material.emission_energy_multiplier = .12 + dusk * 1.3 + night * 3.2 + rain * .22
	var halo_opacity := maxf(dusk * .35, night * .85)
	var halo_material: StandardMaterial3D = $Halos.get_child(0).mesh.material
	halo_material.albedo_color.a = halo_opacity
	$Halos.visible = halo_opacity > .01
	for material: ShaderMaterial in water_materials:
		material.set_shader_parameter("weather", Vector2(rain, minf(1, dusk + night)))
	# The fill from below must fade as well as the sun at night.
	world.get_node("Bounce").light_energy = (.2 - dusk * .058 - rain * .043) * (1 - night) + .011 * night
	for light: OmniLight3D in $Lamps.get_children():
		light.light_energy = (dusk * .8 + night * float(light.get_meta("night_intensity"))) * .25

func _process(delta: float) -> void:
	lamp_countdown -= delta
	if lamp_countdown <= 0:
		lamp_countdown = lamp_update_interval
		update_lamps()
	var reduced: bool = world.get_node("HUD/Menus").reduced_motion
	set_motion(reduced)
	var time := 0.0 if reduced else Time.get_ticks_msec() / 1000.0
	$HearthLight.light_energy = (8.5 + sin(time * 5.7) * .6 + sin(time * 11.3) * .3) * .25
	for material: StandardMaterial3D in coal_materials:
		material.emission_energy_multiplier = .45 + maxf(0, blend.z) * .9 + sin(time * 2.1) * .1

func set_motion(reduced: bool) -> void:
	if reduced_cached==int(reduced): return
	reduced_cached = int(reduced)
	for material: ShaderMaterial in motion_materials: material.set_shader_parameter("motion_amount",0.0 if reduced else 1.0)

func update_lamps() -> void:
	for light: OmniLight3D in active_lamps: light.visible = false
	active_lamps.clear()
	if blend.y * .8 + blend.z * 5.2 <= .01: return
	var distances: Array[float] = []
	for light: OmniLight3D in $Lamps.get_children():
		var gap := Vector2(light.global_position.x - player.global_position.x, light.global_position.z - player.global_position.z).length_squared()
		var index := 0
		while index < distances.size() and distances[index] <= gap: index += 1
		if index >= active_lamp_limit: continue
		distances.insert(index, gap)
		active_lamps.insert(index, light)
		if active_lamps.size() > active_lamp_limit:
			active_lamps.pop_back()
			distances.pop_back()
	for light: OmniLight3D in active_lamps: light.visible = true
