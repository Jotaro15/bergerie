class_name Economy
extends RefCounted
## Tous les prix de revente au même endroit : moutons, laine, décorations, clôtures.
## Les prix d'achat restent dans ShopCatalog, les chiffres dans Config.


## Ce que rapporte un mouton : l'adulte vaut plus que l'agneau, et un blessé
## ne vaut plus qu'une fraction du prix.
static func sheep_base_price(adult: bool, wounded: bool) -> int:
	var price := Config.SELL_ADULT if adult else Config.SELL_LAMB
	if wounded:
		price = roundi(price * Config.WOUNDED_FACTOR)
	return price


static func sheep_price(sheep: Sheep) -> int:
	return scaled(sheep_base_price(sheep.is_adult(), sheep.wounded))


## Valeur de `amount` laines d'un même type (le charme de la bergerie compte).
static func wool_price(id: StringName, amount: int) -> int:
	return scaled(WoolRegistry.price_of(id) * maxi(amount, 0))


## Reprise d'une décoration posée.
static func resale(item: ShopItem) -> int:
	return roundi(item.price * Config.RESALE_RATIO)


static func fence_resale(count: int) -> int:
	return count * roundi(Config.BARRIER_PRICE * Config.RESALE_RATIO)


static func scaled(amount: int) -> int:
	return roundi(amount * Game.price_multiplier())
