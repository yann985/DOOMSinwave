# Construit le .pk3 puis lance le jeu.
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1                  -> GZDoom, Freedoom, menu titre
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1 -Iwad doom2      -> avec le vrai Doom II (GOG, Steam)
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1 -Map MAP01       -> directement sur une map
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1 -Engine uzdoom   -> avec UZDoom

param(
	[ValidateSet("gzdoom", "uzdoom")] [string]$Engine = "gzdoom",
	[string]$Iwad,		# freedoom, doom2, ou le chemin d'un .wad (par défaut : Freedoom)
	[string]$Map,
	[ValidateRange(1, 5)] [int]$Skill = 3,
	[switch]$NoBuild,
	[string[]]$Extra = @()
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")
if ($Iwad) { $IwadPath = Resolve-Iwad $Iwad }

# Hors Freedoom, archive et journal à part (ex. sinwave-doom2.pk3) : un jeu ouvert verrouille
# son archive, et les deux versions peuvent ainsi tourner en même temps.
$suffix = ""
if ($IwadPath -ne $FreedoomIwad) { $suffix = "-" + [IO.Path]::GetFileNameWithoutExtension($IwadPath).ToLower() }
$Pk3Path = Join-Path $BuildDir "$PackageName$suffix.pk3"

if (-not $NoBuild) { & (Join-Path $PSScriptRoot "build.ps1") -Output $Pk3Path }

$exe = Get-EnginePath $Engine
Assert-Iwad

# use_joystick : la manette est désactivée par défaut dans GZDoom ; Sinwave se joue aussi avec.
$engineArgs = @("-iwad", "`"$IwadPath`"", "-file", "`"$Pk3Path`"", "+logfile", "`"$(Join-Path $BuildDir "$Engine$suffix.log")`"", "+use_joystick", "1")
if ($Map) { $engineArgs += @("+map", $Map, "-skill", $Skill) }
$engineArgs += $Extra

"Lancement : $exe $($engineArgs -join ' ')"
Start-Process $exe -ArgumentList $engineArgs -WorkingDirectory (Split-Path $exe)
