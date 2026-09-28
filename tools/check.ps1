# Vérifie que le ZScript compile, sans jouer : le moteur démarre avec -norun puis quitte.
# Les erreurs sont réécrites au format « fichier:ligne: error: message » pour que VS Code
# les affiche dans l'onglet Problèmes (voir .vscode/tasks.json).

param([int]$TimeoutSeconds = 60)

# Uniquement GZDoom (le moteur figé du projet) : UZDoom ignore -norun et ouvre sa fenêtre.
$Engine = "gzdoom"

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

& (Join-Path $PSScriptRoot "build.ps1")

$exe = Get-EnginePath $Engine
Assert-Iwad

$log = Join-Path $BuildDir "check-$Engine.log"
if (Test-Path $log) { Remove-Item $log -Force }

$engineArgs = @("-iwad", "`"$IwadPath`"", "-file", "`"$Pk3Path`"", "-norun", "-nosound", "+logfile", "`"$log`"")
$started = (Get-Date).AddSeconds(-1)
Start-Process $exe -ArgumentList $engineArgs -WorkingDirectory (Split-Path $exe) | Out-Null

# En cas d'erreur fatale, le moteur ouvre une fenêtre et attend : on le ferme dès que
# le log contient le verdict, ou au bout du délai.
function Get-CheckProcesses
{
	Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe -and $_.StartTime -ge $started }
}
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-CheckProcesses) -and (Get-Date) -lt $deadline)
{
	if ((Test-Path $log) -and (Select-String -Path $log -Pattern 'Execution could not continue' -Quiet)) { break }
	Start-Sleep -Milliseconds 500
}
Start-Sleep -Milliseconds 500
Get-CheckProcesses | Stop-Process -Force

if (-not (Test-Path $log)) { throw "Aucun log produit par $Engine." }
# Le log contient des codes couleur du moteur (caractère \x1c suivi d'une lettre) : on les retire.
$lines = Get-Content $log -Encoding UTF8 | ForEach-Object { $_ -replace "\x1c(\[[^\]]*\]|.)", "" }

$problems = 0
for ($i = 0; $i -lt $lines.Count; $i++)
{
	if ($lines[$i] -match '^Script (error|warning), "(?:[^"]*?\.pk3:)?([^"]+)" line (\d+):?\s*(.*)$')
	{
		$kind = $Matches[1]
		$file = "src/" + $Matches[2]
		$line = $Matches[3]
		$message = $Matches[4]
		if (-not $message -and $i + 1 -lt $lines.Count) { $message = $lines[$i + 1].Trim() }
		"{0}:{1}: {2}: {3}" -f $file, $line, $kind, $message
		if ($kind -eq "error") { $problems++ }
	}
	elseif ($lines[$i] -match 'Execution could not continue|^\s*\d+ errors? while parsing')
	{
		"FATAL: $($lines[$i].Trim())"
		$problems++
	}
}

if ($problems -gt 0)
{
	"Échec : $problems erreur(s). Log complet : $log"
	exit 1
}
"OK : le ZScript compile avec $Engine. Log : $log"
