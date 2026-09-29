# Créer une arène personnalisée

Une arène est une carte avec ses cercles (vagues) et ses règles. Elle apparaît dans le choix d'arène du jeu. Il n'y a **pas de code à écrire** : tout se fait avec Ultimate Doom Builder et des fichiers texte.

## 1. Créer les fichiers de départ

```bash
powershell -ExecutionPolicy Bypass -File tools\new-arena.ps1 -Id enfer -Name "L'Enfer" -Shape Circles
```

- `-Id` : identifiant court, en minuscules, sans espace.
- `-Name` : nom affiché dans le jeu.
- `-Shape` : forme de la carte de départ, `Circles` (cercles concentriques) ou `Square` (salle carrée).

Le script crée :
- la carte `src/maps/SW03.wad` (le numéro suit les cartes existantes) ;
- le fichier de cercles `src/data/waves/enfer.txt` ;
- l'entrée `[arena enfer]` dans `src/data/arenas.txt` ;
- la déclaration de la carte dans `src/MAPINFO.txt`.

L'arène est jouable tout de suite : lance le jeu, appuie sur Utiliser au menu et choisis-la.

## 2. Dessiner la carte

Ouvre la carte dans Ultimate Doom Builder (*File → Open Map*, configuration **GZDoom: Doom 2 (UDMF)**, ressources `freedoom2.wad` et `build/sinwave.pk3`). Le raccourci « Sinwave - Travailler » ouvre directement le Purgatoire avec ces réglages.

- Garde un **départ du joueur** (Player 1 Start).
- Place des **points d'apparition** des ennemis : catégorie *Sinwave*, « Point d'apparition des ennemis » (numéro 30001). Mets-les loin du centre : les ennemis n'apparaissent jamais à moins de 384 unités du joueur.
- Sans aucun point d'apparition, les ennemis apparaissent en cercle autour du joueur.
- Les marches ne doivent pas dépasser 24 unités de haut, sinon le joueur ne peut pas les monter.

Enregistre (Ctrl+S). Attention : relancer `new-arena.ps1` ou `generate-arena.ps1` sur la même carte l'écrase.

## 3. Écrire les cercles

Dans `src/data/waves/<id>.txt`, un bloc par cercle, joué dans l'ordre du fichier :

```ini
[wave 1]
name     = Premier cercle
duration = 30              # secondes (0 : jusqu'à la mort du boss)
interval = 1.0             # secondes entre deux apparitions
max      = 15              # ennemis vivants en même temps, au maximum
break    = 4               # répit avant le cercle suivant
curse    = sloth           # malédiction du cercle (data/curses.txt)
enemies  = sloth:3, gluttony:1   # ennemis et poids du tirage (data/enemies.txt)
```

- Malédictions : `sloth`, `gluttony`, `lust`, `envy`, `greed`, `wrath`, `pride`.
- Ennemis : `sloth`, `gluttony`, `lust`, `envy`, `greed`, `wrath`, `pride`.
- Boss : `lucifer`.

Pour un cercle de boss : `duration = 0` et `boss = lucifer`. Le cercle se termine à la mort du boss.

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
```

## 5. Tester

- **Ctrl+Maj+B** dans VS Code : vérifie le code et les données.
- **Sinwave - Jouer** : lance le jeu ; choisis ton arène au menu.
- Dans la console du jeu (touche `²`), `sinwave_debug 1` affiche chaque événement : début des cercles, malédictions, boss...

Une faute de frappe dans un fichier de données (ennemi inconnu, malédiction mal écrite...) est signalée en rouge dans la console, avec le fichier et la ligne.

## Aller plus loin

- **Nouvel ennemi :** un bloc dans `data/enemies.txt` (n'importe quel monstre de Doom II).
- **Nouveau boss :** un ennemi avec `boss = true`, `rage_at`, `rage_speed`, `rage_summon`.
- **Nouvelle malédiction :** une classe ZScript qui hérite de `Sinwave_Curse` (voir `src/zscript/gameplay/curses/`), puis un bloc dans `data/curses.txt`. C'est le seul cas qui demande du code.
