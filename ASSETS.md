# Assets

Pour l'instant, **tout est dessiné en code** (`_draw()` : moutons, loups, berger, chiens,
bâtiments, interface). C'était un choix volontaire : le jeu tourne sans aucun fichier
externe et chaque entité a une silhouette lisible dès le premier lancement. Le jour où
de vrais sprites sont branchés, seules les méthodes `_draw()` des entités sont à remplacer
par un `AnimatedSprite2D`.

## Packs gratuits repérés

À vérifier à chaque fois : la licence exacte est celle affichée sur la page de téléchargement
le jour où on récupère le pack.

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
  prendre un seul pack cohérent (Kenney pour le décor, un seul auteur pour les animaux).
- La direction artistique visée est du flat pastel mignon. Un pack pixel art demandera soit
  de changer de style pour le reste, soit de redessiner les sprites.
- Des outils comme Aseprite (sprites), Tiled ou LDtk (cartes) peuvent compléter la chaîne,
  mais ne sont pas nécessaires au projet actuel.

## Intégrer un pack

1. Copier les images dans `assets/<pack>/` et garder le fichier de licence à côté.
2. Dans `entities/`, remplacer le `_draw()` de l'entité par un `AnimatedSprite2D` alimenté
   par un `SpriteFrames` (animations `idle`, `walk`, `eat`).
3. Ajouter une ligne au tableau ci-dessus avec la source et la licence réellement utilisées.
