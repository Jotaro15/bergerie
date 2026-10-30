# Assets

Pour l'instant, je n'ai pas eu le temps de créer les assets par moi même donc tout est fait avec claude en code, pour avoir malgré tout un rendu cohérent. 

## Packs gratuits repérés

Petite veille de potentiels pack graduits pour éviter d'utiliser le contenu généré de Claude. 

| Besoin | Pack | Licence annoncée | Remarques |
|---|---|---|---|
| Moutons | « Sheep » de mad-era (itch.io) | gratuit / prix libre, usage commercial autorisé | style kawaii, 64x64, animations idle / marche / manger |
| Moutons colorés | Mouton animé de NMR9 (OpenGameArt) | gratuit | plusieurs couleurs, pratique pour les laines futures |
| Décor, bâtiments, clôtures, fermier | « Isometric Miniature Farm » de Kenney | CC0 | une soixantaine de tuiles isométriques, personnages inclus |
| Décor (variante) | « Tiny Farm » de Kenney | CC0 | vue de dessus |
| Animaux isométriques | « Farm, Puzzle & Animals » de Cosmo Myzrail Gorynych | CC0 | 128x64, quatre directions |
| Loup | « Tiny Wolves Pack » de Games-by-Jorel | gratuit | un seul fichier |
| Loup (variante) | « pixel wolf » (OpenGameArt) | CC0 | |
| Loup animé | loup d'Elthen | payant (environ 3 $) | 64x64, idle / marche / morsure / hurlement |
| Chien | « German Shepherd » (OpenGameArt) | CC0 | marche, course, aboiement |
| Mouton riggé | pack « animated sheep » de gamedeveloperstudio | payant (environ 3 £) | fichier Spriter, utile pour des animations plus fluides |

## Limites à garder en tête

- La plupart de ces packs sont en pixel art, de côté ou vus de dessus. Ils ne sont pas tous
  isométriques et n'ont pas quatre directions. Mélanger les styles se voit vite : mieux vaut
  prendre un seul pack cohérent (Kenney pour le décor, un seul auteur pour les animaux)??
  À voir quelle direction je prends pour la DA, car aucun ne me convient, et je ne souhaite pas acheter de packs pour le moment. 

- La direction artistique visée est du flat pastel mignon. (voir inspirations). Un pack pixel art demandera soit de changer de style pour le reste, soit de redessiner les sprites.
- Des outils comme Aseprite (sprites), Tiled ou LDtk (cartes) peuvent compléter la chaîne, mais ne sont pas nécessaires au projet actuel.

## Intégrer un pack (mémo pour plus tard)

1. Copier les images dans `assets/<pack>/` et garder le fichier de licence à côté.
2. Dans `entities/`, remplacer le `_draw()` de l'entité par un `AnimatedSprite2D` alimenté
   par un `SpriteFrames` (animations `idle`, `walk`, `eat`).
3. Ajouter une ligne au tableau ci-dessus avec la source et la licence réellement utilisées.

# Idées pour la suite du projet

## Phase 1:
[x] drag & drop des moutons et retirer le déplacement au clic. Permet de gérer les moutons qui s'égarent, s'échapent, et de placer comme on veut les moutons dans les enclos. 

[ ] Mise en pause du jeu (pratique pour la nuit, ou les loups peuvent attaquer)

[] Enlever la limite de laines possibles, et revoir le système de vente de laine. 

[] nourrir et entretenir les chiens + ajouter des blessures possibles sur les chiens (par pourcentage ou après un certain nb de rencontres ?), entrainant l'appel du vétérinaire pour le soigner. 

[] Rajouter une limite de moutons par enclos et une notion de bien être lié à l'entourage (mouton tout seul ou dans un enclos trop bondé = pas heureux = ne produira plus de ressources)

[]Pouvoir nommer les moutons et au passage de la souris, voir leur noms (permet un meilleur suivi des animaux)

[] empêcher le drag & drop des moutons qui n'appartiennent pas au troupeau. 

## Phase 2:

[] Faire les couleurs de laines différentes, les motifs de laine, et les races différentes

[] faire des accessoires pour moutons et pour chiens, avec bonus et propriétés particulières (par exemple chasser les loups, ou fait fleurir le champ, ou produit *2 de laine en plus, etc)

[] faire propriétés sur les décorations qui s'activent quand elles sont dans un enclos
surveiller la commutativité des bonus

[] stand de vente de laine avec création du camion

[] ajouter un marchant louche (1 chance sur 3 d'avoir un super mouton avec un élément jamais débloqué, et le reste on obtient un peu de laine ou une décoration simple). 

[] ajouter un choix dans les enclos et barrières (montagne, herbe basse, herbe haute, champ de fleurs, champ de blé)

[] ajouter les pièges anti loups. 

## Phase 3:

[] Agrandir la map

[] étendre le filtre de nuit au delà du territoire exploitable

[] pendant la nuit, permettre rarement des pluies d'étoiles filantes, qui font tomber de la poussière d'étoile. En drag & drop, on peut la soupoudrer sur un mouton, ce qui lui donne un skin bleu à paillettes.

[] créer l'abre généalogique

[] En cliquant sur un mouton on peut ouvrir sa fiche avec son historique, son arbre généalogique, et changer ses skins (par exemple etoiles filantes).

[] Ajouter les moutons dorés, qui sont des moutons qui distribuent de la laine extrêmement chère. Dispoonible une fois qu'on a découvert toutes les couleurs de laines d'un mouton, on a le mouton doré de sa race. 
