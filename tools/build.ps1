# Construit build\sinwave.pk3 à partir du dossier src\.
# Un .pk3 est une archive ZIP : les chemins doivent utiliser des « / ».

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

New-Item -ItemType Directory -Force $BuildDir | Out-Null
if (Test-Path $Pk3Path) { Remove-Item $Pk3Path -Force }

# Fichiers propres au dépôt, inutiles dans le jeu.
$excluded = @(".gitkeep", ".DS_Store", "Thumbs.db")

$zip = [System.IO.Compression.ZipFile]::Open($Pk3Path, [System.IO.Compression.ZipArchiveMode]::Create)
$count = 0
try
{
	Get-ChildItem $SrcDir -Recurse -File | Where-Object { $excluded -notcontains $_.Name } | ForEach-Object {
		$entry = $_.FullName.Substring($SrcDir.Length + 1).Replace('\', '/')
		[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal)
		$count++
	}
}
finally
{
	$zip.Dispose()
}

"{0} construit ({1} fichiers, {2:N1} Ko)" -f $Pk3Path, $count, ((Get-Item $Pk3Path).Length / 1KB)
