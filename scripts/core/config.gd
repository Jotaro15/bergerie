class_name Config
extends RefCounted
## Toutes les valeurs d'équilibrage au même endroit, pour pouvoir tweaker sans fouiller.

# --- grille ---
const TILE_W := 32
const TILE_H := 16
const PLOT_SIZE := 16                  # un petit enclos = une parcelle de 16x16 cases
const WORLD_PLOTS := Vector2i(5, 5)
const WORLD_CELLS := Vector2i(80, 80)  # PLOT_SIZE * WORLD_PLOTS
const MIN_SUBPEN := 4                  # taille mini d'un sous-enclos (en cases)
const CELLS_PER_SHEEP := 16            # 1 mouton pour 16 cases, avant bonus des bâtiments

# --- économie ---
const START_MONEY := 800
const DAILY_BONUS := 100
const BONUS_DELAY := 86400             # 24h en secondes réelles - pour la récupération des bonus, 
#c'est mieux car au début j'ai bêtement mis jour-nuit, sauf qu'on peut tricher en enchaînant les journées du coup...
# Est-ce que je reprendrais pas le délai de 24h pour la gestation des agneaux ? (ça me semble plus logique que 2 jours de jeu, et ça permet de mieux gérer les naissances)
const FEED_COST := 3
const MILK_GAIN := 12
const BOTTLE_COST := 5
const VET_COST_BIRTH := 80
const VET_COST_WOUND := 60
const SELL_ADULT := 80
const SELL_LAMB := 40
const BARRIER_PRICE := 5

# --- vie du troupeau (en jours de jeu) ---
const SHEAR_DELAY_DAYS := 3
const PREGNANCY_DAYS := 2
const LAMB_STAGES := 3
const LAMB_SURVIVAL_NO_VET := 0.6
const ESCAPE_CHANCE := 0.3             # par mouton, dans un enclos trop plein, chaque nuit

# --- déplacements (cases par seconde, sauf PLAYER_SPEED qui est en pixels écran) ---
const PLAYER_SPEED := 150.0
const SHEEP_SPEED := 0.9

# --- nuit ---
const SHEEP_PER_WOLF := 6
const MAX_WOLVES := 10
const RESCUE_RADIUS := 1.8
