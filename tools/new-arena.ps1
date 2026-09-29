# Crée une nouvelle arène jouable, prête à être modifiée :
#   - une carte de départ (src\maps\SWnn.wad), à retoucher dans Ultimate Doom Builder
#   - son fichier de cercles (src\data\waves\<id>.txt)
#   - son entrée dans data\arenas.txt (elle apparaît dans le choix d'arène)
#   - sa déclaration dans MAPINFO
#
#   powershell -ExecutionPolicy Bypass -File tools\new-arena.ps1 -Id enfer -Name "L'Enfer" -Shape Circles
#
# Voir docs\CREER-UNE-ARENE.md pour la suite.

param(
	[Parameter(Mandatory = $true)] [ValidatePattern('^[a-z][a-z0-9_]*$')] [string]$Id,
	[string]$Name,
	[string]$Map,
	[ValidateSet("Circles", "Square")] [string]$Shape = "Square"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

if (-not $Name) { $Name = $Id }
$arenas = Join-Path $SrcDir "data\arenas.txt"
$mapinfo = Join-Path $SrcDir "MAPINFO.txt"
$waves = Join-Path $SrcDir "data\waves\$Id.txt"
$utf8 = [Text.UTF8Encoding]::new($false)

if (Select-String -Path $arenas -Pattern "^\[arena $Id\]" -Quiet) { throw "L'arène « $Id » existe déjà dans data\arenas.txt." }
if (Test-Path $waves) { throw "Le fichier $waves existe déjà." }

# Première carte libre : SW03, SW04...
if (-not $Map)
{
	for ($n = 1; $n -lt 100; $n++)
	{
		$candidate = "SW{0:D2}" -f $n
		if (-not (Test-Path (Join-Path $SrcDir "maps\$candidate.wad"))) { $Map = $candidate; break }
	}
}
$Map = $Map.ToUpper()
if (Test-Path (Join-Path $SrcDir "maps\$Map.wad")) { throw "La carte $Map existe déjà." }

& (Join-Path $PSScriptRoot "generate-arena.ps1") -Map $Map -Shape $Shape

$wavesTemplate = @"
# $Name : cercles de l'arène, de plusieurs vagues chacun
# (voir data/waves/purgatoire.txt pour toutes les clés).
#   curse   : sloth, gluttony, lust, envy, greed, wrath, pride (data/curses.txt)
#   enemies : sloth, gluttony, lust, envy, greed, wrath, pride (data/enemies.txt)
#   boss    : lucifer (la dernière vague du cercle dure jusqu'à sa mort)

[circle 1]
name     = Premier cercle
curse    = sloth
waves    = 3
duration = 8
pause    = 2
break    = 4
interval = 1.1
max      = 10
enemies  = sloth:3, gluttony:1

[circle 2]
name     = Deuxième cercle
curse    = wrath
waves    = 3
duration = 8
pause    = 2
break    = 4
interval = 0.9
max      = 14
enemies  = wrath:2, lust:2

[circle 3]
name     = Dernier cercle
curse    = pride
waves    = 3
duration = 8
pause    = 2
break    = 0
interval = 1.6
max      = 7
boss     = lucifer
enemies  = greed:1, lust:1
"@
[IO.File]::WriteAllText($waves, $wavesTemplate.Replace("`r`n", "`n") + "`n", $utf8)

$arenaBlock = @"

[arena $Id]
name         = $Name
description  = Arène personnalisée.
map          = $Map
waves        = data/waves/$Id.txt
enemy_health = 1.0
enemy_speed  = 1.0
spawn_rate   = 1.0
reward       = 1.0
spawn        = player
"@
[IO.File]::AppendAllText($arenas, $arenaBlock.Replace("`r`n", "`n") + "`n", $utf8)

$mapBlock = @"

// Arène personnalisée créée par tools/new-arena.ps1.
map $Map "$Name"
{
	next = "$Map"
	sky1 = "SKY1"
	music = "D_DEAD"
	nointermission
	noinfighting
}
"@
[IO.File]::AppendAllText($mapinfo, $mapBlock.Replace("`r`n", "`n") + "`n", $utf8)

""
"Arène « $Name » créée :"
"  carte   : src\maps\$Map.wad (à retoucher dans Ultimate Doom Builder)"
"  cercles : src\data\waves\$Id.txt"
"  réglages: [arena $Id] dans src\data\arenas.txt"
"Lance le jeu : elle apparaît dans le choix d'arène (touche Utiliser au menu)."
