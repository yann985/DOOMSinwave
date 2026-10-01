# Génère une arène au format UDMF, de façon mathématique, d'après la géographie de Dante :
#   -Shape Funnel : l'entonnoir de l'Enfer (le Purgatoire) : des terrasses qui descendent,
#                   des aiguilles de roche, des tombeaux ardents, un fleuve de sang, et au
#                   centre le lac gelé du Cocyte, où attend Lucifer.
#   -Shape Castle : le noble château des Limbes : un champ obscur, un fossé, un rempart
#                   percé de sept portes, et au centre une prairie lumineuse.
#   -Shape Vestibule : le vestibule de l'Enfer, petite arène de la run minimale : on
#                   entre par la porte, une plaine de cendre semée de rochers descend
#                   vers l'Achéron, le fleuve qui barre le sud.
# (Circles et Square, les anciens noms, donnent Funnel et Castle.)
#
# Principes de level design, repris des modes de survie existants (zombies de Call of
# Duty, mode Horde de Doom Eternal, Serious Sam, Vampire Survivors) :
#   - des boucles pour « tirer » la horde en rond, sans cul-de-sac où se faire coincer ;
#   - des obstacles qui coupent la ligne de tir des tireurs (zombies, mitrailleurs) ;
#   - des passages étroits (portes, ponts) où la horde se tasse, pour le fusil à pompe ;
#   - des zones reconnaissables (sol, lumière, couleur) et un repère au centre.
# Contraintes du moteur : les marches font 24 unités au plus (les monstres ne montent
# ni ne descendent plus haut), les obstacles pleins sont des trous dans la carte, et un
# plateau plus haut (tombeau) n'accueille pas d'ennemi (Sinwave_WaveSystem.CanWalkOff).
# Textures et sols : présents à la fois dans Doom II et dans Freedoom.
#
#   powershell -ExecutionPolicy Bypass -File tools\generate-arena.ps1 -Map SW02 -Shape Funnel
#   powershell -ExecutionPolicy Bypass -File tools\generate-arena.ps1 -Map SW01 -Shape Castle
#   powershell -ExecutionPolicy Bypass -File tools\generate-arena.ps1 -Map SW03 -Shape Vestibule
#
# La carte peut ensuite être retouchée dans Ultimate Doom Builder (configuration
# « GZDoom: Doom 2 (UDMF) »). Attention : relancer ce script écrase les retouches.

param(
	[string]$Map = "SW01",
	[ValidateSet("Funnel", "Castle", "Vestibule", "Circles", "Square")] [string]$Shape = "Funnel",
	[string]$Output		# fichier .wad à écrire (par défaut : src\maps\<Map>.wad)
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "config.ps1")

if ($Shape -eq "Circles") { $Shape = "Funnel" }
if ($Shape -eq "Square") { $Shape = "Castle" }

# --- Boîte à outils UDMF -------------------------------------------------------

$culture = [Globalization.CultureInfo]::InvariantCulture
$vertexText = [Text.StringBuilder]::new()
$lineText = [Text.StringBuilder]::new()
$sideText = [Text.StringBuilder]::new()
$sectorText = [Text.StringBuilder]::new()
$thingText = [Text.StringBuilder]::new()
$script:vertexIds = @{}
$script:vertexCount = 0
$script:sideCount = 0
$script:sectorCount = 0

function Num([double]$value) { $value.ToString("0.###", $culture) }

# Sommet partagé : deux lignes qui se touchent utilisent le même sommet.
function V([double]$X, [double]$Y)
{
	$x = [Math]::Round($X)
	$y = [Math]::Round($Y)
	$key = "$x,$y"
	if ($script:vertexIds.ContainsKey($key)) { return $script:vertexIds[$key] }
	[void]$vertexText.AppendLine("vertex { x = $(Num $x); y = $(Num $y); }")
	$script:vertexIds[$key] = $script:vertexCount
	$script:vertexCount++
	return $script:vertexCount - 1
}

# Secteur à ciel ouvert. Color : teinte de la lumière (0xRRGGBB), blanche par défaut.
function New-Sector([int]$Floor, [string]$Flat, [int]$Light, [int]$Color = 0xFFFFFF, [int]$Ceiling = 512)
{
	$tint = if ($Color -ne 0xFFFFFF) { " lightcolor = $Color;" } else { "" }
	[void]$sectorText.AppendLine("sector { heightfloor = $Floor; heightceiling = $Ceiling; texturefloor = ""$Flat""; textureceiling = ""F_SKY1""; lightlevel = $Light;$tint }")
	$script:sectorCount++
	return $script:sectorCount - 1
}

function New-Side([int]$Sector, [string]$Middle = "-", [string]$Lower = "-", [string]$Upper = "-")
{
	[void]$sideText.AppendLine("sidedef { sector = $Sector; texturemiddle = ""$Middle""; texturebottom = ""$Lower""; texturetop = ""$Upper""; }")
	$script:sideCount++
	return $script:sideCount - 1
}

# Mur plein : sa face avant (à droite en allant de v1 à v2) donne sur `Sector`.
function Add-Wall([int]$V1, [int]$V2, [int]$Sector, [string]$Texture)
{
	if ($V1 -eq $V2) { return }
	$side = New-Side $Sector $Texture
	[void]$lineText.AppendLine("linedef { v1 = $V1; v2 = $V2; sidefront = $side; blocking = true; }")
}

# Passage d'un secteur à l'autre : `Front` à droite de v1 -> v2, `Back` à gauche.
# `Texture` habille la marche quand les sols n'ont pas la même hauteur.
function Add-Pass([int]$V1, [int]$V2, [int]$Front, [int]$Back, [string]$Texture)
{
	if ($V1 -eq $V2) { return }
	$front = New-Side $Front "-" $Texture $Texture
	$back = New-Side $Back "-" $Texture $Texture
	[void]$lineText.AppendLine("linedef { v1 = $V1; v2 = $V2; sidefront = $front; sideback = $back; twosided = true; }")
}

function Add-Thing([double]$X, [double]$Y, [int]$Type, [int]$Angle = 0)
{
	[void]$thingText.AppendLine("thing { x = $(Num ([Math]::Round($X))); y = $(Num ([Math]::Round($Y))); angle = $Angle; type = $Type; skill1 = true; skill2 = true; skill3 = true; skill4 = true; skill5 = true; single = true; coop = true; dm = true; }")
}

# Point à `Radius` du centre, dans la direction `Degrees`.
function Get-Polar([double]$Radius, [double]$Degrees)
{
	$a = $Degrees * [Math]::PI / 180
	return , @(($Radius * [Math]::Cos($a)), ($Radius * [Math]::Sin($a)))
}

# Polygone régulier (liste de points), à partir de l'angle `Start` en degrés.
function Get-RegularPolygon([double]$Radius, [int]$Sides, [double]$Start = 0, [double]$Cx = 0, [double]$Cy = 0)
{
	$points = New-Object System.Collections.ArrayList
	for ($i = 0; $i -lt $Sides; $i++)
	{
		$p = Get-Polar $Radius ($Start + 360.0 * $i / $Sides)
		[void]$points.Add(@(($Cx + $p[0]), ($Cy + $p[1])))
	}
	return , $points.ToArray()
}

# Remet un polygone dans le sens voulu. Sens horaire : la face avant des lignes regarde
# vers l'intérieur (le secteur est dedans) ; sens antihoraire : vers l'extérieur (un trou).
function Set-Orientation($Points, [switch]$Clockwise)
{
	$area = 0.0
	for ($i = 0; $i -lt $Points.Count; $i++)
	{
		$a = $Points[$i]
		$b = $Points[($i + 1) % $Points.Count]
		$area += $a[0] * $b[1] - $b[0] * $a[1]
	}
	$isClockwise = $area -lt 0
	if ($isClockwise -eq [bool]$Clockwise) { return , $Points }
	$reversed = @($Points)
	[Array]::Reverse($reversed)
	return , $reversed
}

function Get-VertexIds($Points)
{
	$ids = New-Object System.Collections.ArrayList
	foreach ($p in $Points) { [void]$ids.Add((V $p[0] $p[1])) }
	return , $ids.ToArray()
}

# Mur d'enceinte : le secteur est à l'intérieur du polygone.
function Add-Enclosure($Points, [int]$Sector, [string]$Texture)
{
	$ids = Get-VertexIds (Set-Orientation $Points -Clockwise)
	for ($i = 0; $i -lt $ids.Count; $i++) { Add-Wall $ids[$i] $ids[($i + 1) % $ids.Count] $Sector $Texture }
}

# Obstacle plein (trou dans la carte) au milieu du secteur `Around`.
function Add-Hole($Points, [int]$Around, [string]$Texture)
{
	$ids = Get-VertexIds (Set-Orientation $Points)
	for ($i = 0; $i -lt $ids.Count; $i++) { Add-Wall $ids[$i] $ids[($i + 1) % $ids.Count] $Around $Texture }
}

# Limite entre deux secteurs : `Inside` dans le polygone, `Outside` autour.
function Add-Border($Points, [int]$Inside, [int]$Outside, [string]$Texture)
{
	$ids = Get-VertexIds (Set-Orientation $Points -Clockwise)
	for ($i = 0; $i -lt $ids.Count; $i++) { Add-Pass $ids[$i] $ids[($i + 1) % $ids.Count] $Inside $Outside $Texture }
}

# Rectangle centré sur (Cx, Cy), de `Length` le long de la direction `Degrees` et de `Width` en travers.
function Get-Rectangle([double]$Cx, [double]$Cy, [double]$Length, [double]$Width, [double]$Degrees)
{
	$u = Get-Polar 1 $Degrees
	$n = Get-Polar 1 ($Degrees + 90)
	$points = New-Object System.Collections.ArrayList
	foreach ($c in @(@(-1, -1), @(1, -1), @(1, 1), @(-1, 1)))
	{
		[void]$points.Add(@(($Cx + $c[0] * $Length / 2 * $u[0] + $c[1] * $Width / 2 * $n[0]),
			($Cy + $c[0] * $Length / 2 * $u[1] + $c[1] * $Width / 2 * $n[1])))
	}
	return , $points.ToArray()
}

# Rocher : polygone irrégulier (mêmes irrégularités à chaque génération).
$random = [Random]::new(7)
function Get-Rock([double]$Cx, [double]$Cy, [double]$Radius, [int]$Sides = 7)
{
	$points = New-Object System.Collections.ArrayList
	$start = $random.NextDouble() * 360
	for ($i = 0; $i -lt $Sides; $i++)
	{
		$r = $Radius * (0.75 + 0.5 * $random.NextDouble())
		$p = Get-Polar $r ($start + 360.0 * $i / $Sides)
		[void]$points.Add(@(($Cx + $p[0]), ($Cy + $p[1])))
	}
	return , $points.ToArray()
}

# --- Les trois plans -------------------------------------------------------------

if ($Shape -eq "Funnel")
{
	# L'entonnoir, du bord au centre : chaque terrasse descend d'une marche. Chaque anneau
	# est une boucle où tirer la horde ; les obstacles y coupent les lignes de tir.
	$sides = 48
	$rim = New-Sector 0 "RROCK09" 176 0xFFE0C8				# le bord : aiguilles de roche
	$tombs = New-Sector -24 "RROCK11" 160 0xFFC8A8			# les tombeaux ardents (6e cercle)
	$outerBank = New-Sector -48 "RROCK13" 144 0xFFB8B0
	$river = New-Sector -56 "BLOOD1" 176 0xFF5040			# le Phlégéthon, fleuve de sang (7e cercle)
	$innerBank = New-Sector -48 "RROCK13" 144 0xFFB8B0
	$lake = New-Sector -72 "FLOOR7_2" 136 0x90B0FF			# le Cocyte, lac gelé où attend Lucifer

	Add-Enclosure (Get-RegularPolygon 1600 $sides) $rim "ROCKRED1"
	Add-Border (Get-RegularPolygon 1250 $sides) $tombs $rim "ROCKRED2"
	Add-Border (Get-RegularPolygon 900 $sides) $outerBank $tombs "ROCKRED2"
	Add-Border (Get-RegularPolygon 780 $sides) $river $outerBank "ROCKRED2"
	Add-Border (Get-RegularPolygon 680 $sides) $innerBank $river "ROCKRED2"
	Add-Border (Get-RegularPolygon 560 $sides) $lake $innerBank "ROCKRED2"

	# Bord : huit aiguilles de roche, à contourner (et torches contre le mur entre elles).
	for ($i = 0; $i -lt 8; $i++)
	{
		$c = Get-Polar 1425 (22.5 + 45 * $i)
		Add-Hole (Get-Rock $c[0] $c[1] 85) $rim "SP_ROCK1"
		$torch = Get-Polar 1555 (45 * $i)
		Add-Thing $torch[0] $torch[1] 46
	}

	# Six tombeaux ardents : des blocs bas qui coupent la vue, avec du feu dessus (aucun
	# en face du départ, pour voir le gouffre en entrant).
	for ($i = 0; $i -lt 6; $i++)
	{
		$angle = 60 * $i
		$c = Get-Polar 1075 $angle
		$tomb = New-Sector 32 "FLAT5_4" 192 0xFF7040
		Add-Border (Get-Rectangle $c[0] $c[1] 190 100 ($angle + 90)) $tomb $tombs "MARBLE2"
		foreach ($side in @(-1, 1))
		{
			$flame = Get-Polar 1075 ($angle + $side * 3)
			Add-Thing $flame[0] $flame[1] 57
		}
	}

	# Berge intérieure : colonnes de crânes le long du fleuve.
	for ($i = 0; $i -lt 6; $i++)
	{
		$p = Get-Polar 625 (30 + 60 * $i)
		Add-Thing $p[0] $p[1] 37
	}

	# Le lac : quatre piliers de feu bleu pour se cacher du boss.
	for ($i = 0; $i -lt 4; $i++)
	{
		$c = Get-Polar 300 (45 + 90 * $i)
		Add-Hole (Get-RegularPolygon 56 8 22.5 $c[0] $c[1]) $lake "FIREBLU1"
	}

	# Départ au bord, face au gouffre ; points d'apparition entre les obstacles.
	$start = Get-Polar 1425 270
	Add-Thing $start[0] $start[1] 1 90
	for ($i = 0; $i -lt 8; $i++) { $p = Get-Polar 1425 (45 * $i); if ($i -ne 6) { Add-Thing $p[0] $p[1] 30001 } }
	for ($i = 0; $i -lt 6; $i++) { $p = Get-Polar 1075 (30 + 60 * $i); Add-Thing $p[0] $p[1] 30001 }
}
elseif ($Shape -eq "Castle")
{
	# Le château, de l'extérieur vers l'intérieur (octogones : pas de coin où se faire
	# coincer). Le rempart a sept portes : la horde s'y tasse, et on peut en faire le tour.
	$sides = 8
	$tilt = 22.5				# côtés alignés sur les axes
	# Le ciel est partout à 256 (des hauteurs de ciel différentes laissent des bandes au
	# raccord) : les falaises du champ font 256, le rempart est un bloc plein de 192.
	$field = New-Sector 0 "RROCK20" 128 0xC8C8FF 256		# le champ obscur, plein de soupirs
	$moat = New-Sector -16 "FWATER1" 144 0x80A0FF 256		# le ruisseau qui défend le château
	$walk = New-Sector 0 "FLAT5_4" 152 0xFFF0D8 256		# la berge, les portes et le chemin de ronde
	$meadow = New-Sector 16 "GRASS1" 208 0xFFF4D0 256		# la prairie de fraîche verdure, lumineuse
	$rampart = New-Sector 192 "FLAT5_4" 152 0xFFF0D8 256	# le rempart : trop haut pour y monter

	Add-Enclosure (Get-RegularPolygon 1500 $sides $tilt) $field "ROCK4"
	Add-Border (Get-RegularPolygon 1180 $sides $tilt) $moat $field "STONE2"
	Add-Border (Get-RegularPolygon 1040 $sides $tilt) $walk $moat "STONE2"
	Add-Border (Get-RegularPolygon 820 $sides $tilt) $meadow $walk "GSTVINE1"

	# Le rempart, entre 940 et 880 : une porte au milieu de chaque côté, sauf au sud. Le
	# côté n va du sommet n au sommet n + 1 : son milieu est à 45 x (n + 1) degrés.
	$outer = Get-RegularPolygon 940 $sides $tilt
	$inner = Get-RegularPolygon 880 $sides $tilt
	$gateHalf = 96.0 / (940 * 2 * [Math]::Sin([Math]::PI / $sides))	# demi-porte, en fraction de côté
	$gates = @(0, 1, 2, 3, 4, 6, 7)			# côté 5 (le sud, à 270 degrés) : pas de porte
	function Get-SidePoint($Polygon, [int]$Side, [double]$T)
	{
		$a = $Polygon[$Side % $sides]
		$b = $Polygon[($Side + 1) % $sides]
		return , @(($a[0] + ($b[0] - $a[0]) * $T), ($a[1] + ($b[1] - $a[1]) * $T))
	}
	for ($g = 0; $g -lt $gates.Count; $g++)
	{
		# Un pan de mur va de la fin d'une porte au début de la suivante, en passant les coins.
		$from = $gates[$g]
		$to = $gates[($g + 1) % $gates.Count]
		if ($to -le $from) { $to += $sides }
		$outside = New-Object System.Collections.ArrayList
		$inside = New-Object System.Collections.ArrayList
		[void]$outside.Add((Get-SidePoint $outer $from (0.5 + $gateHalf)))
		[void]$inside.Add((Get-SidePoint $inner $from (0.5 + $gateHalf)))
		for ($corner = $from + 1; $corner -le $to; $corner++)
		{
			[void]$outside.Add($outer[$corner % $sides])
			[void]$inside.Add($inner[$corner % $sides])
		}
		[void]$outside.Add((Get-SidePoint $outer $to (0.5 - $gateHalf)))
		[void]$inside.Add((Get-SidePoint $inner $to (0.5 - $gateHalf)))
		$inside.Reverse()
		Add-Border ($outside.ToArray() + $inside.ToArray()) $rampart $walk "MARBLE1"
	}

	# La prairie : le temple au centre (quatre colonnes à contourner), sept arbres autour,
	# et des candélabres de part et d'autre de chaque porte.
	Add-Thing 0 0 1 90
	for ($i = 0; $i -lt 4; $i++) { $p = Get-Polar 210 (45 + 90 * $i); Add-Thing $p[0] $p[1] 30 }
	for ($i = 0; $i -lt 7; $i++) { $p = Get-Polar 540 (90 + 360.0 * $i / 7); Add-Thing $p[0] $p[1] 54 }
	foreach ($gate in $gates)
	{
		foreach ($side in @(-1, 1)) { $p = Get-Polar 770 (45 * ($gate + 1) + $side * 9); Add-Thing $p[0] $p[1] 35 }
	}

	# Le champ : arbres morts au milieu des côtés, torches bleues dans les coins.
	for ($i = 0; $i -lt 8; $i++)
	{
		$tree = Get-Polar 1250 (45 * $i)
		Add-Thing $tree[0] $tree[1] 43
		$torch = Get-Polar 1440 (22.5 + 45 * $i)
		Add-Thing $torch[0] $torch[1] 44
		$spawn = Get-Polar 1330 (22.5 + 45 * $i)
		Add-Thing $spawn[0] $spawn[1] 30001
		$bank = Get-Polar 990 (22.5 + 45 * $i)
		Add-Thing $bank[0] $bank[1] 30001
	}
}

else
{
	# Le vestibule : trois bandes du nord au sud (la plaine, l'Achéron, l'autre rive),
	# qui touchent toutes le mur d'enceinte. Coins coupés : pas de coin où se faire coincer.
	$plain = New-Sector 0 "RROCK04" 168 0xE0D8D0 384		# la plaine de cendre, où courent les tièdes
	$river = New-Sector -16 "FWATER4" 160 0x98D0B0 384	# l'Achéron
	$shore = New-Sector 0 "RROCK03" 136 0xD0C0B8 384		# l'autre rive

	# Contour de chaque bande, dans le sens horaire (la face avant des murs regarde dedans).
	# Le côté marqué « vers » une autre bande est un passage (une marche), pas un mur.
	function Add-Band($Points, [int]$Sector, $Walls)
	{
		for ($i = 0; $i -lt $Points.Count; $i++)
		{
			$a = $Points[$i]
			$b = $Points[($i + 1) % $Points.Count]
			$wall = $Walls[$i]
			if ($wall -is [int]) { Add-Pass (V $a[0] $a[1]) (V $b[0] $b[1]) $Sector $wall "ASHWALL2" }
			elseif ($wall) { Add-Wall (V $a[0] $a[1]) (V $b[0] $b[1]) $Sector $wall }
		}
	}
	# La plaine, avec au nord l'alcôve de la porte de l'Enfer.
	Add-Band @(@(-1100, -340), @(-1100, 600), @(-800, 900), @(-160, 900), @(-160, 1060), @(160, 1060), @(160, 900), @(800, 900), @(1100, 600), @(1100, -340)) $plain `
		@("ASHWALL2", "ASHWALL2", "ASHWALL2", "SP_DUDE4", "BIGDOOR7", "SP_DUDE4", "ASHWALL2", "ASHWALL2", "ASHWALL2", $river)
	# L'Achéron ; son bord nord est déjà posé avec la plaine.
	Add-Band @(@(-1100, -560), @(-1100, -340), @(1100, -340), @(1100, -560)) $river @("ASHWALL2", $null, "ASHWALL2", $shore)
	# L'autre rive ; son bord nord est déjà posé avec le fleuve.
	Add-Band @(@(-1100, -600), @(-1100, -560), @(1100, -560), @(1100, -600), @(800, -900), @(-800, -900)) $shore `
		@("ASHWALL2", $null, "ASHWALL2", "ASHWALL2", "ASHWALL2", "ASHWALL2")

	# Rochers à contourner : un au centre, quatre sur les côtés.
	foreach ($rock in @(@(0, 300, 110), @(-560, 480, 80), @(560, 480, 80), @(-640, 20, 90), @(640, 20, 90)))
	{
		Add-Hole (Get-Rock $rock[0] $rock[1] $rock[2]) $plain "ASHWALL4"
	}

	# Départ sous la porte, face à l'Achéron ; torches bleues de part et d'autre.
	Add-Thing 0 980 1 270
	Add-Thing -220 860 44
	Add-Thing 220 860 44
	foreach ($p in @(@(-880, 260), @(880, 260), @(-320, -250), @(320, -250))) { Add-Thing $p[0] $p[1] 43 }
	foreach ($p in @(@(-700, -760), @(700, -760))) { Add-Thing $p[0] $p[1] 70 }
	foreach ($p in @(@(-500, -750), @(0, -780), @(500, -750), @(-960, 350), @(960, 350), @(-960, -150), @(960, -150), @(-700, 780), @(700, 780)))
	{
		Add-Thing $p[0] $p[1] 30001
	}
}

# --- Écriture du WAD : marqueur de carte, TEXTMAP, ENDMAP ------------------------

$textmap = 'namespace = "zdoom";' + "`n" + $vertexText.ToString() + $lineText.ToString() + $sideText.ToString() + $sectorText.ToString() + $thingText.ToString()
$data = [Text.Encoding]::ASCII.GetBytes($textmap)
$lumps = @(
	@{ Name = $Map.ToUpper(); Data = [byte[]]@() },
	@{ Name = "TEXTMAP"; Data = $data },
	@{ Name = "ENDMAP"; Data = [byte[]]@() }
)

$out = if ($Output) { $Output } else { Join-Path $SrcDir "maps\$($Map.ToUpper()).wad" }
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
$stream = [IO.File]::Create($out)
$writer = [IO.BinaryWriter]::new($stream)
try
{
	$writer.Write([Text.Encoding]::ASCII.GetBytes("PWAD"))
	$writer.Write([int]$lumps.Count)
	$writer.Write([int](12 + $data.Length))	# position du répertoire, après les données
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
"{0} généré ({1} : {2} sommets, {3} secteurs, {4} octets)" -f $out, $Shape, $script:vertexCount, $script:sectorCount, (Get-Item $out).Length
