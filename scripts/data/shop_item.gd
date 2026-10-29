class_name ShopItem
extends RefCounted
## Une ligne du catalogue de la boutique. Voir ShopCatalog pour la liste.

enum Kind { LAND, ENCLOSURE, BARRIER, BUILDING, DECORATION, DOG, SHEEP }
enum Shape { LAND, PEN, FENCE, BARN, TROUGH, TREE, FLOWERS, LAMP, STATUE, DOG, SHEEP }

var id: StringName
var kind: Kind
var shape: Shape
var tab := ""
var title := ""
var description := ""
var price := 0
var size := Vector2i.ONE
var build_clicks := 1       # nombre de clics la nuit pour terminer le chantier
var color := Color.WHITE
var capacity_bonus := 0     # places en plus dans l'enclos qui contient le bâtiment
var charm := 0              # chaque point de charme = +1% sur les gains (plafonné)
var extra: Dictionary = {}  # sexe du mouton, rôle du chien...


func is_footprint_item() -> bool:
	return kind == Kind.BUILDING or kind == Kind.DECORATION or kind == Kind.ENCLOSURE
