class_name ItemIcon
extends Control
## Petite vignette dessinée pour les cartes de la boutique.

const PLUM := Color("5a3e4b")

var item: ShopItem


func _init() -> void:
	custom_minimum_size = Vector2(80, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if item == null:
		return
	var c := size / 2.0 + Vector2(0, 8)
	match item.shape:
		ShopItem.Shape.LAND, ShopItem.Shape.PEN:
			_diamond(c, 34.0, 17.0, item.color, true)
			if item.shape == ShopItem.Shape.PEN:
				_diamond(c, 34.0, 17.0, Color("a9714b"), false)
		ShopItem.Shape.FENCE:
			for x in [-26.0, 0.0, 26.0]:
				draw_rect(Rect2(c.x + x - 3.0, c.y - 20.0, 6.0, 26.0), PLUM)
				draw_rect(Rect2(c.x + x - 2.0, c.y - 19.0, 4.0, 24.0), item.color)
			for y in [-14.0, -4.0]:
				draw_rect(Rect2(c.x - 28.0, c.y + y - 2.0, 56.0, 5.0), PLUM)
				draw_rect(Rect2(c.x - 27.0, c.y + y - 1.0, 54.0, 3.0), item.color.lightened(0.1))
		ShopItem.Shape.BARN:
			draw_rect(Rect2(c.x - 24.0, c.y - 18.0, 48.0, 28.0), PLUM)
			draw_rect(Rect2(c.x - 22.0, c.y - 16.0, 44.0, 24.0), Color("f3dcc0"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - 30.0, c.y - 16.0), Vector2(c.x, c.y - 36.0), Vector2(c.x + 30.0, c.y - 16.0)]), PLUM)
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - 26.0, c.y - 17.0), Vector2(c.x, c.y - 33.0), Vector2(c.x + 26.0, c.y - 17.0)]), item.color)
			draw_rect(Rect2(c.x - 6.0, c.y - 6.0, 12.0, 14.0), Color("7b4a2f"))
		ShopItem.Shape.TROUGH:
			draw_rect(Rect2(c.x - 26.0, c.y - 8.0, 52.0, 18.0), PLUM)
			draw_rect(Rect2(c.x - 24.0, c.y - 6.0, 48.0, 14.0), Color("c48a5a"))
			draw_rect(Rect2(c.x - 22.0, c.y - 6.0, 44.0, 6.0), item.color)
		ShopItem.Shape.TREE:
			draw_rect(Rect2(c.x - 4.0, c.y - 10.0, 8.0, 20.0), PLUM)
			draw_rect(Rect2(c.x - 3.0, c.y - 9.0, 6.0, 18.0), Color("8a5a3a"))
			for offset in [Vector2(-12, -18), Vector2(12, -18), Vector2(0, -28)]:
				draw_circle(c + offset, 15.0, PLUM)
			for offset in [Vector2(-12, -18), Vector2(12, -18), Vector2(0, -28)]:
				draw_circle(c + offset, 13.0, item.color)
		ShopItem.Shape.FLOWERS:
			var colors := [Color("f2a0b8"), Color("fff3d6"), Color("f7c948")]
			var spots := [Vector2(-14, -6), Vector2(2, -14), Vector2(14, -2), Vector2(-4, 4), Vector2(8, 8)]
			for i in spots.size():
				draw_circle(c + spots[i], 8.0, PLUM)
				draw_circle(c + spots[i], 6.5, colors[i % colors.size()])
		ShopItem.Shape.LAMP:
			draw_rect(Rect2(c.x - 3.0, c.y - 28.0, 6.0, 38.0), PLUM)
			draw_rect(Rect2(c.x - 2.0, c.y - 27.0, 4.0, 36.0), Color("7b4a2f"))
			draw_circle(c + Vector2(0, -32), 12.0, PLUM)
			draw_circle(c + Vector2(0, -32), 10.0, item.color)
		ShopItem.Shape.STATUE:
			draw_rect(Rect2(c.x - 20.0, c.y - 2.0, 40.0, 14.0), PLUM)
			draw_rect(Rect2(c.x - 18.0, c.y, 36.0, 10.0), Color("e5ded2"))
			draw_circle(c + Vector2(0, -16), 17.0, PLUM)
			draw_circle(c + Vector2(0, -16), 15.0, item.color)
			draw_arc(c + Vector2(8, -22), 8.0, PI * 0.8, PI * 2.2, 12, Color("a9742f"), 3.0)
		ShopItem.Shape.DOG:
			draw_circle(c + Vector2(0, -6), 20.0, PLUM)
			draw_circle(c + Vector2(0, -6), 18.0, Color("b98a5e"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - 16.0, c.y - 16.0), Vector2(c.x - 20.0, c.y - 34.0), Vector2(c.x - 6.0, c.y - 22.0)]), PLUM)
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x + 16.0, c.y - 16.0), Vector2(c.x + 20.0, c.y - 34.0), Vector2(c.x + 6.0, c.y - 22.0)]), PLUM)
			draw_circle(c + Vector2(-7, -8), 2.5, PLUM)
			draw_circle(c + Vector2(7, -8), 2.5, PLUM)
			draw_circle(c + Vector2(0, -1), 4.0, PLUM)
			draw_rect(Rect2(c.x - 14.0, c.y + 8.0, 28.0, 5.0), item.color)
		ShopItem.Shape.SHEEP:
			var wool := Color("fbf8f1")
			for offset in [Vector2(-12, -8), Vector2(0, -14), Vector2(12, -8), Vector2(-6, 0), Vector2(8, 0)]:
				draw_circle(c + offset, 13.0, PLUM)
			for offset in [Vector2(-12, -8), Vector2(0, -14), Vector2(12, -8), Vector2(-6, 0), Vector2(8, 0)]:
				draw_circle(c + offset, 11.5, wool)
			draw_circle(c + Vector2(18, -4), 9.0, PLUM)
			draw_circle(c + Vector2(18, -4), 7.5, Color("6b5560"))
			draw_circle(c + Vector2(21, -6), 1.5, Color.WHITE)
			if item.extra.get("sex") == "ram":
				draw_arc(c + Vector2(16, -10), 6.0, PI * 0.9, PI * 2.2, 10, Color("e0b44a"), 3.0)


func _diamond(center: Vector2, half_w: float, half_h: float, color: Color, filled: bool) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -half_h), center + Vector2(half_w, 0),
		center + Vector2(0, half_h), center + Vector2(-half_w, 0)])
	if filled:
		draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), PLUM if filled else color, 3.0)
