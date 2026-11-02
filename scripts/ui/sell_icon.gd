class_name SellIcon
extends Control
## Les petites icônes de l'onglet « Vendre » : un tas de laine et un marteau de démolition.

enum Kind { WOOL, HAMMER }

const PLUM := Color("5a3e4b")

var kind: Kind = Kind.WOOL
var tint := Color("fbf8f1")


func _init(icon_kind: Kind = Kind.WOOL, icon_size := Vector2(80, 56), icon_tint := Color("fbf8f1")) -> void:
	kind = icon_kind
	tint = icon_tint
	custom_minimum_size = icon_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var k := minf(size.x, size.y) / 56.0   # les dessins sont prévus pour 56 px de haut
	match kind:
		Kind.WOOL:
			_wool(c, k)
		Kind.HAMMER:
			_hammer(c, k)


# Une pelote de laine : trois gros flocons et un brin qui dépasse.
func _wool(c: Vector2, k: float) -> void:
	var puffs := [Vector2(-13, 5), Vector2(0, -7), Vector2(13, 5), Vector2(-3, 8), Vector2(6, 9)]
	for p: Vector2 in puffs:
		draw_circle(c + p * k, 13.0 * k, PLUM)
	for p: Vector2 in puffs:
		draw_circle(c + p * k, 11.4 * k, tint)
	# un peu de relief pour que la couleur claire ne se confonde pas avec le fond
	draw_arc(c + Vector2(0, -7) * k, 7.0 * k, PI * 1.1, PI * 1.6, 8, tint.darkened(0.16), 2.0 * k)
	draw_arc(c + Vector2(13, 5) * k, 7.0 * k, PI * 1.1, PI * 1.6, 8, tint.darkened(0.16), 2.0 * k)


# Une masse : manche en bois en diagonale, grosse tête en acier au bout.
func _hammer(c: Vector2, k: float) -> void:
	var angle := deg_to_rad(-40.0)
	_poly(c, Vector2(0, 2) * k, Vector2(38, 7.4) * k, angle, PLUM)
	_poly(c, Vector2(0, 2) * k, Vector2(35.6, 5.0) * k, angle, Color("b07a3c"))
	_poly(c, Vector2(15, 2) * k, Vector2(15, 22) * k, angle, PLUM)
	_poly(c, Vector2(15, 2) * k, Vector2(12.6, 19.6) * k, angle, Color("8b9db3"))
	_poly(c, Vector2(15.6, -3.5) * k, Vector2(10, 5) * k, angle, Color("c3d0de"))
	# des éclats au pied du manche
	for spot: Vector2 in [Vector2(14, 20), Vector2(20, 14), Vector2(9, 24)]:
		draw_circle(c + spot * k, 1.8 * k, PLUM)


# Un rectangle tourné autour de `center`, `offset` étant donné dans le repère du rectangle.
func _poly(center: Vector2, offset: Vector2, rect_size: Vector2, angle: float, color: Color) -> void:
	var half := rect_size / 2.0
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		points.append(center + (offset + corner).rotated(angle))
	draw_colored_polygon(points, color)
