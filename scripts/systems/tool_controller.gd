class_name ToolController
extends Node
## Les outils de jour : nourrir, traire, tondre, reproduire, biberon, véto, vendre.
## Chaque outil s'applique au clic sur un mouton (ou sur un enclos pour le foin).

var flock: Flock
var map: FarmMap


func apply(tool_id: StringName, point: Vector2) -> void:
	var sheep := flock.pick(point)
	match tool_id:
		&"feed":
			_feed(sheep, point)
		&"milk":
			_milk(sheep)
		&"shear":
			_shear(sheep)
		&"breed":
			_breed(sheep)
		&"grow":
			_bottle(sheep)
		&"vet":
			_vet(sheep)
		&"sell":
			_sell(sheep)


func _feed(sheep: Sheep, point: Vector2) -> void:
	var targets: Array[Sheep] = []
	if sheep != null and sheep.place != Sheep.Place.PEN:
		targets.append(sheep)
	else:
		var region := sheep.region() if sheep != null else map.region_id(Iso.to_grid(point))
		if region < 0:
			Game.say("Clique dans un enclos pour distribuer le foin.")
			return
		targets = flock.sheep_in_region(region)

	var hungry: Array[Sheep] = []
	for target in targets:
		if not target.fed:
			hungry.append(target)
	if hungry.is_empty():
		Game.say("Tout le monde a déjà mangé ici.")
		return

	var cost := hungry.size() * Config.FEED_COST
	if not Game.spend(cost):
		return
	for target in hungry:
		target.fed = true
	Game.say("%d mouton(s) nourris (-%d)." % [hungry.size(), cost])
	flock.refresh_stats()


func _milk(sheep: Sheep) -> void:
	if sheep == null:
		return
	if sheep.sex != Sheep.Sex.EWE or not sheep.is_adult():
		Game.say("On ne trait que les brebis adultes.")
	elif not sheep.fed:
		Game.say("Cette brebis a faim, elle ne donnera rien.")
	elif sheep.last_milk_day == Game.day:
		Game.say("Déjà traite aujourd'hui.")
	else:
		sheep.last_milk_day = Game.day
		var gain := _scaled(Config.MILK_GAIN)
		Game.earn(gain)
		Game.say("Traite : +%d" % gain)


func _shear(sheep: Sheep) -> void:
	if sheep == null:
		return
	if not sheep.is_adult():
		Game.say("Un agneau ne se tond pas.")
	elif not sheep.fed:
		Game.say("Ce mouton a faim, nourris-le d'abord.")
	elif sheep.is_shorn():
		var days_left := Config.SHEAR_DELAY_DAYS - (Game.day - sheep.last_shear_day)
		Game.say("Tonte possible dans %d jour(s)." % days_left)
	else:
		sheep.last_shear_day = Game.day
		var gain := _scaled(WoolRegistry.price_of(sheep.wool_id))
		Game.earn(gain)
		Game.say("Tonte : +%d" % gain)


func _breed(sheep: Sheep) -> void:
	if sheep != null:
		Game.say(flock.try_breed(sheep))


func _bottle(sheep: Sheep) -> void:
	if sheep == null:
		return
	if sheep.is_adult():
		Game.say("Ce mouton est déjà adulte.")
	elif sheep.last_bottle_day == Game.day:
		Game.say("L'agneau a déjà eu son biberon aujourd'hui.")
	elif Game.spend(Config.BOTTLE_COST):
		sheep.last_bottle_day = Game.day
		sheep.growth += 1
		if sheep.is_adult():
			Game.say("Il est devenu adulte !")
		else:
			Game.say("L'agneau grandit (%d/%d)." % [sheep.growth, Config.LAMB_STAGES])
		flock.refresh_stats()


func _vet(sheep: Sheep) -> void:
	if sheep == null:
		return
	if sheep.in_labor:
		if Game.spend(Config.VET_COST_BIRTH):
			flock.deliver(sheep, true)
	elif sheep.wounded:
		if Game.spend(Config.VET_COST_WOUND):
			sheep.wounded = false
			sheep.held = false
			Game.say("Le vétérinaire a soigné le mouton.")
			flock.refresh_stats()
	else:
		Game.say("Ce mouton n'a pas besoin de vétérinaire.")


func _sell(sheep: Sheep) -> void:
	if sheep == null:
		return
	var price := Config.SELL_ADULT if sheep.is_adult() else Config.SELL_LAMB
	if sheep.wounded:
		price /= 2
	price = _scaled(price)
	Game.earn(price)
	Game.say("Mouton vendu : +%d" % price)
	sheep.remove_from_game()


func _scaled(amount: int) -> int:
	return roundi(amount * Game.price_multiplier())
