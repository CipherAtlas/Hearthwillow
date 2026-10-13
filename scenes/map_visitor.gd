extends Control

func _draw() -> void:
	get_parent().draw_visitor(self)
