class_name FarmView
extends Node2D
## Dessine le sol : herbe, parcelles à vendre, sol des enclos et (en mode
## construction) la grille. Tout est redessiné seulement quand la carte change.

const GRASS_A := Color("a4da72")
const GRASS_B := Color("9bd366")
const PEN_FLOOR := Color("e3cf9c")
const FOR_SALE := Color("8cbf68")
const OUTLINE := Color("5a3e4b")

var map: FarmMap
var show_grid := false: set = set_show_grid

var _tufts: Dictionary = {}   # parcelle -> Array[Vector2] (positions en cases)


func _ready() -> void:
	map.changed.connect(queue_redraw)
	Game.mode_changed.connect(_on_mode_changed)
	_scatter_tufts()


func set_show_grid(value: bool) -> void:
	show_grid = value
	queue_redraw()


func _on_mode_changed() -> void:
	var kind := Game.build_item.kind if Game.build_item != null else -1
	show_grid = kind != -1 and kind != ShopItem.Kind.LAND


# Touffes d'herbe tirées une fois pour toutes, avec une graine fixe pour que le
# décor ne change pas à chaque lancement.
func _scatter_tufts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for py in Config.WORLD_PLOTS.y:
		for px in Config.WORLD_PLOTS.x:
			var list: Array[Vector2] = []
			for i in 36:
				list.append(Vector2(rng.randf_range(0.5, 15.5), rng.randf_range(0.5, 15.5)))
			_tufts[Vector2i(px, py)] = list


func _draw() -> void:
	for py in Config.WORLD_PLOTS.y:
		for px in Config.WORLD_PLOTS.x:
			_draw_plot(Vector2i(px, py))


func _draw_plot(plot: Vector2i) -> void:
	var rect := FarmMap.plot_rect(plot)
	var poly := Iso.rect_polygon(rect)
	var origin := Vector2(rect.position)

	if not map.owned_plots.has(plot):
		draw_colored_polygon(poly, FOR_SALE)
		draw_polyline(poly + PackedVector2Array([poly[0]]), Color(1, 1, 1, 0.5), 2.0)
		if map.can_buy_plot(plot):
			_draw_sale_sign(rect)
		return

	draw_colored_polygon(poly, GRASS_A if (plot.x + plot.y) % 2 == 0 else GRASS_B)
	if map.pen_plots.has(plot):
		draw_colored_polygon(poly, PEN_FLOOR)
	else:
		for tuft: Vector2 in _tufts[plot]:
			var base := Iso.to_screen(origin + tuft)
			draw_line(base, base + Vector2(-2, -4), GRASS_A.darkened(0.2), 1.5)
			draw_line(base, base + Vector2(2, -5), GRASS_A.darkened(0.2), 1.5)

	if show_grid:
		_draw_grid(rect)


func _draw_grid(rect: Rect2i) -> void:
	var color := Color(1, 1, 1, 0.22)
	for i in range(rect.size.x + 1):
		draw_line(Iso.to_screen(Vector2(rect.position.x + i, rect.position.y)),
				Iso.to_screen(Vector2(rect.position.x + i, rect.end.y)), color, 1.0)
	for j in range(rect.size.y + 1):
		draw_line(Iso.to_screen(Vector2(rect.position.x, rect.position.y + j)),
				Iso.to_screen(Vector2(rect.end.x, rect.position.y + j)), color, 1.0)


func _draw_sale_sign(rect: Rect2i) -> void:
	var center := Iso.to_screen(Vector2(rect.position) + Vector2(rect.size) / 2.0)
	var font := ThemeDB.fallback_font
	var label := "À vendre : %d" % ShopCatalog.land_price(map.owned_plots.size())
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_rect(Rect2(center.x - width / 2.0 - 8.0, center.y - 16.0, width + 16.0, 26.0), OUTLINE)
	draw_rect(Rect2(center.x - width / 2.0 - 6.0, center.y - 14.0, width + 12.0, 22.0), Color("fff3d6"))
	draw_string(font, center + Vector2(-width / 2.0, 3.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, OUTLINE)
