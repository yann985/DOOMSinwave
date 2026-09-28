# Construit build\sinwave.pk3 à partir du dossier src\.
# Un .pk3 est une archive ZIP : les chemins doivent utiliser des « / ».
#   -Source / -Output : construire une autre archive (utilisé par tools\test.ps1).

param(
	[string]$Source,
	[string]$Output
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

if (-not $Source) { $Source = $SrcDir }
if (-not $Output) { $Output = $Pk3Path }
$Source = (Resolve-Path $Source).Path

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

New-Item -ItemType Directory -Force (Split-Path $Output) | Out-Null
if (Test-Path $Output) { Remove-Item $Output -Force }

# Fichiers propres au dépôt, inutiles dans le jeu.
$excluded = @(".gitkeep", ".DS_Store", "Thumbs.db")

$zip = [System.IO.Compression.ZipFile]::Open($Output, [System.IO.Compression.ZipArchiveMode]::Create)
$count = 0
try
{
	Get-ChildItem $Source -Recurse -File | Where-Object { $excluded -notcontains $_.Name } | ForEach-Object {
		$entry = $_.FullName.Substring($Source.Length + 1).Replace('\', '/')
		[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal)
		$count++
	}
}
finally
{
	$zip.Dispose()
}

"{0} construit ({1} fichiers, {2:N1} Ko)" -f $Output, $count, ((Get-Item $Output).Length / 1KB)
