class_name WoolRegistry
extends RefCounted
## Accès aux types de laine. Pour en ajouter un : créer le .tres dans data/wool/
## puis l'ajouter à PATHS (je préfère une liste explicite à un scan de dossier,
## ça marche aussi une fois le jeu exporté).

const PATHS: Array[String] = [
	"res://data/wool/white.tres",
]

static var _types: Dictionary = {}


static func _ensure_loaded() -> void:
	if not _types.is_empty():
		return
	for path in PATHS:
		var wool := load(path) as WoolType
		if wool != null:
			_types[wool.id] = wool


static func get_type(id: StringName) -> WoolType:
	_ensure_loaded()
	return _types.get(id) as WoolType


static func all() -> Array:
	_ensure_loaded()
	return _types.values()


static func color_of(id: StringName) -> Color:
	var wool := get_type(id)
	return wool.color if wool != null else Color.WHITE


static func price_of(id: StringName) -> int:
	var wool := get_type(id)
	return wool.sell_price if wool != null else 10


## Tirage pondéré pour les moutons égarés de la nuit.
static func random_stray_wool() -> StringName:
	_ensure_loaded()
	var total := 0
	for wool: WoolType in _types.values():
		total += wool.stray_weight
	if total <= 0:
		return &"white"
	var roll := randi_range(1, total)
	for wool: WoolType in _types.values():
		roll -= wool.stray_weight
		if roll <= 0:
			return wool.id
	return &"white"
