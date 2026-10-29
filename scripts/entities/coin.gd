class_name Coin
extends Node2D
## Pièce à ramasser en se baladant de jour.

var cell_pos := Vector2.ZERO
var value := 10

var _time := randf() * TAU


func _ready() -> void:
	add_to_group("coins")
	position = Iso.to_screen(cell_pos)


func _process(delta: float) -> void:
	_time += delta * 3.0
	queue_redraw()


func _draw() -> void:
	var lift := -10.0 + sin(_time) * 2.0
	var width := absf(cos(_time * 0.5)) * 6.0 + 2.0
	draw_circle(Vector2(0, 0), 3.5, Color(0, 0, 0, 0.15))
	var points := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		points.append(Vector2(cos(a) * width, lift + sin(a) * 6.5))
	draw_colored_polygon(points, Color("f7c948"))
	draw_polyline(points + PackedVector2Array([points[0]]), Color("a9742f"), 1.5)
