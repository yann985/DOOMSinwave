# Crée les raccourcis du bureau :
#   « Sinwave - Travailler »         : ouvre VS Code, Doom Builder, SLADE et Claude (tools\workspace.ps1)
#   « Sinwave - Jouer (Freedoom) »   : compile et lance le jeu avec Freedoom (tools\play.ps1)
#   « Sinwave - Jouer (Doom II) »    : pareil avec le vrai Doom II, s'il est installé (GOG, Steam)
#   powershell -ExecutionPolicy Bypass -File tools\create-shortcuts.ps1

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

$desktop = [Environment]::GetFolderPath("Desktop")
$shell = New-Object -ComObject WScript.Shell
$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

function New-Shortcut([string]$Name, [string]$Script, [string]$ScriptArgs, [string]$Icon, [string]$Description)
{
	$path = Join-Path $desktop "$Name.lnk"
	$link = $shell.CreateShortcut($path)
	$link.TargetPath = $powershell
	$link.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $PSScriptRoot $Script)`" $ScriptArgs".TrimEnd()
	$link.WorkingDirectory = $RepoRoot
	$link.WindowStyle = 7	# réduit : pas de fenêtre de console visible
	$link.Description = $Description
	if ($Icon -and (Test-Path $Icon)) { $link.IconLocation = "$Icon,0" }
	$link.Save()
	"Raccourci créé : $path"
}

$codeIcon = Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\Code.exe"
New-Shortcut "Sinwave - Travailler" "workspace.ps1" "" $codeIcon "Ouvre VS Code, Ultimate Doom Builder, SLADE et Claude sur le projet Sinwave"
New-Shortcut "Sinwave - Jouer (Freedoom)" "play.ps1" "" $Engines.gzdoom "Compile et lance Sinwave dans GZDoom, avec Freedoom"

# La version Doom II prend l'icône du jeu GOG quand il y en a une.
$doom2 = Find-Doom2Iwad
$doom2Icon = $Engines.gzdoom
if ($doom2)
{
	# L'icône est à la racine de l'installation GOG, quelques dossiers au-dessus du .wad.
	for ($dir = Split-Path $doom2; $dir; $dir = Split-Path $dir)
	{
		$ico = Get-ChildItem $dir -Filter "goggame-*.ico" -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($ico) { $doom2Icon = $ico.FullName; break }
	}
}
else
{
	"Doom II introuvable pour l'instant : le raccourci Doom II le dira au lancement."
}
New-Shortcut "Sinwave - Jouer (Doom II)" "play.ps1" "-Iwad doom2" $doom2Icon "Compile et lance Sinwave dans GZDoom, avec le vrai Doom II"

# L'ancien raccourci « Sinwave - Jouer » est remplacé par « Sinwave - Jouer (Freedoom) ».
$old = Join-Path $desktop "Sinwave - Jouer.lnk"
if ((Test-Path $old) -and $shell.CreateShortcut($old).Arguments -match [regex]::Escape((Join-Path $PSScriptRoot "play.ps1")))
{
	Remove-Item $old
	"Ancien raccourci remplacé : $old"
}
