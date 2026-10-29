class_name Wolf
extends Node2D
## Un loup de nuit : il vise le mouton le plus proche, le mord, le dévore, puis
## repart ou en cherche un deuxième. Il fuit dès qu'un "scarer" (berger, chien
## protecteur) passe à portée.

enum State { APPROACH, EATING, FLEE }

const SPEED := 4.6
const FLEE_SPEED := 8.0
const BITE_RANGE := 0.9
const EAT_TIME := 3.5

var cell_pos := Vector2.ZERO
var kills_left := 1
var state := State.APPROACH

var _victim: Sheep = null
var _eat_left := 0.0
var _flee_dir := Vector2.ZERO
var _facing := 1.0
var _bob := 0.0


func _ready() -> void:
	add_to_group("wolves")
	_sync_position()


func _exit_tree() -> void:
	_release_victim()


func _process(delta: float) -> void:
	_bob += delta * 10.0
	if state != State.FLEE:
		_check_scared()

	match state:
		State.APPROACH:
			_approach(delta)
		State.EATING:
			_eat(delta)
		State.FLEE:
			_flee(delta)
	queue_redraw()


func _check_scared() -> void:
	for node in get_tree().get_nodes_in_group("scarers"):
		var threat_pos: Vector2 = node.cell_pos
		if threat_pos.distance_to(cell_pos) < node.scare_radius:
			_flee_from(threat_pos)
			return


func _approach(delta: float) -> void:
	if not is_instance_valid(_victim):
		_victim = _pick_victim()
	if _victim == null:
		_leave()
		return

	var to_victim := _victim.cell_pos - cell_pos
	if to_victim.length() < BITE_RANGE:
		_victim.wound()
		state = State.EATING
		_eat_left = EAT_TIME
		return
	_move(to_victim.normalized(), SPEED, delta)


func _eat(delta: float) -> void:
	if not is_instance_valid(_victim):
		_victim = null
		state = State.APPROACH
		return

	_eat_left -= delta
	if _eat_left > 0.0:
		return

	Game.say("Un loup a dévoré un mouton...")
	_victim.get_eaten()
	_victim = null
	kills_left -= 1
	state = State.APPROACH if kills_left > 0 else State.FLEE
	if state == State.FLEE:
		_flee_dir = _towards_edge()


func _flee(delta: float) -> void:
	_move(_flee_dir, FLEE_SPEED, delta)
	if cell_pos.x < -8.0 or cell_pos.y < -8.0 \
			or cell_pos.x > Config.WORLD_CELLS.x + 8.0 or cell_pos.y > Config.WORLD_CELLS.y + 8.0:
		queue_free()


func _pick_victim() -> Sheep:
	var best: Sheep = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("sheep"):
		var sheep := node as Sheep
		if sheep.targeted or sheep.place == Sheep.Place.STRAY:
			continue
		var dist := sheep.cell_pos.distance_to(cell_pos)
		if dist < best_dist:
			best_dist = dist
			best = sheep
	if best != null:
		best.targeted = true
	return best


func _flee_from(threat: Vector2) -> void:
	_release_victim()
	_flee_dir = (cell_pos - threat).normalized()
	if _flee_dir == Vector2.ZERO:
		_flee_dir = Vector2.RIGHT
	state = State.FLEE


func _leave() -> void:
	_flee_dir = _towards_edge()
	state = State.FLEE


func _towards_edge() -> Vector2:
	var away := cell_pos - Vector2(Config.WORLD_CELLS) * 0.5
	return away.normalized() if away != Vector2.ZERO else Vector2.LEFT


# Un mouton mordu mais pas mangé reste blessé : c'est au joueur d'appeler le véto.
func _release_victim() -> void:
	if is_instance_valid(_victim):
		_victim.targeted = false
		_victim.held = false
	_victim = null


func _move(direction: Vector2, speed: float, delta: float) -> void:
	cell_pos += direction * speed * delta
	var dx := Iso.to_screen(cell_pos).x - position.x
	if absf(dx) > 0.01:
		_facing = signf(dx)
	_sync_position()


func _sync_position() -> void:
	position = Iso.to_screen(cell_pos)


func _draw() -> void:
	var fur := Color("7d7f8c")
	var dark := Color("5a3e4b")
	var bob := absf(sin(_bob)) * 2.0 if state != State.EATING else 0.0

	var points := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		points.append(Vector2(cos(a) * 13.0, 5.0 + sin(a) * 5.0))
	draw_colored_polygon(points, Color(0, 0, 0, 0.2))

	draw_set_transform(Vector2(0, -bob), 0.0, Vector2(_facing, 1.0))
	# queue
	draw_line(Vector2(-11, -11), Vector2(-17, -16), dark, 5.0)
	draw_line(Vector2(-11, -11), Vector2(-17, -16), fur, 3.0)
	# pattes
	draw_rect(Rect2(-8, -6, 3, 6), dark)
	draw_rect(Rect2(5, -6, 3, 6), dark)
	# corps
	draw_circle(Vector2(-3, -11), 8.6, dark)
	draw_circle(Vector2(4, -11), 7.6, dark)
	draw_circle(Vector2(-3, -11), 7.2, fur)
	draw_circle(Vector2(4, -11), 6.2, fur)
	# tête + oreilles + museau
	draw_circle(Vector2(12, -14), 6.4, dark)
	draw_circle(Vector2(12, -14), 5.2, fur)
	draw_colored_polygon(PackedVector2Array([Vector2(9, -18), Vector2(10, -25), Vector2(13, -19)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(13, -19), Vector2(16, -25), Vector2(17, -17)]), dark)
	draw_circle(Vector2(17, -12), 2.4, dark)
	var eye := Color("ff5a4a") if state == State.EATING else Color.WHITE
	draw_circle(Vector2(13, -15), 1.1, eye)
	draw_set_transform(Vector2.ZERO)

	if state == State.EATING:
		var ratio := clampf(_eat_left / EAT_TIME, 0.0, 1.0)
		draw_rect(Rect2(-14, -34, 28, 5), dark)
		draw_rect(Rect2(-13, -33, 26.0 * ratio, 3), Color("e0504a"))
