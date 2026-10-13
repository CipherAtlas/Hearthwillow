extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 120: await process_frame
	await RenderingServer.frame_post_draw
	var renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	var output := "res://evidence/native-%s.png" % renderer
	assert(root.get_texture().get_image().save_png(output) == OK)
	print("Saved entrance: "+output)
	quit()
