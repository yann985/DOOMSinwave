# Génère une arène au format UDMF, de façon mathématique :
#   -Shape Circles : cercles concentriques qui descendent vers le centre (le Purgatoire)
#   -Shape Square  : salle carrée à ciel ouvert (les Limbes)
# avec des piliers, des torches et un anneau de points d'apparition
# (Sinwave_SpawnPoint, numéro d'éditeur 30001).
#
#   powershell -ExecutionPolicy Bypass -File tools\generate-arena.ps1 -Map SW01 -Shape Circles
#   powershell -ExecutionPolicy Bypass -File tools\generate-arena.ps1 -Map SW02 -Shape Square
#
# La carte peut ensuite être retouchée dans Ultimate Doom Builder (configuration
# « GZDoom: Doom 2 (UDMF) »). Attention : relancer ce script écrase les retouches.

param(
	[string]$Map = "SW01",
	[ValidateSet("Circles", "Square")] [string]$Shape = "Circles",
	[int]$SpawnCount = 16
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

$culture = [Globalization.CultureInfo]::InvariantCulture
$text = [Text.StringBuilder]::new()
$script:vertexCount = 0
$script:sideCount = 0

function Add([string]$line) { [void]$text.AppendLine($line) }
function Num([double]$value) { $value.ToString("0.000", $culture) }

function Add-Vertex([double]$x, [double]$y)
{
	Add "vertex { x = $(Num $x); y = $(Num $y); }"
	$script:vertexCount++
	return $script:vertexCount - 1
}

function Add-Side([int]$sector, [string]$middle = "-", [string]$lower = "-")
{
	Add "sidedef { sector = $sector; texturemiddle = ""$middle""; texturebottom = ""$lower""; }"
	$script:sideCount++
	return $script:sideCount - 1
}

function Add-Thing([double]$x, [double]$y, [int]$type, [int]$angle = 0)
{
	Add "thing { x = $(Num $x); y = $(Num $y); angle = $angle; type = $type; skill1 = true; skill2 = true; skill3 = true; skill4 = true; skill5 = true; single = true; coop = true; dm = true; }"
}

# Polygone régulier, sommets dans le sens horaire (la face avant des lignes regarde vers l'intérieur).
function Add-Polygon([double]$radius, [int]$sides)
{
	$ids = @()
	for ($i = 0; $i -lt $sides; $i++)
	{
		$angle = -2 * [Math]::PI * $i / $sides
		$ids += Add-Vertex ([Math]::Round($radius * [Math]::Cos($angle))) ([Math]::Round($radius * [Math]::Sin($angle)))
	}
	return $ids
}

Add 'namespace = "zdoom";'

if ($Shape -eq "Circles")
{
	# Cinq anneaux concentriques : chaque anneau est 16 unités plus bas que le
	# précédent (une marche franchissable), et plus sombre, jusqu'au centre.
	$sides = 48
	$radii = @(1400, 1100, 800, 520, 260)
	$floors = @(0, -16, -32, -48, -64)
	$lights = @(192, 176, 160, 144, 128)
	$flats = @("RROCK09", "RROCK11", "RROCK13", "RROCK16", "FLOOR6_1")

	$rings = @()
	foreach ($radius in $radii) { $rings += , (Add-Polygon $radius $sides) }

	# Mur extérieur : lignes à une face, face avant = anneau extérieur (secteur 0).
	$outer = $rings[0]
	for ($i = 0; $i -lt $sides; $i++)
	{
		$side = Add-Side 0 "MARBLE1"
		Add "linedef { v1 = $($outer[$i]); v2 = $($outer[($i + 1) % $sides]); sidefront = $side; blocking = true; }"
	}
	# Limites entre anneaux : lignes à deux faces ; l'avant regarde l'anneau intérieur (plus bas).
	for ($k = 1; $k -lt $radii.Count; $k++)
	{
		$ring = $rings[$k]
		for ($i = 0; $i -lt $sides; $i++)
		{
			$front = Add-Side $k "-" "MARBLE2"
			$back = Add-Side ($k - 1) "-" "MARBLE2"
			Add "linedef { v1 = $($ring[$i]); v2 = $($ring[($i + 1) % $sides]); sidefront = $front; sideback = $back; twosided = true; }"
		}
	}
	for ($k = 0; $k -lt $radii.Count; $k++)
	{
		Add "sector { heightfloor = $($floors[$k]); heightceiling = 512; texturefloor = ""$($flats[$k])""; textureceiling = ""F_SKY1""; lightlevel = $($lights[$k]); }"
	}

	Add-Thing 0 0 1 90
	# Piliers sur l'anneau du milieu, torches rouges contre le mur extérieur.
	for ($i = 0; $i -lt 6; $i++)
	{
		$angle = 2 * [Math]::PI * ($i + 0.5) / 6
		Add-Thing ([Math]::Round(650 * [Math]::Cos($angle))) ([Math]::Round(650 * [Math]::Sin($angle))) 48
	}
	for ($i = 0; $i -lt 8; $i++)
	{
		$angle = 2 * [Math]::PI * $i / 8
		Add-Thing ([Math]::Round(1340 * [Math]::Cos($angle))) ([Math]::Round(1340 * [Math]::Sin($angle))) 46
	}
	$spawnRing = 1250
}
else
{
	# Salle carrée : 4 sommets dans le sens horaire, face avant des murs vers l'intérieur.
	$h = 1280
	$corners = @((Add-Vertex -$h $h), (Add-Vertex $h $h), (Add-Vertex $h -$h), (Add-Vertex -$h -$h))
	for ($i = 0; $i -lt 4; $i++)
	{
		$side = Add-Side 0 "SP_HOT1"
		Add "linedef { v1 = $($corners[$i]); v2 = $($corners[($i + 1) % 4]); sidefront = $side; blocking = true; }"
	}
	Add 'sector { heightfloor = 0; heightceiling = 384; texturefloor = "FLAT5_7"; textureceiling = "F_SKY1"; lightlevel = 160; }'

	Add-Thing 0 0 1 90
	foreach ($p in @(@(-512, -512), @(512, -512), @(-512, 512), @(512, 512), @(0, 768), @(0, -768), @(768, 0), @(-768, 0)))
	{
		Add-Thing $p[0] $p[1] 48
	}
	$corner = $h - 96
	foreach ($p in @(@(-$corner, -$corner), @($corner, -$corner), @(-$corner, $corner), @($corner, $corner)))
	{
		Add-Thing $p[0] $p[1] 46
	}
	$spawnRing = 1100
}

# Anneau de points d'apparition.
for ($i = 0; $i -lt $SpawnCount; $i++)
{
	$angle = 2 * [Math]::PI * $i / $SpawnCount
	Add-Thing ([Math]::Round($spawnRing * [Math]::Cos($angle))) ([Math]::Round($spawnRing * [Math]::Sin($angle))) 30001
}

# Écriture du WAD : marqueur de carte, TEXTMAP, ENDMAP.
$textmap = [Text.Encoding]::ASCII.GetBytes($text.ToString())
$lumps = @(
	@{ Name = $Map.ToUpper(); Data = [byte[]]@() },
	@{ Name = "TEXTMAP"; Data = $textmap },
	@{ Name = "ENDMAP"; Data = [byte[]]@() }
)

$out = Join-Path $SrcDir "maps\$($Map.ToUpper()).wad"
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
"{0} généré ({1}, {2} octets)" -f $out, $Shape, (Get-Item $out).Length
