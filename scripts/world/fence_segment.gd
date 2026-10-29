class_name FenceSegment
extends Node2D
## Un morceau de clôture sur le bord d'une case. Un nœud par segment pour que
## le tri en profondeur marche (un mouton derrière la barrière passe derrière).

const OUTLINE := Color("5a3e4b")

var edge := Vector3i.ZERO
var inner := false   # barrière intérieure (plus claire) ou clôture extérieure

var _a := Vector2.ZERO
var _b := Vector2.ZERO


func _ready() -> void:
	var start := Vector2(edge.x, edge.y)
	var end := start + (Vector2(1, 0) if edge.z == FarmMap.H else Vector2(0, 1))
	var screen_a := Iso.to_screen(start)
	var screen_b := Iso.to_screen(end)
	position = (screen_a + screen_b) / 2.0
	_a = screen_a - position
	_b = screen_b - position


func _draw() -> void:
	var wood := Color("d8a56c") if inner else Color("a9714b")
	var up := Vector2(0, -10)

	# deux lisses puis les poteaux par-dessus
	for height in [4.0, 9.0]:
		var lift := Vector2(0, -height)
		draw_line(_a + lift, _b + lift, OUTLINE, 4.0)
	for height in [4.0, 9.0]:
		var lift := Vector2(0, -height)
		draw_line(_a + lift, _b + lift, wood, 2.0)

	for point in [_a, _b]:
		draw_line(point, point + up, OUTLINE, 5.0)
		draw_line(point, point + up, wood.lightened(0.1), 3.0)
