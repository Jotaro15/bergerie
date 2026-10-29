class_name Shepherd
extends Node2D
## Le joueur. Se déplace au clavier (ZQSD / WASD / flèches) ou en cliquant sur le sol.

var cell_pos := Vector2(40.0, 50.0)
var scare_radius := 4.5   # les loups fuient en dessous de cette distance
var moving := false
var moved_by_keys := false

var _target := Vector2.ZERO
var _has_target := false
var _facing := 1.0
var _walk_time := 0.0


func _ready() -> void:
	add_to_group("scarers")
	_sync_position()


func walk_to(cell: Vector2) -> void:
	_target = _clamped(cell)
	_has_target = true


func teleport(cell: Vector2) -> void:
	cell_pos = _clamped(cell)
	_has_target = false
	_sync_position()


func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moved_by_keys = input != Vector2.ZERO
	moving = false

	if moved_by_keys:
		_has_target = false
		# l'entrée est en espace écran, on la convertit en déplacement sur la grille
		_move_by(Iso.to_cell(input * Config.PLAYER_SPEED * delta))
	elif _has_target:
		var to_target := _target - cell_pos
		var step := Config.PLAYER_SPEED / Config.TILE_W * delta * 1.2
		if to_target.length() <= step:
			cell_pos = _target
			_has_target = false
			_sync_position()
		else:
			_move_by(to_target.normalized() * step)

	if moving:
		_walk_time += delta * 10.0
	queue_redraw()


func _move_by(offset: Vector2) -> void:
	cell_pos = _clamped(cell_pos + offset)
	var dx := Iso.to_screen(cell_pos).x - position.x
	if absf(dx) > 0.01:
		_facing = signf(dx)
	moving = true
	_sync_position()


func _clamped(cell: Vector2) -> Vector2:
	return cell.clamp(Vector2(0.5, 0.5), Vector2(Config.WORLD_CELLS) - Vector2(0.5, 0.5))


func _sync_position() -> void:
	position = Iso.to_screen(cell_pos)


func _draw() -> void:
	var outline := Color("5a3e4b")
	var bob := absf(sin(_walk_time)) * 2.0 if moving else 0.0

	var shadow := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		shadow.append(Vector2(cos(a) * 9.0, sin(a) * 3.5))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.2))

	draw_set_transform(Vector2(0, -bob), 0.0, Vector2(_facing, 1.0))
	# jambes
	draw_rect(Rect2(-4, -8, 3, 8), outline)
	draw_rect(Rect2(1, -8, 3, 8), outline)
	# corps (tunique)
	draw_rect(Rect2(-6, -22, 12, 15), outline)
	draw_rect(Rect2(-5, -21, 10, 13), Color("5cc8c8"))
	# tête
	draw_circle(Vector2(0, -28), 7.0, outline)
	draw_circle(Vector2(0, -28), 5.8, Color("f6d2b0"))
	# chapeau de paille
	draw_rect(Rect2(-9, -34, 18, 3), outline)
	draw_rect(Rect2(-8, -33, 16, 1.5), Color("f0d27a"))
	draw_rect(Rect2(-5, -39, 10, 6), outline)
	draw_rect(Rect2(-4, -38, 8, 5), Color("f0d27a"))
	draw_circle(Vector2(2, -28), 0.9, outline)
	# houlette
	draw_line(Vector2(9, -2), Vector2(9, -30), outline, 4.0)
	draw_line(Vector2(9, -2), Vector2(9, -30), Color("a9714b"), 2.0)
	draw_arc(Vector2(12, -30), 3.5, PI, TAU * 0.95, 8, Color("a9714b"), 2.0)
	draw_set_transform(Vector2.ZERO)
