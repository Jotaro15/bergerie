class_name WoolType
extends Resource
## Un motif de laine. Un fichier .tres par type dans data/wool/.

@export var id: StringName = &"white"
@export var display_name := "Blanche"
@export var color := Color(0.98, 0.97, 0.94)
@export var sell_price := 25
## Poids dans le tirage des moutons égarés (0 = n'apparaît jamais comme égaré)
@export var stray_weight := 10
