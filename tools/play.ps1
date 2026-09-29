# Construit la dernière version du code puis lance le jeu.
# Lancé par le raccourci « Sinwave - Jouer » du bureau (tools\create-shortcuts.ps1).
# Une erreur de ZScript est affichée par GZDoom lui-même, avec le fichier et la ligne.

$ErrorActionPreference = "Stop"

try
{
	& (Join-Path $PSScriptRoot "run.ps1") | Out-Null
}
catch
{
	Add-Type -AssemblyName System.Windows.Forms
	[void][System.Windows.Forms.MessageBox]::Show("Impossible de lancer le jeu :`n$($_.Exception.Message)", "Sinwave", "OK", "Error")
}
