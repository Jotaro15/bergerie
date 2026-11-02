class_name SellController
extends Node2D
## Les modes de revente qui se font directement sur la carte : vendre une décoration,
## vendre des clôtures (en glissant) et marquer un bâtiment à démolir.
## Comme BuildController, il ne modifie rien lui-même : il émet des signaux et c'est
## le monde qui touche aux pièces, aux chantiers et à la carte.

signal decoration_sale_requested(building: Building)
signal demolition_toggled(building: Building)
signal fences_sale_requested(edges: Array[Vector3i])

const MODES: Array[StringName] = [&"sell_deco", &"sell_fence", &"demolish"]
const PLUM := Color("5a3e4b")

var map: FarmMap

var _mode: StringName = &""
var _dragging := false
var _start := Vector2i.ZERO


func _ready() -> void:
	Game.mode_changed.connect(_on_mode_changed)
	Game.pause_changed.connect(func(_paused: bool) -> void: _dragging = false)
	set_process(false)


func _on_mode_changed() -> void:
	_mode = Game.tool_id if Game.tool_id in MODES else &""
	_dragging = false
	set_process(_mode != &"")
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _mode == &"" or not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse.pressed:
		get_viewport().set_input_as_handled()
		_on_press()
	elif _dragging:
		get_viewport().set_input_as_handled()
		_dragging = false
		var edges := _existing_fences(BuildController.barrier_line(_start, _mouse_vertex()))
		if not edges.is_empty():
			fences_sale_requested.emit(edges)


func _on_press() -> void:
	match _mode:
		&"sell_deco":
			var building := building_at(_mouse_cell(), ShopItem.Kind.DECORATION)
			if building != null:
				decoration_sale_requested.emit(building)
		&"demolish":
			var building := building_at(_mouse_cell(), ShopItem.Kind.BUILDING)
			if building != null:
				demolition_toggled.emit(building)
		&"sell_fence":
			_dragging = true
			_start = _mouse_vertex()


# --- recherche ---

func building_at(cell: Vector2i, kind: ShopItem.Kind) -> Building:
	for node in get_tree().get_nodes_in_group("buildings"):
		var building := node as Building
		if building.item.kind == kind and building.rect.has_point(cell):
			return building
	return null


## Le chantier de démolition d'un bâtiment, s'il y en a un.
func demolition_site_of(building: Building) -> ConstructionSite:
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as ConstructionSite
		if site.demolish and site.building == building:
			return site
	return null


func _existing_fences(edges: Array[Vector3i]) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for edge in edges:
		if map.has_barrier(edge):
			result.append(edge)
	return result


func _mouse_cell() -> Vector2i:
	return Iso.to_grid(get_global_mouse_position())


func _mouse_vertex() -> Vector2i:
	var c := Iso.to_cell(get_global_mouse_position())
	return Vector2i(roundi(c.x), roundi(c.y))


# --- aperçu ---

func _draw() -> void:
	match _mode:
		&"sell_deco":
			var building := building_at(_mouse_cell(), ShopItem.Kind.DECORATION)
			if building != null:
				_highlight(building, Color(0.3, 0.9, 0.4, 0.4))
				_draw_tag("Vendre : +%d" % Economy.resale(building.item), false)
		&"demolish":
			var building := building_at(_mouse_cell(), ShopItem.Kind.BUILDING)
			if building != null:
				var condemned := demolition_site_of(building) != null
				_highlight(building, Color(1.0, 0.7, 0.3, 0.4) if condemned else Color(0.95, 0.3, 0.3, 0.4))
				_draw_tag("Annuler la démolition" if condemned else "Démolir cette nuit  (rien n'est récupéré)", not condemned)
		&"sell_fence":
			_draw_fence_preview()


func _highlight(building: Building, color: Color) -> void:
	var poly := Iso.rect_polygon(building.rect)
	draw_colored_polygon(poly, color)
	draw_polyline(poly + PackedVector2Array([poly[0]]), Color.WHITE, 2.0)


func _draw_fence_preview() -> void:
	var vertex := _mouse_vertex()
	draw_circle(Iso.to_screen(Vector2(vertex)), 5.0, Color.WHITE)
	if not _dragging:
		return
	var edges := _existing_fences(BuildController.barrier_line(_start, vertex))
	for edge in edges:
		var a := Vector2(edge.x, edge.y)
		var b := a + (Vector2(1, 0) if edge.z == FarmMap.H else Vector2(0, 1))
		draw_line(Iso.to_screen(a), Iso.to_screen(b), Color(1.0, 0.7, 0.3), 5.0)
	_draw_tag("%d clôture(s)  =  +%d" % [edges.size(), Economy.fence_resale(edges.size())], false)


func _draw_tag(text: String, warning: bool) -> void:
	var font := ThemeDB.fallback_font
	var pos := get_global_mouse_position() + Vector2(16, -18)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_rect(Rect2(pos.x - 6.0, pos.y - 16.0, width + 12.0, 22.0), PLUM)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color("ff9a8a") if warning else Color.WHITE)
