class_name ShopCatalog
extends RefCounted
## Catalogue de la boutique, construit une fois à la demande.

const TABS: Array[String] = ["Terrain", "Enclos", "Décoration", "Chiens", "Moutons"]

static var _items: Array[ShopItem] = []


static func all() -> Array[ShopItem]:
	if _items.is_empty():
		_fill()
	return _items


static func by_id(id: StringName) -> ShopItem:
	for item in all():
		if item.id == id:
			return item
	return null


static func in_tab(tab: String) -> Array[ShopItem]:
	var result: Array[ShopItem] = []
	for item in all():
		if item.tab == tab:
			result.append(item)
	return result


## Le terrain coûte de plus en plus cher à mesure qu'on s'agrandit.
static func land_price(owned_count: int) -> int:
	return 300 + 150 * maxi(owned_count - 1, 0)


static func _make(id: StringName, kind: ShopItem.Kind, shape: ShopItem.Shape, tab: String,
		title: String, price: int, description: String) -> ShopItem:
	var item := ShopItem.new()
	item.id = id
	item.kind = kind
	item.shape = shape
	item.tab = tab
	item.title = title
	item.price = price
	item.description = description
	_items.append(item)
	return item


static func _fill() -> void:
	var land := _make(&"land", ShopItem.Kind.LAND, ShopItem.Shape.LAND, "Terrain",
		"Parcelle", land_price(1), "Une parcelle de 16x16 à côté de ton terrain.")
	land.color = Color("9bd66b")

	var pen := _make(&"pen", ShopItem.Kind.ENCLOSURE, ShopItem.Shape.PEN, "Enclos",
		"Enclos", 300, "16x16 cases. Collés les uns aux autres, ils fusionnent.")
	pen.size = Vector2i(16, 16)
	pen.build_clicks = 20
	pen.color = Color("d9c28c")

	var barrier := _make(&"barrier", ShopItem.Kind.BARRIER, ShopItem.Shape.FENCE, "Enclos",
		"Barrière", Config.BARRIER_PRICE, "Sépare un enclos en habitats (4x4 mini). Prix par case.")
	barrier.color = Color("c48a5a")

	var barn := _make(&"barn", ShopItem.Kind.BUILDING, ShopItem.Shape.BARN, "Enclos",
		"Bergerie", 400, "+6 places dans l'enclos qui la contient.")
	barn.size = Vector2i(4, 3)
	barn.build_clicks = 12
	barn.capacity_bonus = 6
	barn.color = Color("e0705c")

	var trough := _make(&"trough", ShopItem.Kind.BUILDING, ShopItem.Shape.TROUGH, "Enclos",
		"Abreuvoir", 90, "+2 places dans l'enclos.")
	trough.size = Vector2i(2, 1)
	trough.build_clicks = 3
	trough.capacity_bonus = 2
	trough.color = Color("7fc8d8")

	var tree := _make(&"tree", ShopItem.Kind.DECORATION, ShopItem.Shape.TREE, "Décoration",
		"Arbre", 60, "Un peu d'ombre. +1 charme.")
	tree.size = Vector2i(2, 2)
	tree.build_clicks = 3
	tree.charm = 1
	tree.color = Color("5fae5a")

	var flowers := _make(&"flowers", ShopItem.Kind.DECORATION, ShopItem.Shape.FLOWERS, "Décoration",
		"Fleurs", 25, "Se plante vite, glisse pour en mettre plein. +1 charme.")
	flowers.build_clicks = 1
	flowers.charm = 1
	flowers.color = Color("f2a0b8")

	var lamp := _make(&"lamp", ShopItem.Kind.DECORATION, ShopItem.Shape.LAMP, "Décoration",
		"Lampadaire", 40, "Pour y voir clair la nuit. +1 charme.")
	lamp.build_clicks = 2
	lamp.charm = 1
	lamp.color = Color("f7c948")

	var statue := _make(&"statue", ShopItem.Kind.DECORATION, ShopItem.Shape.STATUE, "Décoration",
		"Bélier doré", 600, "La fierté de la bergerie. +8 charme.")
	statue.size = Vector2i(2, 2)
	statue.build_clicks = 10
	statue.charm = 8
	statue.color = Color("f7c948")

	var protector := _make(&"dog_protector", ShopItem.Kind.DOG, ShopItem.Shape.DOG, "Chiens",
		"Chien protecteur", 250, "Fait fuir les loups qui s'approchent.")
	protector.extra = {"role": "protector"}
	protector.color = Color("c45a4a")

	var finder := _make(&"dog_finder", ShopItem.Kind.DOG, ShopItem.Shape.DOG, "Chiens",
		"Chien de recherche", 200, "Ramène les moutons échappés à l'enclos.")
	finder.extra = {"role": "finder"}
	finder.color = Color("5fae5a")

	var builder := _make(&"dog_builder", ShopItem.Kind.DOG, ShopItem.Shape.DOG, "Chiens",
		"Chien bâtisseur", 300, "Accélère les chantiers, même quand tu fais autre chose.")
	builder.extra = {"role": "builder"}
	builder.color = Color("f7c948")

	var ewe := _make(&"sheep_ewe", ShopItem.Kind.SHEEP, ShopItem.Shape.SHEEP, "Moutons",
		"Brebis", 120, "Pour la traite et les agneaux.")
	ewe.extra = {"sex": "ewe"}

	var ram := _make(&"sheep_ram", ShopItem.Kind.SHEEP, ShopItem.Shape.SHEEP, "Moutons",
		"Bélier", 150, "Indispensable pour la reproduction.")
	ram.extra = {"sex": "ram"}
