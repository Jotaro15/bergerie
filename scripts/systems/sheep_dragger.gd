class_name SheepDragger
extends Node2D
## Drag & drop des moutons : on attrape un mouton à la souris, on le promène,
## et on le dépose dans un enclos (le même ou un autre). Un mouton échappé
## qu'on dépose dans un enclos y est ramené donc.
## Pendant le glissé, le mouton garde sa case d'origine (`cell_pos`) : seule sa
## position à l'écran suit la souris. Comme ça, une annulation ou une sauvegarde
## en plein glissé ne peut pas laisser un mouton coincé hors d'un enclos (astuce prise de reddit, et c'est pas bête en effet)

## Écart entre le curseur et les pattes du mouton : on tient le mouton par le corps.
const GRAB_OFFSET := Vector2(0, 10)

var map: FarmMap
var flock: Flock

var _sheep: Sheep = null


func _ready() -> void:
	Game.phase_changed.connect(_on_phase_changed)


func is_dragging() -> bool:
	return is_instance_valid(_sheep)


## Attrape le mouton sous `point` (coordonnées du monde). Renvoie false s'il n'y en a pas.
func begin(point: Vector2) -> bool:
	var sheep := flock.pick(point)
	if sheep == null or sheep.held:
		return false
	_sheep = sheep
	_sheep.dragged = true
	return true


func carry_to(point: Vector2) -> void:
	if is_dragging():
		_sheep.carry_to(point + GRAB_OFFSET)


## Lâche le mouton à l'endroit où il se trouve.
func drop() -> void:
	if not is_dragging():
		_sheep = null
		return

	var sheep := _sheep
	_sheep = null
	sheep.dragged = false

	var cell := Iso.to_cell(sheep.position)
	var target := map.region_id(Iso.to_grid(sheep.position))
	if target < 0:
		_refuse(sheep, "Dépose le mouton à l'intérieur d'un enclos.")
		return

	var same_region := sheep.place == Sheep.Place.PEN and target == sheep.region()
	if not same_region and flock.sheep_in_region(target).size() >= map.capacity_of(target):
		_refuse(sheep, "Cet enclos est plein.")
		return

	sheep.place = Sheep.Place.PEN
	sheep.place_at(cell)
	flock.refresh_stats()


## Remet le mouton là où il était.
func cancel() -> void:
	if not is_dragging():
		_sheep = null
		return
	_sheep.dragged = false
	_sheep.place_at(_sheep.cell_pos)
	_sheep = null


func _process(_delta: float) -> void:
	if _sheep == null:
		return
	# on suit le bouton plutôt que l'événement de relâchement : si la souris est
	# lâchée au-dessus de l'interface, le glissé se termine quand même
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		carry_to(get_global_mouse_position())
	else:
		drop()


func _refuse(sheep: Sheep, message: String) -> void:
	sheep.place_at(sheep.cell_pos)
	Game.say(message)


func _on_phase_changed(_phase: int) -> void:
	cancel()