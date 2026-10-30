class_name Hud
extends CanvasLayer
## Interface : barre de ressources en haut, outils de jour à gauche, boutique en
## bas, messages qui apparaissent puis disparaissent, bonus quotidien.

# id, libellé, aide affichée en bas
const TOOLS := [
	[&"walk", "Déplacer", "Glisse un mouton pour le changer d'enclos. Le berger se déplace avec ZQSD / les flèches."],
	[&"feed", "Nourrir", "Clique sur un enclos (ou un mouton) pour distribuer le foin : 3 pièces par mouton."],
	[&"milk", "Traire", "Clique sur une brebis adulte qui a mangé. Une fois par jour."],
	[&"shear", "Tondre", "Clique sur un mouton adulte qui a mangé. Possible tous les 3 jours."],
	[&"breed", "Reproduire", "Clique sur un mouton : il cherche un partenaire dans son enclos."],
	[&"grow", "Biberon", "Clique sur un agneau pour le faire grandir (une fois par jour, 5 pièces)."],
	[&"vet", "Vétérinaire", "Clique sur une brebis qui met bas ou sur un mouton blessé."],
	[&"sell", "Vendre", "Clique sur un mouton pour le vendre."],
]

const NIGHT_HINT := "Nuit : approche-toi des loups pour les faire fuir, clique sur les chantiers pour les construire (en étant dessus) et rattrape les moutons égarés."

var _money: Label
var _day: Label
var _flock: Label
var _wool: Label
var _alerts: Label
var _alerts_chip: PanelContainer
var _phase_button: Button
var _toolbar: PanelContainer
var _tool_buttons: Dictionary = {}
var _hint: Label
var _hint_panel: PanelContainer
var _toasts: VBoxContainer
var _shop: ShopPanel
var _bonus_popup: PanelContainer


func _ready() -> void:
	layer = 10

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	root.add_child(margin)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)

	layout.add_child(_build_top_bar())

	var middle := HBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(middle)
	middle.add_child(_build_toolbar())
	middle.add_child(_build_toast_area())

	layout.add_child(_build_bottom())
	root.add_child(_build_bonus_popup())

	Game.money_changed.connect(func(_amount: int) -> void: _refresh())
	Game.day_changed.connect(func(_day_number: int) -> void: _refresh())
	Game.stats_changed.connect(_refresh)
	Game.phase_changed.connect(func(_phase: int) -> void: _on_phase_changed())
	Game.mode_changed.connect(_on_mode_changed)
	Game.toast.connect(_show_toast)
	Game.item_chosen.connect(_on_item_chosen)

	_refresh()
	_on_phase_changed()
	_bonus_popup.visible = Game.bonus_ready()


# --- construction des blocs ---

func _build_top_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.CREAM, UiTheme.WOOD_DARK, 14, 4))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	_money = _chip(row, UiTheme.YELLOW.lightened(0.3))
	_day = _chip(row, UiTheme.TEAL.lightened(0.4))
	_flock = _chip(row, UiTheme.PINK.lightened(0.4))
	_wool = _chip(row, Color("e6dcf5"))
	_alerts = _chip(row, Color("ffb3a8"))
	_alerts_chip = _alerts.get_parent() as PanelContainer

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var shop_button := Button.new()
	shop_button.text = "Boutique"
	shop_button.pressed.connect(_toggle_shop)
	row.add_child(shop_button)

	_phase_button = Button.new()
	_phase_button.pressed.connect(Game.toggle_phase)
	row.add_child(_phase_button)
	return bar


func _chip(parent: Control, tint: Color) -> Label:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiTheme.chip_style(tint))
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 17)
	chip.add_child(label)
	parent.add_child(chip)
	return label


func _build_toolbar() -> PanelContainer:
	_toolbar = PanelContainer.new()
	_toolbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_toolbar.add_child(column)

	for tool_def in TOOLS:
		var button := Button.new()
		button.text = tool_def[1]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(130, 0)
		button.pressed.connect(_on_tool_pressed.bind(tool_def[0]))
		column.add_child(button)
		_tool_buttons[tool_def[0]] = button
	return _toolbar


func _build_toast_area() -> Control:
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_top = 8.0
	_toasts.add_theme_constant_override("separation", 6)
	area.add_child(_toasts)
	return area


func _build_bottom() -> VBoxContainer:
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 8)

	_hint_panel = PanelContainer.new()
	_hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hint_panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.CREAM, UiTheme.WOOD_DARK, 12, 3))
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(560, 0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint)
	bottom.add_child(_hint_panel)

	_shop = ShopPanel.new()
	_shop.visible = false
	bottom.add_child(_shop)
	return bottom


func _build_bonus_popup() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bonus_popup = PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_bonus_popup.add_child(column)

	var title := Label.new()
	title.text = "Cadeau du jour !"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)

	var button := Button.new()
	button.text = "Récupérer %d pièces" % Config.DAILY_BONUS
	button.pressed.connect(func() -> void:
		Game.claim_bonus()
		_bonus_popup.hide())
	column.add_child(button)

	center.add_child(_bonus_popup)
	return center


# --- mise à jour ---

func _refresh() -> void:
	_money.text = "Pièces : %d" % Game.money
	_day.text = "Jour %d  -  %s" % [Game.day, "Jour" if Game.is_day() else "Nuit"]
	_flock.text = "Troupeau : %d" % Game.flock_size
	_wool.text = "Laines : %d/%d" % [Game.wool_found.size(), WoolRegistry.all().size()]

	var alert_parts: Array[String] = []
	if Game.labor_count > 0:
		alert_parts.append("Mises bas : %d" % Game.labor_count)
	if Game.wounded_count > 0:
		alert_parts.append("Blessés : %d" % Game.wounded_count)
	_alerts.text = "  ".join(alert_parts)
	_alerts_chip.visible = not alert_parts.is_empty()


func _on_phase_changed() -> void:
	var day := Game.is_day()
	_phase_button.text = "Passer à la nuit" if day else "Passer au jour"
	_toolbar.visible = day
	if not day:
		_shop.hide()
	_refresh()
	_on_mode_changed()


func _on_mode_changed() -> void:
	for id: StringName in _tool_buttons:
		(_tool_buttons[id] as Button).set_pressed_no_signal(id == Game.tool_id)
	_hint.text = _hint_text()


func _hint_text() -> String:
	if not Game.is_day():
		return NIGHT_HINT
	var item := Game.build_item
	if item != null:
		match item.kind:
			ShopItem.Kind.LAND:
				return "Clique sur une parcelle voisine pour l'acheter. Clic droit : annuler."
			ShopItem.Kind.ENCLOSURE:
				return "Clique ou glisse pour planifier des enclos (16x16). Collés, ils fusionnent. Clic droit : annuler."
			ShopItem.Kind.BARRIER:
				return "Glisse pour tracer une barrière (clic droit + glisser pour en retirer). Sous-enclos de 4x4 minimum."
			_:
				return "Clique ou glisse pour planifier. La nuit, va sur le chantier et clique pour construire. Clic droit : annuler."
	for tool_def in TOOLS:
		if tool_def[0] == Game.tool_id:
			return tool_def[2]
	return ""


func _on_tool_pressed(id: StringName) -> void:
	# recliquer sur l'outil actif revient au déplacement
	Game.set_tool(&"walk" if Game.tool_id == id else id)


func _toggle_shop() -> void:
	if not Game.is_day():
		Game.say("La boutique n'ouvre que de jour.")
		return
	if _shop.visible:
		_shop.hide()
	else:
		_shop.open()


func _on_item_chosen(item: ShopItem) -> void:
	# les moutons et les chiens s'achètent à la chaîne, le reste fait fermer la boutique
	if item.kind != ShopItem.Kind.SHEEP and item.kind != ShopItem.Kind.DOG:
		_shop.hide()


func _show_toast(text: String) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.CREAM, UiTheme.PLUM, 10, 2))
	var label := Label.new()
	label.text = text
	panel.add_child(label)
	_toasts.add_child(panel)

	while _toasts.get_child_count() > 4:
		var oldest := _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()

	# le tween est rattaché au panneau : s'il est supprimé avant la fin, le tween s'arrête avec
	var tween := panel.create_tween()
	tween.tween_interval(2.8)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)
