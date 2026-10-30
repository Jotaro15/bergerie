class_name World
extends Node2D
## La ferme : assemble la carte, le troupeau, les chantiers et gère les entrées
## (déplacement, outils de jour, construction de nuit, caméra).

const START_PLOT := Vector2i(2, 2)
const AUTOSAVE_EVERY := 45.0
const HOVER_TOOLS: Array[StringName] = [&"feed", &"milk", &"shear", &"breed", &"grow", &"vet", &"sell"]
const DAY_TINT := Color.WHITE
const NIGHT_TINT := Color(0.46, 0.5, 0.78)

var farm_map := FarmMap.new()
var occupied: Dictionary = {}   # cases prises par un bâtiment ou un chantier

var view: FarmView
var site_layer: Node2D
var entities: Node2D
var build_controller: BuildController
var flock: Flock
var director: NightDirector
var tools: ToolController
var shepherd: Shepherd
var camera: Camera2D
var night_tint: CanvasModulate
var dragger: SheepDragger

var _fences: Array[FenceSegment] = []
var _buildings: Array[Building] = []
var _dogs: Array[Dog] = []
var _follow_camera := true
var _panning := false
var _autosave_timer := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("7fb85a"))
	_build_tree()
	_connect_signals()


# L'ordre des enfants compte : le sol, puis les chantiers, puis les entités
# (triées en profondeur), puis l'aperçu de construction par-dessus tout.
func _build_tree() -> void:
	view = FarmView.new()
	view.map = farm_map
	add_child(view)

	site_layer = Node2D.new()
	add_child(site_layer)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)

	flock = Flock.new()
	flock.map = farm_map
	flock.container = entities
	add_child(flock)

	director = NightDirector.new()
	director.map = farm_map
	director.flock = flock
	director.container = entities
	add_child(director)

	tools = ToolController.new()
	tools.map = farm_map
	tools.flock = flock
	add_child(tools)
	
	dragger = SheepDragger.new()
	dragger.map = farm_map
	dragger.flock = flock
	add_child(dragger)

	build_controller = BuildController.new()
	build_controller.map = farm_map
	build_controller.occupied = occupied
	build_controller.z_index = 100
	add_child(build_controller)

	shepherd = Shepherd.new()
	entities.add_child(shepherd)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.2, 1.2)
	camera.limit_left = -1400
	camera.limit_right = 1400
	camera.limit_top = -100
	camera.limit_bottom = 1400
	add_child(camera)

	night_tint = CanvasModulate.new()
	add_child(night_tint)


func _connect_signals() -> void:
	farm_map.changed.connect(_refresh_fences)
	Game.phase_changed.connect(_on_phase_changed)
	Game.item_chosen.connect(_on_item_chosen)
	build_controller.stamps_requested.connect(_on_stamps_requested)
	build_controller.barrier_requested.connect(_on_barrier_requested)
	build_controller.land_requested.connect(_on_land_requested)


## Lance une partie : à partir d'une sauvegarde si on en a une, sinon neuve.
func start(save_data: Dictionary) -> void:
	if save_data.is_empty():
		_new_game()
	else:
		_load(save_data)
	_refresh_fences()
	camera.position = shepherd.position


func _new_game() -> void:
	farm_map.add_pen(START_PLOT)
	flock.add_to_best_pen(Sheep.Sex.EWE, &"white")
	flock.add_to_best_pen(Sheep.Sex.EWE, &"white")
	flock.add_to_best_pen(Sheep.Sex.RAM, &"white")
	shepherd.teleport(Vector2(40.0, 49.5))
	_spawn_coins()


# --- boucle principale ---

func _process(delta: float) -> void:
	_update_camera(delta)
	_collect_things()
	var hovering := Game.is_day() and Game.tool_id in HOVER_TOOLS
	flock.update_hover(get_global_mouse_position(), hovering)

	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_EVERY:
		save_game()


func _update_camera(delta: float) -> void:
	if shepherd.moved_by_keys:
		_follow_camera = true
	if _follow_camera:
		camera.position = camera.position.lerp(shepherd.position, 1.0 - exp(-5.0 * delta))


# Pièces à ramasser, moutons égarés ou échappés à rattraper : il suffit de passer à côté.
func _collect_things() -> void:
	for coin in get_tree().get_nodes_in_group("coins"):
		if coin.cell_pos.distance_to(shepherd.cell_pos) < 1.3:
			Game.earn(coin.value)
			coin.remove_from_group("coins")
			coin.queue_free()

	for sheep in flock.sheep_list.duplicate():
		if sheep.place == Sheep.Place.PEN or sheep.held:
			continue
		if sheep.cell_pos.distance_to(shepherd.cell_pos) >= Config.RESCUE_RADIUS:
			continue
		if sheep.place == Sheep.Place.STRAY:
			flock.rescue_stray(sheep)
		else:
			flock.return_sheep(sheep)


# --- entrées ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _panning:
		camera.position -= (event as InputEventMouseMotion).relative / camera.zoom
		_follow_camera = false
	elif event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE:
				_cancel_or_clear()
			KEY_F:
				_follow_camera = true


func _on_mouse_button(mouse: InputEventMouseButton) -> void:
	match mouse.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / 1.1)
		MOUSE_BUTTON_MIDDLE:
			_panning = mouse.pressed
		MOUSE_BUTTON_RIGHT:
			if mouse.pressed:
				_cancel_or_clear()
		MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_on_left_click()

func _cancel_or_clear() -> void:
	if dragger.is_dragging():
		dragger.cancel()
	else:
		Game.clear_mode()

func _zoom(factor: float) -> void:
	camera.zoom = (camera.zoom * factor).clamp(Vector2(0.5, 0.5), Vector2(2.4, 2.4))


func _on_left_click() -> void:
	var point := get_global_mouse_position()
	var cell := Iso.to_cell(point)

	if not Game.is_day():
		_night_click(cell)
	elif Game.tool_id == &"walk":
		# déplacement au clic abandonné pour le moment au profit du drag & drop des moutons
		# _walk_to(cell)
		dragger.begin(point)


# La nuit : cliquer sur un chantier quand on est dessus le fait avancer,
# sinon on se déplace (vers le chantier si on a cliqué dessus).
func _night_click(cell: Vector2) -> void:
	var grid := Vector2i(floori(cell.x), floori(cell.y))
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as ConstructionSite
		if not site.contains_cell(grid):
			continue
		if site.reach_rect().has_point(shepherd.cell_pos):
			site.hit()
		else:
			Game.say("Place-toi sur le chantier pour construire.")
			# déplacement au clic abandonné pour le moment au profit du drag & drop des moutons
			# _walk_to(cell)
		return
	# déplacement au clic abandonné pour le moment au profit du drag & drop des moutons
	# _walk_to(cell)


func _walk_to(cell: Vector2) -> void:
	_follow_camera = true
	shepherd.walk_to(cell)


# --- jour / nuit ---

func _on_phase_changed(phase: int) -> void:
	var night := phase == Game.Phase.NIGHT
	if night:
		flock.start_night()
		director.start_night()
	else:
		director.end_night()
		flock.new_day()
		_spawn_coins()

	var tween := create_tween()
	tween.tween_property(night_tint, "color", NIGHT_TINT if night else DAY_TINT, 1.2)
	save_game()


func _spawn_coins() -> void:
	for coin in get_tree().get_nodes_in_group("coins"):
		coin.queue_free()
	var plots := farm_map.owned_plots.keys()
	for i in randi_range(5, 8):
		var rect := FarmMap.plot_rect(plots[randi() % plots.size()])
		var coin := Coin.new()
		coin.cell_pos = Vector2(
			randf_range(rect.position.x + 1.0, rect.end.x - 1.0),
			randf_range(rect.position.y + 1.0, rect.end.y - 1.0))
		coin.value = randi_range(5, 15)
		entities.add_child(coin)


# --- boutique ---

func _on_item_chosen(item: ShopItem) -> void:
	if not Game.is_day():
		Game.say("La boutique n'ouvre que de jour.")
		return
	match item.kind:
		ShopItem.Kind.SHEEP:
			_buy_sheep(item)
		ShopItem.Kind.DOG:
			_buy_dog(item)
		_:
			Game.set_build_item(item)


func _buy_sheep(item: ShopItem) -> void:
	if not flock.has_room():
		Game.say("Aucun enclos n'a de place libre !")
		return
	if not Game.spend(item.price):
		return
	var sex := Sheep.Sex.RAM if item.extra.get("sex") == "ram" else Sheep.Sex.EWE
	flock.add_to_best_pen(sex, &"white")
	Game.say("%s ajouté(e) au troupeau." % item.title)


func _buy_dog(item: ShopItem) -> void:
	if not Game.spend(item.price):
		return
	_spawn_dog(_role_from_name(item.extra.get("role", "protector")), shepherd.cell_pos + Vector2(1.5, 1.5))
	Game.say("%s adopté !" % item.title)


func _spawn_dog(role: Dog.Role, cell: Vector2) -> void:
	var dog := Dog.new()
	dog.role = role
	dog.cell_pos = cell
	entities.add_child(dog)
	_dogs.append(dog)


func _role_from_name(role_name: String) -> Dog.Role:
	match role_name:
		"finder":
			return Dog.Role.FINDER
		"builder":
			return Dog.Role.BUILDER
	return Dog.Role.PROTECTOR


# --- construction ---

func _on_stamps_requested(item: ShopItem, rects: Array[Rect2i]) -> void:
	var planned := 0
	for rect in rects:
		if Game.money < item.price:
			Game.say("Plus assez de pièces pour tout planifier.")
			break
		Game.spend(item.price)
		_add_site(item, rect, 0)
		planned += 1
	if planned > 0:
		Game.say("%d chantier(s) planifié(s), à construire la nuit." % planned)


func _add_site(item: ShopItem, rect: Rect2i, clicks_done: int) -> void:
	var site := ConstructionSite.new()
	site.item = item
	site.rect = rect
	site.clicks_done = clicks_done
	site.completed.connect(_on_site_completed)
	site_layer.add_child(site)
	_mark(rect, true)


func _on_site_completed(site: ConstructionSite) -> void:
	var item := site.item
	var rect := site.rect
	site.queue_free()

	if item.kind == ShopItem.Kind.ENCLOSURE:
		_mark(rect, false)
		farm_map.add_pen(FarmMap.plot_of(rect.position))
		Game.say("Enclos terminé !")
	else:
		_spawn_building(item, rect)
		Game.say("%s terminé(e) !" % item.title)


func _spawn_building(item: ShopItem, rect: Rect2i) -> void:
	var building := Building.new()
	building.item = item
	building.rect = rect
	entities.add_child(building)
	_buildings.append(building)

	if item.capacity_bonus > 0:
		farm_map.add_capacity_bonus(rect.position + rect.size / 2, item.capacity_bonus)
	Game.charm += item.charm
	Game.stats_changed.emit()


func _mark(rect: Rect2i, taken: bool) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if taken:
				occupied[Vector2i(x, y)] = true
			else:
				occupied.erase(Vector2i(x, y))


func _on_land_requested(plot: Vector2i) -> void:
	if not farm_map.can_buy_plot(plot):
		Game.say("Tu peux seulement acheter une parcelle à côté de ton terrain.")
		return
	if Game.spend(ShopCatalog.land_price(farm_map.owned_plots.size())):
		farm_map.buy_plot(plot)
		Game.say("Nouvelle parcelle achetée !")


func _on_barrier_requested(edges: Array[Vector3i], remove: bool) -> void:
	if remove:
		var removed := farm_map.remove_barriers(edges)
		if removed > 0:
			Game.earn(removed * Config.BARRIER_PRICE / 2)
		return

	match farm_map.check_barriers(edges):
		"outside":
			Game.say("Les barrières se posent à l'intérieur des enclos.")
		"too_small":
			Game.say("Un sous-enclos doit faire 4x4 cases minimum.")
		"nothing":
			pass
		_:
			var added := 0
			for edge in edges:
				if not farm_map.has_barrier(edge):
					added += 1
			if Game.spend(added * Config.BARRIER_PRICE):
				farm_map.add_barriers(edges)


func _refresh_fences() -> void:
	for fence in _fences:
		fence.queue_free()
	_fences.clear()
	for edge in farm_map.fence_edges():
		_add_fence(edge, false)
	for edge: Vector3i in farm_map.barriers:
		_add_fence(edge, true)
	Game.owned_plots = farm_map.owned_plots.size()
	Game.stats_changed.emit()


func _add_fence(edge: Vector3i, inner: bool) -> void:
	var fence := FenceSegment.new()
	fence.edge = edge
	fence.inner = inner
	entities.add_child(fence)
	_fences.append(fence)


# --- sauvegarde ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func save_game() -> void:
	_autosave_timer = 0.0

	var sheep_data := []
	for sheep in flock.sheep_list:
		if sheep.place != Sheep.Place.STRAY:
			sheep_data.append(sheep.to_dict())

	var buildings := []
	for building in _buildings:
		buildings.append({"id": String(building.item.id), "rect": _rect_to_array(building.rect)})

	var sites := []
	for node in get_tree().get_nodes_in_group("sites"):
		var site := node as ConstructionSite
		sites.append({"id": String(site.item.id), "rect": _rect_to_array(site.rect), "clicks": site.clicks_done})

	var dogs := []
	for dog in _dogs:
		dogs.append({"role": dog.role, "x": dog.cell_pos.x, "y": dog.cell_pos.y})

	SaveFile.write({
		"version": 1,
		"game": Game.to_dict(),
		"map": farm_map.to_dict(),
		"sheep": sheep_data,
		"buildings": buildings,
		"sites": sites,
		"dogs": dogs,
		"shepherd": [shepherd.cell_pos.x, shepherd.cell_pos.y],
	})


func _load(data: Dictionary) -> void:
	Game.charm = 0
	Game.from_dict(data.get("game", {}))
	farm_map.from_dict(data.get("map", {}))

	for entry: Dictionary in data.get("buildings", []):
		var item := ShopCatalog.by_id(StringName(entry["id"]))
		if item != null:
			_spawn_building(item, _rect_from_array(entry["rect"]))

	for entry: Dictionary in data.get("sites", []):
		var item := ShopCatalog.by_id(StringName(entry["id"]))
		if item != null:
			_add_site(item, _rect_from_array(entry["rect"]), int(entry.get("clicks", 0)))

	for entry: Dictionary in data.get("sheep", []):
		var sheep := flock.create(Sheep.Sex.EWE, &"white", Config.LAMB_STAGES, Sheep.Place.PEN, Vector2.ZERO)
		sheep.load_dict(entry)
		sheep.place_at(sheep.cell_pos)

	for entry: Dictionary in data.get("dogs", []):
		_spawn_dog(int(entry["role"]) as Dog.Role, Vector2(float(entry["x"]), float(entry["y"])))

	var pos: Array = data.get("shepherd", [40.0, 49.5])
	shepherd.teleport(Vector2(float(pos[0]), float(pos[1])))
	flock.refresh_stats()
	_spawn_coins()


func _rect_to_array(rect: Rect2i) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _rect_from_array(values: Array) -> Rect2i:
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
