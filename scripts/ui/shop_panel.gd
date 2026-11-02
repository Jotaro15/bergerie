class_name ShopPanel
extends PanelContainer
## Boutique : des onglets en haut, des cartes d'objets en dessous.
## Les onglets du catalogue servent à acheter ; « Vendre » regroupe tout ce qui se
## revend (laine, moutons, décorations, clôtures, démolition) et « Du jour » propose
## une sélection qui change toutes les 24 h réelles.

const SELL_TAB := "Vendre"
const DAILY_TAB := "Du jour"

var _tab: String = ShopCatalog.TABS[0]
var _tab_buttons: Dictionary = {}
var _cards: HBoxContainer
var _buy_buttons: Array[Dictionary] = []   # {button, item}
var _demolish_button: Button
var _daily_info: Label


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	var tab_names: Array[String] = ShopCatalog.TABS.duplicate()
	tab_names.append(SELL_TAB)
	tab_names.append(DAILY_TAB)
	for tab_name in tab_names:
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

	_daily_info = Label.new()
	_daily_info.add_theme_font_size_override("font_size", 14)
	tabs.add_child(_daily_info)

	_demolish_button = _make_demolish_button()
	tabs.add_child(_demolish_button)

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
	# le prix du terrain monte à chaque achat, le stock du jour baisse : il faut rafraîchir les cartes
	Game.stats_changed.connect(func() -> void:
		if visible and (_tab == "Terrain" or _tab == DAILY_TAB):
			_rebuild_cards())
	_select_tab(_tab)


func open() -> void:
	_select_tab(_tab)
	show()


func _process(_delta: float) -> void:
	if not visible or _tab != DAILY_TAB:
		return
	# minuit passé pendant que la boutique est ouverte : on change les offres
	if DailyShop.refresh():
		_rebuild_cards()
	var left := DailyShop.seconds_left()
	_daily_info.text = "Nouvelles offres dans %d h %02d min" % [left / 3600, (left % 3600) / 60]


func _select_tab(tab_name: String) -> void:
	_tab = tab_name
	for key: String in _tab_buttons:
		(_tab_buttons[key] as Button).set_pressed_no_signal(key == tab_name)
	_demolish_button.visible = tab_name == SELL_TAB
	_daily_info.visible = tab_name == DAILY_TAB
	_rebuild_cards()


func _rebuild_cards() -> void:
	for child in _cards.get_children():
		child.queue_free()
	_buy_buttons.clear()

	match _tab:
		SELL_TAB:
			_fill_sell_tab()
		DAILY_TAB:
			for item in DailyShop.items():
				_cards.add_child(_make_card(item))
		_:
			for item in ShopCatalog.in_tab(_tab):
				if item.kind == ShopItem.Kind.LAND:
					item.price = ShopCatalog.land_price(Game.owned_plots)
				_cards.add_child(_make_card(item))
	_update_affordability()


# --- cartes d'achat ---

func _card_frame(width: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 204)
	card.add_theme_stylebox_override("panel", UiTheme.box(Color.WHITE, UiTheme.PLUM, 12, 3))
	return card


func _make_card(item: ShopItem) -> PanelContainer:
	var card := _card_frame(176)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)

	var icon := ItemIcon.new()
	icon.item = item
	column.add_child(icon)

	column.add_child(_title(item.title))

	var daily: String = item.extra.get("daily", "")
	var text := item.description
	if daily != "":
		# on rappelle le prix de la boutique permanente quand l'offre est une vraie remise
		var base := ShopCatalog.by_id(item.id)
		text = "Reste : %d" % DailyShop.remaining(daily)
		if base != null and base.price > item.price:
			text += "   (boutique : %d)" % base.price
	column.add_child(_small_text(text, 54))

	var buy := Button.new()
	buy.text = "Acheter  %d" % item.price
	buy.pressed.connect(func() -> void: Game.item_chosen.emit(item))
	column.add_child(buy)
	_buy_buttons.append({"button": buy, "item": item})
	return card


func _title(text: String) -> Label:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	return title


func _small_text(text: String, height: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(150, height)
	label.add_theme_font_size_override("font_size", 12)
	return label


func _update_affordability() -> void:
	for entry in _buy_buttons:
		var button: Button = entry["button"]
		var item: ShopItem = entry["item"]
		var daily: String = item.extra.get("daily", "")
		var sold_out := daily != "" and DailyShop.remaining(daily) <= 0
		button.disabled = sold_out or Game.money < item.price
		if sold_out:
			button.text = "Épuisé"


# --- onglet Vendre ---

func _fill_sell_tab() -> void:
	# une carte par laine découverte (la blanche toujours), puis les modes de revente sur la carte
	var wools: Array[StringName] = []
	for id: StringName in Game.wool_found:
		wools.append(id)
	if not wools.has(&"white"):
		wools.append(&"white")
	wools.sort()
	for id in wools:
		_cards.add_child(_make_wool_card(id))

	_cards.add_child(_make_mode_card("Moutons", _sheep_prices_text(), ShopCatalog.by_id(&"sheep_ewe"),
			&"sell", "Choisir un mouton"))
	_cards.add_child(_make_mode_card("Décorations",
			"Revends une décoration posée pour %d %% de son prix." % roundi(Config.RESALE_RATIO * 100.0),
			ShopCatalog.by_id(&"tree"), &"sell_deco", "Choisir une décoration"))
	_cards.add_child(_make_mode_card("Clôtures",
			"Glisse sur tes barrières intérieures : %d pièces le segment." % Economy.fence_resale(1),
			ShopCatalog.by_id(&"barrier"), &"sell_fence", "Retirer des clôtures"))


func _sheep_prices_text() -> String:
	return "Adulte : %d   Agneau : %d\nBlessés : seulement %d et %d" % [
		Economy.scaled(Economy.sheep_base_price(true, false)),
		Economy.scaled(Economy.sheep_base_price(false, false)),
		Economy.scaled(Economy.sheep_base_price(true, true)),
		Economy.scaled(Economy.sheep_base_price(false, true))]


func _make_wool_card(id: StringName) -> PanelContainer:
	var type := WoolRegistry.get_type(id)
	var stock := Game.wool_count(id)

	var card := _card_frame(210)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)

	var icon := SellIcon.new(SellIcon.Kind.WOOL, Vector2(80, 48), WoolRegistry.color_of(id))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	column.add_child(_title("Laine %s" % (type.display_name.to_lower() if type != null else "")))
	column.add_child(_small_text("En stock : %d   (%d pièces l'unité)" % [stock, Economy.wool_price(id, 1)], 18))

	# la quantité à vendre, avec un raccourci pour tout prendre
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	var amount := SpinBox.new()
	amount.min_value = 1
	amount.max_value = maxi(stock, 1)
	amount.value = 1
	amount.editable = stock > 0
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(amount)
	var all := Button.new()
	all.text = "Tout"
	all.disabled = stock <= 0
	all.pressed.connect(func() -> void: amount.value = stock)
	row.add_child(all)

	# l'aperçu se met à jour dès que la quantité change
	var preview := Label.new()
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(preview)
	var refresh_preview := func(_value: float = 0.0) -> void:
		preview.text = "Tu obtiens : +%d" % Economy.wool_price(id, int(amount.value))
	amount.value_changed.connect(refresh_preview)
	refresh_preview.call()

	var sell := Button.new()
	sell.text = "Vendre"
	sell.disabled = stock <= 0
	sell.pressed.connect(func() -> void: _sell_wool(id, int(amount.value)))
	column.add_child(sell)
	return card


func _sell_wool(id: StringName, quantity: int) -> void:
	var gain := Economy.wool_price(id, quantity)
	if not Game.take_wool(id, quantity):
		Game.say("Tu n'as pas autant de laine.")
		return
	Game.earn(gain)
	Game.say("%d laine(s) vendue(s) : +%d" % [quantity, gain])
	_rebuild_cards()


func _make_mode_card(title: String, text: String, shown: ShopItem, tool_id: StringName, button_text: String) -> PanelContainer:
	var card := _card_frame(190)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)

	var icon := ItemIcon.new()
	icon.item = shown
	column.add_child(icon)
	column.add_child(_title(title))
	column.add_child(_small_text(text, 54))

	var choose := Button.new()
	choose.text = button_text
	choose.pressed.connect(_start_sell_mode.bind(tool_id))
	column.add_child(choose)
	return card


# Un mode de revente se joue sur la carte : on referme la boutique pour la voir.
func _start_sell_mode(tool_id: StringName) -> void:
	Game.set_tool(tool_id)
	hide()


# Le petit marteau de l'onglet Vendre : choisir un bâtiment à démolir.
func _make_demolish_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(44, 40)
	button.tooltip_text = "Démolir un bâtiment (bergerie, abreuvoir). La démolition se fait la nuit et ne rend rien."
	button.pressed.connect(_start_sell_mode.bind(&"demolish"))
	var icon := SellIcon.new(SellIcon.Kind.HAMMER, Vector2(32, 32))
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	return button
