# Sinwave

Survivors-like sur le thème des sept péchés capitaux, écrit en **ZScript** pour le moteur **GZDoom**.
Prototype du projet Aegis (B3 Workshop 1) : l'accent est mis sur l'architecture (machine à états, bus d'événements, services, données externes, méta-progression).

- **Architecture expliquée : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**
- **Créer une arène : [docs/CREER-UNE-ARENE.md](docs/CREER-UNE-ARENE.md)**

## Jouer

1. Choisis une arène : **Le Purgatoire** (7 cercles puis le boss Lucifer, environ 3 minutes) ou **Les Limbes** (3 cercles, plus dur et mieux payé). Règle ensuite la descente : difficulté prédéfinie ou défi personnalisé (vie, vitesse et rythme des ennemis, dégâts subis), et cercle de départ. Plus c'est dur, plus ça rapporte.
2. Chaque cercle est un péché et impose sa **malédiction**. Exemples : l'Avarice fait disparaître les orbes, la Colère fait enrager les ennemis blessés.
3. Ramasse les orbes bleues d'expérience. À chaque niveau, choisis entre deux **vertus** et un **péché**, plus puissant mais avec un défaut.
4. Les péchés remplissent ta **corruption** ; au seuil, la run finit en **Damnation** plutôt qu'en **Absolution**.
5. Les **indulgences** gagnées s'achètent entre les runs, à la **boutique** : des armes de départ et des améliorations permanentes.

| Touche | Action |
|---|---|
| Utiliser (E / Espace) | Choisir l'arène et lancer la run, recommencer après le bilan |
| B | Boutique des indulgences (écran titre ou écran de fin) |
| P | Pause de la run |
| 1 à 9 ou flèches + Entrée | Choisir dans les menus |
| Gauche / Droite | Régler une valeur (règles de la descente) |

Les touches B et P se changent dans *Options → Commandes → Sinwave*.

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
