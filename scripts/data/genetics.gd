class_name Genetics
extends RefCounted
## Héritage de la laine à la naissance d'un agneau.
## Pour l'instant il n'y a qu'une laine blanche, donc rien ne se passe.
## Quand d'autres laines arriveront, les croisements spéciaux se déclarent ici.

## Clé = ids triés "a+b", valeur = [laine obtenue, probabilité]
## ex : "black+white": [&"grey", 0.25]
const MUTATIONS := {}


static func mix(a: StringName, b: StringName, rng: RandomNumberGenerator = null) -> StringName:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var key := _key(a, b)
	if MUTATIONS.has(key):
		var mutation: Array = MUTATIONS[key]
		if rng.randf() < float(mutation[1]):
			return StringName(mutation[0])

	# sinon l'agneau prend la laine d'un des deux parents
	return a if rng.randf() < 0.5 else b


static func _key(a: StringName, b: StringName) -> String:
	var ids := [String(a), String(b)]
	ids.sort()
	return "%s+%s" % ids
