class_name Iso
extends RefCounted
## Conversions entre la grille (cases) et l'écran, vue isométrique 2:1.
## Une position en "cases" peut être flottante, (3.5, 2.5) c'est le centre de la case (3, 2).

static func to_screen(cell: Vector2) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * Config.TILE_W * 0.5,
		(cell.x + cell.y) * Config.TILE_H * 0.5)


static func to_cell(point: Vector2) -> Vector2:
	return Vector2(
		point.y / Config.TILE_H + point.x / Config.TILE_W,
		point.y / Config.TILE_H - point.x / Config.TILE_W)


static func to_grid(point: Vector2) -> Vector2i:
	var c := to_cell(point)
	return Vector2i(floori(c.x), floori(c.y))


## Les 4 coins d'un rectangle de cases, dans l'ordre haut / droite / bas / gauche.
static func rect_polygon(rect: Rect2i, lift := 0.0) -> PackedVector2Array:
	var p := Vector2(rect.position)
	var s := Vector2(rect.size)
	var up := Vector2(0, -lift)
	return PackedVector2Array([
		to_screen(p) + up,
		to_screen(p + Vector2(s.x, 0)) + up,
		to_screen(p + s) + up,
		to_screen(p + Vector2(0, s.y)) + up,
	])
