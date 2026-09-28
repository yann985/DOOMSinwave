# Génère l'arène src\maps\SW01.wad (format UDMF) de façon mathématique :
# une salle carrée à ciel ouvert, des piliers pour se couvrir, des torches, et un
# anneau de points d'apparition (Sinwave_SpawnPoint, numéro d'éditeur 30001).
#
# La carte générée peut ensuite être retouchée dans Ultimate Doom Builder
# (configuration « GZDoom: Doom 2 (UDMF) »). Attention : relancer ce script
# écrase les retouches.

param(
	[int]$HalfSize = 1280,		# demi-largeur de l'arène
	[int]$SpawnRing = 1100,		# distance du centre des points d'apparition
	[int]$SpawnCount = 16
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

$culture = [Globalization.CultureInfo]::InvariantCulture
$text = [Text.StringBuilder]::new()
function Add([string]$line) { [void]$text.AppendLine($line) }
function Num([double]$value) { $value.ToString("0.000", $culture) }

function Add-Thing([double]$x, [double]$y, [int]$type, [int]$angle = 0)
{
	Add "thing { x = $(Num $x); y = $(Num $y); angle = $angle; type = $type; skill1 = true; skill2 = true; skill3 = true; skill4 = true; skill5 = true; single = true; coop = true; dm = true; }"
}

Add 'namespace = "zdoom";'

# Salle : 4 sommets dans le sens horaire, la face avant des murs vers l'intérieur.
$h = $HalfSize
Add "vertex { x = $(Num -$h); y = $(Num $h); }"
Add "vertex { x = $(Num $h); y = $(Num $h); }"
Add "vertex { x = $(Num $h); y = $(Num -$h); }"
Add "vertex { x = $(Num -$h); y = $(Num -$h); }"
for ($i = 0; $i -lt 4; $i++)
{
	Add "linedef { v1 = $i; v2 = $(($i + 1) % 4); sidefront = $i; blocking = true; }"
	Add "sidedef { sector = 0; texturemiddle = ""MARBLE1""; }"
}
Add 'sector { heightfloor = 0; heightceiling = 512; texturefloor = "RROCK09"; textureceiling = "F_SKY1"; lightlevel = 176; }'

# Joueur au centre, regardant vers le nord.
Add-Thing 0 0 1 90

# Piliers (TechPillar, 48) et torches rouges (RedTorch, 46).
foreach ($p in @(@(-512, -512), @(512, -512), @(-512, 512), @(512, 512), @(0, 768), @(0, -768), @(768, 0), @(-768, 0)))
{
	Add-Thing $p[0] $p[1] 48
}
$corner = $h - 96
foreach ($p in @(@(-$corner, -$corner), @($corner, -$corner), @(-$corner, $corner), @($corner, $corner)))
{
	Add-Thing $p[0] $p[1] 46
}

# Anneau de points d'apparition.
for ($i = 0; $i -lt $SpawnCount; $i++)
{
	$angle = 2 * [Math]::PI * $i / $SpawnCount
	Add-Thing ([Math]::Round($SpawnRing * [Math]::Cos($angle))) ([Math]::Round($SpawnRing * [Math]::Sin($angle))) 30001
}

# Écriture du WAD : marqueur SW01, TEXTMAP, ENDMAP.
$textmap = [Text.Encoding]::ASCII.GetBytes($text.ToString())
$lumps = @(
	@{ Name = "SW01"; Data = [byte[]]@() },
	@{ Name = "TEXTMAP"; Data = $textmap },
	@{ Name = "ENDMAP"; Data = [byte[]]@() }
)

$out = Join-Path $SrcDir "maps\SW01.wad"
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
$stream = [IO.File]::Create($out)
$writer = [IO.BinaryWriter]::new($stream)
try
{
	$writer.Write([Text.Encoding]::ASCII.GetBytes("PWAD"))
	$writer.Write([int]$lumps.Count)
	$writer.Write([int](12 + $textmap.Length))	# position du répertoire, après les données
	$offsets = @()
	foreach ($lump in $lumps)
	{
		$offsets += [int]$stream.Position
		$writer.Write($lump.Data)
	}
	for ($i = 0; $i -lt $lumps.Count; $i++)
	{
		$writer.Write([int]$offsets[$i])
		$writer.Write([int]$lumps[$i].Data.Length)
		$name = [byte[]]::new(8)
		$bytes = [Text.Encoding]::ASCII.GetBytes($lumps[$i].Name)
		[Array]::Copy($bytes, $name, $bytes.Length)
		$writer.Write($name)
	}
}
finally
{
	$writer.Dispose()
}
"{0} généré ({1} octets)" -f $out, (Get-Item $out).Length
