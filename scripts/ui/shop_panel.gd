class_name ShopPanel
extends PanelContainer
## Boutique : des onglets en haut, des cartes d'objets en dessous.

var _tab: String = ShopCatalog.TABS[0]
var _tab_buttons: Dictionary = {}
var _cards: HBoxContainer
var _buy_buttons: Array[Dictionary] = []   # {button, item}


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	for tab_name in ShopCatalog.TABS:
		var button := Button.new()
		button.text = tab_name
		button.toggle_mode = true
		button.pressed.connect(_select_tab.bind(tab_name))
		tabs.add_child(button)
		_tab_buttons[tab_name] = button

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_child(spacer)
	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(hide)
	tabs.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 218)
	column.add_child(scroll)

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	scroll.add_child(_cards)

	Game.money_changed.connect(func(_amount: int) -> void: _update_affordability())
	# le prix du terrain monte à chaque achat, il faut rafraîchir la carte
	Game.stats_changed.connect(func() -> void:
		if visible and _tab == "Terrain":
			_rebuild_cards())
	_select_tab(_tab)


func open() -> void:
	_select_tab(_tab)
	show()


func _select_tab(tab_name: String) -> void:
	_tab = tab_name
	for key: String in _tab_buttons:
		(_tab_buttons[key] as Button).set_pressed_no_signal(key == tab_name)
	_rebuild_cards()


func _rebuild_cards() -> void:
	for child in _cards.get_children():
		child.queue_free()
	_buy_buttons.clear()

	for item in ShopCatalog.in_tab(_tab):
		if item.kind == ShopItem.Kind.LAND:
			item.price = ShopCatalog.land_price(Game.owned_plots)
		_cards.add_child(_make_card(item))
	_update_affordability()


func _make_card(item: ShopItem) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(176, 204)
	card.add_theme_stylebox_override("panel", UiTheme.box(Color.WHITE, UiTheme.PLUM, 12, 3))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)

	var icon := ItemIcon.new()
	icon.item = item
	column.add_child(icon)

	var title := Label.new()
	title.text = item.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)

	var description := Label.new()
	description.text = item.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.custom_minimum_size = Vector2(150, 54)
	description.add_theme_font_size_override("font_size", 12)
	column.add_child(description)

	var buy := Button.new()
	buy.text = "Acheter  %d" % item.price
	buy.pressed.connect(func() -> void: Game.item_chosen.emit(item))
	column.add_child(buy)
	_buy_buttons.append({"button": buy, "item": item})
	return card


func _update_affordability() -> void:
	for entry in _buy_buttons:
		var button: Button = entry["button"]
		var item: ShopItem = entry["item"]
		button.disabled = Game.money < item.price
