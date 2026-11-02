class_name NeedIcons
extends RefCounted
## Les pastilles qui flottent au-dessus des moutons : une petite icône dessinée par
## besoin, pour comprendre d'un coup d'oeil ce qu'il faut faire.
##
## Tout est dessiné avec des formes (pas de texte) : ça ne dépend d'aucune police et
## les icônes restent lisibles même sans se fier aux couleurs.

enum Need {
	HUNGRY,     # pas encore mangé : du foin
	SHEAR,      # prêt à être tondu
	MILK,       # brebis à traire
	BOTTLE,     # agneau qui attend son biberon
	PREGNANT,   # attend un agneau
	LABOR,      # met bas : le vétérinaire est nécessaire
	WOUNDED,    # mordu par un loup : le vétérinaire est nécessaire
	STRAY,      # égaré, à rejoindre pour le recueillir
	ESCAPED,    # sorti de l'enclos, à ramener
}

const RADIUS := 9.0
const SPACING := 22.0

const OUTLINE := Color("5a3e4b")
const BACKGROUND := Color("fff9ea")
const URGENT := Color("e0504a")


static func draw(canvas: CanvasItem, need: Need, center: Vector2) -> void:
	# un liseré rouge pour ce qui ne peut pas attendre
	var ring := URGENT if need == Need.LABOR or need == Need.WOUNDED else OUTLINE
	canvas.draw_circle(center, RADIUS + 1.5, ring)
	canvas.draw_circle(center, RADIUS, BACKGROUND)

	match need:
		Need.HUNGRY:
			_hay(canvas, center)
		Need.SHEAR:
			_scissors(canvas, center)
		Need.MILK:
			_milk_drop(canvas, center)
		Need.BOTTLE:
			_baby_bottle(canvas, center)
		Need.PREGNANT:
			_heart(canvas, center, Color("f2a0b8"), Color("c45c80"))
		Need.LABOR:
			_heart(canvas, center, URGENT, Color("9c2f2a"))
			_plus(canvas, center + Vector2(0, 0.6), Color.WHITE)
		Need.WOUNDED:
			_plaster(canvas, center)
		Need.STRAY:
			_question_mark(canvas, center)
		Need.ESCAPED:
			_house(canvas, center)


# --- les icônes ---

# Une gamelle remplie de foin.
static func _hay(canvas: CanvasItem, c: Vector2) -> void:
	var gold := Color("e3a92f")
	var straws := [
		[Vector2(-3.4, 0.4), Vector2(-5.0, -4.6)],
		[Vector2(-1.7, 0.4), Vector2(-2.2, -6.4)],
		[Vector2(0.0, 0.4), Vector2(0.6, -7.0)],
		[Vector2(1.7, 0.4), Vector2(3.0, -6.2)],
		[Vector2(3.4, 0.4), Vector2(5.2, -4.2)],
	]
	for straw: Array in straws:
		canvas.draw_line(c + straw[0], c + straw[1], gold, 1.5)

	var bowl := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		bowl.append(c + Vector2(cos(a) * 7.0, 0.0 + sin(a) * 6.2))
	var edge := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		edge.append(c + Vector2(cos(a) * 8.0, -0.6 + sin(a) * 7.2))
	canvas.draw_colored_polygon(edge, OUTLINE)
	canvas.draw_colored_polygon(bowl, Color("c48a5a"))
	canvas.draw_line(c + Vector2(-7.0, 0.0), c + Vector2(7.0, 0.0), Color("8a5a3a"), 1.4)


static func _scissors(canvas: CanvasItem, c: Vector2) -> void:
	var steel := Color("5f7388")
	var handle := Color("f2a0b8")
	canvas.draw_line(c + Vector2(-2.6, -5.5), c + Vector2(1.9, 3.0), steel, 2.4)
	canvas.draw_line(c + Vector2(2.6, -5.5), c + Vector2(-1.9, 3.0), steel, 2.4)
	canvas.draw_arc(c + Vector2(2.8, 4.5), 1.8, 0.0, TAU, 12, handle, 1.9)
	canvas.draw_arc(c + Vector2(-2.8, 4.5), 1.8, 0.0, TAU, 12, handle, 1.9)
	canvas.draw_circle(c + Vector2(0, -0.6), 1.0, OUTLINE)


# Une goutte de lait.
static func _milk_drop(canvas: CanvasItem, c: Vector2) -> void:
	var edge := Color("4f93b5")
	var blue := Color("a8dcf0")
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -7.0), c + Vector2(-4.4, 0.6), c + Vector2(4.4, 0.6)]), edge)
	canvas.draw_circle(c + Vector2(0, 2.0), 4.8, edge)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -5.4), c + Vector2(-3.4, 0.6), c + Vector2(3.4, 0.6)]), blue)
	canvas.draw_circle(c + Vector2(0, 2.0), 3.6, blue)
	canvas.draw_circle(c + Vector2(-1.4, 1.4), 1.0, Color.WHITE)


# Un biberon : tétine, collerette, flacon gradué.
static func _baby_bottle(canvas: CanvasItem, c: Vector2) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-4.0, -2.4), Vector2(8.0, 10.0)), OUTLINE)
	canvas.draw_rect(Rect2(c + Vector2(-3.0, -1.4), Vector2(6.0, 8.0)), Color("fbd5e0"))
	canvas.draw_rect(Rect2(c + Vector2(-4.0, -3.6), Vector2(8.0, 2.4)), Color("5cc8c8"))
	canvas.draw_circle(c + Vector2(0, -5.2), 2.2, OUTLINE)
	canvas.draw_circle(c + Vector2(0, -5.2), 1.4, Color("f0b27a"))
	canvas.draw_line(c + Vector2(0.4, 0.8), c + Vector2(2.4, 0.8), OUTLINE, 1.0)
	canvas.draw_line(c + Vector2(0.4, 3.2), c + Vector2(2.4, 3.2), OUTLINE, 1.0)


static func _heart(canvas: CanvasItem, c: Vector2, fill: Color, edge: Color) -> void:
	canvas.draw_circle(c + Vector2(-2.7, -1.6), 4.0, edge)
	canvas.draw_circle(c + Vector2(2.7, -1.6), 4.0, edge)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-6.4, -0.4), c + Vector2(6.4, -0.4), c + Vector2(0, 7.2)]), edge)
	canvas.draw_circle(c + Vector2(-2.7, -1.6), 3.0, fill)
	canvas.draw_circle(c + Vector2(2.7, -1.6), 3.0, fill)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-5.5, -0.4), c + Vector2(5.5, -0.4), c + Vector2(0, 6.0)]), fill)


static func _plus(canvas: CanvasItem, c: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-0.9, -2.6), Vector2(1.8, 5.2)), color)
	canvas.draw_rect(Rect2(c + Vector2(-2.6, -0.9), Vector2(5.2, 1.8)), color)


# Un pansement en diagonale.
static func _plaster(canvas: CanvasItem, c: Vector2) -> void:
	var angle := deg_to_rad(-40.0)
	canvas.draw_colored_polygon(_rotated_rect(c, Vector2(15.0, 7.4), angle), OUTLINE)
	canvas.draw_colored_polygon(_rotated_rect(c, Vector2(13.0, 5.4), angle), Color("f2c79a"))
	canvas.draw_colored_polygon(_rotated_rect(c, Vector2(5.4, 5.4), angle), Color("fff3d6"))
	for x in [-4.6, 4.6]:
		for y in [-0.9, 0.9]:
			canvas.draw_circle(c + Vector2(x, y).rotated(angle), 0.5, Color("b5835a"))


static func _question_mark(canvas: CanvasItem, c: Vector2) -> void:
	var blue := Color("4f93b5")
	canvas.draw_arc(c + Vector2(0, -2.4), 3.0, PI * 0.95, PI * 2.5, 14, blue, 2.4)
	canvas.draw_line(c + Vector2(0, 0.6), c + Vector2(0, 2.2), blue, 2.4)
	canvas.draw_circle(c + Vector2(0, 5.2), 1.4, blue)


# Une maisonnette : "ramène-le à l'enclos".
static func _house(canvas: CanvasItem, c: Vector2) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-7.0, -0.2), c + Vector2(0, -7.4), c + Vector2(7.0, -0.2)]), OUTLINE)
	canvas.draw_rect(Rect2(c + Vector2(-5.2, -1.2), Vector2(10.4, 8.6)), OUTLINE)
	canvas.draw_rect(Rect2(c + Vector2(-4.2, -0.2), Vector2(8.4, 6.6)), Color("f3dcc0"))
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-5.6, -0.8), c + Vector2(0, -6.2), c + Vector2(5.6, -0.8)]), Color("e07a6b"))
	canvas.draw_rect(Rect2(c + Vector2(-1.3, 2.2), Vector2(2.6, 4.2)), Color("7b4a2f"))


# --- outils de dessin ---

static func _ellipse(canvas: CanvasItem, center: Vector2, rx: float, ry: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	canvas.draw_colored_polygon(points, color)


static func _rotated_rect(center: Vector2, size: Vector2, angle: float) -> PackedVector2Array:
	var half := size / 2.0
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	var points := PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(center + corner.rotated(angle))
	return points
