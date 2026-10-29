extends Node
## Test d'intégration : lance vraiment le jeu et déroule une partie en accéléré.
## Usage : godot --headless --fixed-fps 60 res://tests/smoke_game.tscn
## (--fixed-fps pour que chaque frame compte 1/60 s même si ça tourne beaucoup plus vite)

var _passed := 0
var _failed := 0
var _world: World


func _ready() -> void:
	_run()


func _run() -> void:
	SaveFile.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	# la racine est encore occupée à installer cette scène : on ajoute le jeu juste après
	get_tree().root.add_child.call_deferred(main)
	await _frames(5)
	for child in main.get_children():
		if child is World:
			_world = child
	if _world == null:
		printerr("ECHEC : le monde n'a pas été créé par main.gd")
		get_tree().quit(1)
		return

	await _test_start()
	await _test_day_tools()
	await _test_shop_and_building()
	await _test_labor_and_vet()
	await _test_escape_and_return()
	await _test_night_wolves()
	_test_save()

	print("\nsmoke : %d ok, %d en échec" % [_passed, _failed])
	SaveFile.delete()
	get_tree().quit(1 if _failed > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("ECHEC : " + label)


func _group(name: String) -> Array[Node]:
	return get_tree().get_nodes_in_group(name)


func _first_ewe() -> Sheep:
	for sheep in _world.flock.sheep_list:
		if sheep.sex == Sheep.Sex.EWE and sheep.is_adult():
			return sheep
	return null


func _point_on(sheep: Sheep) -> Vector2:
	return sheep.position + Vector2(0, -10)


# --- scénarios ---

func _test_start() -> void:
	_check(_world.flock.count() == 3, "3 moutons au départ")
	_check(Game.money == Config.START_MONEY, "argent de départ")
	_check(_world.farm_map.pen_plots.size() == 1, "un enclos au départ")
	_check(_world.farm_map.fence_edges().size() == 64, "clôture de 64 segments")
	_check(Game.is_day() and Game.day == 1, "on commence de jour")


func _test_day_tools() -> void:
	var ewe := _first_ewe()
	var money := Game.money

	_world.tools.apply(&"milk", _point_on(ewe))
	_check(Game.money == money, "pas de traite si affamée")

	_world.tools.apply(&"feed", _point_on(ewe))
	_check(Game.money == money - 3 * Config.FEED_COST, "foin payé pour 3 moutons")
	_check(ewe.fed, "la brebis est nourrie")

	money = Game.money
	_world.tools.apply(&"milk", _point_on(ewe))
	_check(Game.money > money, "traite rapporte des pièces")
	money = Game.money
	_world.tools.apply(&"milk", _point_on(ewe))
	_check(Game.money == money, "une seule traite par jour")

	_world.tools.apply(&"shear", _point_on(ewe))
	_check(Game.money > money, "tonte rapporte des pièces")
	money = Game.money
	_world.tools.apply(&"shear", _point_on(ewe))
	_check(Game.money == money, "pas de 2e tonte avant 3 jours")

	_world.tools.apply(&"breed", _point_on(ewe))
	_check(ewe.pregnant, "reproduction : la brebis est pleine")
	_check(ewe.due_day == Game.day + Config.PREGNANCY_DAYS, "terme dans 2 jours")

	await _frames(60)


func _test_shop_and_building() -> void:
	Game.money = 5000
	var flock_before := _world.flock.count()

	Game.item_chosen.emit(ShopCatalog.by_id(&"sheep_ewe"))
	_check(_world.flock.count() == flock_before + 1, "achat d'une brebis")
	Game.item_chosen.emit(ShopCatalog.by_id(&"dog_builder"))
	_check(_group("scarers").size() == 1, "le chien bâtisseur ne fait pas peur aux loups")
	Game.item_chosen.emit(ShopCatalog.by_id(&"dog_protector"))
	_check(_group("scarers").size() == 2, "le chien protecteur fait peur aux loups")

	# terrain
	_world._on_land_requested(Vector2i(3, 2))
	_check(_world.farm_map.owned_plots.size() == 2, "parcelle achetée")
	_world._on_land_requested(Vector2i(4, 4))
	_check(_world.farm_map.owned_plots.size() == 2, "parcelle non voisine refusée")

	# on planifie un enclos sur la nouvelle parcelle, de jour
	var pen := ShopCatalog.by_id(&"pen")
	var rects: Array[Rect2i] = [Rect2i(48, 32, 16, 16)]
	_world._on_stamps_requested(pen, rects)
	_check(_group("sites").size() == 1, "chantier d'enclos planifié")

	# la nuit on le construit à la main
	Game.toggle_phase()
	await _frames(5)
	for site in _group("sites"):
		for i in pen.build_clicks:
			(site as ConstructionSite).hit()
	await _frames(5)
	_check(_world.farm_map.pen_plots.size() == 2, "enclos construit")
	_check(_world.farm_map.region_ids().size() == 1, "les deux enclos ont fusionné")

	# retour de jour
	Game.toggle_phase()
	await _frames(5)
	_check(Game.day == 2, "jour 2")

	# barrière qui coupe l'enclos fusionné en deux
	var wall: Array[Vector3i] = []
	for y in range(32, 48):
		wall.append(Vector3i(48, y, FarmMap.V))
	_world._on_barrier_requested(wall, false)
	_check(_world.farm_map.region_ids().size() == 2, "barrière : deux habitats")

	# barrière trop proche du bord : refusée
	var bad: Array[Vector3i] = []
	for y in range(32, 48):
		bad.append(Vector3i(50, y, FarmMap.V))
	var count_before := _world.farm_map.barriers.size()
	_world._on_barrier_requested(bad, false)
	_check(_world.farm_map.barriers.size() == count_before, "sous-enclos de moins de 4x4 refusé")

	# bâtiment : capacité
	var barn := ShopCatalog.by_id(&"barn")
	var barn_rect: Array[Rect2i] = [Rect2i(34, 34, 4, 3)]
	var region := _world.farm_map.region_id(Vector2i(35, 35))
	var capacity_before := _world.farm_map.capacity_of(region)
	_world._on_stamps_requested(barn, barn_rect)
	Game.toggle_phase()
	for site in _group("sites"):
		for i in barn.build_clicks:
			(site as ConstructionSite).hit()
	Game.toggle_phase()
	await _frames(5)
	_check(_world.farm_map.capacity_of(region) == capacity_before + 6, "la bergerie ajoute 6 places")


func _test_labor_and_vet() -> void:
	var ewe := _first_ewe()
	ewe.pregnant = true
	ewe.due_day = Game.day
	ewe.baby_wool = &"white"
	_world.flock.new_day()
	_check(ewe.in_labor, "mise bas déclenchée")
	var before := _world.flock.count()
	Game.money = 1000
	_world.tools.apply(&"vet", _point_on(ewe))
	_check(_world.flock.count() == before + 1, "agneau né avec le vétérinaire")
	_check(Game.money == 1000 - Config.VET_COST_BIRTH, "vétérinaire payé")

	var lamb: Sheep = null
	for sheep in _world.flock.sheep_list:
		if not sheep.is_adult():
			lamb = sheep
	_check(lamb != null, "l'agneau existe")
	if lamb != null:
		for i in Config.LAMB_STAGES:
			lamb.last_bottle_day = -1
			_world.tools.apply(&"grow", _point_on(lamb))
		_check(lamb.is_adult(), "l'agneau devient adulte avec le biberon")

	# un mouton blessé non soigné ne survit pas à la nuit suivante
	var victim := _world.flock.sheep_list[0]
	victim.wound()
	victim.wounded_day = Game.day - 1
	var count := _world.flock.count()
	_world.flock.start_night()
	_check(_world.flock.count() == count - 1, "un blessé non soigné meurt")


func _test_escape_and_return() -> void:
	# on surcharge un habitat pour forcer des évasions
	var region := _world.farm_map.region_id(Vector2i(60, 40))
	var capacity := _world.farm_map.capacity_of(region)
	for i in capacity + 25:
		var cell := Vector2(_world.farm_map.random_cell_in_region(region)) + Vector2(0.5, 0.5)
		_world.flock.create(Sheep.Sex.EWE, &"white", Config.LAMB_STAGES, Sheep.Place.PEN, cell)
	_world.flock.start_night()
	var escaped: Array[Sheep] = []
	for sheep in _world.flock.sheep_list:
		if sheep.place == Sheep.Place.ESCAPED:
			escaped.append(sheep)
	_check(not escaped.is_empty(), "des moutons s'échappent d'un enclos surpeuplé")
	if not escaped.is_empty():
		_check(not _world.farm_map.is_pen_cell(escaped[0].cell_i()), "l'échappé est hors enclos")
		# l'autre habitat (à gauche) a de la place : on y ramène un échappé
		_check(_world.flock.return_sheep(escaped[0]), "un échappé peut être ramené")
		_check(escaped[0].place == Sheep.Place.PEN, "et il est de nouveau dans un enclos")


func _test_night_wolves() -> void:
	# repartir d'un troupeau réduit et sain pour un test lisible
	for sheep in _world.flock.sheep_list.duplicate():
		sheep.remove_from_game()
	for i in 3:
		_world.flock.add_to_best_pen(Sheep.Sex.EWE, &"white")
	_check(_world.flock.count() == 3, "troupeau remis à 3")

	# un loup collé au berger doit fuir tout de suite
	_world.shepherd.teleport(Vector2(10.0, 10.0))
	var wolf := Wolf.new()
	wolf.cell_pos = Vector2(11.0, 10.0)
	_world.entities.add_child(wolf)
	await _frames(3)
	_check(wolf.state == Wolf.State.FLEE, "le loup fuit devant le berger")
	wolf.queue_free()

	# sans chien protecteur (acheté plus haut) et avec le berger loin : le loup fait son travail
	for node in _group("scarers"):
		if node is Dog:
			node.remove_from_group("scarers")
	Game.toggle_phase()
	await _frames(4500)
	_check(_world.flock.count() < 3, "un loup sans opposition mange au moins un mouton")

	Game.toggle_phase()
	await _frames(5)
	_check(_group("wolves").is_empty(), "les loups disparaissent à l'aube")


func _test_save() -> void:
	_world.save_game()
	var data := SaveFile.read()
	_check(data.has("sheep") and data.has("map") and data.has("game"), "sauvegarde complète")
	_check((data["sheep"] as Array).size() == _world.flock.count(), "tous les moutons sont sauvegardés")
	_check(int(data["game"]["day"]) == Game.day, "jour sauvegardé")

	var copy := FarmMap.new()
	copy.from_dict(data["map"])
	_check(copy.pen_plots.size() == _world.farm_map.pen_plots.size(), "enclos rechargés")
	_check(copy.barriers.size() == _world.farm_map.barriers.size(), "barrières rechargées")
