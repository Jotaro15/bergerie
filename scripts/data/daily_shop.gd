class_name DailyShop
extends RefCounted
## La boutique du jour : une sélection de décorations, de chiens et de moutons qui
## change toutes les 24 h *réelles* (comme le cadeau quotidien), à un peu moins cher
## que la boutique permanente. Les moutons n'ont que des laines déjà découvertes.
##
## L'état est statique (une seule boutique du jour par partie) et passe par la
## sauvegarde via Game.to_dict().

const DECORATIONS := 3
const DOGS := 2
const SHEEP := 3

static var window := -1                   # numéro du jour réel pour lequel les offres ont été tirées
static var offers: Array[Dictionary] = [] # {key, id, wool, price, stock}


## Numéro du jour réel (minuit, heure locale).
static func current_window() -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return floori((Time.get_unix_time_from_system() + bias) / 86400.0)


static func seconds_left() -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var into_day := fmod(Time.get_unix_time_from_system() + bias, 86400.0)
	return 86400 - int(into_day)


## Renouvelle les offres si on est passé au jour suivant. Renvoie true si elles ont changé.
static func refresh() -> bool:
	var today := current_window()
	if today == window and not offers.is_empty():
		return false
	window = today
	_generate()
	return true


static func _generate() -> void:
	offers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(window)   # tout le monde voit les mêmes offres le même jour
	_pick_items(rng, "Décoration", DECORATIONS)
	_pick_items(rng, "Chiens", DOGS)

	var wools := _found_wools()
	for i in SHEEP:
		var base := ShopCatalog.by_id(&"sheep_ram" if rng.randf() < 0.35 else &"sheep_ewe")
		var wool: StringName = wools[rng.randi_range(0, wools.size() - 1)]
		offers.append(_offer(base, wool, _sheep_price(base, wool), 1))


static func _pick_items(rng: RandomNumberGenerator, tab: String, count: int) -> void:
	var pool := ShopCatalog.in_tab(tab)
	for i in mini(count, pool.size()):
		var index := rng.randi_range(0, pool.size() - 1)
		var base := pool[index]
		pool.remove_at(index)
		# les grosses pièces (la statue) n'existent qu'en un exemplaire
		var stock := 1 if base.kind == ShopItem.Kind.DOG or base.charm >= 5 else 3
		offers.append(_offer(base, &"", discounted(base.price), stock))


static func _offer(base: ShopItem, wool: StringName, price: int, stock: int) -> Dictionary:
	return {"key": "o%d" % offers.size(), "id": base.id, "wool": wool, "price": price, "stock": stock}


static func discounted(price: int) -> int:
	return roundi(price * Config.DAILY_DISCOUNT)


## Une laine rare coûte plus cher que la blanche, qui sert de référence.
static func _sheep_price(base: ShopItem, wool: StringName) -> int:
	var rarity := maxi(WoolRegistry.price_of(wool) - WoolRegistry.price_of(&"white"), 0)
	return discounted(base.price) + rarity * Config.DAILY_WOOL_PREMIUM


static func _found_wools() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in Game.wool_found:
		result.append(id)
	if result.is_empty():
		result.append(&"white")
	result.sort()
	return result


# --- lecture / achat ---

## Les offres sous forme d'objets de boutique prêts à être achetés (prix du jour,
## stock restant). Ceux dont le stock est épuisé restent dans la liste (grisés).
static func items() -> Array[ShopItem]:
	refresh()
	var result: Array[ShopItem] = []
	for offer in offers:
		var base := ShopCatalog.by_id(offer["id"])
		if base == null:
			continue
		var item := base.copy()
		item.price = int(offer["price"])
		item.extra["daily"] = offer["key"]
		item.extra["stock"] = int(offer["stock"])
		var wool := StringName(offer["wool"])
		if base.kind == ShopItem.Kind.SHEEP:
			item.extra["wool"] = wool
			item.extra["wool_color"] = WoolRegistry.color_of(wool)
			var type := WoolRegistry.get_type(wool)
			item.title = "%s %s" % [base.title, type.display_name.to_lower() if type != null else ""]
		result.append(item)
	return result


static func remaining(key: String) -> int:
	for offer in offers:
		if offer["key"] == key:
			return int(offer["stock"])
	return 0


## Un exemplaire acheté : le stock baisse. Renvoie false s'il n'y en avait plus.
static func consume(key: String) -> bool:
	for offer in offers:
		if offer["key"] == key and int(offer["stock"]) > 0:
			offer["stock"] = int(offer["stock"]) - 1
			return true
	return false


# --- sauvegarde ---

static func to_dict() -> Dictionary:
	var list := []
	for offer in offers:
		list.append({"key": offer["key"], "id": String(offer["id"]), "wool": String(offer["wool"]),
				"price": offer["price"], "stock": offer["stock"]})
	return {"window": window, "offers": list}


static func from_dict(data: Dictionary) -> void:
	offers.clear()
	window = int(data.get("window", -1))
	for entry: Dictionary in data.get("offers", []):
		offers.append({"key": String(entry["key"]), "id": StringName(entry["id"]),
				"wool": StringName(entry.get("wool", "")), "price": int(entry["price"]),
				"stock": int(entry["stock"])})
	refresh()
