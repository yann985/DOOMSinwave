# Crée deux raccourcis sur le bureau :
#   « Sinwave - Travailler » : ouvre VS Code, Doom Builder, SLADE et Claude (tools\workspace.ps1)
#   « Sinwave - Jouer »      : compile et lance le jeu (tools\play.ps1)
#   powershell -ExecutionPolicy Bypass -File tools\create-shortcuts.ps1

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

$desktop = [Environment]::GetFolderPath("Desktop")
$shell = New-Object -ComObject WScript.Shell
$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

function New-Shortcut([string]$Name, [string]$Script, [string]$Icon, [string]$Description)
{
	$path = Join-Path $desktop "$Name.lnk"
	$link = $shell.CreateShortcut($path)
	$link.TargetPath = $powershell
	$link.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $PSScriptRoot $Script)`""
	$link.WorkingDirectory = $RepoRoot
	$link.WindowStyle = 7	# réduit : pas de fenêtre de console visible
	$link.Description = $Description
	if ($Icon -and (Test-Path $Icon)) { $link.IconLocation = "$Icon,0" }
	$link.Save()
	"Raccourci créé : $path"
}

$codeIcon = Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\Code.exe"
New-Shortcut "Sinwave - Travailler" "workspace.ps1" $codeIcon "Ouvre VS Code, Ultimate Doom Builder, SLADE et Claude sur le projet Sinwave"
New-Shortcut "Sinwave - Jouer" "play.ps1" $Engines.gzdoom "Compile et lance Sinwave dans GZDoom"
