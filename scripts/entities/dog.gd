class_name Dog
extends Node2D
## Chien de berger. Trois rôles :
##  - protecteur : fait fuir les loups
##  - recherche : ramène les moutons échappés
##  - bâtisseur : fait avancer les chantiers la nuit

enum Role { PROTECTOR, FINDER, BUILDER }

const SPEED := 5.0
const BUILD_INTERVAL := 1.2

var role: Role = Role.PROTECTOR
var cell_pos := Vector2.ZERO
var scare_radius := 0.0

var _wander_target := Vector2.ZERO
var _wander_wait := 0.0
var _work_timer := 0.0
var _facing := 1.0
var _bob := 0.0
var _moving := false


func _ready() -> void:
	if role == Role.PROTECTOR:
		scare_radius = 5.5
		add_to_group("scarers")
	_wander_target = cell_pos
	_sync_position()


func _process(delta: float) -> void:
	_moving = false
	match role:
		Role.PROTECTOR:
			_protect(delta)
		Role.FINDER:
			_find(delta)
		Role.BUILDER:
			_build(delta)
	if _moving:
		_bob += delta * 12.0
	queue_redraw()


# --- comportements ---

func _protect(delta: float) -> void:
	if not Game.is_day():
		var wolf := _nearest("wolves")
		if wolf != null:
			_go_to(wolf.cell_pos, SPEED * 1.2, delta)
			return
	_wander(delta)


func _find(delta: float) -> void:
	var lost := _nearest_escaped()
	if lost == null:
		_wander(delta)
		return

	if _go_to(lost.cell_pos, SPEED, delta):
		var flock := get_tree().get_first_node_in_group("flock") as Flock
		if flock != null:
			flock.return_sheep(lost)


func _build(delta: float) -> void:
	if Game.is_day():
		_wander(delta)
		return
	var site := _nearest("sites") as ConstructionSite
	if site == null:
		_wander(delta)
		return

	if not site.reach_rect().has_point(cell_pos):
		_go_to(site.cell_pos, SPEED, delta)
		return

	_work_timer += delta
	if _work_timer >= BUILD_INTERVAL:
		_work_timer = 0.0
		site.hit()


# Il traîne autour du berger quand il n'a rien à faire.
func _wander(delta: float) -> void:
	_wander_wait -= delta
	if _wander_wait <= 0.0:
		var anchor := cell_pos
		for node in get_tree().get_nodes_in_group("scarers"):
			if node is Shepherd:
				anchor = node.cell_pos
				break
		_wander_target = anchor + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
		_wander_wait = randf_range(2.0, 5.0)
	if cell_pos.distance_to(_wander_target) > 0.3:
		_go_to(_wander_target, SPEED * 0.5, delta)


# Renvoie true une fois arrivé (à moins d'une case).
func _go_to(target: Vector2, speed: float, delta: float) -> bool:
	var to_target := target - cell_pos
	if to_target.length() < 1.0:
		return true
	cell_pos += to_target.normalized() * speed * delta
	cell_pos = cell_pos.clamp(Vector2.ZERO, Vector2(Config.WORLD_CELLS))
	var dx := Iso.to_screen(cell_pos).x - position.x
	if absf(dx) > 0.01:
		_facing = signf(dx)
	_moving = true
	_sync_position()
	return false


func _nearest(group: StringName) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(group):
		# loups et chantiers exposent tous les deux cell_pos
		var other_pos: Vector2 = node.cell_pos
		var dist := other_pos.distance_to(cell_pos)
		if dist < best_dist:
			best_dist = dist
			best = node as Node2D
	return best


func _nearest_escaped() -> Sheep:
	var best: Sheep = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("sheep"):
		var sheep := node as Sheep
		if sheep.place != Sheep.Place.ESCAPED:
			continue
		var dist := sheep.cell_pos.distance_to(cell_pos)
		if dist < best_dist:
			best_dist = dist
			best = sheep
	return best


func _sync_position() -> void:
	position = Iso.to_screen(cell_pos)


# --- dessin ---

func _draw() -> void:
	var outline := Color("5a3e4b")
	var fur := Color("b98a5e")
	var collar := _collar_color()
	var bob := absf(sin(_bob)) * 1.5

	var shadow := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		shadow.append(Vector2(cos(a) * 9.0, sin(a) * 3.5))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.2))

	draw_set_transform(Vector2(0, -bob), 0.0, Vector2(_facing, 1.0))
	draw_rect(Rect2(-7, -5, 3, 5), outline)
	draw_rect(Rect2(4, -5, 3, 5), outline)
	draw_line(Vector2(-8, -9), Vector2(-13, -14), outline, 4.0)
	draw_line(Vector2(-8, -9), Vector2(-13, -14), fur, 2.0)
	draw_circle(Vector2(-2, -9), 7.0, outline)
	draw_circle(Vector2(3, -9), 6.0, outline)
	draw_circle(Vector2(-2, -9), 5.8, fur)
	draw_circle(Vector2(3, -9), 4.8, fur)
	draw_circle(Vector2(9, -12), 5.2, outline)
	draw_circle(Vector2(9, -12), 4.1, fur)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -15), Vector2(5, -21), Vector2(9, -16)]), outline)
	draw_circle(Vector2(13, -11), 1.8, outline)
	draw_circle(Vector2(10, -13), 0.8, Color.WHITE)
	draw_rect(Rect2(5, -8, 3, 2), collar)
	draw_set_transform(Vector2.ZERO)


func _collar_color() -> Color:
	match role:
		Role.FINDER:
			return Color("5fae5a")
		Role.BUILDER:
			return Color("f7c948")
	return Color("c45a4a")
