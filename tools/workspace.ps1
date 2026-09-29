# Ouvre tout l'environnement de travail de Sinwave :
#   - VS Code sur le dépôt (code, données, documentation)
#   - Ultimate Doom Builder sur le Purgatoire (SW02), avec Freedoom et le mod chargés
#   - SLADE sur le dossier src (ressources du .pk3)
#   - l'application Claude
# Lancé par le raccourci « Sinwave - Travailler » du bureau (tools\create-shortcuts.ps1).

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

function Show-Error([string]$Message)
{
	Add-Type -AssemblyName System.Windows.Forms
	[void][System.Windows.Forms.MessageBox]::Show($Message, "Sinwave", "OK", "Error")
}

try
{
	# Le mod est construit d'abord : Doom Builder lit ses classes (points d'apparition...).
	& (Join-Path $PSScriptRoot "build.ps1") | Out-Null

	# 1. VS Code
	$code = Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\Code.exe"
	if (Test-Path $code) { Start-Process $code -ArgumentList "`"$RepoRoot`"" }

	# 2. Ultimate Doom Builder : carte, configuration GZDoom UDMF, puis ressources.
	$builder = Join-Path $ToolsDir "UltimateDoomBuilder\Builder.exe"
	$map = Join-Path $SrcDir "maps\SW02.wad"
	if ((Test-Path $builder) -and (Test-Path $map))
	{
		Start-Process $builder -WorkingDirectory (Split-Path $builder) -ArgumentList @(
			"`"$map`"", "-map", "SW02", "-cfg", "GZDoom_DoomUDMF.cfg", "`"$FreedoomIwad`"", "`"$Pk3Path`"")
	}

	# 3. SLADE
	$slade = @("${env:ProgramFiles(x86)}\SLADE\SLADE.exe", "$env:ProgramFiles\SLADE\SLADE.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
	if ($slade) { Start-Process $slade -ArgumentList "`"$SrcDir`"" }

	# 4. Claude (application du Microsoft Store)
	$claude = Get-StartApps | Where-Object { $_.Name -eq "Claude" } | Select-Object -First 1
	if ($claude) { Start-Process "explorer.exe" -ArgumentList "shell:AppsFolder\$($claude.AppID)" }
}
catch
{
	Show-Error "Impossible d'ouvrir l'environnement de travail :`n$($_.Exception.Message)"
}
