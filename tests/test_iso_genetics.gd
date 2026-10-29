extends RefCounted

var runner


func test_iso_roundtrip() -> void:
	for cell in [Vector2(0, 0), Vector2(12.5, 3.25), Vector2(79, 79)]:
		var back := Iso.to_cell(Iso.to_screen(cell))
		runner.assert_true(back.distance_to(cell) < 0.001, "aller-retour %s" % cell)


func test_iso_grid_picks_the_right_cell() -> void:
	# le centre de la case (5, 7) doit retomber sur la case (5, 7)
	var screen := Iso.to_screen(Vector2(5.5, 7.5))
	runner.assert_eq(Iso.to_grid(screen), Vector2i(5, 7))


func test_rect_polygon_has_four_corners() -> void:
	runner.assert_eq(Iso.rect_polygon(Rect2i(0, 0, 2, 2)).size(), 4)


func test_same_wool_gives_same_wool() -> void:
	for i in 20:
		runner.assert_eq(Genetics.mix(&"white", &"white"), &"white")


func test_mix_returns_a_parent_wool_without_mutation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 20:
		var result := Genetics.mix(&"white", &"black", rng)
		runner.assert_true(result == &"white" or result == &"black")


func test_catalog_is_consistent() -> void:
	var ids := {}
	for item in ShopCatalog.all():
		runner.assert_true(not ids.has(item.id), "id en double : %s" % item.id)
		ids[item.id] = true
		runner.assert_true(item.price > 0)
		runner.assert_true(ShopCatalog.TABS.has(item.tab), "onglet inconnu pour %s" % item.id)


func test_land_price_grows() -> void:
	runner.assert_true(ShopCatalog.land_price(5) > ShopCatalog.land_price(1))


func test_white_wool_is_registered() -> void:
	runner.assert_true(WoolRegistry.get_type(&"white") != null)
	runner.assert_true(WoolRegistry.price_of(&"white") > 0)
