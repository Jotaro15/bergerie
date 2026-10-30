class_name BuildController
extends Node2D
## Mode construction : on choisit un objet dans la boutique, puis on clique ou on
## *glisse* pour en poser plusieurs d'un coup (comme dans la plupart des jeux de
## gestion). Pendant le glissé on voit un aperçu vert (valide) ou rouge (impossible).
## Clic droit ou Échap pour annuler.
##
## Ce contrôleur ne modifie rien lui-même, il émet des signaux et c'est le monde
## qui décide (argent, chantiers...).

signal stamps_requested(item: ShopItem, rects: Array[Rect2i])
signal barrier_requested(edges: Array[Vector3i], remove: bool)
signal land_requested(plot: Vector2i)

const MAX_STAMPS := 150

var map: FarmMap
var occupied: Dictionary   # cases prises par un bâtiment ou un chantier (partagé avec le monde)

var item: ShopItem = null

var _dragging := false
var _drag_button := MOUSE_BUTTON_LEFT
var _start := Vector2i.ZERO
var _barrier_error := ""
var _last_preview_key := ""


func _ready() -> void:
	Game.mode_changed.connect(_on_mode_changed)
	Game.pause_changed.connect(func(_paused: bool) -> void: _dragging = false)
	set_process(false)


func _on_mode_changed() -> void:
	item = Game.build_item
	_dragging = false
	set_process(item != null)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if item == null:
		return

	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		Game.clear_mode()
		# sans ça, le monde recevrait le même Échap et ouvrirait la pause dans la foulée
		get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	var button := mouse.button_index
	if button != MOUSE_BUTTON_LEFT and button != MOUSE_BUTTON_RIGHT:
		return

	if mouse.pressed:
		if _mouse_over_ui():
			return
		get_viewport().set_input_as_handled()
		if _dragging:
			_dragging = false          # un 2e bouton pendant le glissé = annuler
		elif button == MOUSE_BUTTON_RIGHT and item.kind != ShopItem.Kind.BARRIER:
			Game.clear_mode()
		else:
			_begin(button)
	elif _dragging and button == _drag_button:
		get_viewport().set_input_as_handled()
		_finish()


func _mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


# --- début / fin du glissé ---

func _begin(button: int) -> void:
	var cell := _mouse_cell()
	if item.kind == ShopItem.Kind.LAND:
		if button == MOUSE_BUTTON_LEFT:
			land_requested.emit(FarmMap.plot_of(cell))
		return

	_dragging = true
	_drag_button = button as MouseButton
	_start = _mouse_vertex() if item.kind == ShopItem.Kind.BARRIER else _anchor(cell)


func _finish() -> void:
	_dragging = false
	if item.kind == ShopItem.Kind.BARRIER:
		var edges := _barrier_line(_start, _mouse_vertex())
		if not edges.is_empty():
			barrier_requested.emit(edges, _drag_button == MOUSE_BUTTON_RIGHT)
		return

	var valid: Array[Rect2i] = []
	for rect in _stamps():
		if _stamp_is_valid(rect):
			valid.append(rect)
	if not valid.is_empty():
		stamps_requested.emit(item, valid)


# --- géométrie ---

func _mouse_cell() -> Vector2i:
	return Iso.to_grid(get_global_mouse_position())


# Sommet de grille le plus proche de la souris (pour tracer les barrières).
func _mouse_vertex() -> Vector2i:
	var c := Iso.to_cell(get_global_mouse_position())
	return Vector2i(roundi(c.x), roundi(c.y))


func _step() -> Vector2i:
	if item.kind == ShopItem.Kind.ENCLOSURE:
		return Vector2i(Config.PLOT_SIZE, Config.PLOT_SIZE)
	return item.size


# Coin haut-gauche d'un objet posé "autour" de la case visée.
func _anchor(cell: Vector2i) -> Vector2i:
	if item.kind == ShopItem.Kind.ENCLOSURE:
		return FarmMap.plot_of(cell) * Config.PLOT_SIZE
	return cell - item.size / 2


# Les rectangles posés entre le point de départ et la souris : une grille de
# "tampons" de la taille de l'objet, dans la direction du glissé.
func _stamps() -> Array[Rect2i]:
	var step := _step()
	var current := _anchor(_mouse_cell())
	var first := _start if _dragging else current

	var nx := _count(current.x - first.x, step.x)
	var ny := _count(current.y - first.y, step.y)
	var dir_x := 1 if current.x >= first.x else -1
	var dir_y := 1 if current.y >= first.y else -1

	var rects: Array[Rect2i] = []
	for j in ny:
		for i in nx:
			if rects.size() >= MAX_STAMPS:
				return rects
			var pos := first + Vector2i(i * step.x * dir_x, j * step.y * dir_y)
			rects.append(Rect2i(pos, item.size))
	return rects


func _count(delta: int, step: int) -> int:
	if delta >= 0:
		return delta / step + 1
	return (-delta + step - 1) / step + 1


func _stamp_is_valid(rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if not FarmMap.in_world(cell) or not map.is_owned(cell) or occupied.has(cell):
				return false

	if item.kind == ShopItem.Kind.ENCLOSURE:
		return not map.pen_plots.has(FarmMap.plot_of(rect.position))
	return true


# Les segments d'une barrière tracée en ligne droite entre deux sommets.
func _barrier_line(from: Vector2i, to: Vector2i) -> Array[Vector3i]:
	var edges: Array[Vector3i] = []
	var delta := to - from
	if absi(delta.x) >= absi(delta.y):
		# ligne le long de x : segments "H" au niveau y = from.y
		for x in range(mini(from.x, to.x), maxi(from.x, to.x)):
			edges.append(Vector3i(x, from.y, FarmMap.H))
	else:
		for y in range(mini(from.y, to.y), maxi(from.y, to.y)):
			edges.append(Vector3i(from.x, y, FarmMap.V))
	return edges


# --- dessin de l'aperçu ---

func _draw() -> void:
	if item == null:
		return
	match item.kind:
		ShopItem.Kind.LAND:
			_draw_land_preview()
		ShopItem.Kind.BARRIER:
			_draw_barrier_preview()
		_:
			_draw_stamp_preview()


func _draw_land_preview() -> void:
	var plot := FarmMap.plot_of(_mouse_cell())
	var ok := map.can_buy_plot(plot)
	var poly := Iso.rect_polygon(FarmMap.plot_rect(plot))
	draw_colored_polygon(poly, Color(0.3, 0.9, 0.4, 0.4) if ok else Color(0.95, 0.3, 0.3, 0.4))
	draw_polyline(poly + PackedVector2Array([poly[0]]), Color.WHITE, 2.5)


func _draw_stamp_preview() -> void:
	var valid := 0
	for rect in _stamps():
		var ok := _stamp_is_valid(rect)
		if ok:
			valid += 1
		var poly := Iso.rect_polygon(rect)
		draw_colored_polygon(poly, Color(0.3, 0.9, 0.4, 0.42) if ok else Color(0.95, 0.3, 0.3, 0.42))
		draw_polyline(poly + PackedVector2Array([poly[0]]), Color.WHITE, 1.5)
	_draw_tag("x%d  =  %d" % [valid, valid * item.price], not Game.money >= valid * item.price)


func _draw_barrier_preview() -> void:
	var vertex := _mouse_vertex()
	var tip := Iso.to_screen(Vector2(vertex))
	draw_circle(tip, 5.0, Color.WHITE)

	if not _dragging:
		return
	var edges := _barrier_line(_start, vertex)
	var removing := _drag_button == MOUSE_BUTTON_RIGHT

	# on ne recalcule la validité que quand la ligne change (flood fill pas gratuit)
	var key := "%s-%s-%s" % [_start, vertex, removing]
	if key != _last_preview_key:
		_last_preview_key = key
		_barrier_error = "" if removing else map.check_barriers(edges)

	var color := Color(0.95, 0.3, 0.3)
	if removing:
		color = Color(1.0, 0.7, 0.3)
	elif _barrier_error == "":
		color = Color(0.3, 0.9, 0.4)
	for edge in edges:
		var a := Vector2(edge.x, edge.y)
		var b := a + (Vector2(1, 0) if edge.z == FarmMap.H else Vector2(0, 1))
		draw_line(Iso.to_screen(a), Iso.to_screen(b), color, 5.0)

	if not removing:
		var cost := edges.size() * item.price
		var text := "%d segments  =  %d" % [edges.size(), cost]
		if _barrier_error == "too_small":
			text = "Sous-enclos de 4x4 minimum !"
		elif _barrier_error == "outside":
			text = "Seulement à l'intérieur d'un enclos"
		_draw_tag(text, _barrier_error != "" and _barrier_error != "nothing")


func _draw_tag(text: String, warning: bool) -> void:
	var font := ThemeDB.fallback_font
	var pos := get_global_mouse_position() + Vector2(16, -18)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_rect(Rect2(pos.x - 6.0, pos.y - 16.0, width + 12.0, 22.0), Color("5a3e4b"))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color("ff9a8a") if warning else Color.WHITE)
