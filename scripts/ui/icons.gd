extends Control
## Small painted icons for the interface, drawn in code in the game's style
## (warm brown outlines, soft highlights). One Control per icon; `kind`
## selects the motif. Used for goods, tools, categories and menu buttons.

const INK := Color("4b2f1e")

@export var kind := "holz"

static func make(k: String, size_px := 26.0) -> Control:
	var icon = load("res://scripts/ui/icons.gd").new()
	icon.kind = k
	icon.custom_minimum_size = Vector2(size_px, size_px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _draw() -> void:
	draw_icon(self, kind, Rect2(Vector2.ZERO, size))

static func _e(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, outline := true) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := float(i) / 20.0 * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)
	if outline:
		pts.append(pts[0])
		ci.draw_polyline(pts, INK, 1.2, true)

static func _p(ci: CanvasItem, pts: PackedVector2Array, col: Color, outline := true) -> void:
	ci.draw_colored_polygon(pts, col)
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, INK, 1.2, true)

static func draw_icon(ci: CanvasItem, k: String, rect: Rect2) -> void:
	var s := minf(rect.size.x, rect.size.y) / 24.0
	var o := rect.position + (rect.size - Vector2(24, 24) * s) * 0.5
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var R := func(x: float, y: float) -> Vector2: return Vector2(x, y) * s
	match k:
		"holz":
			for i in range(2):
				var y := 14.0 - i * 6.0
				ci.draw_line(P.call(3, y + 2), P.call(19, y - 2), INK, 6.2 * s, true)
				ci.draw_line(P.call(3, y + 2), P.call(19, y - 2), Color("a8733f"), 4.4 * s, true)
				_e(ci, P.call(19.5, y - 2), R.call(2.6, 2.6), Color("e6c48c"))
				ci.draw_circle(P.call(19.5, y - 2), 1.0 * s, Color("b88d58"))
		"stein":
			_p(ci, PackedVector2Array([P.call(3, 18), P.call(6, 9), P.call(12, 5), P.call(19, 8), P.call(21, 17), P.call(14, 20)]), Color("9ea3a0"))
			_e(ci, P.call(9, 10), R.call(2.5, 1.6), Color("c9ccc6"), false)
		"nahrung":
			_e(ci, P.call(12, 14), R.call(8, 7.5), Color("d8473a"))
			_e(ci, P.call(9, 11), R.call(2.2, 1.6), Color("f08a7c"), false)
			ci.draw_line(P.call(12, 7), P.call(13, 3), INK, 1.6 * s, true)
			_p(ci, PackedVector2Array([P.call(13, 5), P.call(18, 3), P.call(16, 7)]), Color("7fa04a"))
		"getreide", "korn":
			ci.draw_line(P.call(12, 22), P.call(12, 6), Color("b8954a"), 1.8 * s, true)
			for i in range(4):
				_e(ci, P.call(10, 8 + i * 3.4), R.call(2.0, 1.3), Color("e7c169"))
				_e(ci, P.call(14, 8 + i * 3.4), R.call(2.0, 1.3), Color("e7c169"))
			_e(ci, P.call(12, 5), R.call(1.6, 2.2), Color("e7c169"))
		"mehl":
			_p(ci, PackedVector2Array([P.call(5, 21), P.call(6, 8), P.call(9, 5), P.call(15, 5), P.call(18, 8), P.call(19, 21)]), Color("f1e6c8"))
			ci.draw_line(P.call(8, 7), P.call(16, 7), Color("a07a4a"), 1.4 * s, true)
			_e(ci, P.call(12, 14), R.call(3, 3), Color("e7c169"), false)
		"bretter":
			for i in range(3):
				var y := 7.0 + i * 5.0
				_p(ci, PackedVector2Array([P.call(3, y), P.call(21, y - 2), P.call(21, y + 2), P.call(3, y + 4)]), Color("d9b07a"))
		"brot":
			_e(ci, P.call(12, 14), R.call(9, 6), Color("c98a43"))
			for i in range(3): ci.draw_line(P.call(8 + i * 4, 11), P.call(10 + i * 4, 16), Color("ecc890"), 1.4 * s, true)
		"muenzen":
			_e(ci, P.call(12, 12), R.call(9, 9), Color("d9aa2f"))
			_e(ci, P.call(12, 12), R.call(6.5, 6.5), Color("efc94f"), false)
			_p(ci, PackedVector2Array([P.call(12, 7), P.call(14, 12), P.call(12, 17), P.call(10, 12)]), Color("fbe39a"), false)
		"beeren":
			for q in [Vector2(9, 14), Vector2(15, 14), Vector2(12, 9), Vector2(12, 18)]:
				_e(ci, P.call(q.x, q.y), R.call(3.4, 3.4), Color("b3283a"))
				ci.draw_circle(P.call(q.x - 1, q.y - 1), 0.9 * s, Color("f2a3ab"))
		"honig", "marmelade":
			var jar := Color("e3a72f") if k == "honig" else Color("b8344a")
			_p(ci, PackedVector2Array([P.call(6, 9), P.call(18, 9), P.call(19, 20), P.call(5, 20)]), jar)
			_p(ci, PackedVector2Array([P.call(6, 5), P.call(18, 5), P.call(18, 9), P.call(6, 9)]), Color("d8c39a"))
			_e(ci, P.call(9, 13), R.call(1.4, 2.6), Color(1, 1, 1, 0.45), false)
		"karotten":
			_p(ci, PackedVector2Array([P.call(8, 7), P.call(16, 7), P.call(12, 22)]), Color("e98a2e"))
			for i in range(3): ci.draw_line(P.call(12, 7), P.call(8 + i * 4, 2), Color("6f9a3f"), 1.8 * s, true)
		"kartoffeln":
			_e(ci, P.call(12, 13), R.call(9, 6.5), Color("c9a46a"))
			for q in [Vector2(9, 11), Vector2(15, 14), Vector2(12, 16)]: ci.draw_circle(P.call(q.x, q.y), 0.8 * s, Color("8f6e4c"))
		"kohl":
			_e(ci, P.call(12, 13), R.call(9, 8), Color("8fb38a"))
			_e(ci, P.call(12, 13), R.call(5, 5), Color("b9d4ae"))
		"zwiebeln":
			_e(ci, P.call(12, 15), R.call(7, 7), Color("d9a35a"))
			ci.draw_line(P.call(12, 8), P.call(12, 3), Color("7fa65a"), 1.8 * s, true)
		"kuerbis":
			_e(ci, P.call(12, 14), R.call(10, 7.5), Color("e5782a"))
			for x in [8.0, 12.0, 16.0]: ci.draw_line(P.call(x, 8), P.call(x, 20), Color("c45d1e"), 1.0 * s, true)
			ci.draw_line(P.call(12, 7), P.call(13, 3), Color("6b4a2a"), 1.8 * s, true)
		"flachs":
			for i in range(5):
				var a := float(i) / 5.0 * TAU
				_e(ci, P.call(12 + cos(a) * 5, 12 + sin(a) * 5), R.call(3.2, 3.2), Color("7f9fd8"))
			_e(ci, P.call(12, 12), R.call(2, 2), Color("f2d55a"))
		"sonnenblumen":
			for i in range(10):
				var a := float(i) / 10.0 * TAU
				_e(ci, P.call(12 + cos(a) * 6.5, 12 + sin(a) * 6.5), R.call(2.6, 2.6), Color("f2c330"), false)
			_e(ci, P.call(12, 12), R.call(4.5, 4.5), Color("6b4426"))
		"fisch", "raeucherfisch":
			var fc := Color("8fa8b8") if k == "fisch" else Color("b07a4a")
			_p(ci, PackedVector2Array([P.call(3, 12), P.call(10, 6), P.call(17, 12), P.call(10, 18)]), fc)
			_p(ci, PackedVector2Array([P.call(16, 12), P.call(22, 7), P.call(22, 17)]), fc.darkened(0.15))
			ci.draw_circle(P.call(7, 11), 1.0 * s, INK)
		"eier":
			_e(ci, P.call(12, 13), R.call(6.5, 8.5), Color("f6efdf"))
			_e(ci, P.call(10, 10), R.call(1.6, 2.6), Color(1, 1, 1, 0.7), false)
		"wolle":
			_e(ci, P.call(12, 13), R.call(8.5, 8.5), Color("f2eee4"))
			for i in range(4): ci.draw_arc(P.call(12, 13), (3.0 + i * 1.6) * s, 0.4 + i, 2.6 + i, 6, Color("c8c0b0"), 1.0 * s, true)
		"milch":
			_p(ci, PackedVector2Array([P.call(7, 8), P.call(17, 8), P.call(18, 21), P.call(6, 21)]), Color("d0d8dc"))
			_p(ci, PackedVector2Array([P.call(9, 3), P.call(15, 3), P.call(17, 8), P.call(7, 8)]), Color("b9c3c8"))
			ci.draw_line(P.call(7, 13), P.call(17, 13), Color("8fa0a8"), 1.0 * s, true)
		"kaese":
			_p(ci, PackedVector2Array([P.call(3, 18), P.call(21, 18), P.call(21, 12), P.call(6, 7)]), Color("f0c84a"))
			for q in [Vector2(9, 13), Vector2(15, 15), Vector2(17, 12)]: ci.draw_circle(P.call(q.x, q.y), 1.4 * s, Color("c99a2a"))
		# --- tools and categories
		"bauen", "handwerk":
			ci.draw_line(P.call(5, 20), P.call(15, 9), INK, 4.0 * s, true)
			ci.draw_line(P.call(5, 20), P.call(15, 9), Color("a8733f"), 2.6 * s, true)
			_p(ci, PackedVector2Array([P.call(11, 5), P.call(20, 7), P.call(18, 12), P.call(13, 10)]), Color("8d969b"))
		"info":
			_e(ci, P.call(12, 12), R.call(9, 9), Color("6a9ac0"))
			ci.draw_circle(P.call(12, 7.5), 1.6 * s, Color.WHITE)
			ci.draw_line(P.call(12, 11), P.call(12, 17), Color.WHITE, 2.6 * s, true)
		"bewegen":
			for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				var tip: Vector2 = Vector2(12, 12) + d * 9.0
				var side := Vector2(-d.y, d.x) * 3.0
				_p(ci, PackedVector2Array([P.call(tip.x, tip.y), P.call(tip.x - d.x * 4 + side.x, tip.y - d.y * 4 + side.y), P.call(tip.x - d.x * 4 - side.x, tip.y - d.y * 4 - side.y)]), Color("7fa04a"))
			ci.draw_line(P.call(12, 5), P.call(12, 19), Color("7fa04a"), 2.2 * s, true)
			ci.draw_line(P.call(5, 12), P.call(19, 12), Color("7fa04a"), 2.2 * s, true)
		"abriss":
			ci.draw_line(P.call(7, 4), P.call(14, 15), INK, 3.6 * s, true)
			ci.draw_line(P.call(7, 4), P.call(14, 15), Color("a8733f"), 2.2 * s, true)
			_p(ci, PackedVector2Array([P.call(11, 14), P.call(19, 12), P.call(21, 19), P.call(15, 22)]), Color("8d969b"))
		"wohnen", "bewohner":
			_p(ci, PackedVector2Array([P.call(5, 12), P.call(19, 12), P.call(19, 21), P.call(5, 21)]), Color("e8d3a6"))
			_p(ci, PackedVector2Array([P.call(2, 13), P.call(12, 3), P.call(22, 13)]), Color("7f9c3d"))
			ci.draw_rect(Rect2(P.call(10, 15), R.call(4, 6)), Color("8a5a32"))
			if k == "bewohner":
				_p(ci, PackedVector2Array([P.call(18, 1), P.call(19.4, 4.6), P.call(23, 5), P.call(20.2, 7.4), P.call(21, 11), P.call(18, 9), P.call(15, 11), P.call(15.8, 7.4), P.call(13, 5), P.call(16.6, 4.6)]), Color("f2c94a"))
		"ernte":
			draw_icon(ci, "getreide", rect)
		"tiere":
			_e(ci, P.call(12, 14), R.call(7, 6), Color("f6efdf"))
			_e(ci, P.call(16, 8), R.call(3.4, 3.4), Color("f6efdf"))
			_p(ci, PackedVector2Array([P.call(19, 8), P.call(23, 9), P.call(19, 10)]), Color("e8a94a"))
			ci.draw_circle(P.call(16, 4.5), 1.6 * s, Color("d0413a"))
			ci.draw_circle(P.call(17, 7.5), 0.8 * s, INK)
			ci.draw_line(P.call(10, 19), P.call(10, 23), Color("e8a94a"), 1.4 * s)
			ci.draw_line(P.call(14, 19), P.call(14, 23), Color("e8a94a"), 1.4 * s)
		"wege":
			_p(ci, PackedVector2Array([P.call(9, 2), P.call(15, 2), P.call(21, 22), P.call(3, 22)]), Color("dbc795"))
			for y in [7.0, 13.0, 19.0]: ci.draw_line(P.call(12, y - 2), P.call(12, y), Color("a08e62"), 1.4 * s, true)
		"natur":
			ci.draw_rect(Rect2(P.call(10.5, 14), R.call(3, 8)), Color("7a4a2a"))
			_e(ci, P.call(12, 10), R.call(8, 7), Color("7fa04a"))
			_e(ci, P.call(9, 8), R.call(3, 2.4), Color("a9c96a"), false)
		"ernten":
			_p(ci, PackedVector2Array([P.call(3, 11), P.call(21, 11), P.call(18, 21), P.call(6, 21)]), Color("b8874a"))
			ci.draw_arc(P.call(12, 11), 7.0 * s, PI, TAU, 10, INK, 1.4 * s, true)
			for q in [Vector2(8, 10), Vector2(12, 9), Vector2(16, 10)]: ci.draw_circle(P.call(q.x, q.y), 2.0 * s, Color("e7c169"))
		"sammeln":
			_p(ci, PackedVector2Array([P.call(12, 2), P.call(20, 10), P.call(12, 22), P.call(4, 10)]), Color("8fae4a"))
			ci.draw_line(P.call(12, 4), P.call(12, 21), Color("c9dc8a"), 1.2 * s, true)
		"verkaufen":
			_p(ci, PackedVector2Array([P.call(6, 9), P.call(18, 9), P.call(20, 21), P.call(4, 21)]), Color("c9a46a"))
			ci.draw_line(P.call(8, 8), P.call(16, 8), Color("8a6b40"), 2.0 * s, true)
			_e(ci, P.call(12, 15), R.call(3.6, 3.6), Color("efc94f"))
		"speichern":
			_p(ci, PackedVector2Array([P.call(4, 3), P.call(20, 3), P.call(20, 21), P.call(4, 21)]), Color("6a8fb0"))
			ci.draw_rect(Rect2(P.call(7, 3), R.call(10, 6)), Color("dfe8ee"))
			ci.draw_rect(Rect2(P.call(7, 13), R.call(10, 8)), Color("f4f1ea"))
		"pause":
			ci.draw_rect(Rect2(P.call(6, 5), R.call(4, 14)), Color("6f8a5a"))
			ci.draw_rect(Rect2(P.call(14, 5), R.call(4, 14)), Color("6f8a5a"))
		"x1", "x2", "x4":
			var n: int = {"x1": 1, "x2": 2, "x4": 3}[k]
			for i in range(n):
				var x0: float = 4.0 + i * (16.0 / n)
				var w: float = 16.0 / n + 2.0
				_p(ci, PackedVector2Array([P.call(x0, 5), P.call(x0 + w, 12), P.call(x0, 19)]), Color("6f8a5a"), false)
		"optionen":
			for i in range(8):
				var a := float(i) / 8.0 * TAU
				ci.draw_line(P.call(12, 12), P.call(12 + cos(a) * 10, 12 + sin(a) * 10), Color("8a8f86"), 3.4 * s, true)
			_e(ci, P.call(12, 12), R.call(7, 7), Color("8a8f86"))
			_e(ci, P.call(12, 12), R.call(3, 3), Color("f4ead2"))
		"hilfe":
			_e(ci, P.call(12, 12), R.call(9, 9), Color("d9aa2f"))
			ci.draw_arc(P.call(12, 10), 3.2 * s, PI, TAU + 1.2, 8, Color.WHITE, 2.2 * s, true)
			ci.draw_line(P.call(12, 13), P.call(12, 15), Color.WHITE, 2.2 * s, true)
			ci.draw_circle(P.call(12, 18), 1.3 * s, Color.WHITE)
		"beenden":
			_p(ci, PackedVector2Array([P.call(5, 3), P.call(16, 3), P.call(16, 21), P.call(5, 21)]), Color("a0703f"))
			ci.draw_circle(P.call(13, 12), 1.2 * s, Color("efc94f"))
			_p(ci, PackedVector2Array([P.call(17, 9), P.call(22, 12), P.call(17, 15)]), Color("c0563f"), false)
		"waldlinge":
			_e(ci, P.call(12, 14), R.call(6.5, 6.5), Color("f2c897"))
			_p(ci, PackedVector2Array([P.call(4, 12), P.call(6, 6), P.call(12, 3), P.call(18, 6), P.call(20, 12)]), Color("8b5a2e"))
			ci.draw_circle(P.call(10, 15), 0.9 * s, INK)
			ci.draw_circle(P.call(14, 15), 0.9 * s, INK)
		"fruehling":
			for i in range(5):
				var a := float(i) / 5.0 * TAU
				_e(ci, P.call(12 + cos(a) * 5, 12 + sin(a) * 5), R.call(3.6, 3.6), Color("f6cfe0"))
			_e(ci, P.call(12, 12), R.call(2.4, 2.4), Color("f2d55a"))
		"sommer":
			for i in range(8):
				var a := float(i) / 8.0 * TAU
				ci.draw_line(P.call(12 + cos(a) * 7, 12 + sin(a) * 7), P.call(12 + cos(a) * 10.5, 12 + sin(a) * 10.5), Color("f2c330"), 2.2 * s, true)
			_e(ci, P.call(12, 12), R.call(5.5, 5.5), Color("f2c330"))
		"herbst":
			_p(ci, PackedVector2Array([P.call(12, 2), P.call(16, 8), P.call(21, 9), P.call(17, 14), P.call(18, 21), P.call(12, 18), P.call(6, 21), P.call(7, 14), P.call(3, 9), P.call(8, 8)]), Color("d9822e"))
			ci.draw_line(P.call(12, 6), P.call(12, 23), Color("8a4a1e"), 1.4 * s, true)
		"winter":
			for i in range(6):
				var a := float(i) / 6.0 * TAU
				ci.draw_line(P.call(12, 12), P.call(12 + cos(a) * 10, 12 + sin(a) * 10), Color("8ab8d8"), 2.0 * s, true)
				ci.draw_line(P.call(12 + cos(a) * 6, 12 + sin(a) * 6), P.call(12 + cos(a + 0.5) * 8, 12 + sin(a + 0.5) * 8), Color("8ab8d8"), 1.4 * s, true)
		"auftraege":
			_p(ci, PackedVector2Array([P.call(5, 3), P.call(19, 3), P.call(19, 21), P.call(5, 21)]), Color("f4ead2"))
			for y in [8.0, 12.0, 16.0]: ci.draw_line(P.call(8, y), P.call(16, y), Color("8a6b40"), 1.2 * s, true)
		"gebaeude":
			draw_icon(ci, "wohnen", rect)
		"lager":
			_p(ci, PackedVector2Array([P.call(3, 8), P.call(21, 8), P.call(21, 21), P.call(3, 21)]), Color("a07040"))
			ci.draw_line(P.call(3, 8), P.call(21, 21), INK, 1.2 * s, true)
			ci.draw_line(P.call(21, 8), P.call(3, 21), INK, 1.2 * s, true)
		_:
			_e(ci, P.call(12, 12), R.call(8, 8), Color("c9b98a"))
