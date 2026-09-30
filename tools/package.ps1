# Prépare le build Windows à rendre : dist\Sinwave-win64.zip
# Contenu : le moteur GZDoom (licence GPL, redistribuable), sinwave.pk3,
# freedoom2.wad (licence BSD, redistribuable) et deux lanceurs : « Jouer Sinwave.bat »
# (Freedoom) et « Jouer Sinwave (Doom II).bat » pour qui possède le vrai Doom II.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

& (Join-Path $PSScriptRoot "build.ps1")

$exe = Get-EnginePath "gzdoom"
# Toujours Freedoom dans le build rendu : un IWAD commercial n'est pas redistribuable.
$IwadPath = $FreedoomIwad
Assert-Iwad

$outDir = Join-Path $DistDir "$GameName-win64"
$outZip = Join-Path $DistDir "$GameName-win64.zip"
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
if (Test-Path $outZip) { Remove-Item $outZip -Force }
New-Item -ItemType Directory -Force $outDir | Out-Null

# Moteur, sans les réglages ni sauvegardes locales du développeur.
Get-ChildItem (Split-Path $exe) | Where-Object { $_.Name -notmatch '\.ini$|^save|^screenshots$|\.log$' } |
	Copy-Item -Destination $outDir -Recurse -Force

Copy-Item $Pk3Path $outDir
Copy-Item $IwadPath $outDir

# Mode portable : réglages et méta-progression enregistrés à côté de l'exécutable.
New-Item -ItemType File -Force (Join-Path $outDir "gzdoom_portable.ini") | Out-Null

# use_joystick : la manette est désactivée par défaut dans GZDoom ; Sinwave se joue aussi avec.
# Le vrai Doom II n'est jamais livré (il n'est pas libre) : GZDoom le trouve lui-même dans une
# installation GOG ou Steam, ou à côté de gzdoom.exe. Sinon, il propose les jeux qu'il a trouvés.
function New-Launcher([string]$Name, [string]$Iwad)
{
	$launcher = @"
@echo off
cd /d "%~dp0"
start "" "gzdoom.exe" -iwad $Iwad -file $PackageName.pk3 +use_joystick 1
"@
	Set-Content -Path (Join-Path $outDir "$Name.bat") -Value $launcher -Encoding ASCII
}
New-Launcher "Jouer $GameName" "freedoom2.wad"
New-Launcher "Jouer $GameName (Doom II)" "doom2.wad"

$readme = @"
$GameName - build Windows
Lancer : double-clic sur « Jouer $GameName.bat » (avec Freedoom, fourni).
Avec le vrai Doom II : « Jouer $GameName (Doom II).bat ». GZDoom le trouve dans une
installation GOG ou Steam de DOOM II, sinon copie ton doom2.wad à côté de gzdoom.exe.
Les deux versions partagent la même progression.
Se joue au clavier et à la souris, ou à la manette.

Moteur : GZDoom $GZDoomVersion (GPL v3) - https://zdoom.org
Données de base : Freedoom $FreedoomVersion (BSD) - https://freedoom.github.io
"@
Set-Content -Path (Join-Path $outDir "LISEZMOI.txt") -Value $readme -Encoding UTF8

Compress-Archive -Path (Join-Path $outDir "*") -DestinationPath $outZip -CompressionLevel Optimal
"{0} prêt ({1:N1} Mo)" -f $outZip, ((Get-Item $outZip).Length / 1MB)
