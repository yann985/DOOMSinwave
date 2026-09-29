# Sinwave

Survivors-like sur le thème des sept péchés capitaux, écrit en **ZScript** pour le moteur **GZDoom**.
Prototype du projet Aegis (B3 Workshop 1) : l'accent est mis sur l'architecture (machine à états, bus d'événements, services, données externes, méta-progression).

- **Architecture expliquée : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**
- **Créer une arène : [docs/CREER-UNE-ARENE.md](docs/CREER-UNE-ARENE.md)**

## Jouer

1. Choisis une arène : **Le Purgatoire** (7 cercles puis le boss Lucifer, environ 3 minutes) ou **Les Limbes** (3 cercles, plus dur et mieux payé). Règle ensuite la descente : difficulté prédéfinie ou défi personnalisé (vie, vitesse et rythme des ennemis, dégâts subis), et cercle de départ. Plus c'est dur, plus ça rapporte.
2. Chaque cercle est un péché et impose sa **malédiction**. Exemples : l'Avarice fait disparaître les orbes, la Colère fait enrager les ennemis blessés. Un cercle enchaîne plusieurs **vagues**, chacune plus dure que la précédente, avant de passer au cercle suivant.
3. Une marque rouge autour du viseur t'avertit quand un ennemi hors de ta vue prépare une attaque ou qu'un projectile arrive dans ton dos, avant qu'il ne te touche.
4. Ramasse les orbes bleues d'expérience. À chaque niveau, choisis entre deux **vertus** et un **péché**, plus puissant mais avec un défaut.
5. Tes choix font pencher la **balance de l'âme** (corruption de 0 à 30, départ à 15, l'équilibre) : les péchés la font monter, les vertus descendre. Plus elle penche, plus la partie change :
   - vers le péché : plus de munitions et moins de soins, jusqu'aux **munitions infinies** ;
   - vers la vertu : l'inverse, jusqu'à l'**aura sainte** ;
   - la pente est glissante : une âme qui penche se voit proposer plus de choix de son côté ;
   - reste 20 secondes au bout de la balance : ton **reflet damné** surgit (un mini-boss qui rapporte beaucoup d'XP), ou un **ange** vient te soigner ;
   - Lucifer suit ton âme : plus elle est pure, plus il est fort mais seul ; plus elle est corrompue, plus il est faible mais entouré.

   En fin de run : **Absolution**, **Purgatoire** ou **Damnation**.
6. Les **indulgences** gagnées s'achètent entre les runs, à la **boutique** : des armes de départ et des améliorations permanentes.

Le jeu se joue entièrement au clavier et à la souris, ou à la manette (activée automatiquement par les lanceurs).

| Action | Clavier | Souris | Manette |
|---|---|---|---|
| Se déplacer, viser, tirer | touches de GZDoom | viser, clic pour tirer | stick gauche, stick droit, gâchette droite |
| Choisir l'arène, recommencer après le bilan | Utiliser (E) | | A |
| Boutique des indulgences (écran titre ou écran de fin) | B | | B |
| Pause de la run | P | | Start |
| Choisir dans un menu | flèches + Entrée, ou 1 à 9 | survol + clic, molette | croix ou stick gauche + A |
| Régler une valeur (règles de la descente) | Gauche / Droite | clic sur `<` ou `>` | croix gauche / droite |
| Revenir en arrière | Échap | clic droit ou bouton *Retour* | B |

Les touches B et P se changent dans *Options → Commandes → Sinwave*. Tant qu'elles ne servent à rien d'autre, B et P marchent toujours, même si leur liaison a disparu de la configuration de GZDoom. Hors d'une run, Start ouvre le menu de GZDoom (options, quitter).

## Démarrage rapide (développement)

1. Installer les outils (moteurs, IWAD libre, éditeurs) :

   ```bash
   powershell -ExecutionPolicy Bypass -File tools\setup.ps1
   ```

2. Ouvrir le dossier dans VS Code (accepter les extensions recommandées).
3. **Ctrl+Maj+B** : construit le `.pk3` et vérifie que le ZScript compile. Les erreurs s'affichent dans l'onglet *Problèmes*.
4. *Terminal → Exécuter la tâche → « Sinwave : jouer (GZDoom) »*.

## Outils

| Outil | Rôle | Emplacement |
|---|---|---|
| GZDoom 4.14.2 | Moteur de référence du projet (version figée) | `..\DoomTools\gzdoom` |
| UZDoom 5.0.3 | Fork de GZDoom, pour vérifier la compatibilité | `..\DoomTools\uzdoom` |
| Freedoom 0.13.0 | IWAD libre (données de base), livré avec le build | `..\DoomTools\iwads` |
| Ultimate Doom Builder | Éditeur de maps (UDMF) | `..\DoomTools\UltimateDoomBuilder` |
| SLADE 3 | Édition des ressources du `.pk3` | menu Démarrer |
| VS Code + GZDoom ZScript | Édition du code | menu Démarrer |
| GIMP, Audacity | Sprites et sons | menu Démarrer |

Le dossier des outils peut être déplacé avec la variable d'environnement `SINWAVE_TOOLS`.
Pour tester avec un vrai `doom2.wad` (version achetée), définir `SINWAVE_IWAD` vers ce fichier. Le build rendu utilise toujours Freedoom, seul IWAD redistribuable.

## Arborescence

```
src/                     contenu du jeu -> build/sinwave.pk3
  zscript/app/           racine de composition (seul point d'entrée du moteur)
  zscript/core/          bus d'événements, Service Locator, machine à états, lecteur de données
  zscript/data/          définitions chargées depuis data/, sauvegarde
  zscript/gameplay/      événements, états, systèmes, malédictions, acteurs
  zscript/ui/            modèle, présentateur, HUD, menus
  data/                  contenu : arènes, cercles, ennemis, malédictions, vertus et péchés, boutique
  maps/                  SW01 Les Limbes, SW02 Le Purgatoire (tools/generate-arena.ps1)
tests/smoke/             archive de test chargée par-dessus le jeu + tests unitaires
tools/                   build, lancement, tests, packaging
docs/                    documentation (architecture)
.github/workflows/       build automatique sur GitHub
```

## Scripts

Tous se lancent avec `powershell -ExecutionPolicy Bypass -File tools\<script>.ps1`, ou depuis les tâches VS Code.

| Script | Rôle |
|---|---|
| `setup.ps1` | Installe tous les outils (versions figées dans `config.ps1`) |
| `build.ps1` | Construit `build\sinwave.pk3` à partir de `src\` |
| `check.ps1` | Construit puis vérifie que le ZScript compile dans GZDoom |
| `test.ps1` | Tests automatiques : joue des runs complètes et vérifie chaque étape (ne pas toucher au clavier) |
| `run.ps1` | Construit puis lance le jeu (`-Map SW02` pour aller directement au Purgatoire, `-Engine uzdoom`) |
| `package.ps1` | Crée le build Windows à rendre : `dist\Sinwave-win64.zip` |
| `new-arena.ps1` | Crée une arène personnalisée : carte, cercles et réglages (voir docs/CREER-UNE-ARENE.md) |
| `generate-arena.ps1` | Génère une carte (`-Shape Circles` ou `Square`) ; écrase les retouches faites dans Doom Builder |
| `create-shortcuts.ps1` | Crée sur le bureau les raccourcis « Sinwave - Travailler » et « Sinwave - Jouer » |
| `workspace.ps1` | Ouvre VS Code, Ultimate Doom Builder (sur l'arène), SLADE et Claude |
| `play.ps1` | Construit le code et lance le jeu |

Dans le jeu, `sinwave_debug 1` (console, touche `²`) affiche chaque événement du bus.

## Conventions

- Classes ZScript préfixées par `Sinwave_` (ZScript n'a pas d'espaces de noms).
- La branche `main` reste toujours jouable ; les nouveautés se font sur une branche (`feat/event-bus`, `fix/xp-orbes`…) puis sont fusionnées.
- Messages de commit : `type(couche): description`, par exemple `feat(core): ajoute le bus d'événements`.
  Types : `feat`, `fix`, `refactor`, `data`, `ui`, `docs`, `build`, `chore`.
- Une version se publie avec un tag : `git tag v0.1.0` puis `git push --tags`. GitHub construit alors le build Windows et le met dans *Releases*.

## Licences

- GZDoom : GPL v3 (<https://zdoom.org>)
- Freedoom : BSD modifiée (<https://freedoom.github.io>)
