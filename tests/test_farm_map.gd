extends RefCounted

var runner


func _map_with_plots(plots: Array) -> FarmMap:
	var map := FarmMap.new()
	for plot: Vector2i in plots:
		map.add_pen(plot)
	return map


# Pose une cloison verticale complète à x = column, sur toute la hauteur d'une parcelle
func _vertical_wall(column: int, from_y: int, to_y: int) -> Array:
	var edges := []
	for y in range(from_y, to_y):
		edges.append(Vector3i(column, y, FarmMap.V))
	return edges


func test_single_pen_is_one_region() -> void:
	var map := _map_with_plots([Vector2i(2, 2)])
	runner.assert_eq(map.region_ids().size(), 1)
	var id := map.region_id(Vector2i(32, 32))
	runner.assert_eq(map.region_cells(id).size(), 256)


func test_adjacent_pens_merge() -> void:
	var map := _map_with_plots([Vector2i(2, 2), Vector2i(3, 2)])
	runner.assert_eq(map.region_ids().size(), 1)
	var id := map.region_id(Vector2i(32, 32))
	runner.assert_eq(map.region_cells(id).size(), 512)


func test_diagonal_pens_stay_separate() -> void:
	var map := _map_with_plots([Vector2i(2, 2), Vector2i(3, 3)])
	runner.assert_eq(map.region_ids().size(), 2)


func test_fence_perimeter_of_merged_pens() -> void:
	var single := _map_with_plots([Vector2i(2, 2)])
	runner.assert_eq(single.fence_edges().size(), 64)
	# deux enclos collés : plus de clôture au milieu, 2 * 16 + 2 * 32 = 96
	var merged := _map_with_plots([Vector2i(2, 2), Vector2i(3, 2)])
	runner.assert_eq(merged.fence_edges().size(), 96)


func test_barrier_splits_pen() -> void:
	var map := _map_with_plots([Vector2i(2, 2)])
	var wall := _vertical_wall(40, 32, 48)
	runner.assert_eq(map.check_barriers(wall), "")
	map.add_barriers(wall)
	runner.assert_eq(map.region_ids().size(), 2)
	runner.assert_true(map.region_id(Vector2i(35, 35)) != map.region_id(Vector2i(45, 35)))


func test_barrier_too_close_to_border_is_refused() -> void:
	var map := _map_with_plots([Vector2i(2, 2)])
	# cloison à 3 cases du bord gauche : il resterait une bande de 3 de large
	runner.assert_eq(map.check_barriers(_vertical_wall(35, 32, 48)), "too_small")
	# à 4 cases c'est bon
	runner.assert_eq(map.check_barriers(_vertical_wall(36, 32, 48)), "")


func test_barrier_outside_pen_is_refused() -> void:
	var map := _map_with_plots([Vector2i(2, 2)])
	runner.assert_eq(map.check_barriers([Vector3i(10, 10, FarmMap.H)]), "outside")


func test_open_barrier_does_not_split() -> void:
	var map := _map_with_plots([Vector2i(2, 2)])
	# cloison qui ne va pas jusqu'au bout : l'enclos reste d'un seul tenant
	var wall := _vertical_wall(40, 32, 44)
	runner.assert_eq(map.check_barriers(wall), "")
	map.add_barriers(wall)
	runner.assert_eq(map.region_ids().size(), 1)


func test_capacity_counts_bonus() -> void:
	var map := _map_with_plots([Vector2i(2, 2)])
	var id := map.region_id(Vector2i(33, 33))
	runner.assert_eq(map.capacity_of(id), 16)
	map.add_capacity_bonus(Vector2i(33, 33), 6)
	runner.assert_eq(map.capacity_of(id), 22)


func test_can_buy_only_next_to_owned_land() -> void:
	var map := FarmMap.new()
	map.owned_plots[Vector2i(2, 2)] = true
	runner.assert_true(map.can_buy_plot(Vector2i(3, 2)))
	runner.assert_true(not map.can_buy_plot(Vector2i(3, 3)))
	runner.assert_true(not map.can_buy_plot(Vector2i(2, 2)))
	runner.assert_true(not map.can_buy_plot(Vector2i(-1, 2)))


func test_save_roundtrip() -> void:
	var map := _map_with_plots([Vector2i(2, 2)])
	map.add_barriers(_vertical_wall(40, 32, 48))
	var copy := FarmMap.new()
	copy.from_dict(map.to_dict())
	runner.assert_eq(copy.pen_plots.size(), 1)
	runner.assert_eq(copy.barriers.size(), 16)
	runner.assert_eq(copy.region_ids().size(), 2)
