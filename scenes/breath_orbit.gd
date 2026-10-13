extends Control

var fraction := 1.0

func _draw() -> void:
	var center := size*.5
	draw_circle(center,65,Color(.88,.93,.85,.07))
	draw_arc(center,65,0,TAU,80,Color("d0decb"),1.5,true)
	draw_arc(center,65,-PI*.5,-PI*.5+TAU*clampf(fraction,0,1),80,Color("b6c6a5"),3,true)
