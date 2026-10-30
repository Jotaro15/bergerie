extends Node
## État global du jeu (argent, jour/nuit, outil actif) + les signaux que l'interface écoute.
#à rajouter : gestion du jour différé/ des phases de la lune + gestion des tickets 

signal money_changed(amount: int)
signal day_changed(day: int)
signal phase_changed(phase: int)
signal stats_changed
signal toast(message: String)
signal mode_changed
# émis par la boutique (shop_panel.gd), pas ici : Godot ne peut pas le deviner
@warning_ignore("unused_signal")
signal item_chosen(item: ShopItem)

enum Phase { DAY, NIGHT }

const MOVE_KEYS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
}

var money: int = Config.START_MONEY
var day: int = 1
var phase: Phase = Phase.DAY
var last_bonus_unix: int = 0

# mode courant : un outil de jour, ou un objet de la boutique en cours de placement
var tool_id: StringName = &"walk"
var build_item: ShopItem = null

# stats poussées par le troupeau / le monde, lues par l'interface
var flock_size := 0
var labor_count := 0
var wounded_count := 0
var charm := 0
var owned_plots := 1
var wool_found: Dictionary = {}


func _ready() -> void:
	_register_inputs()


# On déclare les touches en code avec les keycodes *physiques* : ça donne ZQSD
# sur un clavier AZERTY sans rien avoir à configurer. (tiré de stackoverflow)
# possibilité de changer les touches + ajout manette à rajouter + tard.
func _register_inputs() -> void:
	for action: StringName in MOVE_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in MOVE_KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key as Key
			InputMap.action_add_event(action, event)


func is_day() -> bool:
	return phase == Phase.DAY


func say(message: String) -> void:
	toast.emit(message)


func earn(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func spend(amount: int) -> bool:
	if money < amount:
		say("Pas assez de pièces !")
		return false
	money -= amount
	money_changed.emit(money)
	return true


func price_multiplier() -> float:
	return 1.0 + minf(float(charm), 30.0) * 0.01


func toggle_phase() -> void:
	if phase == Phase.DAY:
		phase = Phase.NIGHT
	else:
		phase = Phase.DAY
		day += 1
		day_changed.emit(day)
	clear_mode()
	phase_changed.emit(phase)


func set_tool(id: StringName) -> void:
	tool_id = id
	build_item = null
	mode_changed.emit()


func set_build_item(item: ShopItem) -> void:
	build_item = item
	tool_id = &"build"
	mode_changed.emit()


func clear_mode() -> void:
	tool_id = &"walk"
	build_item = null
	mode_changed.emit()


func bonus_ready() -> bool:
	return int(Time.get_unix_time_from_system()) - last_bonus_unix >= Config.BONUS_DELAY


func claim_bonus() -> int:
	if not bonus_ready():
		return 0
	last_bonus_unix = int(Time.get_unix_time_from_system())
	earn(Config.DAILY_BONUS)
	return Config.DAILY_BONUS


func to_dict() -> Dictionary:
	return {
		"money": money,
		"day": day,
		"last_bonus": last_bonus_unix,
		"wool_found": wool_found.keys(),
	}


func from_dict(data: Dictionary) -> void:
	money = int(data.get("money", Config.START_MONEY))
	day = int(data.get("day", 1))
	last_bonus_unix = int(data.get("last_bonus", 0))
	wool_found.clear()
	for id: String in data.get("wool_found", []):
		wool_found[StringName(id)] = true
	phase = Phase.DAY
	money_changed.emit(money)
	day_changed.emit(day)
	stats_changed.emit()
