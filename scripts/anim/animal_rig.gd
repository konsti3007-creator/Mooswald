extends RefCounted
## Procedural animals in the same projection as the woodlings.
## Body, head and other volumes are ellipsoids in a local 3D frame
## (x right, y forward, z up); their projected outline (convex hull of
## surface samples) is filled with soft shading. Legs follow a trot
## (diagonal pairs), hop (rabbit, squirrel) or two-legged gait (birds) with
## planted feet. Every species is drawn from the same code in all eight
## directions; nothing is mirrored.
##
## Animations (frame counts in anim_defs.gd style, but local here):
##   walk 8, idle 8, graze 8 (head down / pecking), sleep 4, swim 8 (duck)

const OUTLINE := Color("4b2f1e")
const ISO := 0.5
const FRAMES := {"walk": 8, "idle": 8, "graze": 8, "sleep": 4, "swim": 8}
const DURATION := {"idle": 2.4, "graze": 1.8, "sleep": 3.2, "swim": 2.4}
## Gait cycle length in rig units of ground distance (walk is distance driven).
const CYCLE := {"huhn": 7.0, "ente": 7.0, "schaf": 12.0, "ziege": 13.0, "reh": 22.0, "hase": 14.0, "eichhoernchen": 11.0, "igel": 6.0}

## Species: body half-axes (side, length, height), body height, leg layout,
## colours and extras.
const SPECIES := {
	"huhn": {"body": Vector3(3.2, 4.2, 3.4), "bz": 6.0, "legs": 2, "leg": 4.0, "head": 3.0, "neck": Vector3(0, 3.6, 4.0), "col": Color("f6efdf"), "col2": Color("e1cfae"), "leg_col": Color("e8a94a"), "extra": "chicken"},
	"ente": {"body": Vector3(3.4, 5.0, 3.0), "bz": 4.6, "legs": 2, "leg": 2.6, "head": 3.0, "neck": Vector3(0, 4.0, 4.0), "col": Color("f4f1ea"), "col2": Color("d8d2c2"), "leg_col": Color("e8932e"), "extra": "duck"},
	"schaf": {"body": Vector3(5.2, 7.6, 5.0), "bz": 9.0, "legs": 4, "leg": 5.4, "head": 3.8, "neck": Vector3(0, 7.6, 3.2), "col": Color("f2eee4"), "col2": Color("d8d0bf"), "leg_col": Color("3d3430"), "head_col": Color("3d3430"), "extra": "wool"},
	"ziege": {"body": Vector3(4.2, 7.4, 4.4), "bz": 10.4, "legs": 4, "leg": 7.0, "head": 3.8, "neck": Vector3(0, 7.2, 5.0), "col": Color("e2cfa8"), "col2": Color("bf9f72"), "leg_col": Color("8f7454"), "extra": "goat"},
	"reh": {"body": Vector3(4.6, 9.6, 5.0), "bz": 16.0, "legs": 4, "leg": 12.0, "head": 4.1, "neck": Vector3(0, 9.4, 8.0), "col": Color("c98a54"), "col2": Color("9a6438"), "leg_col": Color("9a6438"), "extra": "deer"},
	"hase": {"body": Vector3(2.8, 4.6, 3.0), "bz": 4.0, "legs": 4, "leg": 2.8, "head": 3.0, "neck": Vector3(0, 4.2, 2.4), "col": Color("b9946c"), "col2": Color("8f6e4c"), "leg_col": Color("8f6e4c"), "extra": "hare", "hop": true},
	"eichhoernchen": {"body": Vector3(2.2, 3.6, 2.6), "bz": 3.4, "legs": 4, "leg": 2.2, "head": 2.6, "neck": Vector3(0, 3.2, 2.6), "col": Color("cf7434"), "col2": Color("a05428"), "leg_col": Color("a05428"), "extra": "squirrel", "hop": true},
	"igel": {"body": Vector3(3.0, 4.2, 2.6), "bz": 2.8, "legs": 4, "leg": 1.4, "head": 2.2, "neck": Vector3(0, 4.0, 0.0), "col": Color("6e5a46"), "col2": Color("4e3e30"), "leg_col": Color("8a6e56"), "head_col": Color("c9a985"), "extra": "hedgehog"},
}

var f := Vector2(0, 1)
var r := Vector2(-1, 0)
var s := 1.0
var ci: CanvasItem

static func frame_for(anim: String, t: float, dist: float, species: String) -> int:
	if anim == "walk":
		var u := fposmod(dist / float(CYCLE.get(species, 10.0)), 1.0)
		return int(u * 8.0) % 8
	var n: int = FRAMES.get(anim, 8)
	var d: float = DURATION.get(anim, 2.0)
	return int(fposmod(t / d, 1.0) * n) % n

func P(v: Vector3) -> Vector2:
	var g := r * v.x + f * v.y
	return Vector2(g.x, g.y * ISO - v.z) * s

func depth(v: Vector3) -> float:
	return (r * v.x + f * v.y).y

## Draws the animal with its ground point at the canvas origin.
func draw(canvas: CanvasItem, species: String, anim: String, frame: int, facing: float, scale_value := 1.0, variant := 0) -> void:
	ci = canvas
	f = Vector2(sin(facing), cos(facing))
	r = Vector2(-cos(facing), sin(facing))
	s = scale_value
	var sp: Dictionary = SPECIES[species]
	var body: Vector3 = sp.body
	var col: Color = sp.col
	if variant % 3 == 1: col = col.darkened(0.08)
	if variant % 3 == 2: col = col.lightened(0.05)
	var u := float(frame) / float(FRAMES.get(anim, 8))
	var bz: float = sp.bz
	var pitch := 0.0
	var head_drop := 0.0
	var lying := anim == "sleep"
	var hop: bool = sp.get("hop", false)
	if anim == "walk":
		bz += (absf(sin(u * TAU * 2.0)) * 0.6 if not hop else maxf(0.0, sin(u * TAU)) * body.z * 0.9)
		pitch = 0.0 if not hop else -0.18 * cos(u * TAU)
	elif anim == "idle":
		bz += sin(u * TAU) * 0.15
	elif anim == "graze":
		head_drop = 1.0 if species not in ["huhn", "ente"] else (1.0 if frame in [1, 2, 5, 6] else 0.3)
		pitch = 0.08 if species not in ["huhn", "ente"] else 0.35 * head_drop
	elif lying:
		bz = body.z * 0.95
	elif anim == "swim":
		bz = body.z * 0.55 + sin(u * TAU) * 0.3
	# Shadow.
	_ellipse_fill(P(Vector3(0, 0, 0)), (body.x + 2.0) * s * 1.15, (body.y * 0.5 + 1.5) * s * 0.7, Color(0.16, 0.22, 0.12, 0.28) if anim != "swim" else Color(0.85, 0.95, 1.0, 0.25))
	if anim == "swim":
		var ring := u * 4.0
		var ring_pts := PackedVector2Array()
		var c0 := P(Vector3.ZERO)
		for i in range(21):
			var a := float(i) / 20.0 * TAU
			ring_pts.append(c0 + Vector2(cos(a), sin(a) * 0.45) * (body.y + ring) * s)
		ci.draw_polyline(ring_pts, Color(1, 1, 1, 0.35 * (1.0 - u)), 0.8 * s, true)
	var parts: Array = []
	# Legs.
	if not lying and anim != "swim":
		var cyc: float = CYCLE.get(species, 10.0)
		if sp.legs == 4:
			var hips := [[-1, 1, 0.0], [1, 1, 0.5], [-1, -1, 0.5], [1, -1, 0.0]]
			if hop: hips = [[-1, 1, 0.0], [1, 1, 0.0], [-1, -1, 0.5], [1, -1, 0.5]]
			for h in hips:
				var root := Vector3(h[0] * body.x * 0.55, h[1] * body.y * 0.62, bz - body.z * 0.4)
				var foot := Vector3(root.x, root.y, 0.0)
				if anim == "walk":
					foot = _foot(fposmod(u + h[2], 1.0), cyc * 0.5, 1.4 if not hop else 0.6, root.x, root.y)
				parts.append([depth(foot) - 0.5, "leg", root, foot, sp.leg_col])
		else:
			for side in [-1, 1]:
				var root := Vector3(side * body.x * 0.4, -0.4, bz - body.z * 0.5)
				var foot := Vector3(root.x, root.y, 0.0)
				if anim == "walk":
					foot = _foot(fposmod(u + (0.5 if side > 0 else 0.0), 1.0), cyc * 0.5, 1.6, root.x, root.y)
				parts.append([depth(foot) - 0.5, "leg", root, foot, sp.leg_col])
	var center := Vector3(0, 0, bz)
	parts.append([0.0, "body", center, body, col, sp.col2, pitch])
	# Neck and head.
	var neck_base := center + Vector3(0, body.y * 0.7, body.z * 0.3)
	var head_pos := center + Vector3(sp.neck.x, sp.neck.y, sp.neck.z)
	if head_drop > 0.0:
		head_pos = head_pos.lerp(Vector3(0, sp.neck.y + 1.5, sp.head * 0.9), head_drop)
	if lying: head_pos = center + Vector3(0, body.y * 0.9, body.z * 0.4)
	if anim == "idle" and frame in [5, 6]: head_pos += Vector3(0.8, 0, 0.3)
	var head_d := depth(head_pos)
	parts.append([head_d * 1.05 + 0.2, "head", neck_base, head_pos, species, col, sp, lying, frame, anim])
	var tail_base := center + Vector3(0, -body.y * 0.9, body.z * 0.3)
	parts.append([depth(tail_base) * 1.05, "tail", tail_base, species, col, sp, frame])
	parts.sort_custom(func(a, b): return a[0] < b[0])
	for p in parts:
		match p[1]:
			"leg": _leg(p[2], p[3], p[4])
			"body": _body(p[2], p[3], p[4], p[5], p[6], species)
			"head": _head(p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9])
			"tail": _tail(p[2], p[3], p[4], p[5], p[6])

static func _foot(q: float, stride: float, lift: float, x: float, y: float) -> Vector3:
	if q < 0.5:
		return Vector3(x, y + stride * 0.5 - (q / 0.5) * stride, 0.0)
	var w := (q - 0.5) / 0.5
	var e := w * w * (3.0 - 2.0 * w)
	return Vector3(x, y - stride * 0.5 + stride * e, lift * sin(PI * w))

func _ellipse_fill(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := float(i) / 16.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_fan(pts, color)

func _fan(points: PackedVector2Array, color: Color) -> void:
	var cols := PackedColorArray([color, color, color])
	for i in range(1, points.size() - 1):
		ci.draw_primitive(PackedVector2Array([points[0], points[i], points[i + 1]]), cols, PackedVector2Array())

## Projected outline of an ellipsoid (convex hull of surface samples).
func _hull(c: Vector3, ax: Vector3, pitch := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(5):
		var el := -PI * 0.5 + (i + 0.5) / 5.0 * PI
		for j in range(10):
			var az := float(j) / 10.0 * TAU
			var v := Vector3(cos(el) * sin(az) * ax.x, cos(el) * cos(az) * ax.y, sin(el) * ax.z)
			# Pitch about the side axis (nose up/down).
			var y2 := v.y * cos(pitch) - v.z * sin(pitch)
			var z2 := v.y * sin(pitch) + v.z * cos(pitch)
			pts.append(P(c + Vector3(v.x, y2, z2)))
	return Geometry2D.convex_hull(pts)

func _shaded(c: Vector3, ax: Vector3, col: Color, pitch := 0.0, outline := true) -> void:
	var hull := _hull(c, ax, pitch)
	if hull.size() < 3: return
	_fan(hull, col.darkened(0.12))
	var hi := _hull(c + Vector3(-ax.x * 0.15, 0, ax.z * 0.2), ax * 0.78, pitch)
	if hi.size() >= 3: _fan(hi, col)
	var glint := _hull(c + Vector3(-ax.x * 0.35, ax.y * 0.1, ax.z * 0.55), ax * 0.32, pitch)
	if glint.size() >= 3: _fan(glint, col.lightened(0.12))
	if outline:
		var closed := hull.duplicate()
		if closed.size() > 0 and closed[0] != closed[closed.size() - 1]: closed.append(closed[0])
		ci.draw_polyline(closed, OUTLINE, 0.75 * s, true)

func _leg(root: Vector3, foot: Vector3, col: Color) -> void:
	ci.draw_line(P(root), P(foot), OUTLINE, 2.4 * s, true)
	ci.draw_line(P(root), P(foot), col, 1.5 * s, true)
	ci.draw_circle(P(foot), 0.9 * s, col.darkened(0.3))

func _body(c: Vector3, ax: Vector3, col: Color, col2: Color, pitch: float, species: String) -> void:
	var sp: Dictionary = SPECIES[species]
	match sp.extra:
		"wool":
			_shaded(c, ax, col2, pitch)
			# Woolly bumps on the visible upper surface.
			for j in range(14):
				var az := float(j) / 14.0 * TAU
				for el in [0.15, 0.7]:
					var v := Vector3(cos(el) * sin(az) * ax.x, cos(el) * cos(az) * ax.y, sin(el) * ax.z)
					if depth(v) < -ax.x * 0.3 and el < 0.5: continue
					var p := P(c + v * 0.92)
					ci.draw_circle(p, 1.7 * s, col.darkened(0.06))
					ci.draw_circle(p + Vector2(-0.3, -0.4) * s, 1.2 * s, col)
		"hedgehog":
			_shaded(c, ax, col, pitch)
			for j in range(16):
				var az := float(j) / 16.0 * TAU
				var v := Vector3(sin(az) * ax.x, cos(az) * ax.y, ax.z * 0.6)
				var p := P(c + v)
				ci.draw_line(p, p + Vector2(sin(az) * 1.6, -1.8) * s, col.darkened(0.35), 0.8 * s, true)
		_:
			_shaded(c, ax, col, pitch)
			if sp.extra in ["hare", "squirrel", "deer", "goat"]:
				# Lighter belly and chest, painted-in fur strokes on the back.
				_shaded(c + Vector3(0, ax.y * 0.35, -ax.z * 0.35), Vector3(ax.x * 0.7, ax.y * 0.55, ax.z * 0.5), col.lightened(0.28), pitch, false)
				for j in range(5):
					var az := -0.6 + j * 0.3
					var top := c + Vector3(sin(az) * ax.x * 0.5, cos(az) * ax.y * 0.4 - ax.y * 0.3, ax.z * 0.92)
					ci.draw_line(P(top), P(top + Vector3(0, -0.9, 0.5)), col.darkened(0.22), 0.6 * s, true)
			if sp.extra in ["chicken", "duck"]:
				# Folded wing.
				for side in [-1, 1]:
					var w := c + Vector3(side * ax.x * 0.9, -0.4, 0.3)
					if depth(Vector3(side, 0, 0)) > -0.2:
						_shaded(w, Vector3(0.7, ax.y * 0.6, ax.z * 0.55), col2, pitch, false)
			if sp.extra == "deer":
				_shaded(c + Vector3(0, -ax.y * 0.75, ax.z * 0.1), Vector3(ax.x * 0.5, 1.6, ax.z * 0.6), Color("f0e6d4"), 0.0, false)

func _head(neck_base: Vector3, head: Vector3, species: String, col: Color, sp: Dictionary, lying: bool, frame: int, anim: String) -> void:
	var hc: Color = sp.get("head_col", col)
	var hr: float = sp.head
	if sp.legs == 4 and sp.extra not in ["hare", "squirrel", "hedgehog"]:
		ci.draw_line(P(neck_base), P(head), OUTLINE, (hr * 1.5 + 0.8) * s, true)
		ci.draw_line(P(neck_base), P(head), col if sp.extra != "wool" else sp.col2, hr * 1.5 * s, true)
	elif sp.extra in ["chicken", "duck"]:
		ci.draw_line(P(neck_base), P(head), OUTLINE, (hr * 1.4 + 0.8) * s, true)
		ci.draw_line(P(neck_base), P(head), col, hr * 1.4 * s, true)
	var ax := Vector3(hr * 0.85, hr * 1.1, hr * 0.85)
	if sp.extra in ["deer", "goat", "wool"]: ax = Vector3(hr * 0.75, hr * 1.4, hr * 0.8)
	var snout := Vector3(0, ax.y * 0.9, -ax.z * 0.2)
	# Ears / horns behind the head when they face away.
	_ears(head, ax, sp, true)
	_shaded(head, ax, hc)
	_ears(head, ax, sp, false)
	match sp.extra:
		"chicken":
			_tri(P(head + Vector3(0, ax.y * 1.0, 0)), P(head + Vector3(0, ax.y * 1.8, -0.3)), P(head + Vector3(0, ax.y * 1.0, -0.6)), Color("e8a23a"))
			for i in range(3): ci.draw_circle(P(head + Vector3(0, -0.3 + i * 0.6, ax.z + 0.4 + (i % 2) * 0.3)), 0.75 * s, Color("d0413a"))
			ci.draw_circle(P(head + Vector3(0, ax.y * 0.9, -ax.z * 0.9)), 0.6 * s, Color("d0413a"))
		"duck":
			var tip := head + Vector3(0, ax.y * 2.0, -0.4)
			ci.draw_line(P(head + Vector3(0, ax.y * 0.8, -0.2)), P(tip), Color("e8932e"), 1.6 * s, true)
		"hedgehog", "hare", "squirrel", "goat", "deer", "wool":
			ci.draw_circle(P(head + snout), 0.6 * s, Color("2b2220"))
	# Eyes on both sides, only where they face the camera.
	for side in [-1, 1]:
		var e := head + Vector3(side * ax.x * 0.62, ax.y * 0.48, ax.z * 0.18)
		if depth(Vector3(side, 0.4, 0)) > -0.1:
			if lying or (anim == "idle" and frame == 7):
				ci.draw_line(P(e) + Vector2(-0.6, 0) * s, P(e) + Vector2(0.6, 0) * s, Color("2b2220"), 0.6 * s, true)
			else:
				var er := 0.8 if sp.legs == 4 else 0.7
				_ellipse_fill(P(e), er * 0.85 * s, er * 1.15 * s, Color("3b2414"))
				ci.draw_circle(P(e) + Vector2(-0.25, -0.35) * s, er * 0.38 * s, Color("fff6e6"))
			var cheek := head + Vector3(side * ax.x * 0.8, ax.y * 0.55, -ax.z * 0.15)
			if sp.extra not in ["chicken", "duck", "hedgehog"]:
				ci.draw_circle(P(cheek), 0.9 * s, Color(0.93, 0.5, 0.42, 0.32))

func _ears(head: Vector3, ax: Vector3, sp: Dictionary, behind: bool) -> void:
	for side in [-1, 1]:
		var front := depth(Vector3(side, 0, 0)) > 0.0
		if front == behind: continue
		match sp.extra:
			"hare":
				_ear(head + Vector3(side * ax.x * 0.4, -ax.y * 0.2, ax.z * 0.6), head + Vector3(side * ax.x * 0.7, -ax.y * 1.2, ax.z * 3.4), sp.col, 1.2)
			"squirrel", "deer", "goat":
				_ear(head + Vector3(side * ax.x * 0.6, -ax.y * 0.1, ax.z * 0.6), head + Vector3(side * ax.x * 1.6, -ax.y * 0.4, ax.z * 1.5), sp.get("head_col", sp.col), 0.9)
				if sp.extra == "goat":
					var b := head + Vector3(side * ax.x * 0.3, -ax.y * 0.1, ax.z * 0.8)
					ci.draw_polyline(PackedVector2Array([P(b), P(b + Vector3(side * 0.4, -1.2, 1.4)), P(b + Vector3(side * 0.6, -2.4, 1.6))]), Color("8a7a62"), 1.1 * s, true)
			"wool":
				_ear(head + Vector3(side * ax.x * 0.7, 0, ax.z * 0.3), head + Vector3(side * ax.x * 1.9, -0.4, ax.z * 0.1), sp.head_col, 0.8)

func _ear(a: Vector3, b: Vector3, col: Color, w: float) -> void:
	var mid := a.lerp(b, 0.5)
	var up := Vector3(0, 0, w)
	var side := Vector3(0, w, 0)
	var pts := PackedVector2Array([P(a), P(mid + side), P(b), P(mid - side * 0.6 + up * 0.2)])
	_fan(pts, col.darkened(0.05))
	if w >= 0.85:
		var inner := PackedVector2Array([P(a.lerp(b, 0.15)), P(mid + side * 0.5), P(a.lerp(b, 0.85)), P(mid - side * 0.2)])
		_fan(inner, Color(0.94, 0.68, 0.62, 0.8))
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUTLINE, 0.6 * s, true)

func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	_fan(PackedVector2Array([a, b, c]), col)

func _tail(base: Vector3, species: String, col: Color, sp: Dictionary, frame: int) -> void:
	var wag := sin(float(frame) / 8.0 * TAU) * 0.6
	match sp.extra:
		"squirrel":
			# Big bushy tail curling up behind.
			var pts: Array[Vector3] = [base, base + Vector3(wag, -2.0, 2.0), base + Vector3(wag, -2.6, 5.0), base + Vector3(wag * 0.5, -1.4, 7.2)]
			for i in range(pts.size() - 1):
				_shaded(pts[i].lerp(pts[i + 1], 0.5), Vector3(1.6, 1.4, 1.8), col if i % 2 == 0 else col.lightened(0.08), 0.0, i == 0)
		"chicken":
			for i in range(3):
				_ear(base + Vector3(0, 0, 0.4), base + Vector3((i - 1) * 0.8, -1.6, 3.0 + i * 0.4), [Color("d9cdb4"), Color("8a6a4a"), Color("c9b8a0")][i], 0.6)
		"duck":
			_ear(base, base + Vector3(0, -1.4, 1.2), col, 0.6)
		"hare", "wool":
			ci.draw_circle(P(base + Vector3(0, -0.4, 0.4)), 1.2 * s, Color("f2eee4"))
		"deer":
			ci.draw_circle(P(base + Vector3(0, -0.3, 0.2)), 1.0 * s, Color("f0e6d4"))
		"goat":
			ci.draw_line(P(base), P(base + Vector3(wag * 0.3, -0.8, 1.6)), col.darkened(0.2), 1.0 * s, true)
