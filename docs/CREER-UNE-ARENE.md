# Créer une arène personnalisée

Une arène est une carte avec ses cercles, de plusieurs vagues chacun, et ses règles. Elle apparaît dans le choix d'arène du jeu. Il n'y a **pas de code à écrire** : tout se fait avec Ultimate Doom Builder et des fichiers texte.

## 1. Créer les fichiers de départ

```bash
powershell -ExecutionPolicy Bypass -File tools\new-arena.ps1 -Id enfer -Name "L'Enfer" -Shape Funnel
```

- `-Id` : identifiant court, en minuscules, sans espace.
- `-Name` : nom affiché dans le jeu.
- `-Shape` : plan de la carte de départ, le même que l'une des deux arènes du jeu :
  - `Funnel` : l'entonnoir de l'Enfer du Purgatoire (terrasses, aiguilles de roche, tombeaux, fleuve de sang, lac gelé) ;
  - `Castle` : le château des Limbes (champ, fossé, rempart à sept portes, prairie).

  Les anciens noms `Circles` et `Square` marchent encore.

Le script crée :
- la carte `src/maps/SW03.wad` (le numéro suit les cartes existantes) ;
- le fichier de cercles `src/data/waves/enfer.txt` ;
- l'entrée `[arena enfer]` dans `src/data/arenas.txt` ;
- la déclaration de la carte dans `src/MAPINFO.txt`.

L'arène est jouable tout de suite : lance le jeu, appuie sur Utiliser au menu et choisis-la.

## 2. Dessiner la carte

Ouvre la carte dans Ultimate Doom Builder (*File → Open Map*, configuration **GZDoom: Doom 2 (UDMF)**, ressources `freedoom2.wad` et `build/sinwave.pk3`). Le raccourci « Sinwave - Travailler » ouvre directement le Purgatoire avec ces réglages.

- Garde un **départ du joueur** (Player 1 Start).
- Par défaut, les ennemis apparaissent **autour du joueur**, juste hors de portée (clé `spawn = player`, voir plus bas).
- Tu peux aussi placer des **points d'apparition** : catégorie *Sinwave*, « Point d'apparition des ennemis » (numéro 30001). Ils servent de secours quand la place manque autour du joueur, ou de seule source avec `spawn = points`. Mets-les loin du centre : ils ne servent jamais à moins de 384 unités du joueur.
- Les marches ne doivent pas dépasser 24 unités de haut, sinon le joueur ne peut pas les monter, et les monstres ne savent ni les monter ni les descendre.
- Un obstacle plein (rocher, pilier) se dessine comme un trou dans la carte. Un bloc bas (tombeau, rempart) peut être un secteur plus haut : aucun ennemi n'apparaît sur un plateau plus haut d'une marche que tout ce qui l'entoure.
- Pour que la horde soit agréable à combattre : des boucles autour des obstacles pour la faire tourner en rond, pas de cul-de-sac, des obstacles qui coupent les tirs, et des passages plus étroits où elle se tasse. Les deux arènes du jeu suivent ces règles (voir `tools/generate-arena.ps1`).

Enregistre (Ctrl+S). Attention : relancer `new-arena.ps1` ou `generate-arena.ps1` sur la même carte l'écrase.

## 3. Écrire les cercles

Dans `src/data/waves/<id>.txt`, un bloc par cercle, joué dans l'ordre du fichier. Chaque cercle enchaîne plusieurs **vagues**, séparées par un court répit, puis on passe au cercle suivant :

```ini
[circle 1]
name     = Premier cercle
curse    = sloth           # malédiction de tout le cercle (data/curses.txt)
waves    = 3               # nombre de vagues du cercle
duration = 20              # durée d'une vague, en secondes
pause    = 3               # répit entre deux vagues du cercle
break    = 5               # répit avant le cercle suivant
interval = 1.1             # secondes entre deux apparitions, à la 1re vague
max      = 10              # ennemis vivants en même temps, à la 1re vague
enemies  = sloth:3, gluttony:1   # ennemis et poids du tirage (data/enemies.txt)
```

- Malédictions : `sloth`, `gluttony`, `lust`, `envy`, `greed`, `wrath`, `pride`.
- Ennemis : `sloth`, `gluttony`, `lust`, `envy`, `greed`, `wrath`, `pride`.
- Boss : `lucifer`.

**Difficulté croissante :** `interval` et `max` sont ceux de la première vague. Chaque vague suivante du cercle fait apparaître les ennemis plus vite et en autorise davantage, et la vie des ennemis augmente d'une vague à l'autre sur toute l'arène. Ces montées se règlent dans `src/data/progression.txt` (`wave_spawn_growth`, `wave_max_growth`, `wave_health_growth`). Pour que la difficulté monte aussi d'un cercle à l'autre, donne aux cercles suivants un `interval` plus court, un `max` plus grand ou des ennemis plus forts.

**Durée :** vise au moins 5 minutes de vagues au total (nombre de vagues × `duration`, sur tous les cercles, sans compter la vague du boss). Le Purgatoire en a 6 (18 vagues de 20 s), les Limbes 5 min 15 (9 vagues de 35 s).

**Cercle de boss :** ajoute `boss = lucifer`. La dernière vague du cercle est celle du boss : elle dure jusqu'à sa mort. Avec `waves = 1`, le cercle n'a que la vague du boss.

## 4. Régler l'arène

Dans `src/data/arenas.txt` :

```ini
[arena enfer]
name         = L'Enfer
description  = Texte affiché dans le choix d'arène.
map          = SW03
waves        = data/waves/enfer.txt
enemy_health = 1.2     # vie des ennemis ×1,2
enemy_speed  = 1.1     # vitesse des ennemis ×1,1
spawn_rate   = 1.5     # apparitions 1,5 fois plus fréquentes
reward       = 1.5     # indulgences gagnées ×1,5
spawn        = player  # player : autour du joueur ; points : sur les points d'apparition
```

Choisis `spawn = points` pour une carte faite de couloirs ou de pièces : autour du joueur, un ennemi pourrait apparaître derrière un mur et rester coincé.

## 5. Tester

- **Ctrl+Maj+B** dans VS Code : vérifie le code et les données.
- **Sinwave - Jouer** : lance le jeu ; choisis ton arène au menu.
- Dans la console du jeu (touche `²`), `sinwave_debug 1` affiche chaque événement : début des cercles et des vagues, malédictions, boss...

Une faute de frappe dans un fichier de données (ennemi inconnu, malédiction mal écrite...) est signalée en rouge dans la console, avec le fichier et la ligne.

## Aller plus loin

- **Nouvel ennemi :** un bloc dans `data/enemies.txt` (n'importe quel monstre de Doom II).
- **Nouveau boss :** un ennemi avec `boss = true`, `rage_at`, `rage_speed`, `rage_summon`.
- **Nouvelle malédiction :** une classe ZScript qui hérite de `Sinwave_Curse` (voir `src/zscript/gameplay/curses/`), puis un bloc dans `data/curses.txt`. C'est le seul cas qui demande du code.
