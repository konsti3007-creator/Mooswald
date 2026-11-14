extends RefCounted
## Resident navigation on the village grid.
##
## - 8-connected A* with a binary heap. Diagonal steps are only allowed when
##   both orthogonal neighbours are walkable (no squeezing past corners).
## - Roads cost 1.0, meadow 1.8: residents prefer paths but cut across open
##   meadow when that is clearly shorter.
## - Connected regions are labelled once per world revision, so unreachable
##   goals are rejected in O(1) instead of exploring the whole map.
## - Paths are string-pulled into straight segments (never leaving the road
##   network once on it) so movement is natural and uses all 8 headings.
## - Results are cached per revision.

const ROAD_COST := 1.0
const MEADOW_COST := 1.8
const DIAG := 1.41421356
const NEIGHBOURS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## Stateless: region labels and the path cache live in the village model
## (nav_revision, nav_regions, nav_cache), avoiding reference cycles.

static func refresh(v) -> void:
	if v.nav_revision == v.revision: return
	v.nav_revision = v.revision
	v.nav_cache.clear()
	v.nav_regions.clear()
	var regions: Dictionary = v.nav_regions
	var label := 0
	for y in range(v.SIZE.y):
		for x in range(v.SIZE.x):
			var start := Vector2i(x, y)
			if regions.has(start) or not v.walkable(start): continue
			label += 1
			var queue: Array[Vector2i] = [start]
			regions[start] = label
			var head := 0
			while head < queue.size():
				var c: Vector2i = queue[head]
				head += 1
				for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var n: Vector2i = c + d
					if not regions.has(n) and v.walkable(n):
						regions[n] = label
						queue.append(n)

static func region(v, c: Vector2i) -> int:
	refresh(v)
	return v.nav_regions.get(c, 0)

static func reachable(v, a: Vector2i, b: Vector2i) -> bool:
	refresh(v)
	var ra: int = v.nav_regions.get(a, 0)
	return ra != 0 and ra == v.nav_regions.get(b, 0)

static func step_cost(v, c: Vector2i) -> float:
	return ROAD_COST if v.has_road(c) else MEADOW_COST

## Grid path of cells from start (exclusive) to goal (inclusive).
static func cells(v, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if start == goal: return result
	if not reachable(v, start, goal): return result
	var key := Vector4i(start.x, start.y, goal.x, goal.y)
	var cache: Dictionary = v.nav_cache
	if cache.has(key): return cache[key].duplicate()
	v.nav_searches += 1
	var heap: Array = []  # [f, counter, cell]
	var counter := 0
	var g := {start: 0.0}
	var came := {}
	_push(heap, [_h(start, goal), counter, start])
	var closed := {}
	while not heap.is_empty():
		var item: Array = _pop(heap)
		var c: Vector2i = item[2]
		if closed.has(c): continue
		if c == goal:
			while c != start:
				result.push_front(c)
				c = came[c]
			break
		closed[c] = true
		for d in NEIGHBOURS:
			var n: Vector2i = c + d
			if closed.has(n) or not v.walkable(n): continue
			var diagonal: bool = d.x != 0 and d.y != 0
			if diagonal and (not v.walkable(c + Vector2i(d.x, 0)) or not v.walkable(c + Vector2i(0, d.y))): continue
			var cost: float = g[c] + step_cost(v, n) * (DIAG if diagonal else 1.0)
			if cost < g.get(n, INF):
				g[n] = cost
				came[n] = c
				counter += 1
				_push(heap, [cost + _h(n, goal), counter, n])
	if cache.size() > 400: cache.clear()
	cache[key] = result.duplicate()
	return result

## Smoothed waypoints (cell centres as Vector2) ending at goal.
static func waypoints(v, start: Vector2i, goal: Vector2i) -> Array:
	var raw := cells(v, start, goal)
	var points: Array = []
	if raw.is_empty(): return points
	var chain: Array[Vector2i] = [start]
	chain.append_array(raw)
	var i := 0
	while i < chain.size() - 1:
		var j := chain.size() - 1
		while j > i + 1 and not clear(v, chain[i], chain[j]): j -= 1
		points.append(Vector2(chain[j]))
		i = j
	return points

## Straight segment check: every touched cell walkable; segments that start
## and end on roads must stay on roads; no corner squeezing.
static func clear(v, a: Vector2i, b: Vector2i) -> bool:
	var on_road: bool = v.has_road(a) and v.has_road(b)
	var delta := Vector2(b - a)
	var steps := int(ceil(delta.length() * 8.0))
	var prev := a
	for k in range(1, steps + 1):
		var p := Vector2(a) + delta * (float(k) / steps)
		var c := Vector2i(roundi(p.x), roundi(p.y))
		if c == prev: continue
		if not v.walkable(c): return false
		if on_road and not v.has_road(c): return false
		if c.x != prev.x and c.y != prev.y:
			if not v.walkable(Vector2i(c.x, prev.y)) or not v.walkable(Vector2i(prev.x, c.y)): return false
		# Avoid shaving tiles off building corners: keep a clear margin.
		var frac := p - Vector2(c)
		if absf(frac.x) > 0.3 and not v.walkable(c + Vector2i(signi(int(sign(frac.x))), 0)): return false
		if absf(frac.y) > 0.3 and not v.walkable(c + Vector2i(0, signi(int(sign(frac.y))))): return false
		prev = c
	return true

## Nearest walkable cell by breadth-first search (for rescuing residents
## when something is built on top of them).
static func nearest_walkable(v, c: Vector2i) -> Vector2i:
	if v.walkable(c): return c
	var seen := {c: true}
	var queue: Array[Vector2i] = [c]
	var head := 0
	while head < queue.size() and head < 2000:
		var cur: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = cur + d
			if seen.has(n) or not v.inside(n): continue
			if v.walkable(n): return n
			seen[n] = true
			queue.append(n)
	return Vector2i(-1, -1)

static func _h(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return (maxi(dx, dy) - mini(dx, dy)) * ROAD_COST + mini(dx, dy) * ROAD_COST * DIAG

static func _less(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])

static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if not _less(heap[i], heap[parent]): break
		var t = heap[i]
		heap[i] = heap[parent]
		heap[parent] = t
		i = parent

static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var n := heap.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and _less(heap[l], heap[m]): m = l
			if r < n and _less(heap[r], heap[m]): m = r
			if m == i: break
			var t = heap[i]
			heap[i] = heap[m]
			heap[m] = t
			i = m
	return top
