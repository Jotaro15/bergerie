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
	await _test_selling()
	await _test_demolition()
	await _test_daily_shop()
	await _test_drag_and_drop()
	await _test_pause()
	_test_needs()
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
	_check(Game.wool_count(&"white") == 1, "tonte : une laine de plus dans le stock")
	_check(Game.money == money, "tonte : rien n'est payé tout de suite")
	_world.tools.apply(&"shear", _point_on(ewe))
	_check(Game.wool_count(&"white") == 1, "pas de 2e tonte avant 3 jours")

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


func _shop_panel() -> ShopPanel:
	return get_tree().root.find_children("*", "ShopPanel", true, false)[0] as ShopPanel


# Revente : laine, moutons, décorations, clôtures.
func _test_selling() -> void:
	Game.money = 1000

	# la laine du stock est illimitée et se vend à la quantité choisie
	Game.add_wool(&"white", 49)
	_check(Game.wool_count(&"white") >= 50, "le stock de laine n'a pas de plafond")
	_check(Economy.wool_price(&"white", 4) == Economy.scaled(4 * WoolRegistry.price_of(&"white")), "aperçu : prix de la laine")
	var panel := _shop_panel()
	panel._select_tab(ShopPanel.SELL_TAB)
	await _frames(2)
	var stock := Game.wool_count(&"white")
	var expected := Economy.wool_price(&"white", 10)
	panel._sell_wool(&"white", 10)
	_check(Game.wool_count(&"white") == stock - 10 and Game.money == 1000 + expected, "vente de 10 laines")
	var all := Game.wool_count(&"white")
	panel._sell_wool(&"white", all)
	_check(Game.wool_count(&"white") == 0, "tout vendre vide le stock")
	var money := Game.money
	panel._sell_wool(&"white", 1)
	_check(Game.money == money, "impossible de vendre de la laine qu'on n'a pas")
	panel._select_tab("Terrain")

	# moutons : l'adulte vaut plus que l'agneau, le blessé bien moins
	var adult := Economy.sheep_base_price(true, false)
	var lamb := Economy.sheep_base_price(false, false)
	_check(adult > lamb, "un adulte vaut plus qu'un agneau")
	_check(Economy.sheep_base_price(true, true) * 3 <= adult, "un adulte blessé vaut beaucoup moins")
	_check(Economy.sheep_base_price(false, true) < lamb, "un agneau blessé vaut moins")
	var young := _world.flock.add_to_best_pen(Sheep.Sex.EWE, &"white", 0)
	var count := _world.flock.count()
	money = Game.money
	young.wounded = true
	_world.tools._sell(young)
	_check(Game.money - money == Economy.scaled(Economy.sheep_base_price(false, true)), "agneau blessé vendu au prix réduit")
	await _frames(2)
	_check(_world.flock.count() == count - 1, "le mouton vendu quitte le troupeau")

	# décoration : revendue à 40 %, elle rend sa place et son charme
	var tree := ShopCatalog.by_id(&"tree")
	var tree_rect := Rect2i(40, 40, 2, 2)
	_world._spawn_building(tree, tree_rect)
	var charm := Game.charm
	_check(_world.occupied.has(Vector2i(40, 40)), "la décoration occupe ses cases")
	var building := _world.seller.building_at(Vector2i(41, 41), ShopItem.Kind.DECORATION)
	_check(building != null, "le mode vente retrouve la décoration sous la souris")
	_check(_world.seller.building_at(Vector2i(41, 41), ShopItem.Kind.BUILDING) == null, "une décoration n'est pas un bâtiment")
	money = Game.money
	_world._on_decoration_sale_requested(building)
	await _frames(2)
	_check(Game.money - money == Economy.resale(tree) and Economy.resale(tree) < tree.price, "décoration revendue moins cher qu'achetée")
	_check(not _world.occupied.has(Vector2i(40, 40)), "la place est libérée")
	_check(Game.charm == charm - tree.charm, "le charme est retiré")
	_check(_world.seller.building_at(Vector2i(41, 41), ShopItem.Kind.DECORATION) == null, "la décoration a disparu")

	# clôtures : on revend la barrière posée plus tôt, puis on la remet
	var wall: Array[Vector3i] = []
	for y in range(32, 48):
		wall.append(Vector3i(48, y, FarmMap.V))
	var before := _world.farm_map.barriers.size()
	money = Game.money
	_world._on_fences_sale_requested(wall)
	_check(_world.farm_map.barriers.size() == before - wall.size(), "les clôtures sont retirées")
	_check(Game.money - money == Economy.fence_resale(wall.size()), "les clôtures rapportent leur prix de reprise")
	_check(_world.farm_map.region_ids().size() == 1, "sans la barrière, un seul habitat")
	_world._on_barrier_requested(wall, false)
	_check(_world.farm_map.region_ids().size() == 2, "barrière reposée")


# Démolition : un chantier de nuit, sans rien récupérer.
func _test_demolition() -> void:
	Game.money = 2000
	var trough := ShopCatalog.by_id(&"trough")
	var rect := Rect2i(36, 40, 2, 1)
	var region := _world.farm_map.region_id(Vector2i(36, 40))
	var capacity := _world.farm_map.capacity_of(region)

	_world._on_stamps_requested(trough, [rect] as Array[Rect2i])
	Game.toggle_phase()
	for site in _group("sites"):
		for i in trough.build_clicks:
			(site as ConstructionSite).hit()
	Game.toggle_phase()
	await _frames(5)
	var building := _world.seller.building_at(Vector2i(36, 40), ShopItem.Kind.BUILDING)
	_check(building != null, "l'abreuvoir est construit")
	_check(_world.farm_map.capacity_of(region) == capacity + trough.capacity_bonus, "l'abreuvoir ajoute des places")

	# on marque pour démolition : le bâtiment reste debout, on peut annuler
	_world._on_demolition_toggled(building)
	var site := _world.seller.demolition_site_of(building)
	_check(site != null and site.demolish, "démolition planifiée")
	_check(_world.farm_map.capacity_of(region) == capacity + trough.capacity_bonus, "le bâtiment sert encore tant qu'il n'est pas démoli")
	_world._on_demolition_toggled(building)
	await _frames(2)
	_check(_world.seller.demolition_site_of(building) == null, "démolition annulée")

	# elle est sauvegardée avec les chantiers
	_world._on_demolition_toggled(building)
	_world.save_game()
	var saved := false
	for entry: Dictionary in SaveFile.read().get("sites", []):
		saved = saved or bool(entry.get("demolish", false))
	_check(saved, "chantier de démolition sauvegardé")

	# la nuit, il faut donner tous les clics
	var money := Game.money
	Game.toggle_phase()
	await _frames(3)
	site = _world.seller.demolition_site_of(building)
	for i in trough.build_clicks - 1:
		site.hit()
	_check(is_instance_valid(building) and building.is_inside_tree(), "pas démoli avant le dernier clic")
	site.hit()
	await _frames(3)
	_check(_world.seller.building_at(Vector2i(36, 40), ShopItem.Kind.BUILDING) == null, "bâtiment démoli")
	_check(_world.farm_map.capacity_of(region) == capacity, "les places du bâtiment sont perdues")
	_check(not _world.occupied.has(Vector2i(36, 40)), "l'emplacement est libre")
	_check(Game.money == money, "aucune ressource récupérée")
	Game.toggle_phase()
	await _frames(3)


# La boutique du jour : offres, remises, stock limité, renouvellement.
func _test_daily_shop() -> void:
	Game.money = 5000
	DailyShop.refresh()
	var items := DailyShop.items()
	_check(items.size() == DailyShop.DECORATIONS + DailyShop.DOGS + DailyShop.SHEEP, "toutes les offres du jour sont là")

	var dog: ShopItem = null
	var sheep: ShopItem = null
	var deco: ShopItem = null
	for item in items:
		var base := ShopCatalog.by_id(item.id)
		if item.kind == ShopItem.Kind.SHEEP:
			sheep = item if sheep == null else sheep
			_check(Game.wool_found.has(StringName(item.extra["wool"])), "mouton du jour : une laine déjà obtenue")
			if item.extra["wool"] == &"white":
				_check(item.price < base.price, "mouton blanc du jour moins cher qu'en boutique")
		else:
			_check(item.price < base.price, "%s : moins cher que la boutique permanente" % item.title)
			if item.kind == ShopItem.Kind.DOG:
				dog = item if dog == null else dog
			else:
				deco = item if deco == null else deco
	_check(dog != null and sheep != null and deco != null, "décorations, chiens et moutons proposés")

	# un chien : payé une fois, puis épuisé
	var money := Game.money
	var dogs := _group("scarers").size() + _group("sites").size()
	Game.item_chosen.emit(dog)
	_check(Game.money == money - dog.price, "chien du jour acheté au prix remisé")
	_check(DailyShop.remaining(dog.extra["daily"]) == 0, "stock du chien épuisé")
	money = Game.money
	Game.item_chosen.emit(dog)
	_check(Game.money == money, "plus de chien du jour une fois épuisé")

	# un mouton : il arrive avec la laine annoncée
	var count := _world.flock.count()
	money = Game.money
	Game.item_chosen.emit(sheep)
	_check(_world.flock.count() == count + 1 and Game.money == money - sheep.price, "mouton du jour acheté")
	_check(_world.flock.sheep_list.back().wool_id == StringName(sheep.extra["wool"]), "il a la laine annoncée")

	# une décoration : placée en chantier, dans la limite du stock
	var stock := DailyShop.remaining(deco.extra["daily"])
	var spots: Array[Rect2i] = []
	for i in 5:
		spots.append(Rect2i(20 + i * 3, 20, 1, 1))
	money = Game.money
	Game.item_chosen.emit(deco)
	_check(Game.build_item != null and Game.build_item.extra.get("daily", "") == deco.extra["daily"], "décoration du jour : mode construction")
	_world._on_stamps_requested(deco, spots)
	_check(money - Game.money == stock * deco.price, "pas plus de décorations que le stock du jour")
	_check(DailyShop.remaining(deco.extra["daily"]) == 0, "stock de décorations épuisé")
	Game.clear_mode()

	# sauvegarde puis nouveau jour réel
	var saved := DailyShop.to_dict()
	DailyShop.from_dict(saved)
	_check(DailyShop.remaining(dog.extra["daily"]) == 0, "le stock restant survit à la sauvegarde")
	DailyShop.window -= 1
	_check(DailyShop.refresh(), "le lendemain, les offres sont renouvelées")
	_check(DailyShop.remaining(dog.extra["daily"]) == 1 or DailyShop.items().size() == items.size(), "nouvelles offres avec du stock")
	await _frames(2)


func _test_drag_and_drop() -> void:
	# à ce stade la barrière a coupé l'enclos en deux : habitat de gauche (x < 48) et de droite
	var dragger := _world.dragger
	var left := _world.farm_map.region_id(Vector2i(40, 40))
	var right := _world.farm_map.region_id(Vector2i(55, 40))
	_check(left >= 0 and right >= 0 and left != right, "deux habitats pour le drag & drop")

	var sheep: Sheep = _world.flock.sheep_in_region(left)[0]
	var origin := sheep.cell_pos

	# attraper puis déposer dans l'autre habitat
	_check(dragger.begin(_point_on(sheep)), "on attrape le mouton")
	_check(dragger.is_dragging() and sheep.dragged, "le mouton est porté")
	dragger.carry_to(Iso.to_screen(Vector2(55.5, 40.5)) - SheepDragger.GRAB_OFFSET)
	_check(sheep.cell_pos == origin, "pendant le glissé, la case d'origine est conservée")
	dragger.drop()
	_check(not dragger.is_dragging() and not sheep.dragged, "le mouton est lâché")
	_check(sheep.region() == right, "déposé dans l'autre habitat")

	# hors de tout enclos : refusé, le mouton reste où il est
	var before := sheep.cell_pos
	dragger.begin(_point_on(sheep))
	dragger.carry_to(Iso.to_screen(Vector2(5.5, 5.5)))
	dragger.drop()
	_check(sheep.region() == right and sheep.cell_pos == before, "dépôt hors enclos refusé")

	# annuler avec Échap
	dragger.begin(_point_on(sheep))
	dragger.carry_to(Iso.to_screen(Vector2(40.5, 40.5)))
	dragger.cancel()
	_check(sheep.region() == right and not sheep.dragged, "annulation : le mouton reste en place")

	# un mouton échappé qu'on dépose dans un enclos y est ramené
	var runaway: Sheep = _world.flock.sheep_in_region(left)[0]
	runaway.place = Sheep.Place.ESCAPED
	runaway.place_at(Vector2(5.5, 5.5))
	dragger.begin(_point_on(runaway))
	dragger.carry_to(Iso.to_screen(Vector2(40.5, 40.5)) - SheepDragger.GRAB_OFFSET)
	dragger.drop()
	_check(runaway.place == Sheep.Place.PEN and runaway.region() == left, "un échappé déposé dans un enclos est ramené")

	# un enclos plein refuse de nouveaux arrivants
	var capacity := _world.farm_map.capacity_of(left)
	var fillers: Array[Sheep] = []
	while _world.flock.sheep_in_region(left).size() < capacity:
		fillers.append(_world.flock.create(
				Sheep.Sex.EWE, &"white", Config.LAMB_STAGES, Sheep.Place.PEN, Vector2(40.5, 40.5)))
	var visitor: Sheep = _world.flock.sheep_in_region(right)[0]
	var visitor_cell := visitor.cell_pos
	dragger.begin(_point_on(visitor))
	dragger.carry_to(Iso.to_screen(Vector2(40.5, 40.5)) - SheepDragger.GRAB_OFFSET)
	dragger.drop()
	_check(visitor.region() == right and visitor.cell_pos == visitor_cell, "enclos plein : dépôt refusé")

	# on retire les moutons ajoutés pour remplir l'enclos, pour ne pas fausser la suite
	for filler in fillers:
		filler.remove_from_game()
	await _frames(5)


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(3)


func _test_pause_keys() -> void:
	Game.set_tool(&"feed")
	await _press(KEY_ESCAPE)
	_check(Game.tool_id == &"walk" and not Game.paused, "Échap annule d'abord l'outil, sans pause")
	await _press(KEY_ESCAPE)
	_check(Game.paused, "Échap sans rien à annuler ouvre la pause")
	await _press(KEY_ESCAPE)
	_check(not Game.paused, "Échap en pause reprend la partie")
	await _press(KEY_P)
	_check(Game.paused, "P met en pause")
	await _press(KEY_P)
	_check(not Game.paused, "P en pause reprend la partie")

	# en construction, un seul Échap ne doit annuler que la construction
	Game.set_build_item(ShopCatalog.by_id(&"tree"))
	await _press(KEY_ESCAPE)
	_check(Game.build_item == null and not Game.paused, "Échap en construction n'ouvre pas la pause")


func _test_pause() -> void:
	await _test_pause_keys()
	var positions := {}
	for sheep in _world.flock.sheep_list:
		positions[sheep] = sheep.position

	SaveFile.delete()
	Game.set_paused(true)
	_check(get_tree().paused and Game.paused, "le jeu est en pause")
	_check(SaveFile.read().has("sheep"), "la partie est sauvegardée en entrant en pause")

	await _frames(240)
	var frozen := true
	for sheep in positions:
		frozen = frozen and sheep.position == positions[sheep]
	_check(frozen, "les moutons ne bougent pas en pause")

	var phase := Game.phase
	Game.toggle_phase()
	_check(Game.phase == phase, "pas de changement de jour/nuit en pause")

	Game.set_paused(false)
	_check(not get_tree().paused and not Game.paused, "le jeu reprend")
	await _frames(600)
	var moved := false
	for sheep in positions:
		if is_instance_valid(sheep) and sheep.position != positions[sheep]:
			moved = true
	_check(moved, "les moutons rebougent après la pause")


func _has(sheep: Sheep, need: NeedIcons.Need) -> bool:
	return sheep.needs().has(need)


# Les icônes au-dessus des moutons doivent dire vrai : elles sont là quand l'action
# correspondante est possible, et seulement à ce moment-là.
func _test_needs() -> void:
	var existing := _world.flock.sheep_list.duplicate()
	Game.money = 5000
	var flock := _world.flock
	# écartés les uns des autres pour que le clic tombe sur le bon mouton
	var ewe := flock.create(Sheep.Sex.EWE, &"white", Config.LAMB_STAGES, Sheep.Place.PEN, Vector2(38.5, 38.5))
	var ram := flock.create(Sheep.Sex.RAM, &"white", Config.LAMB_STAGES, Sheep.Place.PEN, Vector2(42.5, 38.5))
	var lamb := flock.create(Sheep.Sex.EWE, &"white", 0, Sheep.Place.PEN, Vector2(38.5, 42.5))
	for sheep in [ewe, ram, lamb]:
		sheep.fed = false
		sheep.last_shear_day = -99
		sheep.last_milk_day = -99
		sheep.last_bottle_day = -99

	# à jeun : seulement la faim (et le biberon pour l'agneau)
	_check(ewe.needs() == [NeedIcons.Need.HUNGRY], "brebis à jeun : faim seulement")
	_check(_has(lamb, NeedIcons.Need.HUNGRY) and _has(lamb, NeedIcons.Need.BOTTLE), "agneau à jeun : faim et biberon")

	# nourris : on peut tondre, traire la brebis, mais pas traire le bélier
	_world.tools.apply(&"feed", _point_on(ewe))
	_check(not _has(ewe, NeedIcons.Need.HUNGRY), "plus de faim après le foin")
	_check(_has(ewe, NeedIcons.Need.SHEAR) and _has(ewe, NeedIcons.Need.MILK), "brebis nourrie : tonte et traite")
	_check(_has(ram, NeedIcons.Need.SHEAR) and not _has(ram, NeedIcons.Need.MILK), "bélier : tonte, pas de traite")
	_check(not _has(lamb, NeedIcons.Need.SHEAR) and not _has(lamb, NeedIcons.Need.MILK), "agneau : ni tonte ni traite")

	# l'icône disparaît quand l'action a été faite, et l'action rapportait bien
	var money := Game.money
	_world.tools.apply(&"milk", _point_on(ewe))
	_check(Game.money > money and not _has(ewe, NeedIcons.Need.MILK), "traite : gain, puis plus d'icône")
	var wool_before := Game.total_wool()
	_world.tools.apply(&"shear", _point_on(ewe))
	_check(Game.total_wool() == wool_before + 1 and not _has(ewe, NeedIcons.Need.SHEAR), "tonte : laine en stock, puis plus d'icône")
	money = Game.money
	money = Game.money
	_world.tools.apply(&"grow", _point_on(lamb))
	_check(Game.money < money and not _has(lamb, NeedIcons.Need.BOTTLE), "biberon : payé, puis plus d'icône")

	# gestation, mise bas, blessure
	ewe.pregnant = true
	_check(_has(ewe, NeedIcons.Need.PREGNANT) and not _has(ewe, NeedIcons.Need.LABOR), "gestante")
	ewe.in_labor = true
	_check(_has(ewe, NeedIcons.Need.LABOR) and not _has(ewe, NeedIcons.Need.PREGNANT), "mise bas : plus l'icône de gestation")
	money = Game.money
	_world.tools.apply(&"vet", _point_on(ewe))
	_check(Game.money < money and not _has(ewe, NeedIcons.Need.LABOR), "le véto règle la mise bas")

	ewe.pregnant = true
	ewe.wound()
	_check(_has(ewe, NeedIcons.Need.WOUNDED) and _has(ewe, NeedIcons.Need.PREGNANT), "blessée et gestante : les deux icônes")
	money = Game.money
	_world.tools.apply(&"vet", _point_on(ewe))
	_check(Game.money < money and not _has(ewe, NeedIcons.Need.WOUNDED), "le véto soigne la blessure")

	# hors de l'enclos
	ram.place = Sheep.Place.ESCAPED
	_check(_has(ram, NeedIcons.Need.ESCAPED), "échappé : à ramener")
	lamb.place = Sheep.Place.STRAY
	_check(lamb.needs() == [NeedIcons.Need.STRAY], "égaré : une seule icône")
	lamb.place = Sheep.Place.PEN
	ram.place = Sheep.Place.PEN

	# la nuit, plus de soins de jour, mais une blessure reste signalée
	ewe.pregnant = false
	ewe.fed = false
	ewe.wound()
	Game.phase = Game.Phase.NIGHT
	_check(ewe.needs() == [NeedIcons.Need.WOUNDED], "nuit : seule la blessure est signalée")
	ewe.pregnant = true
	_check(_has(ewe, NeedIcons.Need.PREGNANT), "la gestation reste visible la nuit")
	Game.phase = Game.Phase.DAY

	# on remet le troupeau comme avant ce test
	for sheep in flock.sheep_list.duplicate():
		if not existing.has(sheep):
			sheep.remove_from_game()


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
	_check(int(data["game"]["wool_stock"].get("white", 0)) == Game.wool_count(&"white"), "stock de laine sauvegardé")
	_check((data["game"]["daily"]["offers"] as Array).size() == DailyShop.offers.size(), "offres du jour sauvegardées")

	# la laine et les offres reviennent bien d'une sauvegarde
	Game.wool_stock = {&"white": 7}
	var game_data := Game.to_dict()
	Game.wool_stock = {}
	Game.from_dict(game_data)
	_check(Game.wool_count(&"white") == 7, "stock de laine rechargé")

	var copy := FarmMap.new()
	copy.from_dict(data["map"])
	_check(copy.pen_plots.size() == _world.farm_map.pen_plots.size(), "enclos rechargés")
	_check(copy.barriers.size() == _world.farm_map.barriers.size(), "barrières rechargées")
