class_name ConstructionSite
extends Node2D
## Un chantier planifié de jour. La nuit, il faut se tenir dessus et cliquer
## autant de fois que nécessaire (build_clicks) pour le terminer.

signal completed(site: ConstructionSite)

var item: ShopItem
var rect: Rect2i
var clicks_done := 0
var cell_pos := Vector2.ZERO   # centre du chantier, en cases

var _flash := 0.0
var _pulse := 0.0
var _done := false


func _ready() -> void:
	add_to_group("sites")
	cell_pos = Vector2(rect.position) + Vector2(rect.size) / 2.0
	position = Iso.to_screen(cell_pos)
	Game.phase_changed.connect(func(_phase: int) -> void: queue_redraw())


## Zone dans laquelle le berger doit se trouver pour pouvoir construire.
func reach_rect() -> Rect2:
	return Rect2(rect).grow(1.0)


func contains_cell(cell: Vector2i) -> bool:
	return rect.has_point(cell)


func hit() -> void:
	if _done:
		return
	clicks_done += 1
	_flash = 1.0
	queue_redraw()
	if clicks_done >= item.build_clicks:
		# un chien et le joueur peuvent frapper dans la même frame, d'où ce garde-fou
		_done = true
		remove_from_group("sites")
		completed.emit(self)


func _process(delta: float) -> void:
	_pulse += delta * 3.0
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
	if not Game.is_day() or _flash > 0.0:
		queue_redraw()


func _draw() -> void:
	var poly := Iso.rect_polygon(rect)
	for i in poly.size():
		poly[i] -= position

	var night := not Game.is_day()
	var fill := Color(0.45, 0.72, 1.0, 0.28)
	if night:
		fill = Color(1.0, 0.85, 0.35, 0.28 + 0.12 * sin(_pulse) + _flash * 0.4)
	draw_colored_polygon(poly, fill)

	var line_color := Color("f7c948") if night else Color("6aa8e8")
	for i in poly.size():
		draw_dashed_line(poly[i], poly[(i + 1) % poly.size()], line_color, 2.5, 8.0)

	# nom + avancement au centre
	var font := ThemeDB.fallback_font
	var label := "%s  %d/%d" % [item.title, clicks_done, item.build_clicks]
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_rect(Rect2(-width / 2.0 - 6.0, -22.0, width + 12.0, 20.0), Color(0.35, 0.24, 0.29, 0.85))
	draw_string(font, Vector2(-width / 2.0, -8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	var ratio := float(clicks_done) / float(item.build_clicks)
	draw_rect(Rect2(-24.0, 2.0, 48.0, 6.0), Color(0.35, 0.24, 0.29, 0.85))
	draw_rect(Rect2(-23.0, 3.0, 46.0 * ratio, 4.0), Color("8fd96b"))
