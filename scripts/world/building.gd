class_name Building
extends Node2D
## Un bâtiment ou une décoration terminé. Dessiné en code pour l'instant.

const OUTLINE := Color("5a3e4b")

var item: ShopItem
var rect: Rect2i


func _ready() -> void:
	# l'origine est le coin du bas : le tri en profondeur (y-sort) fonctionne bien comme ça
	position = Iso.to_screen(Vector2(rect.end))


# coordonnées locales d'un point en cases
func _p(cell: Vector2) -> Vector2:
	return Iso.to_screen(cell) - position


func _draw() -> void:
	match item.shape:
		ShopItem.Shape.BARN:
			_draw_box(34.0, item.color, Color("f3dcc0"))
		ShopItem.Shape.TROUGH:
			_draw_box(8.0, Color("a9714b"), Color("c48a5a"))
			var inner := PackedVector2Array([
				_p(Vector2(rect.position) + Vector2(0.15, 0.15)) + Vector2(0, -8),
				_p(Vector2(rect.end.x - 0.15, rect.position.y + 0.15)) + Vector2(0, -8),
				_p(Vector2(rect.end) - Vector2(0.15, 0.15)) + Vector2(0, -8),
				_p(Vector2(rect.position.x + 0.15, rect.end.y - 0.15)) + Vector2(0, -8),
			])
			draw_colored_polygon(inner, item.color)
		ShopItem.Shape.TREE:
			_draw_tree()
		ShopItem.Shape.FLOWERS:
			_draw_flowers()
		ShopItem.Shape.LAMP:
			_draw_lamp()
		ShopItem.Shape.STATUE:
			_draw_statue()


func _center() -> Vector2:
	return _p(Vector2(rect.position) + Vector2(rect.size) / 2.0)


func _draw_box(height: float, roof: Color, wall: Color) -> void:
	var top := _p(Vector2(rect.position))
	var right := _p(Vector2(rect.end.x, rect.position.y))
	var bottom := _p(Vector2(rect.end))
	var left := _p(Vector2(rect.position.x, rect.end.y))
	var up := Vector2(0, -height)

	# mur gauche, mur droit, puis le toit
	var left_wall := PackedVector2Array([left, bottom, bottom + up, left + up])
	var right_wall := PackedVector2Array([bottom, right, right + up, bottom + up])
	draw_colored_polygon(left_wall, wall.darkened(0.12))
	draw_colored_polygon(right_wall, wall)
	draw_colored_polygon(PackedVector2Array([top + up, right + up, bottom + up, left + up]), roof)

	for poly in [left_wall, right_wall]:
		draw_polyline(poly + PackedVector2Array([poly[0]]), OUTLINE, 2.0)
	var roof_poly := PackedVector2Array([top + up, right + up, bottom + up, left + up])
	draw_polyline(roof_poly + PackedVector2Array([roof_poly[0]]), OUTLINE, 2.0)

	# une porte sur le mur de gauche pour que ça ressemble à quelque chose
	if height > 20.0:
		var a := left.lerp(bottom, 0.35)
		var b := left.lerp(bottom, 0.65)
		draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, -18), a + Vector2(0, -18)]),
				Color("7b4a2f"))


func _draw_tree() -> void:
	var c := _center()
	draw_circle(c + Vector2(0, 2), 12.0, Color(0, 0, 0, 0.12))
	draw_rect(Rect2(c.x - 3.0, c.y - 18.0, 6.0, 20.0), OUTLINE)
	draw_rect(Rect2(c.x - 2.0, c.y - 17.0, 4.0, 18.0), Color("8a5a3a"))
	for offset in [Vector2(-9, -30), Vector2(9, -30), Vector2(0, -38), Vector2(0, -26)]:
		draw_circle(c + offset, 12.5, OUTLINE)
	for offset in [Vector2(-9, -30), Vector2(9, -30), Vector2(0, -38), Vector2(0, -26)]:
		draw_circle(c + offset, 11.0, item.color)
	draw_circle(c + Vector2(-3, -42), 4.0, item.color.lightened(0.25))


func _draw_flowers() -> void:
	var c := _center()
	draw_circle(c, 7.0, Color("6fbf5a"))
	var colors := [Color("f2a0b8"), Color("fff3d6"), Color("f7c948")]
	var spots := [Vector2(-4, -3), Vector2(3, -4), Vector2(0, 2), Vector2(5, 1), Vector2(-5, 2)]
	for i in spots.size():
		draw_circle(c + spots[i], 2.6, OUTLINE)
		draw_circle(c + spots[i], 1.8, colors[i % colors.size()])


func _draw_lamp() -> void:
	var c := _center()
	draw_circle(c + Vector2(0, 1), 5.0, Color(0, 0, 0, 0.15))
	draw_line(c, c + Vector2(0, -30), OUTLINE, 4.0)
	draw_line(c, c + Vector2(0, -30), Color("7b4a2f"), 2.0)
	draw_circle(c + Vector2(0, -34), 7.0, OUTLINE)
	draw_circle(c + Vector2(0, -34), 5.5, item.color)
	if not Game.is_day():
		draw_circle(c + Vector2(0, -34), 16.0, Color(1.0, 0.9, 0.5, 0.25))


func _draw_statue() -> void:
	_draw_box(10.0, Color("c9c2b8"), Color("e5ded2"))
	var c := _center() + Vector2(0, -10)
	draw_circle(c + Vector2(0, -14), 12.0, OUTLINE)
	draw_circle(c + Vector2(0, -14), 10.5, item.color)
	draw_circle(c + Vector2(8, -18), 6.0, OUTLINE)
	draw_circle(c + Vector2(8, -18), 4.8, item.color.darkened(0.1))
	draw_arc(c + Vector2(6, -22), 5.0, PI * 0.8, PI * 2.2, 12, Color("a9742f"), 2.5)
