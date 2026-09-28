# Sinwave

Survivors-like à vagues sur le thème des sept péchés capitaux, écrit en **ZScript** pour le moteur **GZDoom**.
Prototype du projet Aegis (B3 Workshop 1) : l'accent est mis sur l'architecture (machine à états, bus d'événements, services, données externes, méta-progression).

## Démarrage rapide

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
src/                   contenu du jeu -> build/sinwave.pk3
  zscript/core/        état global, bus d'événements, services
  zscript/gameplay/    ennemis, vagues, XP, améliorations
  zscript/ui/          menus, HUD
  data/                vagues, types d'ennemis, améliorations (données externes)
  maps/ sprites/ sounds/ graphics/
tools/                 scripts de build, lancement, vérification, packaging
docs/                  document de rendu
.github/workflows/     build automatique sur GitHub
```

## Scripts

Tous se lancent avec `powershell -ExecutionPolicy Bypass -File tools\<script>.ps1`, ou depuis les tâches VS Code.

| Script | Rôle |
|---|---|
| `setup.ps1` | Installe tous les outils (versions figées dans `config.ps1`) |
| `build.ps1` | Construit `build\sinwave.pk3` à partir de `src\` |
| `check.ps1` | Construit puis vérifie que le ZScript compile dans GZDoom |
| `run.ps1` | Construit puis lance le jeu (`-Map MAP01`, `-Engine uzdoom`) |
| `package.ps1` | Crée le build Windows à rendre : `dist\Sinwave-win64.zip` |

## Conventions

- Classes ZScript préfixées par `Sinwave_` (ZScript n'a pas d'espaces de noms).
- La branche `main` reste toujours jouable ; les nouveautés se font sur une branche (`feat/event-bus`, `fix/xp-orbes`…) puis sont fusionnées.
- Messages de commit : `type(couche): description`, par exemple `feat(core): ajoute le bus d'événements`.
  Types : `feat`, `fix`, `refactor`, `data`, `ui`, `docs`, `build`, `chore`.
- Une version se publie avec un tag : `git tag v0.1.0` puis `git push --tags`. GitHub construit alors le build Windows et le met dans *Releases*.

## Licences

- GZDoom : GPL v3 (<https://zdoom.org>)
- Freedoom : BSD modifiée (<https://freedoom.github.io>)
