# Tests automatiques de bout en bout : lance GZDoom, joue des runs courtes toutes
# seules et vérifie dans le journal que chaque étape se produit, dans le bon ordre.
#
# L'archive tests\smoke est chargée par-dessus le jeu : elle raccourcit les
# vagues, désactive le système d'interface (test de découplage) et ajoute les
# tests unitaires du noyau. Le jeu lui-même n'est pas modifié.
#
#   powershell -ExecutionPolicy Bypass -File tools\test.ps1

param([int]$TimeoutSeconds = 90)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

& (Join-Path $PSScriptRoot "build.ps1")
$smokePk3 = Join-Path $BuildDir "$PackageName-smoke.pk3"
& (Join-Path $PSScriptRoot "build.ps1") -Source (Join-Path $RepoRoot "tests\smoke") -Output $smokePk3

$exe = Get-EnginePath "gzdoom"
Assert-Iwad

# Joue un scénario (commandes de console, 35 tics = 1 seconde) et renvoie la liste des échecs.
function Invoke-Scenario([string]$Name, [string[]]$Commands, [string[]]$Expected)
{
	Write-Host ""
	Write-Host "=== Scénario : $Name"
	# Configuration isolée : les réglages et la méta-progression du développeur ne sont pas touchés.
	$config = Join-Path $BuildDir "smoke.ini"
	$log = Join-Path $BuildDir "smoke-$Name.log"
	Remove-Item $config, $log -ErrorAction SilentlyContinue
	Set-Content $config -Encoding ASCII -Value "[GlobalSettings]`r`nvid_fullscreen=false`r`n"

	# Une seule commande : « wait » ne retarde que la suite de la même ligne de commandes.
	$scenario = (@("sinwave_debug 1", "disableautosave 1") + $Commands + @("quit")) -join "; "
	$engineArgs = @("-iwad", "`"$IwadPath`"", "-file", "`"$Pk3Path`"", "`"$smokePk3`"", "-config", "`"$config`"",
		"-nosound", "-width", "800", "-height", "500", "+logfile", "`"$log`"", "+map", "SW01", "`"+$scenario`"")

	$started = (Get-Date).AddSeconds(-1)
	Start-Process $exe -ArgumentList $engineArgs -WorkingDirectory (Split-Path $exe) | Out-Null
	$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
	while ((Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe -and $_.StartTime -ge $started }) -and (Get-Date) -lt $deadline)
	{
		Start-Sleep -Milliseconds 500
	}
	$failures = @()
	$remaining = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe -and $_.StartTime -ge $started }
	if ($remaining)
	{
		$remaining | Stop-Process -Force
		$failures += "Le jeu ne s'est pas fermé tout seul (délai de $TimeoutSeconds s dépassé)."
	}
	if (-not (Test-Path $log)) { return @("Aucun journal produit.") }
	$lines = Get-Content $log -Encoding UTF8 | ForEach-Object { $_ -replace "\x1c(\[[^\]]*\]|.)", "" }

	# Erreurs de script ou de données.
	$lines | Where-Object { $_ -match '^Script error|Execution could not continue|^\[Sinwave\] .*(ligne \d+|introuvable)' } |
		ForEach-Object { $failures += "Erreur : $_" }

	# Tests unitaires du noyau.
	$unit = @($lines | Where-Object { $_ -match '^\[test\] ' })
	$unit | Where-Object { $_ -match 'ECHEC' } | ForEach-Object { $failures += $_ }
	$summary = $unit | Where-Object { $_ -match 'réussis' } | Select-Object -First 1
	if ($summary -notmatch ' 0 échoués') { $failures += "Tests unitaires en échec ou absents." }
	Write-Host "  $summary"

	# Étapes attendues dans le journal du bus, dans cet ordre.
	$bus = @($lines | Where-Object { $_ -match '^\[bus\] ' } | ForEach-Object { $_.Substring(6) })
	$position = 0
	foreach ($step in $Expected)
	{
		$found = $false
		while ($position -lt $bus.Count)
		{
			$position++
			if ($bus[$position - 1] -match "^$step") { $found = $true; break }
		}
		if ($found) { Write-Host "  ok   $step" }
		else { Write-Host "  ---  $step"; $failures += "Étape manquante ou dans le désordre : $step"; $position = 0 }
	}
	if ($failures.Count -gt 0) { Write-Host "  Journal : $log" }
	return $failures
}

"Une fenêtre GZDoom va s'ouvrir plusieurs fois (environ 1 minute au total)."
"Ne touche pas au clavier pendant ce temps (Espace ou E comptent comme « Utiliser »)."

$allFailures = @()

# 1. Run complète gagnée : cercle maudit, XP, choix, pause, boss, victoire, sauvegarde, rechargement.
$allFailures += Invoke-Scenario "victoire" @(
	"wait 35", "god",
	"wait 35", "netevent sinwave_confirm",		# t=70   Menu -> choix d'arène
	"wait 5", "netevent sinwave_arena 0",		# t=75   arène de la carte courante : la run démarre
	"wait 105", "kill monsters",				# t=180  XP -> niveau -> choix (automatique, 2 s)
	"wait 105", "netevent sinwave_pause",		# t=285  pause pendant le cercle 1...
	"wait 35", "netevent sinwave_resume",		# t=320  ...et reprise
	"wait 240", "kill monsters",				# t=560  cercle 2 (depuis t=425) : le boss meurt
	"wait 280", "netevent sinwave_confirm",		# t=840  fin de run -> recommencer
	"wait 105"
) @(
	'Sinwave_MetaLoadedEvent : 0 indulgences',
	'Sinwave_StateChangedEvent : None -> Menu',
	'Sinwave_StateChangedEvent : Menu -> ArenaSelect',
	'Sinwave_StateChangedEvent : ArenaSelect -> InGame',
	'Sinwave_RunStartedEvent',
	'Sinwave_WaveStartedEvent : 1/2',
	'Sinwave_CurseStartedEvent : sloth',
	'Sinwave_EnemyKilledEvent',
	'Sinwave_XpCollectedEvent',
	'Sinwave_LevelUpEvent',
	'Sinwave_UpgradeOfferedEvent',
	'Sinwave_StateChangedEvent : InGame -> Upgrade',
	'Sinwave_UpgradePickedEvent',
	'Sinwave_UpgradeChosenEvent',
	'Sinwave_StateChangedEvent : Upgrade -> InGame',
	'Sinwave_EffectGrantedEvent',
	'Sinwave_StateChangedEvent : InGame -> Pause',
	'Sinwave_StateChangedEvent : Pause -> InGame',
	'Sinwave_WaveEndedEvent : 1',
	'Sinwave_CurseEndedEvent',
	'Sinwave_WaveStartedEvent : 2/2',
	'Sinwave_CurseStartedEvent : pride',
	'Sinwave_BossSpawnedEvent : lucifer',
	'Sinwave_BossDefeatedEvent',
	'Sinwave_AllWavesClearedEvent',
	'Sinwave_StateChangedEvent : InGame -> GameOver',
	'Sinwave_RunEndedEvent : victoire',
	'Sinwave_MetaSavedEvent : \+[1-9]\d* indulgences .*absolution',
	'Sinwave_MetaLoadedEvent : [1-9]\d* indulgences',		# après la sauvegarde
	'Sinwave_MetaLoadedEvent : [1-9]\d* indulgences',		# après le rechargement : relu depuis les CVars
	'Sinwave_StateChangedEvent : None -> Menu'
)

# 2. Mort du joueur pendant la run.
$allFailures += Invoke-Scenario "mort" @(
	"wait 35", "netevent sinwave_confirm",
	"wait 5", "netevent sinwave_arena 0",
	"wait 70", "kill",							# suicide du joueur
	"wait 70"
) @(
	'Sinwave_RunStartedEvent',
	'Sinwave_PlayerDiedEvent',
	'Sinwave_StateChangedEvent : InGame -> GameOver',
	'Sinwave_RunEndedEvent : mort',
	'Sinwave_MetaSavedEvent'
)

# 3. Boutique puis voyage vers l'autre arène : les achats s'appliquent au début de la run.
$allFailures += Invoke-Scenario "boutique" @(
	"sinwave_meta_indulgences 500",
	"wait 35", "netevent sinwave_shop",			# Menu -> boutique
	"wait 5", "netevent sinwave_buy 0",			# fusil à pompe (15)
	"wait 5", "netevent sinwave_buy 4",			# Vigueur niveau 1 (10)
	"wait 5", "netevent sinwave_buy 0",			# déjà acheté : refusé
	"wait 5", "netevent sinwave_back",			# retour au menu
	"wait 5", "netevent sinwave_confirm",		# choix d'arène...
	"wait 5", "netevent sinwave_arena 1",		# ...l'autre carte : voyage puis démarrage automatique
	"wait 105"
) @(
	'Sinwave_MetaLoadedEvent : 500 indulgences',
	'Sinwave_StateChangedEvent : Menu -> Shop',
	'Sinwave_PurchaseEvent : shotgun ok',
	'Sinwave_MetaLoadedEvent : 485 indulgences',
	'Sinwave_PurchaseEvent : vigor ok',
	'Sinwave_MetaLoadedEvent : 475 indulgences',
	'Sinwave_PurchaseEvent : shotgun refusé',
	'Sinwave_StateChangedEvent : Shop -> Menu',
	'Sinwave_StateChangedEvent : Menu -> ArenaSelect',
	'Sinwave_MetaLoadedEvent : 475 indulgences',			# nouvelle carte : méta relue
	'Sinwave_StateChangedEvent : None -> Menu',
	'Sinwave_StateChangedEvent : Menu -> InGame',			# démarrage automatique après le voyage
	'Sinwave_RunStartedEvent',
	'Sinwave_EffectGrantedEvent : give Shotgun',
	'Sinwave_EffectGrantedEvent : maxhealth'
)

""
if ($allFailures.Count -gt 0)
{
	$allFailures | ForEach-Object { "ÉCHEC : $_" }
	exit 1
}
"SUCCÈS : tous les scénarios traversent les systèmes attendus."
