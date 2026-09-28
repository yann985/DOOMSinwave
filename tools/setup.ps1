# Installe tous les outils de développement de Sinwave sur une machine Windows.
#   powershell -ExecutionPolicy Bypass -File tools\setup.ps1
# Les moteurs et l'IWAD vont dans $ToolsDir (hors du dépôt), aux versions figées dans config.ps1.
# Relancer le script ne réinstalle pas ce qui est déjà présent.
# -EngineOnly : seulement GZDoom + Freedoom (utilisé par la GitHub Action pour le build Windows).

param([switch]$EngineOnly)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "config.ps1")

$downloads = Join-Path $ToolsDir "_downloads"
New-Item -ItemType Directory -Force $downloads | Out-Null

function Get-File([string]$Url, [string]$Name)
{
	$path = Join-Path $downloads $Name
	if (-not (Test-Path $path))
	{
		Write-Host "Téléchargement de $Url"
		Invoke-WebRequest $Url -OutFile $path -UseBasicParsing
	}
	return $path
}

# 1. Moteurs (versions figées)
if (-not (Test-Path $Engines.gzdoom))
{
	Expand-Archive (Get-File $GZDoomUrl "gzdoom-$GZDoomVersion.zip") (Split-Path $Engines.gzdoom) -Force
}
if (-not $EngineOnly -and -not (Test-Path $Engines.uzdoom))
{
	Expand-Archive (Get-File $UZDoomUrl "uzdoom-$UZDoomVersion.zip") (Split-Path $Engines.uzdoom) -Force
}

# 2. IWAD libre (Freedoom), avec vérification de la somme de contrôle officielle
if (-not (Test-Path $FreedoomIwad))
{
	$zip = Get-File $FreedoomUrl "freedoom-$FreedoomVersion.zip"
	$hash = (Get-FileHash $zip -Algorithm SHA256).Hash
	if ($hash -ne $FreedoomSha256) { throw "Somme de contrôle Freedoom invalide ($hash)." }
	$tmp = Join-Path $downloads "freedoom"
	Expand-Archive $zip $tmp -Force
	New-Item -ItemType Directory -Force (Split-Path $FreedoomIwad) | Out-Null
	Get-ChildItem $tmp -Recurse -Filter "*.wad" | Copy-Item -Destination (Split-Path $FreedoomIwad) -Force
}

# 3. Éditeur de maps
$udb = Join-Path $ToolsDir "UltimateDoomBuilder\Builder.exe"
if (-not $EngineOnly -and -not (Test-Path $udb))
{
	$setup = Get-File $DoomBuilderUrl "UDB-Setup-x64.exe"
	Start-Process $setup -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/DIR=`"$(Split-Path $udb)`"" -Wait
}

# 4. Logiciels installés via winget
if (-not $EngineOnly)
{
	$packages = @(
		"Git.Git",
		"Microsoft.VisualStudioCode",
		"srjuddington.slade",
		"GIMP.GIMP.3",
		"Audacity.Audacity",
		"7zip.7zip",
		"GitHub.cli",
		"JohnMacFarlane.Pandoc",
		"oschwartz10612.Poppler",
		"Python.Python.3.13"
	)
	foreach ($id in $packages)
	{
		"winget : $id"
		winget install --id $id --exact --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity | Out-Null
	}

	$code = Get-Command code -ErrorAction SilentlyContinue
	if ($code) { code --install-extension kaptainmicila.gzdoom-zscript | Out-Null }
}

"Outils prêts dans $ToolsDir"
