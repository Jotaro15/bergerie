class_name Sheep
extends Node2D
## Un mouton. Il se balade dans sa région d'enclos tout seul, le reste (nourrir,
## traire, tondre...) est piloté de l'extérieur par ToolController et Flock.
##
## Le dessin est fait en code pour l'instant (formes simples). Quand j'aurai les
## vrais sprites, il suffira de remplacer _draw() par un AnimatedSprite2D.

signal removed(sheep: Sheep)

enum Sex { EWE, RAM }
enum Place { PEN, ESCAPED, STRAY }

const OUTLINE := Color("5a3e4b")
const SKIN := Color("f4d3c4")
const FACE := Color("6b5560")
const LIFT_HEIGHT := 12.0   # de combien le mouton se soulève quand on l'attrape

var map: FarmMap
var sex: Sex = Sex.EWE
var wool_id: StringName = &"white"
var growth: int = Config.LAMB_STAGES   # < LAMB_STAGES = agneau
var place: Place = Place.PEN
var fed := false
var last_shear_day := -99
var last_milk_day := -99
var last_bottle_day := -99
var pregnant := false
var due_day := 0
var baby_wool: StringName = &"white"
var in_labor := false
var wounded := false
var wounded_day := 0

var cell_pos := Vector2.ZERO
var targeted := false   # un loup l'a déjà dans le viseur
var held := false       # un loup est en train de le croquer, il ne bouge plus
var hovered := false
var dragged := false:   # le joueur le tient à la souris (drag & drop)
	set(value):
		dragged = value
		z_index = 20 if value else 0   # un mouton porté passe devant les autres

var _lift := 0.0
var _shown_needs: Array[NeedIcons.Need] = []   # ce qui est affiché en ce moment
var _target := Vector2.ZERO
var _moving := false
var _wait := 0.0
var _facing := 1.0
var _bob := 0.0
var _redraw_in := 0.0


func _ready() -> void:
	add_to_group("sheep")
	_wait = randf_range(0.5, 3.0)
	_sync_position()


# --- état ---

func cell_i() -> Vector2i:
	return Vector2i(floori(cell_pos.x), floori(cell_pos.y))


func region() -> int:
	return map.region_id(cell_i())


func is_adult() -> bool:
	return growth >= Config.LAMB_STAGES


func is_shorn() -> bool:
	return Game.day - last_shear_day < Config.SHEAR_DELAY_DAYS


func can_shear() -> bool:
	return is_adult() and fed and not is_shorn()


func can_milk() -> bool:
	return sex == Sex.EWE and is_adult() and fed and last_milk_day != Game.day

## Ce dont le mouton a besoin en ce moment, du plus urgent au moins urgent. C'est ce
## qui s'affiche sous forme d'icônes au-dessus de lui ; les conditions reprennent
## celles des outils de jour (ToolController), pour que l'icône soit là quand
## l'action est possible et seulement à ce moment-là.
func needs() -> Array[NeedIcons.Need]:
	var result: Array[NeedIcons.Need] = []
	if place == Place.STRAY:
		# un égaré n'est pas encore dans le troupeau : on ne peut que le rejoindre
		result.append(NeedIcons.Need.STRAY)
		return result

	if place == Place.ESCAPED:
		result.append(NeedIcons.Need.ESCAPED)
	if in_labor:
		result.append(NeedIcons.Need.LABOR)
	if wounded:
		result.append(NeedIcons.Need.WOUNDED)
	if pregnant and not in_labor:
		result.append(NeedIcons.Need.PREGNANT)

	# nourrir, traire, tondre et biberon sont des actions de jour
	if Game.is_day():
		if not fed:
			result.append(NeedIcons.Need.HUNGRY)
		else:
			if can_shear():
				result.append(NeedIcons.Need.SHEAR)
			if can_milk():
				result.append(NeedIcons.Need.MILK)
		if not is_adult() and last_bottle_day != Game.day:
			result.append(NeedIcons.Need.BOTTLE)
	return result

func place_at(cell: Vector2) -> void:
	cell_pos = cell
	_moving = false
	_sync_position()


func wound() -> void:
	wounded = true
	wounded_day = Game.day
	held = true


## Vendu, mangé ou mort : dans tous les cas il sort du troupeau.
func remove_from_game() -> void:
	removed.emit(self)
	queue_free()


func get_eaten() -> void:
	remove_from_game()


# --- déplacement ---

#func _process(delta: float) -> void:
	#_bob += delta * 8.0
	#if held:
		#_moving = false
	#elif _moving:
		#_step(delta)
	#else:
		#_wait -= delta
		#if _wait <= 0.0:
			#_pick_target()
			#_wait = randf_range(1.0, 4.0)

	#_redraw_in -= delta
	#if _moving or _redraw_in <= 0.0:
		#_redraw_in = 0.3
		#queue_redraw()

## Pendant un drag & drop : le mouton suit la souris sans changer de case (`cell_pos`),
## c'est le SheepDragger qui décide au lâcher s'il reste ou s'il retourne à sa place.
func carry_to(point: Vector2) -> void:
	var dx := point.x - position.x
	if absf(dx) > 0.5:
		_facing = signf(dx)
	position = point


func _process(delta: float) -> void:
	_bob += delta * 8.0
	var lift_target := LIFT_HEIGHT if dragged else 0.0
	var lifting := not is_equal_approx(_lift, lift_target)
	_lift = move_toward(_lift, lift_target, delta * 90.0)

	if dragged:
		_moving = false
	elif held:
		_moving = false
	elif _moving:
		_step(delta)
	else:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target()
			_wait = randf_range(1.0, 4.0)

	# les icônes se mettent à jour dès que le besoin change (pas besoin d'attendre le prochain rafraîchissement régulier)
	var current_needs := needs()
	var needs_changed := current_needs != _shown_needs
	_shown_needs = current_needs

	_redraw_in -= delta
	if _moving or dragged or lifting or needs_changed or _redraw_in <= 0.0:
		_redraw_in = 0.3
		queue_redraw()


func _step(delta: float) -> void:
	var speed := Config.SHEEP_SPEED * (1.0 if is_adult() else 1.25)
	var to_target := _target - cell_pos
	var step := speed * delta
	if to_target.length() <= step:
		cell_pos = _target
		_moving = false
		_sync_position()
		return

	var next := cell_pos + to_target.normalized() * step
	if not _allowed(next):
		_moving = false
		return

	var dx := Iso.to_screen(next).x - position.x
	if absf(dx) > 0.01:
		_facing = signf(dx)
	cell_pos = next
	_sync_position()


func _allowed(cell: Vector2) -> bool:
	var ci := Vector2i(floori(cell.x), floori(cell.y))
	if place == Place.PEN:
		# un mouton d'enclos reste dans sa région, les barrières l'arrêtent
		return map.region_id(ci) == region()
	return FarmMap.in_world(ci)


func _pick_target() -> void:
	for attempt in 6:
		var candidate := cell_pos + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		if _allowed(candidate):
			_target = candidate
			_moving = true
			return


func _sync_position() -> void:
	position = Iso.to_screen(cell_pos)


# --- sauvegarde ---

func to_dict() -> Dictionary:
	return {
		"sex": sex, "wool": String(wool_id), "growth": growth, "place": place,
		"x": cell_pos.x, "y": cell_pos.y, "fed": fed,
		"shear": last_shear_day, "milk": last_milk_day, "bottle": last_bottle_day,
		"pregnant": pregnant, "due": due_day, "baby": String(baby_wool),
		"labor": in_labor, "wounded": wounded, "wounded_day": wounded_day,
	}


func load_dict(data: Dictionary) -> void:
	sex = int(data.get("sex", 0)) as Sex
	wool_id = StringName(data.get("wool", "white"))
	growth = int(data.get("growth", Config.LAMB_STAGES))
	place = int(data.get("place", 0)) as Place
	cell_pos = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	fed = bool(data.get("fed", false))
	last_shear_day = int(data.get("shear", -99))
	last_milk_day = int(data.get("milk", -99))
	last_bottle_day = int(data.get("bottle", -99))
	pregnant = bool(data.get("pregnant", false))
	due_day = int(data.get("due", 0))
	baby_wool = StringName(data.get("baby", "white"))
	in_labor = bool(data.get("labor", false))
	wounded = bool(data.get("wounded", false))
	wounded_day = int(data.get("wounded_day", 0))


# --- dessin ---

func _draw() -> void:
	var grow := 0.62 + 0.38 * float(mini(growth, Config.LAMB_STAGES)) / Config.LAMB_STAGES
	var bob := absf(sin(_bob)) * 1.5 if _moving else 0.0
	var wool := WoolRegistry.color_of(wool_id)

	# l'ombre reste au sol, plus petite et plus claire quand le mouton est soulevé
	var shadow_scale := 1.0 - 0.25 * _lift / LIFT_HEIGHT
	_ellipse(Vector2.ZERO, 11.0 * grow * shadow_scale, 4.5 * grow * shadow_scale, Color(0, 0, 0, 0.18 * shadow_scale))

	# tout ce qui suit est dessiné à l'échelle du mouton et retourné selon la direction
	draw_set_transform(Vector2(0, -bob - _lift), 0.0, Vector2(_facing * grow, grow))

	# pattes
	draw_rect(Rect2(-6, -6, 3, 6), FACE)
	draw_rect(Rect2(3, -6, 3, 6), FACE)

	if is_shorn():
		var skin := SKIN.lerp(wool, 0.3)
		_puffs([Vector2(-3, -9), Vector2(3, -9)], 5.5, skin)
	else:
		_puffs([Vector2(-6, -11), Vector2(-1, -14), Vector2(5, -12),
				Vector2(-3, -8), Vector2(3, -8)], 7.0, wool)

	# tête
	draw_circle(Vector2(10, -10), 5.6, OUTLINE)
	draw_circle(Vector2(10, -10), 4.4, FACE)
	draw_circle(Vector2(8, -14), 2.0, FACE)
	draw_circle(Vector2(11.5, -11), 0.9, Color.WHITE)
	if sex == Sex.RAM and is_adult():
		draw_arc(Vector2(8, -14), 3.6, PI * 0.9, PI * 2.2, 10, Color("e0b44a"), 2.0)

	draw_set_transform(Vector2.ZERO)

	if hovered or dragged:
		draw_arc(Vector2(0, -9 - _lift), 18.0, 0.0, TAU, 28, Color.WHITE, 2.0)
	_draw_badges(grow)


func _puffs(centers: Array, radius: float, color: Color) -> void:
	for center: Vector2 in centers:
		draw_circle(center, radius + 1.6, OUTLINE)
	for center: Vector2 in centers:
		draw_circle(center, radius, color)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)


# Les icônes de besoins, centrées au-dessus du mouton (voir NeedIcons).
func _draw_badges(grow: float) -> void:
	var shown := needs()
	var y := -32.0 * grow - 6.0 - _lift
	var x := -(shown.size() - 1) * NeedIcons.SPACING / 2.0
	for need in shown:
		NeedIcons.draw(self, need, Vector2(x, y))
		x += NeedIcons.SPACING
