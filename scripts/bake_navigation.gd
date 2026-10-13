extends SceneTree

func _init() -> void:
	call_deferred("bake")

func bake() -> void:
	var surface := Node.new()
	surface.set_script(load("res://scenes/world_surface.gd"))
	root.add_child(surface)
	var min_point := Vector2(-160,-160)
	var step := .75
	var width := 481
	var height := 428
	var cells := PackedByteArray()
	cells.resize(width*height)
	for z in height:
		for x in width:
			cells[z*width+x] = int(surface.clear_at(min_point+Vector2(x,z)*step))
	var file := FileAccess.open("res://assets/village/navigation.bin",FileAccess.WRITE)
	file.store_buffer(cells)
	var meta := FileAccess.open("res://assets/village/navigation.json",FileAccess.WRITE)
	meta.store_string(JSON.stringify({"min":[min_point.x,min_point.y],"step":step,"width":width,"height":height}))
	var image := Image.create(361,321,false,Image.FORMAT_RGBA8)
	for z in 321:
		for x in 361:
			var elevation: float = surface.floor_at(Vector2(x-160,z-160))
			var color := Color("b5c29a").lerp(Color("ddcfac"),clampf(elevation/50,0,1))
			var shade := sin(elevation*1.25)*.012
			image.set_pixel(x,z,Color(color.r+shade,color.g+shade,color.b+shade,1))
	image.save_png("res://assets/village/map-terrain.png")
	print("Baked navigation: ",cells.size()," cells")
	surface.queue_free()
	quit()
