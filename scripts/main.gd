extends Node
## Point d'entrée : crée le monde, charge la sauvegarde s'il y en a une, puis l'interface :)


func _ready() -> void:
	var world := World.new()
	add_child(world)
	world.start(SaveFile.read())

	# l'interface vient après le monde pour que le bonus quotidien soit déjà chargé
	add_child(Hud.new())
