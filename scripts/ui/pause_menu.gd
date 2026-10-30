class_name PauseMenu
extends CanvasLayer
## Menu de pause : voile sur le jeu, boutons Reprendre / Quitter.
##
## C'est le seul nœud qui reste actif quand l'arbre est en pause (PROCESS_MODE_ALWAYS),
## donc c'est lui qui écoute P et Échap pour reprendre la partie.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	visible = false
	_build()
	Game.pause_changed.connect(_on_pause_changed)


func _build() -> void:
	# ce contrôle plein écran bloque aussi les clics vers l'interface du dessous
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.build()
	add_child(root)

	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.2, 0.12, 0.22, 0.45)
	root.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(240, 0)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var resume := Button.new()
	resume.text = "Reprendre"
	resume.pressed.connect(Game.set_paused.bind(false))
	column.add_child(resume)

	var quit := Button.new()
	quit.text = "Quitter"
	quit.pressed.connect(_quit)
	column.add_child(quit)

	var hint := Label.new()
	hint.text = "P ou Échap pour reprendre"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	column.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if not Game.paused or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_P):
		Game.set_paused(false)
		get_viewport().set_input_as_handled()


func _on_pause_changed(paused: bool) -> void:
	visible = paused


# La partie est sauvegardée au moment où on entre en pause, et rien ne bouge ensuite.
func _quit() -> void:
	get_tree().quit()