extends RefCounted
## Procedural 2D skeleton for the Mooswinkel woodlings.
##
## A small joint hierarchy (feet, hips, pelvis, torso, shoulders, elbows,
## hands, neck, head) lives in a local 3D frame: x = the character's right,
## y = forward, z = up. Each frame is projected into the isometric view
## (ground plane squashed 2:1, like the buildings) for the current facing
## angle, and body parts are drawn back-to-front by depth.
##
## Because every view is produced from the same skeleton, proportions,
## clothing, foot baseline and the tool hand are identical in all eight
## directions. Nothing is ever mirrored: the axe stays in the right hand.
##
## Poses are authored as discrete frames (see pose()); the timing of these
## frames is defined in anim_defs.gd.

const AnimDefs = preload("res://scripts/anim/anim_defs.gd")

const ISO := 0.5
const OUTLINE := Color("4b2f1e")
const PIV_Z := 10.0
const HIP_W := 2.5
const THIGH := 5.4
const SHIN := 5.2
const ANKLE_Z := 1.5
const UPPER_ARM := 4.6
const FOREARM := 4.5
const SHOULDER := Vector3(5.2, 0.0, 10.0)
const HEAD_C := Vector3(0.0, 0.3, 20.6)
const HEAD_R := 8.4
const CAPE_SEGMENTS := 12
const TOOL_LEN := {"rod": 19.0, "axe": 12.5, "pick": 12.5, "sickle": 6.0, "can": 4.0, "saw": 11.0, "ladle": 10.0, "smoker": 4.0, "hammer": 8.0, "trowel": 6.0}

const PALETTES := [
	{"cloak": Color("7f9c3d"), "cloak2": Color("5f8b57"), "cap": Color("8b5a2e"), "hair": Color("b4652d"), "tunic": Color("cfae66"), "skin": Color("f2c897"), "boot": Color("7a4a2a"), "pants": Color("7d6a3e")},
	{"cloak": Color("4f8f85"), "cloak2": Color("6ea489"), "cap": Color("7b4c29"), "hair": Color("8d4c27"), "tunic": Color("d8bd7d"), "skin": Color("eec08e"), "boot": Color("6b4127"), "pants": Color("6f6440")},
	{"cloak": Color("c47b33"), "cloak2": Color("a9612c"), "cap": Color("704427"), "hair": Color("cf913d"), "tunic": Color("d6b878"), "skin": Color("f4cfa2"), "boot": Color("74462a"), "pants": Color("6e5b38")},
	{"cloak": Color("9c5560"), "cloak2": Color("7e9047"), "cap": Color("8a5934"), "hair": Color("6c3e22"), "tunic": Color("cdb07a"), "skin": Color("e9b98a"), "boot": Color("6a3f26"), "pants": Color("72603b")},
	{"cloak": Color("6c8f3a"), "cloak2": Color("b39a3e"), "cap": Color("94603a"), "hair": Color("a05a2c"), "tunic": Color("c9a35d"), "skin": Color("f0c28f"), "boot": Color("7c4b2b"), "pants": Color("6a5e3a")},
	# Specialists: distinct, recognisable outfits.
	{"cloak": Color("3f6b33"), "cloak2": Color("53803c"), "cap": Color("5e3a20"), "hair": Color("d0a050"), "tunic": Color("a0743e"), "skin": Color("eec08e"), "boot": Color("4e2f1b"), "pants": Color("5a4a2c")},
	{"cloak": Color("8dbb52"), "cloak2": Color("e0b8c8"), "cap": Color("a8743e"), "hair": Color("e2b45a"), "tunic": Color("f0dca0"), "skin": Color("f6d2a8"), "boot": Color("8a5a34"), "pants": Color("7d7046")},
	{"cloak": Color("7d8783"), "cloak2": Color("98a19a"), "cap": Color("6a5a4a"), "hair": Color("5a4636"), "tunic": Color("b9a78a"), "skin": Color("e4b487"), "boot": Color("4f4034"), "pants": Color("5f584c")},
	{"cloak": Color("b5682f"), "cloak2": Color("8a4e26"), "cap": Color("7a4a26"), "hair": Color("8a3f1e"), "tunic": Color("d9b77a"), "skin": Color("efc392"), "boot": Color("5d3820"), "pants": Color("6b5634")},
	{"cloak": Color("efe6cf"), "cloak2": Color("d8c9a4"), "cap": Color("c9945a"), "hair": Color("b3743a"), "tunic": Color("f4ead2"), "skin": Color("f3c99c"), "boot": Color("7a4a2a"), "pants": Color("8a7a5a")},
	{"cloak": Color("e3a72f"), "cloak2": Color("4a3a24"), "cap": Color("b07a2e"), "hair": Color("6b3d22"), "tunic": Color("e9d08e"), "skin": Color("f0c28f"), "boot": Color("6a4426"), "pants": Color("5e4c30")},
	{"cloak": Color("6f8f7a"), "cloak2": Color("9a7fb0"), "cap": Color("7c6a8a"), "hair": Color("c4c0b0"), "tunic": Color("d8d0b8"), "skin": Color("ecc090"), "boot": Color("5a4434"), "pants": Color("6a6252")},
	{"cloak": Color("3f5f8a"), "cloak2": Color("c9a03f"), "cap": Color("3a3048"), "hair": Color("2e2218"), "tunic": Color("cdb57a"), "skin": Color("e8b888"), "boot": Color("3a2a1c"), "pants": Color("4a4436")},
]

# Per-draw state.
var f := Vector2(0, 1)
var r := Vector2(-1, 0)
var s := 1.0
var pal: Dictionary = PALETTES[0]
var pd: Dictionary = {}
var ci: CanvasItem

# ---------------------------------------------------------------- pose data

static func base_pose() -> Dictionary:
	return {
		"bz": 0.0, "sway": 0.0, "lean": 0.0, "twist": 0.0, "hy": 0.0, "hp": 0.0,
		"fl": Vector3(-HIP_W, 0.4, 0.0), "fr": Vector3(HIP_W, -0.2, 0.0),
		"hl": Vector3(-5.9, 0.9, 3.2), "hr": Vector3(5.9, 0.9, 3.2),
		"tool": "", "td": Vector3(0, 0, -1), "item": "", "ia": Vector3(0, 5.5, 5.0),
		"blink": false, "mouth": 0, "sit": false, "back_tool": "", "fill": 0.0,
	}

## Pose for animation `anim` at frame `k`. `u` is the fractional cycle used
## by distance-driven animations (k / frames when quantised).
static func pose(anim: String, k: int, extra := {}) -> Dictionary:
	var p := base_pose()
	match anim:
		"walk", "carry_walk":
			var frames := AnimDefs.frame_count(anim)
			_walk(p, float(k) / frames, anim == "carry_walk")
		"idle":
			var breath := sin(float(k) / 8.0 * TAU)
			p.bz = 0.22 * breath
			p.hl = Vector3(-5.9, 0.9 + 0.2 * breath, 3.2 + 0.15 * breath)
			p.hr = Vector3(5.9, 0.9 - 0.2 * breath, 3.2 + 0.15 * breath)
			p.blink = k == 6
			p.hp = 0.04 * breath
		"look":
			var yaw: float = [0.0, 0.35, 0.65, 0.35, 0.0, -0.35, -0.65, -0.35][k]
			p.hy = yaw
			p.twist = yaw * 0.18
			p.hp = -0.06
			p.hl = Vector3(-5.6, 1.6, 4.0)
			p.hr = Vector3(5.6, 1.6, 4.0)
		"rest":
			_sit(p, k)
		"carry_idle":
			_carry_arms(p, sin(float(k) / 4.0 * TAU) * 0.2)
		"draw_tool", "stow_tool":
			_draw_tool(p, k if anim == "draw_tool" else 3 - k, extra.get("tool", "axe"))
		"chop":
			_swing(p, k, "axe", 13.5)
		"mine":
			_swing(p, k, "pick", 7.5)
		"sow":
			_sow(p, k)
		"water":
			_water(p, k)
		"reap":
			_reap(p, k)
		"pick":
			_pick(p, k)
		"pickup":
			_lift(p, k, false)
		"putdown":
			_lift(p, 5 - k, true)
		"saw":
			_saw(p, k)
		"pour":
			_pour(p, k)
		"knead":
			_knead(p, k)
		"stir":
			_stir(p, k)
		"bees":
			_bees(p, k)
		"serve":
			_serve(p, k)
		"plant":
			_plant(p, k)
		"cast":
			_cast(p, k)
		"fish_wait":
			_fish_wait(p, k)
		"reel":
			_reel(p, k)
	for key in extra:
		if key in ["item", "back_tool", "fill"]: p[key] = extra[key]
	if anim in ["carry_walk", "carry_idle"] and p.item == "": p.item = "logs"
	if anim in ["pickup", "putdown"]:
		# The carried load exists only on the carried side of the event frame.
		var has_item: bool = (k >= 3) if anim == "pickup" else (k < 3)
		if not has_item: p.item = ""
	return p

static func _walk(p: Dictionary, u: float, carry: bool) -> void:
	var cycle: float = AnimDefs.ANIMS["carry_walk" if carry else "walk"].cycle
	var stride := cycle * 0.5
	var lift := 2.6 if not carry else 2.0
	p.fl = _foot(u, stride, lift, -HIP_W)
	p.fr = _foot(fmod(u + 0.5, 1.0), stride, lift, HIP_W)
	# Lowest at double support (feet apart), highest when legs pass.
	p.bz = 0.55 * (0.5 - 0.5 * cos(u * TAU * 2.0)) - 0.35
	p.sway = -0.45 * sin(u * TAU)
	p.lean = 0.07 if not carry else 0.02
	p.twist = 0.10 * cos(u * TAU)
	p.hp = 0.03 * cos(u * TAU * 2.0)
	if carry:
		_carry_arms(p, 0.25 * sin(u * TAU * 2.0))
	else:
		var swing := cos(u * TAU)
		# Right arm swings forward with the left foot.
		p.hr = Vector3(5.6, 3.4 * swing, 3.6 + 0.9 * maxf(swing, 0.0))
		p.hl = Vector3(-5.6, -3.4 * swing, 3.6 + 0.9 * maxf(-swing, 0.0))

## Stance: the foot moves back linearly at exactly body speed (planted on the
## ground). Swing: eased forward arc with lift.
static func _foot(q: float, stride: float, lift: float, side: float) -> Vector3:
	if q < 0.5:
		return Vector3(side, stride * 0.5 - (q / 0.5) * stride, 0.0)
	var w := (q - 0.5) / 0.5
	var e := w * w * (3.0 - 2.0 * w)
	return Vector3(side, -stride * 0.5 + stride * e, lift * sin(PI * w))

static func _carry_arms(p: Dictionary, bob: float) -> void:
	p.hl = Vector3(-3.4, 5.4, 6.6 + bob)
	p.hr = Vector3(3.4, 5.4, 6.6 + bob)
	p.ia = Vector3(0, 6.6, 7.4 + bob)

static func _sit(p: Dictionary, k: int) -> void:
	var breath := sin(float(k) / 8.0 * TAU)
	p.sit = true
	p.bz = -6.2
	p.fl = Vector3(-3.0, 6.2, 0.0)
	p.fr = Vector3(3.0, 6.6, 0.0)
	p.lean = -0.12 + 0.02 * breath
	p.hl = Vector3(-3.4, 6.0, 1.6)
	p.hr = Vector3(3.4, 6.2, 1.6)
	p.hp = 0.12 + 0.03 * breath
	p.blink = k >= 4

static func _draw_tool(p: Dictionary, k: int, tool: String) -> void:
	# 0 hand reaches over the shoulder, 1 grips, 2 tool comes forward, 3 ready.
	var keys := [
		[Vector3(4.2, -2.5, 12.0), Vector3(0, -0.3, 1), ""],
		[Vector3(3.0, -3.0, 13.5), Vector3(0.2, -0.6, 0.8), tool],
		[Vector3(4.8, 2.0, 9.0), Vector3(0.1, 0.7, 0.7), tool],
		[Vector3(3.2, 5.0, 4.5), Vector3(0, 0.95, -0.25), tool],
	]
	var key: Array = keys[clampi(k, 0, 3)]
	p.hr = key[0]
	p.td = key[1].normalized()
	p.tool = key[2]
	if p.tool == "": p.back_tool = tool
	if k >= 3 and tool in ["axe", "pick"]: p.hl = key[0] - p.td * 3.4
	p.lean = 0.05

## Overhead two-handed swing (axe on a trunk, pick on a rock). Grip in torso
## frame, handle angle theta measured from straight up towards forward.
static func _swing(p: Dictionary, k: int, tool: String, strike_z: float) -> void:
	var low := strike_z - 13.5
	var keys := [
		# grip, theta (deg), lean, twist, bz
		[Vector3(1.0, 5.2, 3.0 + low * 0.5), 100.0, 0.06, 0.0, 0.0],
		[Vector3(1.6, 3.0, 7.5), 35.0, -0.04, 0.10, 0.1],
		[Vector3(1.9, 0.8, 12.6), -30.0, -0.14, 0.18, 0.25],
		[Vector3(1.9, -0.6, 13.8), -62.0, -0.20, 0.22, 0.35],
		[Vector3(1.3, 4.2, 10.0), 40.0, 0.10, 0.08, 0.0],
		[Vector3(0.9, 7.0, 3.8 + low * 0.55), 96.0 + absf(low) * 2.0, 0.26 + absf(low) * 0.02, 0.0, -0.7],
		[Vector3(0.9, 6.3, 4.4 + low * 0.5), 88.0 + absf(low) * 2.0, 0.20, 0.0, -0.4],
		[Vector3(1.0, 5.6, 3.4 + low * 0.5), 98.0, 0.10, 0.0, -0.1],
	]
	var key: Array = keys[k]
	var th := deg_to_rad(key[1])
	p.hr = key[0]
	p.td = Vector3(0, sin(th), cos(th))
	p.hl = key[0] - p.td * 3.4
	p.tool = tool
	p.lean = key[2]
	p.twist = key[3]
	p.bz = key[4]
	p.fl = Vector3(-HIP_W - 0.6, 2.2, 0)
	p.fr = Vector3(HIP_W + 0.6, -1.6, 0)
	p.hp = 0.10 if k >= 4 else -0.08
	p.blink = k == 5

static func _sow(p: Dictionary, k: int) -> void:
	p.item = "seedbag"
	p.hl = Vector3(-3.8, 3.6, 4.6)
	p.ia = Vector3(-3.0, 4.6, 4.6)
	var keys := [
		Vector3(-1.6, 4.4, 5.6), Vector3(-2.2, 4.4, 5.2), Vector3(-1.6, 4.6, 5.8),
		Vector3(2.6, 6.0, 7.0), Vector3(6.0, 7.2, 6.4), Vector3(8.0, 5.8, 5.2),
		Vector3(6.6, 3.0, 4.2), Vector3(3.2, 2.0, 4.0),
	]
	p.hr = keys[k]
	p.twist = [0.10, 0.12, 0.10, -0.05, -0.18, -0.24, -0.12, 0.02][k]
	p.lean = 0.10
	p.fl = Vector3(-HIP_W, 1.6, 0)
	p.fr = Vector3(HIP_W, -1.0, 0)
	p.hp = 0.12

static func _water(p: Dictionary, k: int) -> void:
	var tilt: float = [0.0, 0.25, 0.7, 0.95, 0.95, 0.9, 0.5, 0.15][k]
	p.tool = "can"
	p.hr = Vector3(3.2, 5.8 + tilt, 6.0 - tilt * 0.6)
	p.td = Vector3(0, cos(1.2 - tilt), -sin(1.2 - tilt) * 0.2).normalized()
	p.td = Vector3(0.0, 1.0, -tilt * 0.9).normalized()
	p.hl = Vector3(-2.0, 5.4, 7.0)
	p.lean = 0.10 + tilt * 0.10
	p.hp = 0.15

static func _reap(p: Dictionary, k: int) -> void:
	# Bend down; the left hand gathers stalks, the sickle sweeps right->left.
	var keys := [
		[Vector3(-2.0, 7.0, 1.0), Vector3(6.5, 4.5, 1.0), Vector3(1, 0.6, 0)],
		[Vector3(-1.0, 7.6, 0.4), Vector3(7.2, 5.5, 0.8), Vector3(0.8, 0.8, 0)],
		[Vector3(-0.4, 8.0, 0.0), Vector3(7.8, 6.0, 1.2), Vector3(0.6, 1.0, 0.2)],
		[Vector3(-0.4, 8.0, 0.0), Vector3(8.2, 4.8, 2.0), Vector3(0.9, 0.5, 0.3)],
		[Vector3(-0.4, 8.0, 0.0), Vector3(3.5, 8.2, 0.4), Vector3(-0.3, 1.0, 0)],
		[Vector3(-0.8, 7.8, 0.2), Vector3(-1.6, 8.0, 0.2), Vector3(-1.0, 0.4, 0)],
		[Vector3(-2.8, 6.0, 2.4), Vector3(1.0, 6.6, 1.4), Vector3(-0.4, 0.9, 0)],
		[Vector3(-3.6, 4.6, 3.4), Vector3(4.8, 5.0, 1.6), Vector3(0.7, 0.7, 0)],
	]
	var key: Array = keys[k]
	p.hl = key[0]
	p.hr = key[1]
	p.td = key[2].normalized()
	p.tool = "sickle"
	p.lean = 0.62
	p.bz = -2.6
	p.twist = [0.20, 0.24, 0.28, 0.30, 0.05, -0.18, -0.08, 0.10][k]
	p.fl = Vector3(-HIP_W - 1.0, 2.6, 0)
	p.fr = Vector3(HIP_W + 1.0, -1.4, 0)
	p.hp = -0.25

static func _pick(p: Dictionary, k: int) -> void:
	# Basket on the left arm; right hand plucks from the bush and drops in.
	p.item = "basket"
	p.hl = Vector3(-4.6, 3.4, 5.4)
	p.ia = Vector3(-4.8, 4.6, 4.2)
	var keys := [
		Vector3(4.0, 5.0, 5.0), Vector3(4.6, 8.0, 6.2), Vector3(4.2, 10.0, 6.6),
		Vector3(4.0, 10.4, 6.0), Vector3(3.6, 8.6, 6.6), Vector3(0.0, 6.4, 6.8),
		Vector3(-2.6, 5.0, 5.8), Vector3(1.0, 4.6, 5.0),
	]
	p.hr = keys[k]
	p.lean = [0.08, 0.16, 0.24, 0.26, 0.20, 0.10, 0.06, 0.06][k]
	p.twist = [0.0, 0.05, 0.10, 0.10, 0.05, -0.08, -0.16, -0.05][k]
	p.hp = 0.15
	p.fl = Vector3(-HIP_W, 1.6, 0)
	p.fr = Vector3(HIP_W, -0.6, 0)

static func _lift(p: Dictionary, k: int, placing: bool) -> void:
	# 0 stand, 1-2 bend down, 3 grip/release on the ground, 4-5 rise.
	var bend: float = [0.0, 0.35, 0.62, 0.70, 0.40, 0.08][k]
	p.lean = bend * 0.95
	p.bz = -bend * 3.6
	p.fl = Vector3(-HIP_W - 0.4, 1.8, 0)
	p.fr = Vector3(HIP_W + 0.4, -0.6, 0)
	if k <= 3:
		var down: float = bend / 0.70
		p.hl = Vector3(-3.4, lerpf(1.0, 6.6, down), lerpf(3.2, -1.6, down))
		p.hr = Vector3(3.4, lerpf(1.0, 6.6, down), lerpf(3.2, -1.6, down))
		p.ia = Vector3(0, lerpf(6.6, 7.6, down), lerpf(7.4, -1.0, down))
	else:
		var up := (k - 3) / 2.0
		p.hl = Vector3(-3.4, lerpf(6.6, 5.4, up), lerpf(-1.6, 6.6, up))
		p.hr = Vector3(3.4, lerpf(6.6, 5.4, up), lerpf(-1.6, 6.6, up))
		p.ia = Vector3(0, lerpf(7.6, 6.6, up), lerpf(-1.0, 7.4, up))
	p.hp = -0.2 * bend
	if placing: p.blink = false

static func _saw(p: Dictionary, k: int) -> void:
	# Two-handed bow saw pushed and pulled across a log in front.
	var push := sin(float(k) / 8.0 * TAU)
	p.tool = "saw"
	p.hr = Vector3(1.6, 5.0 + push * 2.6, 3.2)
	p.hl = Vector3(-1.2, 4.4 + push * 2.6, 3.6)
	p.td = Vector3(0, 1, -0.12).normalized()
	p.lean = 0.24 + push * 0.06
	p.twist = push * 0.05
	p.fl = Vector3(-HIP_W - 0.5, 2.2, 0)
	p.fr = Vector3(HIP_W + 0.5, -1.4, 0)
	p.hp = 0.2

static func _pour(p: Dictionary, k: int) -> void:
	# Lift a grain sack to the hopper and pour it.
	var keys := [
		[Vector3(-3.2, 5.6, 0.6), Vector3(3.2, 5.6, 0.6), Vector3(0, 6.6, 0.4), 0.50, -2.4],
		[Vector3(-3.4, 5.4, 3.4), Vector3(3.4, 5.4, 3.4), Vector3(0, 6.4, 3.6), 0.30, -1.2],
		[Vector3(-3.4, 5.0, 7.0), Vector3(3.4, 5.0, 7.0), Vector3(0, 6.2, 7.6), 0.06, 0.0],
		[Vector3(-3.2, 5.6, 11.0), Vector3(3.2, 5.6, 11.0), Vector3(0, 6.6, 12.0), -0.06, 0.3],
		[Vector3(-3.0, 7.0, 12.0), Vector3(3.0, 7.0, 12.0), Vector3(0, 8.2, 12.6), 0.02, 0.3],
		[Vector3(-3.0, 7.2, 11.4), Vector3(3.0, 7.2, 11.4), Vector3(0, 8.4, 11.8), 0.04, 0.2],
		[Vector3(-3.4, 5.6, 7.0), Vector3(3.4, 5.6, 7.0), Vector3(0, 6.4, 7.4), 0.10, 0.0],
		[Vector3(-3.4, 5.4, 3.0), Vector3(3.4, 5.4, 3.0), Vector3(0, 6.4, 3.2), 0.30, -1.2],
	]
	var key: Array = keys[k]
	p.hl = key[0]
	p.hr = key[1]
	p.ia = key[2]
	p.lean = key[3]
	p.bz = key[4]
	p.item = "sack_empty" if k == 5 else "sack"
	p.hp = -0.15 if k in [3, 4, 5] else 0.1

static func _knead(p: Dictionary, k: int) -> void:
	var press := 0.5 - 0.5 * cos(float(k) / 8.0 * TAU * 2.0)
	p.hl = Vector3(-2.0, 6.0 + press * 1.4, 4.0 - press * 1.6)
	p.hr = Vector3(2.0, 6.0 + press * 1.4, 4.0 - press * 1.6)
	p.lean = 0.18 + press * 0.12
	p.bz = -press * 0.5
	p.item = "dough"
	p.ia = Vector3(0, 7.4, 1.6)
	p.hp = 0.25

static func _stir(p: Dictionary, k: int) -> void:
	var a := float(k) / 8.0 * TAU
	p.tool = "ladle"
	p.hr = Vector3(1.4 + cos(a) * 1.8, 6.0 + sin(a) * 1.4, 5.8)
	p.td = Vector3(cos(a) * 0.15, 0.35, -1.0).normalized()
	p.hl = Vector3(-4.6, 2.6, 4.4)
	p.lean = 0.14
	p.twist = cos(a) * 0.06
	p.hp = 0.25

static func _bees(p: Dictionary, k: int) -> void:
	# Smoker in the left hand, lifting a honeycomb frame with the right.
	var lift: float = [0.0, 0.25, 0.6, 0.95, 1.0, 0.8, 0.4, 0.1][k]
	p.tool = "smoker"
	p.hl = Vector3(-4.4, 4.0, 5.0 + lift * 1.0)
	p.td = Vector3(0, 0.4, 1).normalized()
	p.hr = Vector3(2.6, 6.0, 3.6 + lift * 7.0)
	p.item = "comb"
	p.ia = p.hr + Vector3(-0.6, 0.6, 1.6)
	p.lean = 0.18 - lift * 0.22
	p.hp = 0.1 - lift * 0.35

static func _serve(p: Dictionary, k: int) -> void:
	var a := float(k) / 8.0 * TAU
	p.hr = Vector3(2.4 + cos(a) * 2.0, 6.2 + sin(a) * 1.2, 3.4)
	p.hl = Vector3(-4.2, 4.6, 3.6)
	p.item = "cloth"
	p.ia = p.hr + Vector3(0, 0.4, -0.6)
	p.lean = 0.22
	p.hp = 0.2

## Fishing. The rod is held in the right hand; the line ends in a float on
## the water about half a cell ahead (local y ~ 24).
const BOBBER := Vector3(0.8, 25.0, 0.0)

static func _rod(p: Dictionary, grip: Vector3, angle_deg: float, line: bool) -> void:
	var th := deg_to_rad(angle_deg)
	p.tool = "rod"
	p.hr = grip
	p.td = Vector3(0.12, sin(th), cos(th)).normalized()
	p.hl = grip - p.td * 3.0 + Vector3(-0.6, 0, 0)
	p.line = line
	p.bobber = BOBBER
	p.fl = Vector3(-HIP_W, 1.4, 0)
	p.fr = Vector3(HIP_W, -1.0, 0)

static func _cast(p: Dictionary, k: int) -> void:
	# grip, rod angle from vertical (deg, + = forward), lean, twist
	var keys := [
		[Vector3(2.4, 5.0, 6.0), 55.0, 0.04, 0.0],
		[Vector3(2.8, 2.6, 9.0), 10.0, -0.04, 0.10],
		[Vector3(3.0, 0.4, 12.0), -35.0, -0.12, 0.18],
		[Vector3(3.0, -0.6, 12.6), -60.0, -0.16, 0.22],
		[Vector3(2.6, 3.6, 11.0), 20.0, 0.06, 0.06],
		[Vector3(2.4, 6.0, 8.2), 62.0, 0.16, 0.0],
		[Vector3(2.4, 5.6, 7.0), 58.0, 0.10, 0.0],
		[Vector3(2.4, 5.2, 6.4), 56.0, 0.06, 0.0],
	]
	var key: Array = keys[k]
	_rod(p, key[0], key[1], k >= 5)
	p.lean = key[2]
	p.twist = key[3]
	p.hp = 0.12 if k >= 4 else -0.05

static func _fish_wait(p: Dictionary, k: int) -> void:
	var bob := sin(float(k) / 8.0 * TAU)
	var twitch := 4.0 if k == 3 else 0.0
	_rod(p, Vector3(2.2, 4.6, 5.4 + bob * 0.2), 58.0 + twitch, true)
	p.bz = 0.15 * bob
	p.hp = 0.18
	p.blink = k == 6
	p.bob_dip = 0.8 if k == 3 else 0.0

static func _reel(p: Dictionary, k: int) -> void:
	# Rod rises, the left hand winds the reel, the fish comes out at frame 6.
	var angles := [55.0, 45.0, 38.0, 32.0, 26.0, 20.0, 12.0, 18.0]
	_rod(p, Vector3(2.2, 4.2 - k * 0.15, 6.0 + k * 0.5), angles[k], k < 6)
	var a := float(k) / 8.0 * TAU * 2.0
	p.hl = p.hr - p.td * 2.6 + Vector3(-1.2 + cos(a) * 0.9, 0, sin(a) * 0.9)
	p.lean = -0.04 * k
	p.hp = 0.1 - 0.04 * k
	p.hooked = k >= 6
	if k >= 4: p.bobber = BOBBER * (1.0 - (k - 3) * 0.18)

static func _plant(p: Dictionary, k: int) -> void:
	# Kneel-bend with a trowel, set the sapling.
	var bend: float = [0.2, 0.45, 0.62, 0.68, 0.68, 0.62, 0.45, 0.25][k]
	p.lean = bend
	p.bz = -bend * 3.8
	p.tool = "trowel"
	p.hr = Vector3(2.0, 6.0 + bend * 2.0, lerpf(3.0, -1.4, bend / 0.68) + (0.8 if k == 4 else 0.0))
	p.td = Vector3(0, 0.5, -1).normalized()
	p.hl = Vector3(-2.2, 6.2 + bend * 1.6, lerpf(3.2, -1.0, bend / 0.68))
	p.fl = Vector3(-HIP_W - 0.6, 2.4, 0)
	p.fr = Vector3(HIP_W + 0.6, -1.4, 0)
	p.hp = -0.2

# ------------------------------------------------------------- projection

func _setup(canvas: CanvasItem, facing: float, scale_value: float, palette: int, pose_data: Dictionary) -> void:
	ci = canvas
	f = Vector2(sin(facing), cos(facing))
	r = Vector2(-cos(facing), sin(facing))
	s = scale_value
	pal = PALETTES[posmod(palette, PALETTES.size())]
	pd = pose_data

func P(v: Vector3) -> Vector2:
	var g := r * v.x + f * v.y
	return Vector2(g.x, g.y * ISO - v.z) * s

func depth(v: Vector3) -> float:
	return (r * v.x + f * v.y).y

## Torso frame -> local frame (lean about x, twist about z, then pelvis).
func T(v: Vector3) -> Vector3:
	var l: float = pd.lean
	var y1 := v.y * cos(l) + v.z * sin(l)
	var z1 := -v.y * sin(l) + v.z * cos(l)
	var t: float = pd.twist
	var x2 := v.x * cos(t) - y1 * sin(t)
	var y2 := v.x * sin(t) + y1 * cos(t)
	return Vector3(x2 + pd.sway, y2, z1 + PIV_Z + pd.bz)

## Direction in torso frame -> local frame (no translation).
func TD(v: Vector3) -> Vector3:
	return T(v) - T(Vector3.ZERO)

static func ik(a: Vector3, target: Vector3, l1: float, l2: float, hint: Vector3) -> Vector3:
	var to := target - a
	var d := clampf(to.length(), 0.01, l1 + l2 - 0.02)
	var dir := to.normalized() if to.length() > 0.001 else Vector3(0, 0, -1)
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var bend := hint - dir * hint.dot(dir)
	if bend.length() < 0.001: bend = Vector3(0, 1, 0)
	return a + dir * along + bend.normalized() * h

# ------------------------------------------------------------------ drawing

## Draws one woodling with its feet at the canvas origin.
func draw(canvas: CanvasItem, pose_data: Dictionary, facing: float, scale_value := 1.0, palette := 0) -> void:
	_setup(canvas, facing, scale_value, palette, pose_data)
	var parts: Array = []
	# Shadow first, always.
	_shadow()
	var pelvis := Vector3(pd.sway, 0, PIV_Z + pd.bz)
	# Legs: drawn before the tunic, far leg first.
	var legs: Array = []
	for side in [-1, 1]:
		var hip := pelvis + Vector3(side * HIP_W, 0, -1.0)
		var foot: Vector3 = pd.fl if side < 0 else pd.fr
		var ankle := foot + Vector3(0, 0, ANKLE_Z)
		var knee_hint := Vector3(side * 0.15, 1, 0.0) if not pd.sit else Vector3(side * 0.1, 0.2, 1)
		var knee := ik(hip, ankle, THIGH, SHIN, knee_hint)
		legs.append([depth(ankle), hip, knee, ankle, foot])
	legs.sort_custom(func(a, b): return a[0] < b[0])
	for leg in legs: _leg(leg[1], leg[2], leg[3], leg[4])
	# Upper body parts are depth sorted.
	parts.append([0.0, "torso"])
	parts.append([6.0, "head"])
	for side in [-1, 1]:
		var sh := T(Vector3(side * SHOULDER.x, SHOULDER.y, SHOULDER.z))
		var hand: Vector3 = T(pd.hl if side < 0 else pd.hr)
		var elbow := ik(sh, hand, UPPER_ARM, FOREARM, TD(Vector3(side * 0.9, -0.5, -0.4)))
		var dep := (depth(hand) + depth(elbow)) * 0.5
		parts.append([dep * 1.4 + (0.05 if side > 0 else 0.0), "arm", sh, elbow, hand, side])
	for i in range(CAPE_SEGMENTS):
		var phi := (float(i) + 0.5) / CAPE_SEGMENTS * TAU
		var anchor := T(Vector3(sin(phi) * 5.6, cos(phi) * 4.8, 8.0))
		parts.append([depth(anchor), "cape", i])
	if f.y > 0.05: parts.append([5.9, "clasp"])
	if pd.get("scarf", false): parts.append([5.95, "scarf"])
	if pd.item != "":
		var ia := T(pd.ia)
		parts.append([depth(ia) * 1.3 + 0.3, "item", ia])
	if pd.back_tool != "":
		parts.append([depth(T(Vector3(0, -5, 6))) * 1.1, "back_tool"])
	var bag := T(Vector3(-5.2, 1.6, 2.4))
	parts.append([depth(bag) * 1.1 + 0.01, "bag", bag])
	parts.sort_custom(func(a, b): return a[0] < b[0])
	for part in parts:
		match part[1]:
			"torso": _torso()
			"head": _head()
			"arm": _arm(part[2], part[3], part[4], part[5])
			"cape": _cape(part[2])
			"clasp": _clasp()
			"scarf": _scarf()
			"item": _item(part[2])
			"back_tool": _back_tool()
			"bag": _bag(part[2])

## Fan-triangulated fill: robust for thin or self-overlapping projections
## (an edge-on cape segment must never make the renderer reject a polygon).
func _fan(points: PackedVector2Array, color: Color) -> void:
	var cols := PackedColorArray([color, color, color])
	for i in range(1, points.size() - 1):
		ci.draw_primitive(PackedVector2Array([points[0], points[i], points[i + 1]]), cols, PackedVector2Array())

func _poly(points: PackedVector2Array, color: Color, outline := true, width := 0.9) -> void:
	_fan(points, color)
	if outline:
		var closed := points.duplicate()
		closed.append(points[0])
		ci.draw_polyline(closed, OUTLINE, width * s * 0.7, true)

func _ellipse(c: Vector2, rx: float, ry: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := float(i) / n * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _capsule(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	ci.draw_line(a, b, OUTLINE, (width + 1.2) * s, true)
	ci.draw_circle(a, (width + 1.2) * 0.5 * s, OUTLINE)
	ci.draw_circle(b, (width + 1.2) * 0.5 * s, OUTLINE)
	ci.draw_line(a, b, color, width * s, true)
	ci.draw_circle(a, width * 0.5 * s, color)
	ci.draw_circle(b, width * 0.5 * s, color)

func _shadow() -> void:
	var c := P(Vector3(pd.sway * 0.5, 0.5, 0))
	var size := 1.0 if not pd.sit else 1.15
	_fan(_ellipse(c, 8.6 * s * size, 4.2 * s * size, 16), Color(0.16, 0.22, 0.12, 0.30))

func _leg(hip: Vector3, knee: Vector3, ankle: Vector3, foot: Vector3) -> void:
	var a := P(hip)
	var b := P(knee)
	var c := P(ankle)
	for seg in [[a, b], [b, c]]:
		ci.draw_line(seg[0], seg[1], OUTLINE, 4.6 * s, true)
	for pnt in [a, b, c]: ci.draw_circle(pnt, 2.3 * s, OUTLINE)
	for seg in [[a, b], [b, c]]:
		ci.draw_line(seg[0], seg[1], pal.pants, 3.4 * s, true)
	for pnt in [a, b, c]: ci.draw_circle(pnt, 1.7 * s, pal.pants)
	# Boot: rounded heel-to-toe capsule along the facing, then the shaft.
	var heel := P(foot + Vector3(0, -0.7, 1.1))
	var toe := P(foot + Vector3(0, 2.3, 0.9))
	ci.draw_line(heel, toe, OUTLINE, 4.4 * s, true)
	ci.draw_circle(heel, 2.2 * s, OUTLINE)
	ci.draw_circle(toe, 2.2 * s, OUTLINE)
	ci.draw_line(heel, toe, pal.boot, 3.2 * s, true)
	ci.draw_circle(heel, 1.6 * s, pal.boot)
	ci.draw_circle(toe, 1.6 * s, pal.boot)
	var top := P(ankle + Vector3(0, 0.2, 0.6))
	ci.draw_circle(top, 2.1 * s, OUTLINE)
	ci.draw_circle(top, 1.55 * s, pal.boot.darkened(0.08))
	ci.draw_circle(toe + Vector2(-0.5, -0.7) * s, 0.7 * s, pal.boot.lightened(0.28))

func _torso() -> void:
	var bottom := T(Vector3(0, 0.3, -0.6))
	var top := T(Vector3(0, 0.0, 10.4))
	var b := P(bottom)
	var t := P(top)
	# Silhouette width depends on how much of the front/side we see.
	var view_cos := absf(f.y)
	var wb := lerpf(4.8, 5.9, view_cos) * s
	var wt := lerpf(3.8, 4.7, view_cos) * s
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var light: Color = pal.tunic.lightened(0.12)
	var dark: Color = pal.tunic.darkened(0.18)
	for i in range(7):
		var a := PI + float(i) / 6.0 * PI
		pts.append(t + Vector2(cos(a) * wt, sin(a) * wt * 0.8))
		cols.append(light if i < 3 else dark)
	for i in range(9):
		var a := float(i) / 8.0 * PI
		pts.append(b + Vector2(cos(a) * wb, sin(a) * wb * 0.42))
		cols.append(dark if i < 4 else light)
	ci.draw_polygon(pts, cols)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUTLINE, 0.7 * s, true)
	# Strap across the chest and the acorn clasp, only from the front.
	if f.y > 0.15:
		var strap_a := T(Vector3(3.4, 3.9, 9.6))
		var strap_b := T(Vector3(-4.6, 3.6, 1.8))
		ci.draw_line(P(strap_a), P(strap_b), Color("6e4527"), 1.1 * s, true)

func _cape_ring(phi: float, radius: float, z: float, ry := 0.86) -> Vector3:
	return T(Vector3(sin(phi) * radius, cos(phi) * radius * ry, z))

func _cape_drop(phi: float) -> float:
	var back := (1.0 - cos(phi)) * 0.5
	return 4.6 + 7.6 * pow(back, 1.15)

## One segment of the leaf cape: continuous surface from the shoulders,
## ending in a pointed leaf at the hem. Segments facing away show the darker
## lining and are drawn behind the body.
func _cape(i: int) -> void:
	var p0 := float(i) / CAPE_SEGMENTS * TAU
	var p1 := float(i + 1) / CAPE_SEGMENTS * TAU
	var pm := (p0 + p1) * 0.5
	var top_z := 11.0
	var a0 := _cape_ring(p0, 4.4, top_z)
	var a1 := _cape_ring(p1, 4.4, top_z)
	var h0 := _cape_ring(p0, 7.0, top_z - _cape_drop(p0))
	var h1 := _cape_ring(p1, 7.0, top_z - _cape_drop(p1))
	var tip := _cape_ring(pm, 7.5, top_z - _cape_drop(pm) - 1.9)
	var normal := TD(Vector3(sin(pm), cos(pm), 0.25))
	var facing_cam := depth(normal) / maxf(normal.length(), 0.001)
	var base: Color = pal.cloak if i % 2 == 0 else pal.cloak2
	var color: Color
	if facing_cam < 0.0:
		color = base.darkened(0.42)
	else:
		# Soft light from the upper left of the screen.
		var lit := clampf(-P(normal).x / (s * 1.4), -1.0, 1.0)
		color = base.lightened(0.10 * lit) if lit > 0 else base.darkened(-0.14 * lit)
	var pts := PackedVector2Array([P(a0), P(a1), P(h1), P(tip), P(h0)])
	_fan(pts, color)
	ci.draw_polyline(PackedVector2Array([P(h0), P(tip), P(h1)]), OUTLINE, 0.6 * s, true)
	if facing_cam > 0.15:
		ci.draw_line(P(a0.lerp(a1, 0.5).lerp(tip, 0.45)), P(tip.lerp(a0.lerp(a1, 0.5), 0.12)), Color(color.lightened(0.25), 0.55), 0.5 * s, true)

## Knitted winter scarf around the neck with a hanging end.
func _scarf() -> void:
	var colors := [Color("b8473a"), Color("3f6f8f"), Color("d0a03a"), Color("6f8a3a"), Color("8f4a7a")]
	var c: Color = colors[int(pal.get("cap", Color.BLACK).r8 + pal.get("hair", Color.BLACK).g8) % colors.size()]
	var pts := PackedVector2Array()
	for i in range(12):
		var a := float(i) / 12.0 * TAU
		pts.append(P(T(Vector3(sin(a) * 4.6, cos(a) * 4.0, 11.8))))
	var center := P(T(Vector3(0, 0, 11.8)))
	for i in range(12):
		ci.draw_line(pts[i], pts[(i + 1) % 12], OUTLINE, 3.6 * s, true)
	for i in range(12):
		ci.draw_line(pts[i], pts[(i + 1) % 12], c, 2.6 * s, true)
	var end_a := T(Vector3(2.4, 3.8, 11.0))
	var end_b := T(Vector3(3.0, 4.6, 6.4))
	if depth(end_a) > depth(T(Vector3(0, 0, 11.8))) - 0.5:
		ci.draw_line(P(end_a), P(end_b), OUTLINE, 3.4 * s, true)
		ci.draw_line(P(end_a), P(end_b), c, 2.4 * s, true)
		ci.draw_line(P(end_b) + Vector2(-1.2, 0) * s, P(end_b) + Vector2(1.2, 0.6) * s, c.lightened(0.3), 0.8 * s, true)
	var _unused := center

func _clasp() -> void:
	var clasp := P(T(Vector3(0, 3.9, 10.4)))
	ci.draw_circle(clasp, 1.5 * s, OUTLINE)
	ci.draw_circle(clasp, 1.1 * s, Color("b98b3e"))
	ci.draw_circle(clasp + Vector2(-0.35, -0.35) * s, 0.4 * s, Color("e4c27a"))

func _arm(sh: Vector3, elbow: Vector3, hand: Vector3, side: int) -> void:
	var sleeve: Color = pal.tunic.darkened(0.08) if side > 0 else pal.tunic.darkened(0.14)
	var a := P(sh)
	var b := P(elbow)
	var c := P(hand)
	var tool_drawn := false
	var tool: String = pd.tool
	var held_left := tool == "smoker"
	var behind_tool := tool != "" and ((side > 0 and not held_left) or (side < 0 and held_left)) and depth(hand + TD(pd.td) * 4.0) < depth(hand) - 0.5
	if behind_tool:
		_tool(hand)
		tool_drawn = true
	for seg in [[a, b], [b, c]]:
		ci.draw_line(seg[0], seg[1], OUTLINE, 4.2 * s, true)
	for pnt in [a, b]: ci.draw_circle(pnt, 2.1 * s, OUTLINE)
	for seg in [[a, b], [b, c]]:
		ci.draw_line(seg[0], seg[1], sleeve, 3.0 * s, true)
	for pnt in [a, b]: ci.draw_circle(pnt, 1.5 * s, sleeve)
	ci.draw_circle(c, 2.2 * s, OUTLINE)
	ci.draw_circle(c, 1.7 * s, pal.skin)
	if tool != "" and not tool_drawn and ((side > 0 and not held_left) or (side < 0 and held_left)):
		_tool(hand)

func _tool(hand: Vector3) -> void:
	var tool: String = pd.tool
	var d := TD(pd.td).normalized()
	var length: float = TOOL_LEN.get(tool, 8.0)
	var handle_a := hand - d * 1.6
	var end := hand + d * length
	var wood := Color("8a5a32")
	match tool:
		"axe", "pick":
			ci.draw_line(P(handle_a), P(end), OUTLINE, 2.4 * s, true)
			ci.draw_line(P(handle_a), P(end), wood, 1.4 * s, true)
			# Swing normal: perpendicular to the handle in the swing plane.
			var side := TD(Vector3(1, 0, 0)).normalized()
			var n := side.cross(d).normalized()
			if tool == "axe":
				var blade := PackedVector2Array([P(end - d * 0.6 - n * 1.0), P(end + d * 1.2 - n * 1.0), P(end + d * 2.6 + n * 4.0), P(end - d * 2.4 + n * 4.0), P(end - d * 1.6 + n * 1.0)])
				_poly(blade, Color("9aa3a8"))
				ci.draw_line(P(end + d * 2.4 + n * 3.8), P(end - d * 2.2 + n * 3.8), Color("e6ecee"), 0.8 * s, true)
			else:
				var head := PackedVector2Array([P(end - n * 5.0 - d * 1.2), P(end - d * 0.2 - n * 1.0), P(end + n * 5.0 - d * 1.2), P(end + n * 1.0 + d * 0.8), P(end - n * 1.0 + d * 0.8)])
				_poly(head, Color("8d969b"))
		"sickle":
			ci.draw_line(P(hand - d * 1.0), P(hand + d * 2.0), wood, 1.6 * s, true)
			var up := Vector3(0, 0, 1)
			var arc := PackedVector2Array()
			for i in range(7):
				var a := float(i) / 6.0 * PI * 0.9
				arc.append(P(hand + d * (2.0 + sin(a) * 3.6) + up * 0.4 + d.cross(up).normalized() * (cos(a) * 3.6 - 3.6)))
			ci.draw_polyline(arc, OUTLINE, 2.0 * s, true)
			ci.draw_polyline(arc, Color("c9d0d2"), 1.2 * s, true)
		"can":
			var body := hand + d * 1.2 + Vector3(0, 0, -1.2)
			var c := P(body)
			_poly(_ellipse(c, 3.0 * s, 2.4 * s, 10), Color("6f8f8a"))
			var spout := body + d * 5.0 + Vector3(0, 0, 1.4)
			ci.draw_line(c, P(spout), OUTLINE, 1.8 * s, true)
			ci.draw_line(c, P(spout), Color("86a7a0"), 1.0 * s, true)
		"saw":
			var a := hand
			var b := hand + d * length
			var low := Vector3(0, 0, -2.6)
			ci.draw_line(P(a), P(b), wood, 1.4 * s, true)
			ci.draw_line(P(a + low), P(b + low), Color("b9c1c3"), 1.2 * s, true)
			ci.draw_line(P(a), P(a + low), wood, 1.2 * s, true)
			ci.draw_line(P(b), P(b + low), wood, 1.2 * s, true)
		"ladle":
			ci.draw_line(P(hand - d * 1.5), P(end), Color("9b7146"), 1.2 * s, true)
			ci.draw_circle(P(end), 1.4 * s, Color("7b5434"))
		"smoker":
			var c := P(hand + Vector3(0, 0.6, 1.4))
			_poly(_ellipse(c, 1.8 * s, 2.6 * s, 8), Color("a07a4a"))
			ci.draw_circle(c + Vector2(0, -3.0) * s, 1.0 * s, Color(0.9, 0.9, 0.86, 0.6))
		"rod":
			var tip := hand + d * length
			ci.draw_line(P(hand - d * 1.6), P(tip), OUTLINE, 1.8 * s, true)
			ci.draw_line(P(hand - d * 1.6), P(hand + d * 6.0), Color("7a5232"), 1.3 * s, true)
			ci.draw_line(P(hand + d * 6.0), P(tip), Color("b98d55"), 0.8 * s, true)
			ci.draw_circle(P(hand + d * 0.4), 1.0 * s, Color("8d969b"))
			if pd.get("line", false):
				var bob: Vector3 = pd.get("bobber", BOBBER)
				var dip: float = pd.get("bob_dip", 0.0)
				var mid := tip.lerp(bob, 0.55) + Vector3(0, 0, -2.5)
				ci.draw_polyline(PackedVector2Array([P(tip), P(mid), P(bob)]), Color(0.95, 0.95, 0.9, 0.8), 0.5 * s, true)
				var fb := P(bob) + Vector2(0, dip) * s
				ci.draw_circle(fb, 1.3 * s, Color("c8402f"))
				ci.draw_circle(fb + Vector2(0, -0.7) * s, 0.8 * s, Color("f4efe6"))
			if pd.get("hooked", false):
				var f := P(tip) + Vector2(0, 5.5) * s
				var body := PackedVector2Array([f + Vector2(0, -2.6) * s, f + Vector2(1.4, 0) * s, f + Vector2(0, 2.8) * s, f + Vector2(-1.4, 0) * s])
				_poly(body, Color("8fa8b8"))
				_fan(PackedVector2Array([f + Vector2(0, 2.4) * s, f + Vector2(1.6, 4.4) * s, f + Vector2(-1.6, 4.4) * s]), Color("6f8a9c"))
				ci.draw_line(P(tip), f + Vector2(0, -2.6) * s, Color(0.95, 0.95, 0.9, 0.8), 0.5 * s, true)
		"hammer", "trowel":
			ci.draw_line(P(hand - d), P(end), wood, 1.3 * s, true)
			ci.draw_circle(P(end), 1.4 * s, Color("8d969b"))

func _back_tool() -> void:
	var a := P(T(Vector3(-3.6, -4.8, 1.0)))
	var b := P(T(Vector3(3.8, -4.8, 12.2)))
	ci.draw_line(a, b, OUTLINE, 2.2 * s, true)
	ci.draw_line(a, b, Color("8a5a32"), 1.3 * s, true)
	var head := P(T(Vector3(4.2, -4.9, 12.6)))
	ci.draw_circle(head, 2.0 * s, OUTLINE)
	ci.draw_circle(head, 1.5 * s, Color("98a1a6"))

func _bag(at: Vector3) -> void:
	var c := P(at)
	_poly(_ellipse(c, 2.3 * s, 2.0 * s, 10), Color("8c5a33"))
	ci.draw_line(c + Vector2(-1.8, -0.6) * s, c + Vector2(1.8, -0.6) * s, Color("6a3f22"), 0.7 * s, true)

func _item(at: Vector3) -> void:
	var c := P(at)
	match pd.item:
		"logs":
			var across := TD(Vector3(1, 0, 0)).normalized()
			for i in range(3):
				var off := Vector3(0, 0, [0.0, 0.0, 2.3][i]) + TD(Vector3(0, 0, 0)) + Vector3(0, 0, 0)
				var lateral: float = [-1.2, 1.2, 0.0][i]
				var center: Vector3 = at + off + TD(Vector3(0, 1, 0)) * lateral * 0.4 + Vector3(0, 0, [0.0, 0.0, 0.0][i])
				var a := P(center - across * 4.2 + Vector3(0, 0, lateral))
				var b := P(center + across * 4.2 + Vector3(0, 0, lateral))
				ci.draw_line(a, b, OUTLINE, 3.6 * s, true)
				ci.draw_line(a, b, Color("9a6a3c"), 2.6 * s, true)
				var cap := b if depth(center + across) > depth(center - across) else a
				ci.draw_circle(cap, 1.5 * s, Color("e2c08a"))
				ci.draw_circle(cap, 0.6 * s, Color("b58a55"))
		"fish":
			for i in range(3):
				var fc := c + Vector2(-2.4 + i * 2.4, 0.6 * (i % 2)) * s
				var body := PackedVector2Array([fc + Vector2(0, -3.0) * s, fc + Vector2(1.3, -0.4) * s, fc + Vector2(0, 2.6) * s, fc + Vector2(-1.3, -0.4) * s])
				_poly(body, [Color("8fa8b8"), Color("a9b9a2"), Color("9aa7c2")][i])
				ci.draw_circle(fc + Vector2(0.3, -1.8) * s, 0.35 * s, Color("2b2b2b"))
			ci.draw_line(c + Vector2(-2.6, -3.4) * s, c + Vector2(2.6, -3.4) * s, Color("8a6b40"), 0.8 * s, true)
		"basket_veg":
			var vb := PackedVector2Array()
			for i in range(9):
				var a := float(i) / 8.0 * PI
				vb.append(c + Vector2(cos(a) * 3.6, sin(a) * 2.6) * s)
			vb.append(c + Vector2(-3.8, -1.0) * s)
			vb.append(c + Vector2(3.8, -1.0) * s)
			_poly(vb, Color("b8874a"))
			for i in range(4):
				var q := c + Vector2(-2.6 + i * 1.7, -1.6 - (i % 2) * 0.8) * s
				ci.draw_line(q, q + Vector2(0.3, -1.8) * s, Color("6f9a3f"), 0.8 * s, true)
				ci.draw_circle(q, 1.1 * s, [Color("e98a2e"), Color("c9a46a"), Color("d9a35a"), Color("8fb38a")][i])
		"stone":
			var pts := PackedVector2Array()
			for i in range(9):
				var a := float(i) / 9.0 * TAU
				pts.append(c + Vector2(cos(a) * (3.6 + 0.5 * sin(a * 3.0)), sin(a) * 2.8 - 0.5) * s)
			_poly(pts, Color("9ea3a0"))
			ci.draw_circle(c + Vector2(-1.2, -1.4) * s, 1.1 * s, Color("c3c7c2"))
		"basket", "basket_grain", "basket_berries":
			var body := PackedVector2Array()
			for i in range(9):
				var a := float(i) / 8.0 * PI
				body.append(c + Vector2(cos(a) * 3.6, sin(a) * 2.6) * s)
			body.append(c + Vector2(-3.8, -1.0) * s)
			body.append(c + Vector2(3.8, -1.0) * s)
			_poly(body, Color("b8874a"))
			ci.draw_line(c + Vector2(-3.4, 0.6) * s, c + Vector2(3.4, 0.6) * s, Color("8a5f31"), 0.7 * s, true)
			var fill: float = pd.fill
			if pd.item == "basket_grain" or (pd.item == "basket" and fill > 0.0 and pd.get("crop", "") == "grain"):
				_fan(_ellipse(c + Vector2(0, -1.3) * s, 3.4 * s, 1.3 * s, 10), Color("e3c063"))
				for i in range(4): ci.draw_line(c + Vector2(-2.4 + i * 1.6, -1.2) * s, c + Vector2(-2.8 + i * 1.6, -4.4) * s, Color("d4a948"), 0.8 * s, true)
			elif pd.item == "basket_berries" or fill > 0.0:
				var n := 6 if pd.item == "basket_berries" else int(1 + fill * 5)
				for i in range(n):
					ci.draw_circle(c + Vector2(-2.4 + (i % 3) * 2.4, -1.2 - (i / 3) * 1.2) * s, 1.0 * s, Color("b3283a"))
			var handle := PackedVector2Array()
			for i in range(7):
				var a := PI + float(i) / 6.0 * PI
				handle.append(c + Vector2(cos(a) * 3.0, -1.0 + sin(a) * 3.6) * s)
			ci.draw_polyline(handle, Color("8a5f31"), 0.9 * s, true)
		"sack", "sack_empty":
			var h := 3.4 if pd.item == "sack" else 1.8
			var pts := PackedVector2Array([c + Vector2(-3.4, 2.0) * s, c + Vector2(-3.0, -h) * s, c + Vector2(-1.0, -h - 1.2) * s, c + Vector2(1.0, -h - 1.2) * s, c + Vector2(3.0, -h) * s, c + Vector2(3.4, 2.0) * s])
			_poly(pts, Color("e2d3a8"))
			ci.draw_line(c + Vector2(-1.4, -h - 0.6) * s, c + Vector2(1.4, -h - 0.6) * s, Color("8a6b40"), 0.8 * s, true)
		"seedbag":
			_poly(_ellipse(c, 2.4 * s, 2.0 * s, 10), Color("c9b07a"))
			ci.draw_circle(c + Vector2(0, -1.4) * s, 0.9 * s, Color("8a6b40"))
		"dough":
			_poly(_ellipse(c, 3.6 * s, 1.8 * s, 12), Color("f1e2bd"))
		"comb":
			var pts := PackedVector2Array([c + Vector2(-2.6, -2.0) * s, c + Vector2(2.6, -2.0) * s, c + Vector2(2.6, 2.0) * s, c + Vector2(-2.6, 2.0) * s])
			_poly(pts, Color("e6b443"))
			ci.draw_line(c + Vector2(-2.0, 0) * s, c + Vector2(2.0, 0) * s, Color("b98420"), 0.6 * s, true)
		"cloth":
			_poly(_ellipse(c, 1.8 * s, 1.0 * s, 8), Color("e9e4d3"), false)
		"bread":
			_poly(_ellipse(c, 3.4 * s, 2.0 * s, 12), Color("c98a43"))
			ci.draw_line(c + Vector2(-1.6, -0.6) * s, c + Vector2(-0.6, 0.6) * s, Color("e8c48a"), 0.7 * s, true)
			ci.draw_line(c + Vector2(0.4, -0.6) * s, c + Vector2(1.4, 0.6) * s, Color("e8c48a"), 0.7 * s, true)
		"jar":
			_poly(_ellipse(c, 2.2 * s, 2.6 * s, 10), Color("b8344a"))
			ci.draw_line(c + Vector2(-2.0, -2.4) * s, c + Vector2(2.0, -2.4) * s, Color("d8c39a"), 1.2 * s, true)
		"honey":
			_poly(_ellipse(c, 2.2 * s, 2.6 * s, 10), Color("e3a72f"))
			ci.draw_line(c + Vector2(-2.0, -2.4) * s, c + Vector2(2.0, -2.4) * s, Color("d8c39a"), 1.2 * s, true)
		"planks":
			var across := TD(Vector3(1, 0, 0)).normalized()
			for i in range(3):
				var lift := Vector3(0, 0, i * 1.3)
				var a := P(at + lift - across * 4.4)
				var b := P(at + lift + across * 4.4)
				ci.draw_line(a, b, OUTLINE, 2.6 * s, true)
				ci.draw_line(a, b, Color("d9b07a"), 1.7 * s, true)
		"flour":
			var pts := PackedVector2Array([c + Vector2(-3.2, 2.2) * s, c + Vector2(-2.8, -3.0) * s, c + Vector2(0, -4.2) * s, c + Vector2(2.8, -3.0) * s, c + Vector2(3.2, 2.2) * s])
			_poly(pts, Color("f3ecd8"))
		"coins":
			for i in range(3): ci.draw_circle(c + Vector2(-1.6 + i * 1.6, -i * 0.4) * s, 1.3 * s, Color("e8c24a"))

func _head() -> void:
	var hc := T(HEAD_C)
	var c := P(hc)
	var R := HEAD_R * s
	# Head yaw relative to the body; features live on the sphere surface.
	var yaw: float = pd.hy
	var hf := Vector2(sin(yaw), cos(yaw))
	var fx := f * hf.y - r * hf.x * -1.0
	fx = (f * cos(yaw) + r * sin(yaw)).normalized()
	var rx := Vector2(-fx.y, fx.x) * -1.0
	rx = (r * cos(yaw) - f * sin(yaw)).normalized()
	var face_view := fx.y  # >0: face turned towards the camera
	var pitch: float = pd.hp + pd.lean * 0.4
	# Ears: far one before the head, near one after.
	var ears: Array = []
	for side in [-1, 1]:
		var base3 := _head_point(hc, rx, fx, side * 6.6, -1.4, 1.2)
		var tip3 := _head_point(hc, rx, fx, side * 11.8, -10.6, 7.2)
		ears.append([depth(tip3) - depth(hc), base3, tip3, side])
	for e in ears:
		if e[0] < 0: _ear(e[1], e[2])
	# Head ball with soft shading.
	ci.draw_circle(c, R + 0.75 * s, OUTLINE)
	ci.draw_circle(c, R, pal.skin.darkened(0.10))
	ci.draw_circle(c + Vector2(-0.9, -1.0) * s, R * 0.86, pal.skin)
	# Hair: soft blobs on the lower back hemisphere (the cap covers the top),
	# drawn only where that part of the sphere faces the camera.
	for el in [-0.46, -0.10]:
		for k in range(6):
			var a := PI * 0.66 + float(k) / 5.0 * PI * 0.68
			var spot := _surface(hc, rx, fx, a, el, 0.78)
			if spot[1] > 0.05:
				ci.draw_circle(spot[0], R * 0.27, pal.hair)
	for side in [-1, 1]:
		var tuft := _surface(hc, rx, fx, side * 1.75, -0.18, 0.86)
		if tuft[1] > 0.0:
			ci.draw_circle(tuft[0], R * 0.22, pal.hair)
	for k in range(4):
		var a := PI * 0.75 + float(k) / 3.0 * PI * 0.5
		var spot := _surface(hc, rx, fx, a, -0.62, 0.86)
		if spot[1] > 0.15:
			var sp: Vector2 = spot[0]
			ci.draw_line(sp + Vector2(0, -1.2) * s, sp + Vector2(0, 1.2) * s, pal.hair.darkened(0.25), 0.6 * s, true)
	# Face.
	if face_view > -0.25:
		var squash := clampf(face_view, 0.0, 1.0)
		for side in [-1, 1]:
			var eye := _surface(hc, rx, fx, side * 0.50, -0.05 - pitch * 0.5)
			if eye[1] > 0.12:
				var e: Vector2 = eye[0]
				var w := 1.15 * s * clampf(eye[1] * 1.2, 0.3, 1.0)
				if pd.blink:
					ci.draw_line(e + Vector2(-w, 0), e + Vector2(w, 0), Color("3b2414"), 0.8 * s, true)
				else:
					_fan(_ellipse(e, w, 1.6 * s, 10), Color("3b2414"))
					ci.draw_circle(e + Vector2(-0.35, -0.55) * s, 0.42 * s, Color("fff6e6"))
			var cheek := _surface(hc, rx, fx, side * 0.62, -0.32 - pitch * 0.5)
			if cheek[1] > 0.15:
				ci.draw_circle(cheek[0], 1.3 * s, Color(0.93, 0.5, 0.42, 0.35))
		var mouth := _surface(hc, rx, fx, 0.0, -0.40 - pitch * 0.5)
		if mouth[1] > 0.2:
			var m: Vector2 = mouth[0]
			var mw := 1.6 * s * clampf(mouth[1] * 1.3, 0.35, 1.0)
			var smile := PackedVector2Array()
			for i in range(6):
				var t := float(i) / 5.0
				smile.append(m + Vector2(lerpf(-mw, mw, t), sin(t * PI) * 0.75 * s - 0.25 * s))
			ci.draw_polyline(smile, Color("6b3622"), 0.75 * s, true)
		var nose := _surface(hc, rx, fx, 0.0, -0.27 - pitch * 0.5, 1.02)
		if nose[1] > -0.05:
			var side_view := 1.0 - clampf(nose[1], 0.0, 1.0)
			ci.draw_circle(nose[0], (0.55 + side_view * 0.4) * s, pal.skin.darkened(0.04 + 0.12 * (1.0 - side_view)))
		# Fringe of hair below the cap, rotates with the head.
		for i in range(7):
			var a := -0.95 + i * 0.32
			var tuft := _surface(hc, rx, fx, a, 0.52)
			if tuft[1] > 0.0:
				var tp: Vector2 = tuft[0]
				_fan(PackedVector2Array([tp + Vector2(-1.6, -1.2) * s, tp + Vector2(1.6, -1.2) * s, tp + Vector2(0.3, 1.8) * s]), pal.hair)
	for e in ears:
		if e[0] >= 0: _ear(e[1], e[2])
	_cap(hc, c, R, fx, rx)

## Point on a sphere around hc: horizontal angle a (radians, 0 = facing),
## elevation el (radians). Returns [screen point, view factor].
func _surface(hc: Vector3, rx: Vector2, fx: Vector2, a: float, el: float, radius := 1.0) -> Array:
	var gx := (fx * cos(a) + rx * sin(a)) * cos(el)
	var point := Vector2(hc.x, hc.y) * 0.0
	var g := Vector2(0, 0)
	var center := r * hc.x + f * hc.y
	g = center + gx * HEAD_R * radius
	var z := hc.z + sin(el) * HEAD_R * radius
	var screen := Vector2(g.x, g.y * ISO - z) * s
	return [screen, gx.y / maxf(cos(el), 0.01)]

## Head-relative point given in head-local x (right), y (forward), z (up).
func _head_point(hc: Vector3, rx: Vector2, fx: Vector2, x: float, y: float, z: float) -> Vector3:
	var g := rx * x + fx * y
	# Convert ground vector back to local frame (inverse of r/f basis).
	var lx := g.dot(r)
	var ly := g.dot(f)
	return hc + Vector3(lx, ly, z)

func _ear(base: Vector3, tip: Vector3) -> void:
	var mid := base.lerp(tip, 0.45)
	var up := Vector3(0, 0, 1)
	var pts := PackedVector2Array([P(base + up * 1.4), P(mid + up * 2.6), P(tip), P(mid - up * 1.4), P(base - up * 1.6)])
	_poly(pts, Color("b9c27a"), true, 0.8)
	ci.draw_line(P(base), P(tip), Color("8f9a52"), 0.6 * s, true)

func _cap(hc: Vector3, c: Vector2, R: float, fx: Vector2, rx: Vector2) -> void:
	var cc := c + Vector2(0, -R * 0.42)
	var w := R * 1.14
	var h := R * 1.05
	var cap: Color = pal.cap
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in range(11):
		var a := PI + float(i) / 10.0 * PI
		pts.append(cc + Vector2(cos(a) * w, sin(a) * h))
		cols.append(cap.lightened(0.18) if i < 4 else cap)
	for i in range(9):
		var a := float(i) / 8.0 * PI
		pts.append(cc + Vector2(cos(a) * w, sin(a) * w * 0.32))
		cols.append(cap.darkened(0.15))
	ci.draw_polygon(pts, cols)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUTLINE, 0.8 * s, true)
	# Scale texture: rows of little arcs fixed to the cap, so they rotate.
	for row in range(3):
		var el := 0.25 + row * 0.42
		var ring_w := cos(el) * w * 0.92
		var y := cc.y - sin(el) * h * 0.9
		for j in range(8):
			var a := float(j) / 8.0 * TAU + row * 0.4
			var gdir := fx * cos(a) + rx * sin(a)
			if gdir.y < 0.05: continue
			var p := Vector2(cc.x + gdir.x * ring_w, y + gdir.y * w * 0.12)
			var sw := 1.6 * s * clampf(gdir.y + 0.3, 0.4, 1.0)
			ci.draw_arc(p, sw, 0.2, PI - 0.2, 5, cap.darkened(0.3), 0.7 * s, true)
	# Rim band.
	var rim := PackedVector2Array()
	for i in range(13):
		var a := float(i) / 12.0 * PI
		rim.append(cc + Vector2(cos(a) * w, sin(a) * w * 0.32))
	ci.draw_polyline(rim, cap.darkened(0.35), 1.4 * s, true)
	# Stem and leaf, attached to the cap's own frame (direction cue).
	var top := cc + Vector2(0, -h + 0.6 * s)
	var stem_dir := (-fx * 0.35 + rx * 0.25)
	var stem_end := top + Vector2(stem_dir.x * 2.0, stem_dir.y * ISO * 2.0 - 3.2) * s
	ci.draw_line(top, stem_end, OUTLINE, 2.2 * s, true)
	ci.draw_line(top, stem_end, Color("6b4426"), 1.4 * s, true)
	var leaf_dir := rx * 1.0 - fx * 0.4
	var leaf_tip := top + Vector2(leaf_dir.x * 6.0, leaf_dir.y * ISO * 6.0 - 2.4) * s
	var leaf_mid := top.lerp(leaf_tip, 0.5)
	var nrm := (leaf_tip - top).orthogonal().normalized() * 1.9 * s
	_poly(PackedVector2Array([top, leaf_mid + nrm, leaf_tip, leaf_mid - nrm]), Color("8eaa48"), true, 0.7)
	ci.draw_line(top, leaf_tip, Color("b8cc6a"), 0.5 * s, true)
