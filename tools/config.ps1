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
# IWAD : Freedoom par défaut (libre et redistribuable, c'est lui qui est livré dans le build).
# Le vrai Doom II se choisit avec -Iwad doom2 (run.ps1, play.ps1, test.ps1) ; SINWAVE_IWAD
# remplace l'IWAD par défaut de tous les scripts.
$FreedoomIwad = Join-Path $ToolsDir "iwads\freedoom2.wad"
$IwadPath = if ($env:SINWAVE_IWAD) { $env:SINWAVE_IWAD } else { $FreedoomIwad }

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

# Le vrai Doom II (commercial : jamais livré dans le build). Cherché, dans l'ordre :
# SINWAVE_DOOM2 (chemin d'un doom2.wad), DoomTools\iwads\doom2.wad, puis les
# installations GOG et Steam. La version DOS d'origine passe avant les rééditions.
function Find-Doom2Iwad
{
	$candidates = @($env:SINWAVE_DOOM2, [IO.Path]::Combine($ToolsDir, "iwads\doom2.wad"))

	# GOG : DOOM II, DOOM + DOOM II (2024), DOOM II Enhanced (Unity).
	$gogGames = @(
		@("1435848814", "doom2\DOOM2.WAD"),
		@("1413291984", "dosdoom\base\doom2\DOOM2.WAD"),
		@("1413291984", "doom2.wad"),
		@("1426071866", "DOOM II_Data\StreamingAssets\doom2.wad")
	)
	# (Path.Combine plutôt que Join-Path : un disque absent, ex. E: débranché, ne doit pas faire d'erreur.)
	foreach ($game in $gogGames)
	{
		foreach ($root in "HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games", "HKLM:\SOFTWARE\GOG.com\Games")
		{
			$install = (Get-ItemProperty (Join-Path $root $game[0]) -ErrorAction SilentlyContinue).path
			if ($install) { $candidates += [IO.Path]::Combine($install, $game[1]) }
		}
	}

	# Steam : DOOM II, puis DOOM + DOOM II, dans chaque bibliothèque.
	$steam = Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
	if ($steam -and $steam.SteamPath)
	{
		$libraries = @($steam.SteamPath)
		$vdf = [IO.Path]::Combine($steam.SteamPath, "steamapps\libraryfolders.vdf")
		if (Test-Path $vdf)
		{
			$libraries += [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' }
		}
		foreach ($library in $libraries)
		{
			$candidates += [IO.Path]::Combine($library, "steamapps\common\Doom 2\base\DOOM2.WAD")
			$candidates += [IO.Path]::Combine($library, "steamapps\common\Ultimate Doom\rerelease\doom2.wad")
		}
	}

	foreach ($candidate in $candidates)
	{
		if ($candidate -and (Test-Path $candidate)) { return (Resolve-Path $candidate).Path }
	}
	return $null
}

# IWAD à partir d'un nom : freedoom, doom2, ou le chemin d'un fichier .wad.
function Resolve-Iwad([string]$Name)
{
	switch ($Name)
	{
		"freedoom" { return $FreedoomIwad }
		"doom2"
		{
			$found = Find-Doom2Iwad
			if (-not $found) { throw "Doom II introuvable. Installe DOOM II (GOG ou Steam), ou copie doom2.wad dans $(Join-Path $ToolsDir 'iwads')." }
			return $found
		}
		default { return $Name }
	}
}
