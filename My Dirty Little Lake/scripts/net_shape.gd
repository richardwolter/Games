## The cast net's shape, drawn by rule (2026-10-02, `/grill-me` with Richard; picked off
## `tools/last_net_mockup.png`, look A).
##
## The net is a surface: `rho` 0 at the crown to 1 at the rim, and `theta` round it. Lying on
## the water it is a low dome over the mouth's 2:1 ellipse. Hauled it is laid out again,
## not bent as a picture:
##
##   - the crown leads towards the rope (`LEAD_OUT`), on the water: nothing lifts it, and the
##     dome flattens out under the haul (Richard, 2026-10-02: a big net reeled in "looks like
##     it's being pulled by a crane from top, it should drag on the lake line")
##   - the rim pulls into a pear: its front tip just ahead of the crown (`TIP_GAP`), its back
##     half dragging behind (`RIM_BACK`, `REAR`), narrow across the pull (`PURSE_ACROSS`)
##     and narrowest at the front where the bridle gathers it (`PINCH`)
##   - so the strands to the front are short and the ones to the back long: the cells stretch
##     along the pull, as a net's do
##   - the back of the bag sinks and spreads with the load (`SAG`, `SPREAD`) and swings a
##     little from side to side (`SWAY`); the rim ripples as it drags (`CastNet.HAUL_RIPPLE`)
##
## `at` is the one function both halves of the drawing use, so it is written twice: here for
## what the CPU places against the net (the horn, the bridle, the catch), and in
## `shaders/net_mesh.gdshader`'s `shape` for every vertex of the mesh. **Change them
## together.** The shader also works out the mesh itself per pixel; nothing here does.
class_name NetShape
extends RefCounted

const SHADER := preload("res://shaders/net_mesh.gdshader")

## Cells, in plane world px (on screen a cell is that wide and half that tall). Fixed for a
## cast: a wider net has more cells, not bigger ones; a net pursing shut has the same cells,
## drawn smaller, which is what gathering looks like.
const CELL := 12.0
## How high the crown stands over the rim on a net lying on the water, as a share of the
## mouth's half-width, and never more than `DOME_MOST` px: a net lies on the water, and a
## wide one domed in proportion stood up like a tent.
const DOME := 0.16
const DOME_MOST := 8.0

const LEAD_OUT := 0.35
const RIM_BACK := 0.2
const TIP_GAP := 0.1
const REAR := 0.85
const PURSE_ACROSS := 0.32
const PINCH := 0.55
const SAG := 0.22
const SPREAD := 0.18
const SWAY := 0.1
## A thrown net dangles (2026-10-02, Richard: "it shouldn't be a straight circle, it should be
## dangly"): its skirt streams out behind the way it flies (`TRAIL` of the half-width at the
## back) and tucks in at the front (`TUCK`), and its rim hangs in lobes, `LOBES` round it,
## drooping up to `DANGLE` of the half-width below the plane, the trailing side the most, all
## of it flapping on `flap`. `flutter` is how much of this is on: 1 leaving the hand, easing
## off as it opens and gone once it has settled on the water.
const TRAIL := 0.38
const TUCK := 0.16
const DANGLE := 0.2
const LOBES := 5.0

## Screen px between neighbouring strands of one family before the mesh is thinned: every
## other strand under it, then every fourth, every eighth. Where the bridle gathers the
## front of the bag the cord would otherwise be a solid wedge.
const MIN_GAP := 3.5
## The lead beads on the rim: one every this many plane px of the open rim.
const BEAD_EVERY := 9.0

## The mesh: rings out from the crown and segments round. Positions are worked out on the
## GPU; these only lay the triangles out in (rho, theta). Past the rim by `RIM_OUT` px, so
## the beads and the shade under the rim have pixels to land on.
const RINGS := 14
const SEGMENTS := 64
const RIM_OUT := 6.0

## The cord: a lighter brown than the hand line (Richard), a lit top row, the far side seen
## through the mesh a step down, and a dark pixel under every strand where it lies on the
## water. Lead for the beads. Gold for a lucky cast, the finds' own.
const CORD := Color8(168, 124, 76)
const CORD_LIT := Color8(204, 162, 108)
const CORD_BACK := Color8(116, 80, 46)
const SHADE := Color8(44, 29, 17)
const LEAD_DARK := Color8(30, 32, 38)
const LEAD_MID := Color8(78, 82, 92)
const LEAD_LIT := Color8(138, 144, 156)

## A lucky cast (2026-10-02, `/grill-me` with Richard, look B off
## `tools/last_net_lucky_mockup.png`; the flat gold cord before it read as ugly): the mesh
## stays tan; the rim cord and its beads go gold, a ramp from `GOLD_DEEP` to `GOLD_PALE` off
## the finds' own gold; the gold creeps in from the rim over `FADE_CELLS` cells; a burst of
## light runs round the rim as it lands (both ways from the front over `BURST_RUN` s, a
## `BURST_TAIL` radian tail, gone `BURST_FADE` after) and a glint `GLINT_WIDE` of the net
## wide sweeps it diagonally. The burst and glint numbers are written again in the shader.
## The stars and sparks are `CastNet.LuckStars`.
const GOLD_DEEP := Color8(122, 76, 18)
const GOLD_LOW := Color8(196, 136, 34)
const GOLD := Color8(240, 190, 64)
const GOLD_LIT := Color8(255, 226, 128)
const GOLD_PALE := Color8(255, 244, 196)
const GOLD_SHADE := Color8(70, 40, 8)
const FADE_CELLS := 2.2
## A lucky rim cord runs this many px either side of its line (three deep; plain is 1, two).
const GOLD_RIM_HALF := 1.5
const BURST_RUN := 0.4
const BURST_TAIL := 1.2
const BURST_FADE := 0.35
const GLINT_WIDE := 0.24

## Half-width of the mouth as drawn, in world px, and the open mouth the cells are cut for.
var w: float = 40.0
var w_open: float = 40.0
## The dome's height over the rim, world px.
var h: float = 6.4
## Which way the rope pulls, on the plane (screen y doubled), unit length.
var pull := Vector2(-1.0, 0.0)
## 0 lying, 1 hauled right over; how full the bag is; the swing, -1 to 1.
var haul: float = 0.0
var load: float = 0.0
var sway: float = 0.0
## Flight only: the rim flattened onto the plane, and a wobble round it as it opens.
var squash: float = 1.0
var wobble: float = 0.0
var wob_phase: float = 0.0
## The dangle (`TRAIL`, `DANGLE`): how much is on, which way the net is flying on the plane
## (screen y doubled, unit length) and the flap's phase.
var flutter: float = 0.0
var trail := Vector2(1.0, 0.0)
var flap: float = 0.0
var gold: bool = false
## Seconds since a lucky net landed (the burst), and the glint's phase 0 to 1; -1 for none.
var landed: float = -1.0
var glint: float = -1.0


## A net lying open on the water, `half` px across its half-width.
static func lying(half: float) -> NetShape:
	var s := NetShape.new()
	s.w = half
	s.w_open = half
	s.h = minf(half * DOME, DOME_MOST)
	return s


## Where (`rho`, `theta`) on the net is drawn, relative to the mouth's middle on the water.
func at(rho: float, theta: float) -> Vector2:
	var heading := atan2(pull.y, pull.x)
	var cf := cos(theta - heading)
	var sf := sin(theta - heading)
	var front := maxf(cf, 0.0)
	var back := maxf(-cf, 0.0)
	var wob := 1.0 + wobble * sin(3.0 * theta + wob_phase) + wobble * 0.5 * sin(5.0 * theta - wob_phase)
	var tf := cos(theta - atan2(trail.y, trail.x))
	wob *= 1.0 + flutter * (TRAIL * maxf(-tf, 0.0) - TUCK * maxf(tf, 0.0))
	var mid := -RIM_BACK * haul
	var reach_front := (1.0 - haul) + haul * (LEAD_OUT + RIM_BACK + TIP_GAP)
	var reach_back := (1.0 - haul) + haul * REAR
	var along_r := mid + cf * (reach_front if cf > 0.0 else reach_back) * wob
	var across_r := ((1.0 - PURSE_ACROSS * haul) * (1.0 - PINCH * haul * pow(front, 1.5))
		* (1.0 + SPREAD * load * back) * sf * wob)
	var crown_a := LEAD_OUT * haul
	var s := pow(maxf(rho, 0.0), 1.0 + 0.35 * haul)
	var a := crown_a + (along_r - crown_a) * s
	var b := across_r * s + SWAY * haul * sway * rho * rho * clampf(-cf * 0.5 + 0.5, 0.0, 1.0)
	var across := Vector2(-pull.y, pull.x)
	var plane := (pull * a + across * b) * w
	var z := h * pow(maxf(1.0 - rho, 0.0), 1.4)
	z -= SAG * w * load * sin(PI * clampf(rho, 0.0, 1.0)) * (0.35 + 0.65 * back)
	z -= flutter * DANGLE * w * rho * rho * (0.5 + 0.5 * sin(LOBES * theta + flap)) \
		* (0.55 + 0.45 * maxf(-tf, 0.0))
	return Vector2(plane.x, plane.y * 0.5 * squash - z)


## Set a material's uniforms to this shape.
func push(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter(&"w", w)
	mat.set_shader_parameter(&"h", h)
	mat.set_shader_parameter(&"pull", pull)
	mat.set_shader_parameter(&"haul", haul)
	mat.set_shader_parameter(&"load", load)
	mat.set_shader_parameter(&"sway", sway)
	mat.set_shader_parameter(&"squash", squash)
	mat.set_shader_parameter(&"wobble", wobble)
	mat.set_shader_parameter(&"wob_phase", wob_phase)
	mat.set_shader_parameter(&"flutter", flutter)
	mat.set_shader_parameter(&"trail", trail)
	mat.set_shader_parameter(&"flap", flap)
	mat.set_shader_parameter(&"radial_cells", w_open / CELL)
	mat.set_shader_parameter(&"n_rim", float(rim_spokes(w_open)))
	mat.set_shader_parameter(&"max_lvl", float(levels(w_open)))
	mat.set_shader_parameter(&"bead_count", float(beads(w_open)))
	mat.set_shader_parameter(&"rim_out", 1.0 + RIM_OUT / maxf(w_open, 1.0))
	mat.set_shader_parameter(&"min_gap", MIN_GAP)
	mat.set_shader_parameter(&"cord", CORD)
	mat.set_shader_parameter(&"cord_lit", CORD_LIT)
	mat.set_shader_parameter(&"cord_back", CORD_BACK)
	mat.set_shader_parameter(&"shade", SHADE)
	mat.set_shader_parameter(&"lucky", 1.0 if gold else 0.0)
	mat.set_shader_parameter(&"landed", landed)
	mat.set_shader_parameter(&"glint", glint)
	mat.set_shader_parameter(&"fade_cells", FADE_CELLS)
	mat.set_shader_parameter(&"rim_half", GOLD_RIM_HALF if gold else 1.0)
	mat.set_shader_parameter(&"gold_deep", GOLD_DEEP)
	mat.set_shader_parameter(&"gold_low", GOLD_LOW)
	mat.set_shader_parameter(&"gold", GOLD)
	mat.set_shader_parameter(&"gold_lit", GOLD_LIT)
	mat.set_shader_parameter(&"gold_pale", GOLD_PALE)
	mat.set_shader_parameter(&"gold_shade", GOLD_SHADE)
	mat.set_shader_parameter(&"lead_dark", LEAD_DARK)
	mat.set_shader_parameter(&"lead_mid", LEAD_MID)
	mat.set_shader_parameter(&"lead_lit", LEAD_LIT)


## How many spokes the rim has: a cell apart round the open rim, a multiple of 32 so every
## halving towards the crown and every thinning lands on whole strands.
static func rim_spokes(open_half: float) -> int:
	return maxi(32, int(round(TAU * open_half / CELL / 32.0)) * 32)


## How many times the spoke count halves on the way in: while a level still has eight
## spokes and its outer ring is a cell and a half out from the crown.
static func levels(open_half: float) -> int:
	var n := rim_spokes(open_half)
	var hi := 1.0
	var lvl := 0
	while n >= 16 and hi * 0.5 * open_half >= CELL * 1.5:
		n /= 2
		hi *= 0.5
		lvl += 1
	return lvl


static func beads(open_half: float) -> int:
	return maxi(8, int(round(TAU * open_half / BEAD_EVERY / 4.0)) * 4)


static var _meshes := {}


## The mesh for a net cut for `open_half`: rest positions (only ever used for the draw's
## bounds — the vertex shader lays every point out again), (rho, theta) in the UVs, and
## triangles ordered far side first, so where a bell folds over itself the near side is
## drawn over the far. One degenerate triangle stands at the corners of the furthest the net
## can reach, flagged by a negative rho, so the canvas never culls a net bent past its rest.
static func mesh(open_half: float) -> Dictionary:
	var key := int(round(open_half))
	if _meshes.has(key):
		return _meshes[key]
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var out := 1.0 + RIM_OUT / maxf(open_half, 1.0)
	# RINGS rings to the rim, then one past it, then a crown point for every wedge (its own,
	# carrying the wedge's bearing, or the fan would smear one bearing across all of them).
	var rings: Array[float] = []
	for i in range(1, RINGS + 1):
		rings.append(float(i) / float(RINGS))
	rings.append(out)
	for rho in rings:
		for j in SEGMENTS + 1:
			var theta := TAU * float(j) / float(SEGMENTS)
			points.append(Vector2(cos(theta), sin(theta) * 0.5) * rho * open_half)
			uvs.append(Vector2(rho, theta))
	var tris: Array = []
	var row := SEGMENTS + 1
	for j in SEGMENTS:
		var t := TAU * (float(j) + 0.5) / float(SEGMENTS)
		var crown := points.size()
		points.append(Vector2.ZERO)
		uvs.append(Vector2(0.0, t))
		tris.append([sin(t) * 0.5 / float(RINGS), PackedInt32Array([crown, j, j + 1])])
	for r in rings.size() - 1:
		for j in SEGMENTS:
			var a := r * row + j
			var b := a + 1
			var c := a + row
			var d := c + 1
			var t := TAU * (float(j) + 0.5) / float(SEGMENTS)
			var key_y := sin(t) * (rings[r] + rings[r + 1]) * 0.5
			tris.append([key_y, PackedInt32Array([a, c, b, b, c, d])])
	tris.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var indices := PackedInt32Array()
	for tri: Array in tris:
		indices.append_array(tri[1])
	# The bounds: far enough for a full haul, a throw's dome and a sag.
	var base := points.size()
	for corner: Vector2 in [Vector2(-1.6, -1.4), Vector2(1.6, -1.4), Vector2(0.0, 1.2)]:
		points.append(corner * open_half)
		uvs.append(Vector2(-1.0, 0.0))
	indices.append_array(PackedInt32Array([base, base + 1, base + 2]))
	var made := {"points": points, "uvs": uvs, "indices": indices}
	_meshes[key] = made
	return made


## Add the net to `item`'s draw list at `origin`, with `material` already on the item.
static func draw_into(item: CanvasItem, origin: Vector2, open_half: float) -> void:
	var made := mesh(open_half)
	item.draw_set_transform(origin, 0.0, Vector2.ONE)
	RenderingServer.canvas_item_add_triangle_array(
		item.get_canvas_item(), made["indices"], made["points"],
		PackedColorArray([Color.WHITE]), made["uvs"]
	)
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
