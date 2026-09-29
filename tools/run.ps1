# Construit le .pk3 puis lance le jeu.
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1                  -> GZDoom, menu titre
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1 -Map MAP01       -> directement sur une map
#   powershell -ExecutionPolicy Bypass -File tools\run.ps1 -Engine uzdoom   -> avec UZDoom

param(
	[ValidateSet("gzdoom", "uzdoom")] [string]$Engine = "gzdoom",
	[string]$Map,
	[ValidateRange(1, 5)] [int]$Skill = 3,
	[switch]$NoBuild,
	[string[]]$Extra = @()
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

if (-not $NoBuild) { & (Join-Path $PSScriptRoot "build.ps1") }

$exe = Get-EnginePath $Engine
Assert-Iwad

# use_joystick : la manette est désactivée par défaut dans GZDoom ; Sinwave se joue aussi avec.
$engineArgs = @("-iwad", "`"$IwadPath`"", "-file", "`"$Pk3Path`"", "+logfile", "`"$(Join-Path $BuildDir "$Engine.log")`"", "+use_joystick", "1")
if ($Map) { $engineArgs += @("+map", $Map, "-skill", $Skill) }
$engineArgs += $Extra

"Lancement : $exe $($engineArgs -join ' ')"
Start-Process $exe -ArgumentList $engineArgs -WorkingDirectory (Split-Path $exe)
