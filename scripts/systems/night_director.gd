class_name NightDirector
extends Node
## Gère ce qui arrive la nuit : les loups (plus le troupeau est gros, plus il y en a)
## et les moutons égarés à retrouver.

var map: FarmMap
var flock: Flock
var container: Node2D

var _queue: Array[float] = []   # délais avant l'arrivée de chaque loup


func start_night() -> void:
	_queue.clear()
	var wolves := mini(ceili(float(flock.count()) / Config.SHEEP_PER_WOLF), Config.MAX_WOLVES)
	for i in wolves:
		_queue.append(randf_range(3.0, 28.0))
	if wolves > 0:
		Game.say("Des loups rôdent... approche-toi d'eux pour les faire fuir !")

	for i in randi_range(0, 2):
		_spawn_stray()


## À l'aube les loups disparaissent et les égarés repartent.
func end_night() -> void:
	_queue.clear()
	for wolf in get_tree().get_nodes_in_group("wolves"):
		wolf.queue_free()
	for sheep in flock.sheep_list.duplicate():
		if sheep.place == Sheep.Place.STRAY:
			sheep.remove_from_game()


func _process(delta: float) -> void:
	for i in range(_queue.size() - 1, -1, -1):
		_queue[i] -= delta
		if _queue[i] <= 0.0:
			_queue.remove_at(i)
			_spawn_wolf()


func _spawn_wolf() -> void:
	var wolf := Wolf.new()
	wolf.kills_left = randi_range(1, 2)
	# il arrive par un bord de la carte, au hasard
	var w := float(Config.WORLD_CELLS.x)
	var h := float(Config.WORLD_CELLS.y)
	match randi() % 4:
		0:
			wolf.cell_pos = Vector2(-2.0, randf_range(0.0, h))
		1:
			wolf.cell_pos = Vector2(w + 2.0, randf_range(0.0, h))
		2:
			wolf.cell_pos = Vector2(randf_range(0.0, w), -2.0)
		_:
			wolf.cell_pos = Vector2(randf_range(0.0, w), h + 2.0)
	container.add_child(wolf)


func _spawn_stray() -> void:
	flock.spawn_stray(_random_free_cell(), WoolRegistry.random_stray_wool())


# De préférence sur nos terres mais hors des enclos, sinon n'importe où.
func _random_free_cell() -> Vector2:
	var plots := map.owned_plots.keys()
	for attempt in 30:
		var plot: Vector2i = plots[randi() % plots.size()]
		var rect := FarmMap.plot_rect(plot)
		var cell := Vector2i(
			randi_range(rect.position.x, rect.end.x - 1),
			randi_range(rect.position.y, rect.end.y - 1))
		if not map.is_pen_cell(cell):
			return Vector2(cell) + Vector2(0.5, 0.5)
	return Vector2(randf_range(2.0, 78.0), randf_range(2.0, 78.0))
