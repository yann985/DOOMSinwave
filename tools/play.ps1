# Construit la dernière version du code puis lance le jeu.
# Lancé par les raccourcis « Sinwave - Jouer (Freedoom) » et « Sinwave - Jouer (Doom II) »
# du bureau (tools\create-shortcuts.ps1).
# Une erreur de ZScript est affichée par GZDoom lui-même, avec le fichier et la ligne.
#   -Iwad doom2 : avec le vrai Doom II (GOG, Steam) au lieu de Freedoom.

param([string]$Iwad)

$ErrorActionPreference = "Stop"

try
{
	& (Join-Path $PSScriptRoot "run.ps1") -Iwad $Iwad | Out-Null
}
catch
{
	Add-Type -AssemblyName System.Windows.Forms
	[void][System.Windows.Forms.MessageBox]::Show("Impossible de lancer le jeu :`n$($_.Exception.Message)", "Sinwave", "OK", "Error")
}
