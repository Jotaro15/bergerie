extends SceneTree
## Lanceur de tests minimaliste (pas besoin d'un plugin).
## Usage : godot --headless -s tests/run_tests.gd
## Chaque fichier test_*.gd du dossier expose des méthodes test_*() qui utilisent assert_true / assert_eq.

var _passed := 0
var _failed := 0
var _current := ""


func _init() -> void:
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(file)
	files.sort()

	for file in files:
		var script := load("res://tests/" + file) as GDScript
		var suite: Object = script.new()
		suite.set("runner", self)
		for method in suite.get_method_list():
			var method_name: String = method["name"]
			if method_name.begins_with("test_"):
				_current = "%s::%s" % [file, method_name]
				suite.call(method_name)

	print("\n%d ok, %d en échec" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func assert_true(condition: bool, message := "") -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("ECHEC %s %s" % [_current, message])


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		printerr("ECHEC %s : obtenu %s, attendu %s %s" % [_current, actual, expected, message])
