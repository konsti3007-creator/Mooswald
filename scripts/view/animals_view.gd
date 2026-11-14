extends RefCounted
## Animals in the world (visual life; production of pens is in the model).
## - Pen animals live inside their enclosure: wander, graze, rest; at night
##   they sleep. Their number grows with the pen's upgrade level.
## - Wild animals: hares on meadows, squirrels near forest trees, deer at
##   the forest edge, hedgehogs (hibernate in winter) and ducks on the pond
##   (gone while it is frozen). They keep away from walking woodlings.
## Movement uses the game clock: frozen in pause, faster at 2x/4x.

const Rig = preload("res://scripts/anim/animal_rig.gd")
const AnimDefs = preload("res://scripts/anim/anim_defs.gd")

class AnimalNode extends Node2D:
	static var rig = Rig.new()
	var a: Dictionary = {}
	var key := ""
	var scale_value := 1.3
	func refresh() -> void:
		var frame := Rig.frame_for(a.anim, a.t, a.dist, a.species)
		var dir := roundf(a.facing / (TAU / 8.0)) * (TAU / 8.0)
		var k := "%s|%d|%.2f" % [a.anim, frame, dir]
		if k != key:
			key = k
			queue_redraw()
	func _draw() -> void:
		var frame := Rig.frame_for(a.anim, a.t, a.dist, a.species)
		var dir := roundf(a.facing / (TAU / 8.0)) * (TAU / 8.0)
		rig.draw(self, a.species, a.anim, frame, dir, scale_value, int(a.id))

const SPEED := {"huhn": 0.35, "ente": 0.3, "schaf": 0.3, "ziege": 0.4, "reh": 0.7, "hase": 0.9, "eichhoernchen": 0.9, "igel": 0.22}
const LABELS := {"huhn": "Ein Huhn", "ente": "Eine Ente", "schaf": "Ein Schaf", "ziege": "Eine Ziege", "reh": "Ein Reh", "hase": "Ein Hase", "eichhoernchen": "Ein Eichhörnchen", "igel": "Ein Igel"}

var world
var animals: Array = []
var nodes: Dictionary = {}
var next_id := 1
var rng := RandomNumberGenerator.new()
var wild_revision := -1
var pen_counts: Dictionary = {}

func _init(w) -> void:
	world = w
	rng.seed = 2207

func village():
	return world.village()

func reset() -> void:
	for n in nodes.values(): n.queue_free()
	nodes.clear()
	animals.clear()
	pen_counts.clear()
	wild_revision = -1

func _add(species: String, pos: Vector2, pen := -1) -> void:
	var a := {"id": next_id, "species": species, "x": pos.x, "y": pos.y, "facing": rng.randf() * TAU, "anim": "idle", "t": rng.randf() * 3.0, "dist": 0.0, "tx": pos.x, "ty": pos.y, "wait": rng.randf_range(0.5, 4.0), "pen": pen, "hidden": false, "flee": false}
	next_id += 1
	animals.append(a)
	var node := AnimalNode.new()
	node.a = a
	node.scale_value = AnimDefs.WORLD_SCALE
	world.objects.add_child(node)
	nodes[a.id] = node

func _remove(a: Dictionary) -> void:
	if nodes.has(a.id):
		nodes[a.id].queue_free()
		nodes.erase(a.id)
	animals.erase(a)

## Keeps pen herds and wild animals in line with the village.
func sync() -> void:
	var v = village()
	# Pen herds: 2 + upgrade level animals.
	var wanted := {}
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		if v.DEFS[b.type].get("pen", false): wanted[b.id] = [c, b]
	for a in animals.duplicate():
		if a.pen >= 0 and not wanted.has(a.pen): _remove(a)
	for id in wanted:
		var c: Vector2i = wanted[id][0]
		var b: Dictionary = wanted[id][1]
		var want := 2 + int(b.tier)
		var have := 0
		for a in animals:
			if a.pen == id: have += 1
		for i in range(want - have):
			_add(v.DEFS[b.type].herd, _pen_spot(c, b), id)
	if wild_revision == v.revision and animals.size() > 0: return
	wild_revision = v.revision
	var wild := 0
	for a in animals:
		if a.pen < 0: wild += 1
	if wild > 0: return
	_spawn_wild()

func _pen_spot(c: Vector2i, b: Dictionary) -> Vector2:
	var size: Vector2i = village().DEFS[b.type].size
	return Vector2(c) + Vector2(rng.randf_range(-0.2, size.x - 0.8), rng.randf_range(-0.2, size.y - 0.8))

func _spawn_wild() -> void:
	var v = village()
	var meadow: Array = []
	var near_trees: Array = []
	var pond: Array = []
	for y in range(v.SIZE.y):
		for x in range(v.SIZE.x):
			var c := Vector2i(x, y)
			if v.water(c):
				if (x + y) % 2 == 0: pond.append(c)
				continue
			if not v.walkable(c) or v.has_road(c): continue
			var tree := false
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = c + d
				if v.buildings.has(n) and v.buildings[n].type == "Wildbaum": tree = true
			if tree: near_trees.append(c)
			elif (x * 7 + y * 13) % 5 == 0: meadow.append(c)
	rng.seed = 2207 + v.expansion
	for i in range(4):
		if not meadow.is_empty(): _add("hase", Vector2(meadow[rng.randi() % meadow.size()]))
	for i in range(3):
		if not near_trees.is_empty(): _add("eichhoernchen", Vector2(near_trees[rng.randi() % near_trees.size()]))
	for i in range(2):
		if not meadow.is_empty(): _add("igel", Vector2(meadow[rng.randi() % meadow.size()]))
	for i in range(3):
		if not pond.is_empty(): _add("ente", Vector2(pond[rng.randi() % pond.size()]))
	# Deer graze just outside the cleared land, at the western forest edge.
	for i in range(2):
		_add("reh", Vector2(-1.6 - i * 0.8, 6.0 + i * 9.0))

func update(game_delta: float, hour: float, winter: float) -> void:
	sync()
	var v = village()
	var night := hour > 20.5 or hour < 5.5
	for a in animals:
		var node: Node2D = nodes.get(a.id)
		if node == null: continue
		var hide: bool = (a.species in ["igel", "ente"]) and winter > 0.5
		node.visible = not hide
		if hide: continue
		if game_delta <= 0.0:
			node.position = world.grid_to_screen(Vector2(a.x, a.y))
			continue
		a.t += game_delta
		var pos := Vector2(a.x, a.y)
		var target := Vector2(a.tx, a.ty)
		# Wild animals keep their distance to walking woodlings.
		if a.pen < 0 and a.species != "ente" and not a.flee:
			for r in v.residents:
				var rp := Vector2(r.x, r.y)
				if rp.distance_squared_to(pos) < 1.6 and r.anim in ["walk", "carry_walk"]:
					var away := (pos - rp).normalized()
					var dest := pos + away * rng.randf_range(1.6, 2.6)
					if _free(a, dest):
						a.tx = dest.x
						a.ty = dest.y
						a.flee = true
						a.wait = 0.0
						target = dest
					break
		if pos.distance_to(target) > 0.05:
			var speed: float = SPEED.get(a.species, 0.4) * (2.2 if a.flee else 1.0)
			var stepv := minf(speed * game_delta, pos.distance_to(target))
			var d := (target - pos).normalized()
			var npos := pos + d * stepv
			a.x = npos.x
			a.y = npos.y
			a.dist += stepv * AnimDefs.GROUND_PER_CELL / AnimDefs.WORLD_SCALE
			var want := atan2(d.x - d.y, d.x + d.y)
			a.facing = wrapf(a.facing + clampf(wrapf(want - a.facing, -PI, PI), -8.0 * game_delta, 8.0 * game_delta), -PI, PI)
			a.anim = "swim" if a.species == "ente" else "walk"
		else:
			a.flee = false
			a.wait -= game_delta
			if a.species == "ente":
				a.anim = "swim"
			elif night and a.pen >= 0:
				a.anim = "sleep"
			elif a.anim in ["walk", "swim"] or a.wait > 0.0:
				if a.anim == "walk": a.anim = "graze" if rng.randf() < 0.6 else "idle"
			if a.wait <= 0.0:
				a.wait = rng.randf_range(2.0, 6.0)
				var dest := _wander_target(a)
				a.tx = dest.x
				a.ty = dest.y
				if not night or a.pen < 0:
					a.anim = "graze" if rng.randf() < 0.5 else "idle"
		node.position = world.grid_to_screen(Vector2(a.x, a.y))
		node.refresh()

func _wander_target(a: Dictionary) -> Vector2:
	var v = village()
	var pos := Vector2(a.x, a.y)
	if a.pen >= 0:
		var c: Vector2i = v.anchor_of(a.pen)
		if c.x < 0: return pos
		return _pen_spot(c, v.buildings[c])
	for i in range(6):
		var dest := pos + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
		if _free(a, dest): return dest
	return pos

## Wild animals stay on fitting ground: ducks on water, deer outside the
## cleared land, the others on free meadow.
func _free(a: Dictionary, p: Vector2) -> bool:
	var v = village()
	var c := Vector2i(roundi(p.x), roundi(p.y))
	if a.species == "ente": return v.water(c)
	if a.species == "reh": return c.x < 0 and c.x > -4 and c.y >= 0 and c.y < v.SIZE.y
	return v.walkable(c) and not v.has_road(c)

func animal_at(world_pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 24.0
	for a in animals:
		var node: Node2D = nodes.get(a.id)
		if node == null or not node.visible: continue
		var d := (world_pos - (node.position + Vector2(0, -10))).length()
		if d < best_d:
			best_d = d
			best = a
	return best
