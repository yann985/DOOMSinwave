# Réglages partagés par tous les scripts de tools/.
# La version du moteur est figée ici pour que le build reste reproductible.

$GameName        = "Sinwave"
$PackageName     = "sinwave"

$GZDoomVersion   = "4.14.2"
$GZDoomUrl       = "https://github.com/ZDoom/gzdoom/releases/download/g4.14.2/gzdoom-4-14-2-windows.zip"
$UZDoomVersion   = "5.0.3"
$UZDoomUrl       = "https://github.com/UZDoom/UZDoom/releases/download/5.0.3/Windows-UZDoom-Release-x86_64.zip"
$FreedoomVersion = "0.13.0"
$FreedoomUrl     = "https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip"
$FreedoomSha256  = "3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59"
$DoomBuilderUrl  = "https://ultimatedoombuilder.github.io/files/UltimateDoomBuilder-Setup-latest-x64.exe"

$RepoRoot  = Split-Path $PSScriptRoot -Parent
$SrcDir    = Join-Path $RepoRoot "src"
$BuildDir  = Join-Path $RepoRoot "build"
$DistDir   = Join-Path $RepoRoot "dist"
$Pk3Path   = Join-Path $BuildDir "$PackageName.pk3"

# Dossier des outils (moteurs, IWAD, Doom Builder), partagé hors du dépôt.
# Par défaut : ..\DoomTools à côté du dépôt. Modifiable avec la variable d'environnement SINWAVE_TOOLS.
$ToolsDir = if ($env:SINWAVE_TOOLS) { $env:SINWAVE_TOOLS } else { Join-Path (Split-Path $RepoRoot -Parent) "DoomTools" }

$Engines = @{
	gzdoom = Join-Path $ToolsDir "gzdoom\gzdoom.exe"
	uzdoom = Join-Path $ToolsDir "uzdoom\uzdoom.exe"
}
# IWAD de test : Freedoom par défaut (libre et redistribuable, c'est lui qui est livré dans le build).
# Pour tester avec un vrai doom2.wad (ex : version GOG), définir SINWAVE_IWAD vers ce fichier.
$IwadPath = if ($env:SINWAVE_IWAD) { $env:SINWAVE_IWAD } else { Join-Path $ToolsDir "iwads\freedoom2.wad" }
$FreedoomIwad = Join-Path $ToolsDir "iwads\freedoom2.wad"

function Get-EnginePath([string]$Engine)
{
	$exe = $Engines[$Engine]
	if (-not $exe) { throw "Moteur inconnu '$Engine' (choix : $($Engines.Keys -join ', '))." }
	if (-not (Test-Path $exe)) { throw "Moteur introuvable : $exe. Lance tools\setup.ps1 d'abord." }
	return $exe
}

function Assert-Iwad
{
	if (-not (Test-Path $IwadPath)) { throw "IWAD introuvable : $IwadPath. Lance tools\setup.ps1 d'abord." }
}
