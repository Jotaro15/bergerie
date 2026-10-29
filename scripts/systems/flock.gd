class_name Flock
extends Node
## Le troupeau : création des moutons, reproduction, naissances, évasions.
## Les moutons sont des enfants de `container` (le nœud trié en profondeur du monde).

signal changed

var map: FarmMap
var container: Node2D
var sheep_list: Array[Sheep] = []


func _ready() -> void:
	add_to_group("flock")


# --- création / suppression ---

func create(sex: Sheep.Sex, wool: StringName, growth: int, place: Sheep.Place, cell: Vector2) -> Sheep:
	var sheep := Sheep.new()
	sheep.map = map
	sheep.sex = sex
	sheep.wool_id = wool
	sheep.growth = growth
	sheep.place = place
	sheep.cell_pos = cell
	sheep.removed.connect(_on_sheep_removed)
	container.add_child(sheep)
	sheep_list.append(sheep)
	refresh_stats()
	return sheep


## Ajoute un mouton dans l'enclos qui a le plus de place. Renvoie null s'il n'y en a pas.
func add_to_best_pen(sex: Sheep.Sex, wool: StringName, growth := Config.LAMB_STAGES) -> Sheep:
	var region := _find_room()
	if region < 0:
		return null
	return create(sex, wool, growth, Sheep.Place.PEN, _random_point_in(region))


func spawn_stray(cell: Vector2, wool: StringName) -> Sheep:
	var sex := Sheep.Sex.EWE if randf() < 0.5 else Sheep.Sex.RAM
	return create(sex, wool, Config.LAMB_STAGES, Sheep.Place.STRAY, cell)


func _on_sheep_removed(sheep: Sheep) -> void:
	sheep_list.erase(sheep)
	refresh_stats()


# --- requêtes ---

## Nombre de moutons du troupeau (les égarés pas encore recueillis ne comptent pas).
func count() -> int:
	var total := 0
	for sheep in sheep_list:
		if sheep.place != Sheep.Place.STRAY:
			total += 1
	return total


func sheep_in_region(region: int) -> Array[Sheep]:
	var result: Array[Sheep] = []
	for sheep in sheep_list:
		if sheep.place == Sheep.Place.PEN and sheep.region() == region:
			result.append(sheep)
	return result


func pick(point: Vector2, radius := 26.0) -> Sheep:
	var best: Sheep = null
	var best_dist := radius
	for sheep in sheep_list:
		if sheep.place == Sheep.Place.STRAY:
			continue
		var dist := (sheep.position + Vector2(0, -10)).distance_to(point)
		if dist < best_dist:
			best_dist = dist
			best = sheep
	return best


func update_hover(point: Vector2, enabled: bool) -> void:
	var under := pick(point) if enabled else null
	for sheep in sheep_list:
		sheep.hovered = sheep == under


# --- reproduction ---

## Cherche un partenaire dans le même enclos. Renvoie un message pour le joueur.
func try_breed(target: Sheep) -> String:
	if not target.is_adult():
		return "Un agneau est trop jeune pour se reproduire."
	if target.place != Sheep.Place.PEN:
		return "Il faut d'abord ramener ce mouton dans un enclos."

	var wants_sex := Sheep.Sex.RAM if target.sex == Sheep.Sex.EWE else Sheep.Sex.EWE
	var partner := _nearest_partner(target, wants_sex)
	if partner == null:
		if target.sex == Sheep.Sex.EWE and target.pregnant:
			return "Cette brebis attend déjà un agneau."
		return "Pas de partenaire disponible dans cet enclos."

	var ewe := target if target.sex == Sheep.Sex.EWE else partner
	var ram := partner if ewe == target else target
	ewe.pregnant = true
	ewe.due_day = Game.day + Config.PREGNANCY_DAYS
	ewe.baby_wool = Genetics.mix(ewe.wool_id, ram.wool_id)
	refresh_stats()
	return "Une brebis attend un agneau, naissance dans %d jours." % Config.PREGNANCY_DAYS


func _nearest_partner(from: Sheep, wanted: Sheep.Sex) -> Sheep:
	var best: Sheep = null
	var best_dist := INF
	for candidate in sheep_in_region(from.region()):
		if candidate == from or candidate.sex != wanted or not candidate.is_adult():
			continue
		if candidate.sex == Sheep.Sex.EWE and candidate.pregnant:
			continue
		if from.sex == Sheep.Sex.EWE and from.pregnant:
			continue
		var dist := candidate.cell_pos.distance_to(from.cell_pos)
		if dist < best_dist:
			best_dist = dist
			best = candidate
	return best


## Mise bas. Sans vétérinaire, l'agneau a une chance sur trois de ne pas s'en sortir.
func deliver(ewe: Sheep, assisted: bool) -> void:
	ewe.pregnant = false
	ewe.in_labor = false

	var survives := assisted or randf() < Config.LAMB_SURVIVAL_NO_VET
	if not survives:
		Game.say("Un agneau n'a pas survécu à la naissance...")
	else:
		var sex := Sheep.Sex.EWE if randf() < 0.5 else Sheep.Sex.RAM
		create(sex, ewe.baby_wool, 0, ewe.place, _spot_near(ewe))
		Game.say("Un agneau est né !")
	refresh_stats()


# Un peu à côté de la mère (sinon on ne peut plus cliquer sur l'un sans l'autre),
# en restant dans la même région d'enclos.
func _spot_near(ewe: Sheep) -> Vector2:
	for attempt in 8:
		var spot := ewe.cell_pos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		if ewe.place != Sheep.Place.PEN \
				or map.region_id(Vector2i(floori(spot.x), floori(spot.y))) == ewe.region():
			return spot
	return ewe.cell_pos


# --- cycle jour / nuit ---

func new_day() -> void:
	for sheep in sheep_list:
		sheep.fed = false
		if sheep.pregnant and sheep.due_day <= Game.day:
			sheep.in_labor = true
	refresh_stats()


func start_night() -> void:
	for sheep in sheep_list.duplicate():
		if sheep.in_labor:
			deliver(sheep, false)
		# blessé depuis la veille et jamais soigné : il ne s'en remet pas
		if sheep.wounded and sheep.wounded_day < Game.day:
			Game.say("Un mouton blessé n'a pas survécu...")
			sheep.remove_from_game()
	_check_escapes()
	refresh_stats()


# Un enclos trop plein : certains moutons trouvent un moyen de se faire la malle.
func _check_escapes() -> void:
	var escaped := 0
	for region: int in map.region_ids():
		var members := sheep_in_region(region)
		if members.size() <= map.capacity_of(region):
			continue
		for sheep in members:
			if randf() < Config.ESCAPE_CHANCE:
				_escape(sheep)
				escaped += 1
	if escaped > 0:
		Game.say("%d mouton(s) se sont échappés de l'enclos surpeuplé !" % escaped)


func _escape(sheep: Sheep) -> void:
	sheep.place = Sheep.Place.ESCAPED
	# on cherche la case libre la plus proche en dehors des enclos
	for radius in range(2, 30):
		for attempt in 12:
			var angle := randf() * TAU
			var cell := sheep.cell_pos + Vector2(cos(angle), sin(angle)) * radius
			var grid := Vector2i(floori(cell.x), floori(cell.y))
			if FarmMap.in_world(grid) and not map.is_pen_cell(grid):
				sheep.place_at(cell)
				return


## Un mouton égaré ou échappé est rattrapé et rejoint un enclos qui a de la place.
func return_sheep(sheep: Sheep) -> bool:
	var region := _find_room()
	if region < 0:
		return false
	sheep.place = Sheep.Place.PEN
	sheep.place_at(_random_point_in(region))
	refresh_stats()
	return true


func rescue_stray(sheep: Sheep) -> void:
	if return_sheep(sheep):
		Game.say("Un mouton égaré a rejoint ton troupeau !")
	else:
		# pas de place : il reste dehors mais fait quand même partie du troupeau
		sheep.place = Sheep.Place.ESCAPED
		Game.say("Un mouton égaré te suit, mais il n'y a plus de place dans les enclos.")
		refresh_stats()


func has_room() -> bool:
	return _find_room() >= 0


func _find_room() -> int:
	var best := -1
	var best_free := 0
	for region: int in map.region_ids():
		var free := map.capacity_of(region) - sheep_in_region(region).size()
		if free > best_free:
			best_free = free
			best = region
	return best


func _random_point_in(region: int) -> Vector2:
	return Vector2(map.random_cell_in_region(region)) + Vector2(0.5, 0.5)


# --- stats pour l'interface ---

func refresh_stats() -> void:
	Game.flock_size = count()
	Game.labor_count = 0
	Game.wounded_count = 0
	for sheep in sheep_list:
		if sheep.place == Sheep.Place.STRAY:
			continue
		Game.wool_found[sheep.wool_id] = true
		if sheep.in_labor:
			Game.labor_count += 1
		if sheep.wounded:
			Game.wounded_count += 1
	Game.stats_changed.emit()
	changed.emit()
