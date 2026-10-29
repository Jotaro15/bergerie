class_name FarmMap
extends RefCounted
## Les données de la ferme : parcelles achetées, enclos, barrières, régions.
## Aucun nœud ici, ça permet de tester la logique sans lancer le jeu.
##
## Une "région" = un ensemble de cases d'enclos reliées entre elles sans barrière.
## Deux enclos collés ne forment qu'une seule région, c'est ce qui les fait fusionner.
## Les barrières posées à l'intérieur découpent ces régions.

signal changed

# Une barrière est identifiée par un Vector3i(x, y, orientation) :
#   H -> bord nord de la case (x, y), entre (x, y-1) et (x, y)
#   V -> bord ouest de la case (x, y), entre (x-1, y) et (x, y)
const H := 0
const V := 1

const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var owned_plots: Dictionary = {}     # Vector2i (parcelle) -> true
var pen_plots: Dictionary = {}       # Vector2i (parcelle) -> true
var barriers: Dictionary = {}        # Vector3i -> true
var capacity_bonus: Dictionary = {}  # Vector2i (case) -> places en plus

var _region_of: Dictionary = {}      # Vector2i (case) -> id de région
var _regions: Dictionary = {}        # id -> Array[Vector2i]
var _dirty := true


# --- helpers statiques ---

static func plot_of(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / Config.PLOT_SIZE),
		floori(float(cell.y) / Config.PLOT_SIZE))


static func plot_rect(plot: Vector2i) -> Rect2i:
	return Rect2i(plot * Config.PLOT_SIZE, Vector2i(Config.PLOT_SIZE, Config.PLOT_SIZE))


static func in_world(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 \
		and cell.x < Config.WORLD_CELLS.x and cell.y < Config.WORLD_CELLS.y


static func plot_in_world(plot: Vector2i) -> bool:
	return plot.x >= 0 and plot.y >= 0 \
		and plot.x < Config.WORLD_PLOTS.x and plot.y < Config.WORLD_PLOTS.y


## Les deux cases séparées par une barrière.
static func edge_cells(edge: Vector3i) -> Array[Vector2i]:
	var cell := Vector2i(edge.x, edge.y)
	var cells: Array[Vector2i] = []
	if edge.z == H:
		cells.append(cell + Vector2i.UP)
	else:
		cells.append(cell + Vector2i.LEFT)
	cells.append(cell)
	return cells


## Le bord partagé entre deux cases voisines.
static func edge_between(a: Vector2i, b: Vector2i) -> Vector3i:
	if a.x != b.x:
		return Vector3i(maxi(a.x, b.x), a.y, V)
	return Vector3i(a.x, maxi(a.y, b.y), H)


# --- parcelles et enclos ---

func is_owned(cell: Vector2i) -> bool:
	return owned_plots.has(plot_of(cell))


func is_pen_cell(cell: Vector2i) -> bool:
	return pen_plots.has(plot_of(cell))


func can_buy_plot(plot: Vector2i) -> bool:
	if not plot_in_world(plot) or owned_plots.has(plot):
		return false
	for dir in DIRECTIONS:
		if owned_plots.has(plot + dir):
			return true
	return false


func buy_plot(plot: Vector2i) -> void:
	owned_plots[plot] = true
	changed.emit()


func add_pen(plot: Vector2i) -> void:
	owned_plots[plot] = true
	pen_plots[plot] = true
	_dirty = true
	changed.emit()


func add_capacity_bonus(cell: Vector2i, bonus: int) -> void:
	capacity_bonus[cell] = capacity_bonus.get(cell, 0) + bonus


# --- barrières ---

func has_barrier(edge: Vector3i) -> bool:
	return barriers.has(edge)


## Une barrière n'a de sens qu'entre deux cases d'enclos.
func can_hold_barrier(edge: Vector3i) -> bool:
	for cell in edge_cells(edge):
		if not is_pen_cell(cell):
			return false
	return true


## Teste l'ajout de barrières sans rien modifier.
## Renvoie "" si c'est bon, sinon un code : "outside", "nothing", "too_small".
func check_barriers(new_edges: Array) -> String:
	var test := barriers.duplicate()
	var added := 0
	for edge: Vector3i in new_edges:
		if not can_hold_barrier(edge):
			return "outside"
		if not test.has(edge):
			test[edge] = true
			added += 1
	if added == 0:
		return "nothing"

	var computed := _compute_regions(test)
	var regions: Dictionary = computed["regions"]
	for id in regions:
		if not _has_block(regions[id]):
			return "too_small"
	return ""


func add_barriers(edges: Array) -> void:
	for edge: Vector3i in edges:
		barriers[edge] = true
	_dirty = true
	changed.emit()


func remove_barriers(edges: Array) -> int:
	var removed := 0
	for edge: Vector3i in edges:
		if barriers.erase(edge):
			removed += 1
	if removed > 0:
		_dirty = true
		changed.emit()
	return removed


## Les segments de clôture qui entourent les enclos (le périmètre extérieur).
func fence_edges() -> Array[Vector3i]:
	var edges: Array[Vector3i] = []
	for plot: Vector2i in pen_plots:
		var rect := plot_rect(plot)
		for x in range(rect.position.x, rect.end.x):
			if not is_pen_cell(Vector2i(x, rect.position.y - 1)):
				edges.append(Vector3i(x, rect.position.y, H))
			if not is_pen_cell(Vector2i(x, rect.end.y)):
				edges.append(Vector3i(x, rect.end.y, H))
		for y in range(rect.position.y, rect.end.y):
			if not is_pen_cell(Vector2i(rect.position.x - 1, y)):
				edges.append(Vector3i(rect.position.x, y, V))
			if not is_pen_cell(Vector2i(rect.end.x, y)):
				edges.append(Vector3i(rect.end.x, y, V))
	return edges


# --- régions ---

func region_id(cell: Vector2i) -> int:
	_ensure_regions()
	return _region_of.get(cell, -1)


func region_ids() -> Array:
	_ensure_regions()
	return _regions.keys()


func region_cells(id: int) -> Array:
	_ensure_regions()
	return _regions.get(id, [])


func random_cell_in_region(id: int) -> Vector2i:
	var cells := region_cells(id)
	if cells.is_empty():
		return Vector2i.ZERO
	return cells[randi() % cells.size()]


## Nombre de moutons que peut accueillir une région avant que ça déborde.
func capacity_of(id: int) -> int:
	var total := region_cells(id).size() / Config.CELLS_PER_SHEEP
	for cell: Vector2i in capacity_bonus:
		if region_id(cell) == id:
			total += capacity_bonus[cell]
	return total


func _ensure_regions() -> void:
	if not _dirty:
		return
	var computed := _compute_regions(barriers)
	_region_of = computed["region_of"]
	_regions = computed["regions"]
	_dirty = false


# Parcours en largeur sur toutes les cases d'enclos, en s'arrêtant aux barrières.
func _compute_regions(barrier_set: Dictionary) -> Dictionary:
	var region_of := {}
	var regions := {}
	var next_id := 0

	for plot: Vector2i in pen_plots:
		var rect := plot_rect(plot)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var start := Vector2i(x, y)
				if region_of.has(start):
					continue

				var cells: Array[Vector2i] = []
				var stack: Array[Vector2i] = [start]
				region_of[start] = next_id
				while not stack.is_empty():
					var current: Vector2i = stack.pop_back()
					cells.append(current)
					for dir in DIRECTIONS:
						var neighbour := current + dir
						if region_of.has(neighbour) or not is_pen_cell(neighbour):
							continue
						if barrier_set.has(edge_between(current, neighbour)):
							continue
						region_of[neighbour] = next_id
						stack.append(neighbour)

				regions[next_id] = cells
				next_id += 1

	return {"region_of": region_of, "regions": regions}


# Une région est valide si elle contient un carré plein de MIN_SUBPEN x MIN_SUBPEN cases.
func _has_block(cells: Array) -> bool:
	var set := {}
	for cell: Vector2i in cells:
		set[cell] = true

	for cell: Vector2i in cells:
		var fits := true
		for dy in Config.MIN_SUBPEN:
			for dx in Config.MIN_SUBPEN:
				if not set.has(cell + Vector2i(dx, dy)):
					fits = false
					break
			if not fits:
				break
		if fits:
			return true
	return false


# --- sauvegarde ---

func to_dict() -> Dictionary:
	var owned := []
	for plot: Vector2i in owned_plots:
		owned.append([plot.x, plot.y])
	var pens := []
	for plot: Vector2i in pen_plots:
		pens.append([plot.x, plot.y])
	var edges := []
	for edge: Vector3i in barriers:
		edges.append([edge.x, edge.y, edge.z])
	return {"owned": owned, "pens": pens, "barriers": edges}


func from_dict(data: Dictionary) -> void:
	owned_plots.clear()
	pen_plots.clear()
	barriers.clear()
	capacity_bonus.clear()
	for p: Array in data.get("owned", []):
		owned_plots[Vector2i(int(p[0]), int(p[1]))] = true
	for p: Array in data.get("pens", []):
		pen_plots[Vector2i(int(p[0]), int(p[1]))] = true
	for e: Array in data.get("barriers", []):
		barriers[Vector3i(int(e[0]), int(e[1]), int(e[2]))] = true
	_dirty = true
	changed.emit()
