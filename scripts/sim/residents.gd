extends RefCounted
## Resident task simulation (pure model, no rendering, deterministic).
##
## Life cycle of a woodling:
##   idle -> find task -> walk to workplace -> work -> carry goods ->
##   hand over -> idle (rests at home when tired)
##
## Every task is a list of steps. Walking steps move along navigation
## paths; action steps play an animation whose timing comes from
## anim_defs.gd. Action events (hit, cut, pickup, handover ...) are fired by
## the shared event table, exactly once per pass, at any game speed. Goods
## are credited to the village ONLY in the handover event; a cancelled task
## credits carried goods once and releases every reservation.
##
## State lives in plain dictionaries inside the village model so it can be
## saved, validated and tested headlessly. Functions are static (no
## reference cycles).

const AnimDefs = preload("res://scripts/anim/anim_defs.gd")
const Nav = preload("res://scripts/sim/navigation.gd")

const SPEED_ROAD := 0.80
const SPEED_MEADOW := 0.56
const CARRY_FACTOR := 0.85
const HUNGRY_FACTOR := 0.75
const TURN_RATE := 9.0
const FOREST_RADIUS := 8
const PLANT_RADIUS := 4
const HITS_TREE := 4
const HITS_ROCK := 5
const HITS_FACE := 4
const LOAD_WOOD := 8
const LOAD_STONE := 5
const LOAD_FACE := 3
const LOAD_FISH := 4
const TREE_LOADS := 3
const ROCK_LOADS := 6
const REST_TIME := 9.0
const ENERGY_DRAIN := 1.0 / 240.0
const MAX_EVENTS := 96

const STEPS := {
	"wood": ["go_work", "draw", "chop", "stow", "pickup", "go_drop", "putdown"],
	"stone": ["go_work", "draw", "mine", "stow", "pickup", "go_drop", "putdown"],
	"plant": ["go_work", "plant"],
	"reap": ["go_work", "reap", "go_drop", "putdown"],
	"berries": ["go_work", "pick", "go_drop", "putdown"],
	"sow": ["go_work", "sow"],
	"tend": ["go_work", "water"],
	"fetch": ["go_src", "pickup", "go_work", "putdown"],
	"work": ["go_work", "work"],
	"rest": ["go_home", "rest"],
	"fish": ["go_work", "cast", "angle", "reel", "go_drop", "putdown"],
	"idle": ["idle"],
	"stroll": ["go_work", "idle"],
}
const STEP_ANIM := {
	"draw": "draw_tool", "stow": "stow_tool", "chop": "chop", "mine": "mine",
	"plant": "plant", "reap": "reap", "pick": "pick", "sow": "sow",
	"water": "water", "pickup": "pickup", "putdown": "putdown", "rest": "rest",
	"cast": "cast", "angle": "fish_wait", "reel": "reel",
}
const LOOPS := {"chop": HITS_TREE, "mine": HITS_ROCK, "reap": 3, "pick": 3, "sow": 3, "water": 2, "plant": 2}
const STATE_LABEL := {
	"idle": "Ruht", "rest": "Erholt sich zu Hause", "stroll": "Schlendert",
	"wood": "Holzfäller", "stone": "Steinsammler", "plant": "Pflanzt einen Baum",
	"reap": "Erntet ein Beet", "berries": "Pflückt Beeren", "sow": "Sät aus",
	"tend": "Gießt ein Beet", "fetch": "Holt Waren", "work": "Arbeitet", "fish": "Angelt",
}
const ITEM_FOR := {"holz": "logs", "stein": "stone", "getreide": "basket_grain", "beeren": "basket_berries", "mehl": "sack", "bretter": "planks", "brot": "bread", "honig": "honey", "marmelade": "jar", "muenzen": "coins", "nahrung": "basket_berries", "karotten": "basket_veg", "kartoffeln": "basket_veg", "zwiebeln": "basket_veg", "kuerbis": "basket_veg", "kohl": "basket_veg", "flachs": "basket_grain", "sonnenblumen": "basket_grain", "fisch": "fish", "raeucherfisch": "fish"}
const SOURCES := {
	"holz": ["Forsthaus", "Haus"], "stein": ["Steinbruch", "Haus"], "getreide": ["Haus", "Muehle"],
	"mehl": ["Muehle", "Haus"], "brot": ["Baeckerei", "Haus"], "honig": ["Imkerei", "Haus"],
	"beeren": ["Haus", "Kochhaus"], "marmelade": ["Kochhaus", "Haus"],
}
const STORES := {"getreide": ["Haus", "Muehle", "Gasthaus"], "beeren": ["Haus", "Kochhaus", "Gasthaus"]}

# ------------------------------------------------------------- population

static func sync_population(v) -> void:
	var wanted := {}
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		if b.type == "Haus": wanted[b.id] = 2 * int(b.tier)
		elif v.DEFS[b.type].has("special"): wanted[b.id] = 1
	var have := {}
	var keep: Array = []
	for r in v.residents:
		var n: int = have.get(r.home, 0)
		if wanted.has(r.home) and n < wanted[r.home]:
			have[r.home] = n + 1
			keep.append(r)
		else:
			_drop_resident(v, r)
	v.residents = keep
	for home_id in wanted:
		for i in range(int(wanted[home_id]) - int(have.get(home_id, 0))):
			v.residents.append(_new_resident(v, home_id))
	assign_jobs(v)

static func _new_resident(v, home_id: int) -> Dictionary:
	var rid: int = v.next_rid
	v.next_rid += 1
	var r := {
		"id": rid, "home": home_id, "job": -1, "x": -1.0, "y": -1.0,
		"facing": 0.6, "anim": "idle", "at": 0.0, "walk": 0.0, "task": {},
		"carry": {}, "item": "", "energy": 1.0, "think": 0.2 + fmod(rid * 0.37, 1.0),
		"variant": rid % 5, "path": [], "rev": -1, "blocked": 0, "trapped": false,
	}
	var home_b: Dictionary = v.building_by_id(home_id)
	if not home_b.is_empty() and v.DEFS[home_b.type].has("special"):
		var sp: Dictionary = v.SPECIALISTS[v.DEFS[home_b.type].special]
		r.special = v.DEFS[home_b.type].special
		r.variant = sp.palette
	_place_at_home(v, r)
	return r

static func _place_at_home(v, r: Dictionary) -> void:
	var home: Vector2i = v.anchor_of(r.home)
	var spots: Array = v.entrances(home) if home.x >= 0 else []
	if spots.is_empty():
		r.trapped = true
		r.x = float(home.x) + 1.0
		r.y = float(home.y) + 2.0
		return
	r.trapped = false
	var pick: Vector2i = spots[r.id % spots.size()]
	r.x = float(pick.x)
	r.y = float(pick.y)

## Removing a resident (house demolished, capacity reduced) must not lose or
## duplicate goods: carried goods are credited once, reservations released.
static func _drop_resident(v, r: Dictionary) -> void:
	abort_task(v, r, "Bewohner ist ausgezogen")

static func assign_jobs(v) -> void:
	var slots: Array = []
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		if v.is_workplace(b.type) and not b.paused:
			for i in range(int(b.tier)): slots.append(b.id)
	slots.sort()
	var open := {}
	for id in slots: open[id] = open.get(id, 0) + 1
	var free: Array = []
	for r in v.residents:
		if r.job >= 0 and open.get(r.job, 0) > 0:
			open[r.job] -= 1
		else:
			if r.job >= 0:
				if r.task.get("type", "") in ["work", "fetch", "wood", "stone", "plant"]: abort_task(v, r, "")
				r.job = -1
			free.append(r)
	var vacancies: Array = []
	for id in slots:
		if open.get(id, 0) > 0:
			vacancies.append(id)
			open[id] -= 1
	# Specialists first take a free place in their own trade.
	for r in free.duplicate():
		var trade: String = v.SPECIALISTS.get(r.get("special",""), {}).get("job","")
		if trade == "": continue
		for id in vacancies:
			var bb: Dictionary = v.building_by_id(id)
			if not bb.is_empty() and bb.type == trade:
				r.job = id
				vacancies.erase(id)
				free.erase(r)
				break
	# Fill vacancies in building order with the free resident living closest.
	for id in vacancies:
		if free.is_empty(): break
		var at: Vector2i = v.anchor_of(id)
		var best := 0
		for i in range(free.size()):
			var a: Vector2i = v.anchor_of(free[i].home)
			var b: Vector2i = v.anchor_of(free[best].home)
			if a.distance_squared_to(at) < b.distance_squared_to(at): best = i
		var r: Dictionary = free[best]
		free.remove_at(best)
		if not r.task.is_empty() and r.task.type in ["reap", "berries", "sow", "tend", "stroll", "idle"] and r.carry.is_empty():
			abort_task(v, r, "")
		r.job = id

# ------------------------------------------------------------- main step

static func step(v, dt: float) -> void:
	if v.residents_rev != v.revision:
		v.residents_rev = v.revision
		sync_population(v)
	for r in v.residents:
		if r.trapped:
			r.think -= dt
			if r.think <= 0:
				r.think = 2.0
				_place_at_home(v, r)
			continue
		if r.rev != v.revision:
			r.rev = v.revision
			_revalidate(v, r)
		_update(v, r, dt)

static func _update(v, r: Dictionary, dt: float) -> void:
	if r.task.is_empty():
		r.think -= dt
		_set_anim(r, "idle")
		r.at += dt
		if r.think <= 0:
			r.think = 0.6
			choose_task(v, r)
		return
	var t: Dictionary = r.task
	var steps: Array = STEPS[t.type]
	if t.step >= steps.size():
		_finish(v, r)
		return
	var step_name: String = steps[t.step]
	var factor: float = HUNGRY_FACTOR if v.hungry else 1.0
	if step_name != "idle" and step_name != "rest": r.energy = maxf(0.0, r.energy - dt * ENERGY_DRAIN)
	if step_name.begins_with("go_"):
		var target := _walk_target(v, r, step_name)
		if target.x < -100.0:
			abort_task(v, r, "Kein Weg zum Ziel")
			r.blocked += 1
			r.think = 2.5
			return
		if _move(v, r, target, dt * factor):
			r.path = []
			t.step += 1
			t.erase("goal_x")
			_begin_step(v, r)
		return
	_action(v, r, step_name, dt * factor)

# ------------------------------------------------------------- choosing

static func choose_task(v, r: Dictionary) -> void:
	if r.energy < 0.25 and _start(v, r, {"type": "rest"}): return
	if r.job >= 0:
		var a: Vector2i = v.anchor_of(r.job)
		if a.x >= 0:
			var b: Dictionary = v.buildings[a]
			match b.type:
				"Forsthaus":
					if _job_wood(v, r, a): return
					if _job_plant(v, r, a): return
				"Steinbruch":
					if _job_stone(v, r, a): return
				"Angler":
					if _job_fish(v, r, a): return
				_:
					if _job_workshop(v, r, a, b): return
	if _job_fields(v, r): return
	_job_idle(v, r)

static func _start(v, r: Dictionary, task: Dictionary) -> bool:
	task.step = 0
	r.task = task
	r.path = []
	r.blocked = 0
	_begin_step(v, r)
	return true

static func _cell(r: Dictionary) -> Vector2i:
	return Vector2i(roundi(r.x), roundi(r.y))

static func _dist2(r: Dictionary, c: Vector2i) -> float:
	return Vector2(r.x, r.y).distance_squared_to(Vector2(c))

## Work spot next to an object: [cell, Vector2 position] or [].
static func work_spot(v, r: Dictionary, anchor: Vector2i, others_ok := false) -> Array:
	var b: Dictionary = v.buildings.get(anchor, {})
	if b.is_empty(): return []
	var here := _cell(r)
	var options: Array = []
	var size: Vector2i = v.DEFS[b.type].size
	var center := Vector2(anchor) + Vector2(size - Vector2i.ONE) * 0.5
	for cell in v.entrances(anchor):
		if not Nav.reachable(v, here, cell): continue
		var key := "c%d,%d" % [cell.x, cell.y]
		if v.reserved.has(key) and v.reserved[key] != r.id and not others_ok: continue
		# Prefer spots on the camera side so the work stays visible.
		var front: float = (cell.x + cell.y) - (center.x + center.y)
		var score: float = _dist2(r, cell) * 0.05 - front * 2.0
		options.append([score, cell])
	if options.is_empty(): return []
	options.sort_custom(func(p, q): return p[0] < q[0])
	var cell: Vector2i = options[0][1]
	# Step towards the object: close enough for the tool to reach.
	var nearest := anchor
	for fp in v.footprint(anchor, b.type):
		if Vector2(fp).distance_squared_to(Vector2(cell)) < Vector2(nearest).distance_squared_to(Vector2(cell)): nearest = fp
	var pull := 0.40 if size == Vector2i.ONE else 0.30
	if v.DEFS[b.type].get("pen", false): pull = 0.0  # stay outside the fence
	var pos := Vector2(cell) + (Vector2(nearest) - Vector2(cell)) * pull
	return [cell, pos]

static func _reserve_spot(v, r: Dictionary, task: Dictionary, spot: Array) -> void:
	task.spot_x = spot[1].x
	task.spot_y = spot[1].y
	task.spot_cell = [spot[0].x, spot[0].y]
	v.reserved["c%d,%d" % [spot[0].x, spot[0].y]] = r.id

static func _job_wood(v, r: Dictionary, lodge: Vector2i) -> bool:
	if not v.has_space("holz", LOAD_WOOD):
		v.buildings[lodge].status = "full"
		return false
	var best: Array = []
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		if b.type != "Wildbaum" or b.stock <= 0: continue
		if v.reserved.has("b%d" % b.id): continue
		var d := Vector2(c).distance_to(Vector2(lodge) + Vector2(0.5, 0.5))
		if d > FOREST_RADIUS: continue
		var spot := work_spot(v, r, c)
		if spot.is_empty(): continue
		var score := d + sqrt(_dist2(r, c)) * 0.3
		if best.is_empty() or score < best[0]: best = [score, c, spot]
	if best.is_empty(): return false
	var tree: Dictionary = v.buildings[best[1]]
	var task := {"type": "wood", "target": tree.id, "drop": r.job, "hits": 0, "tool": "axe"}
	v.reserved["b%d" % tree.id] = r.id
	_reserve_spot(v, r, task, best[2])
	return _start(v, r, task)

static func _job_plant(v, r: Dictionary, lodge: Vector2i) -> bool:
	var young := 0
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		if b.type == "Wildbaum" and Vector2(c).distance_to(Vector2(lodge)) <= FOREST_RADIUS:
			if b.stock <= 0: young += 1
	if young >= 3: return false
	# A free meadow cell that does not touch roads or buildings (never block
	# an entrance), with a reachable neighbour to stand on.
	var best: Array = []
	for dy in range(-PLANT_RADIUS, PLANT_RADIUS + 2):
		for dx in range(-PLANT_RADIUS, PLANT_RADIUS + 2):
			var c := lodge + Vector2i(dx, dy)
			if not v.can_place(c, "Wildbaum") or v.reserved.has("p%d,%d" % [c.x, c.y]): continue
			var crowded := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if v.occupied.has(c + Vector2i(ox, oy)) or v.water(c + Vector2i(ox, oy)): crowded = true
			if crowded: continue
			var stand := c + Vector2i(1, 0)
			if not v.walkable(stand): stand = c + Vector2i(0, 1)
			if not v.walkable(stand) or not Nav.reachable(v, _cell(r), stand): continue
			var score := Vector2(c).distance_to(Vector2(lodge)) + float((c.x * 7 + c.y * 13) % 5) * 0.1
			if best.is_empty() or score < best[0]: best = [score, c, stand]
	if best.is_empty(): return false
	var c: Vector2i = best[1]
	var stand: Vector2i = best[2]
	var task := {"type": "plant", "cell": [c.x, c.y], "tool": "trowel"}
	v.reserved["p%d,%d" % [c.x, c.y]] = r.id
	var pos := Vector2(stand) + (Vector2(c) - Vector2(stand)) * 0.4
	_reserve_spot(v, r, task, [stand, pos])
	return _start(v, r, task)

static func _job_stone(v, r: Dictionary, quarry: Vector2i) -> bool:
	if not v.has_space("stein", LOAD_STONE):
		v.buildings[quarry].status = "full"
		return false
	var best: Array = []
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		if b.type != "Felsen" or b.stock <= 0 or v.reserved.has("b%d" % b.id): continue
		var d := Vector2(c).distance_to(Vector2(quarry) + Vector2(0.5, 0.5))
		if d > FOREST_RADIUS: continue
		var spot := work_spot(v, r, c)
		if spot.is_empty(): continue
		var score := d + sqrt(_dist2(r, c)) * 0.3
		if best.is_empty() or score < best[0]: best = [score, c, spot]
	var task := {"type": "stone", "drop": r.job, "hits": 0, "tool": "pick"}
	if best.is_empty():
		# No boulder around: work the quarry's own rock face (smaller loads).
		var spot := work_spot(v, r, quarry)
		if spot.is_empty(): return false
		task.target = r.job
		task.face = true
		_reserve_spot(v, r, task, spot)
		return _start(v, r, task)
	var rock: Dictionary = v.buildings[best[1]]
	task.target = rock.id
	v.reserved["b%d" % rock.id] = r.id
	_reserve_spot(v, r, task, best[2])
	return _start(v, r, task)

## Angler: walks to a free shore spot near the hut, casts, waits for a
## bite (longer in winter), reels in and carries the catch to the hut.
static func _job_fish(v, r: Dictionary, hut: Vector2i) -> bool:
	if not v.has_space("fisch", LOAD_FISH):
		v.buildings[hut].status = "full"
		return false
	var best: Array = []
	var here := _cell(r)
	for dy in range(-FOREST_RADIUS, FOREST_RADIUS + 2):
		for dx in range(-FOREST_RADIUS, FOREST_RADIUS + 2):
			var c := hut + Vector2i(dx, dy)
			if not v.walkable(c) or v.reserved.has("c%d,%d" % [c.x, c.y]): continue
			var wet := Vector2i(-1, -1)
			for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				if v.water(c + d) and v.inside(c + d): wet = c + d
			if wet.x < 0 or not Nav.reachable(v, here, c): continue
			var score := Vector2(c).distance_to(Vector2(hut)) + float((c.x * 5 + c.y * 3) % 4) * 0.2
			# Avoid spots hidden behind the hut's own roof.
			if c.x + c.y < hut.x + hut.y + 2 and absi((c.x - c.y) - (hut.x - hut.y)) <= 3: score += 5.0
			if best.is_empty() or score < best[0]: best = [score, c, wet]
	if best.is_empty(): return false
	var c: Vector2i = best[1]
	var wet: Vector2i = best[2]
	var patience: float = 3.0 / maxf(0.3, v.season_factor("fish"))
	var task := {"type": "fish", "drop": r.job, "cell": [wet.x, wet.y], "tool": "rod", "loops": maxi(2, roundi(patience))}
	_reserve_spot(v, r, task, [c, Vector2(c) + (Vector2(wet) - Vector2(c)) * 0.35])
	return _start(v, r, task)

static func _job_workshop(v, r: Dictionary, a: Vector2i, b: Dictionary) -> bool:
	var d: Dictionary = v.DEFS[b.type]
	if not d.has("output"): return false
	var inputs: Dictionary = d.get("input", {})
	if b.working or b.supply > 0 or inputs.is_empty():
		var spot := work_spot(v, r, a)
		if spot.is_empty(): return false
		var task := {"type": "work", "target": b.id}
		_reserve_spot(v, r, task, spot)
		return _start(v, r, task)
	# Fetch inputs for up to two cycles if the village has them.
	var cycles := 0
	for n in [2, 1]:
		var need := {}
		for k in inputs: need[k] = inputs[k] * n
		if v.afford(need):
			cycles = n
			break
	if cycles == 0:
		b.status = "wartet"
		return false
	if v.reserved.has("f%d" % b.id): return false
	var main_kind: String = inputs.keys()[0]
	var source := _nearest_building(v, r, SOURCES.get(main_kind, ["Haus"]), a)
	var task := {"type": "fetch", "target": b.id, "cycles": cycles, "kind": main_kind}
	if source.x >= 0:
		var src_spot := work_spot(v, r, source, true)
		if not src_spot.is_empty():
			task.src_x = src_spot[1].x
			task.src_y = src_spot[1].y
			task.src = v.buildings[source].id
	var spot := work_spot(v, r, a)
	if spot.is_empty(): return false
	v.reserved["f%d" % b.id] = r.id
	_reserve_spot(v, r, task, spot)
	if not task.has("src"):
		# Nothing to walk to: the goods are handed over at the workshop.
		task.src_x = spot[1].x
		task.src_y = spot[1].y
	return _start(v, r, task)

static func _job_fields(v, r: Dictionary) -> bool:
	var best: Array = []
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		var kind := ""
		if b.type == "Feld":
			var crop: Dictionary = v.crop_of(b)
			var main_good: String = crop.harvest.keys()[0]
			if b.progress >= 1.0 and b.sown:
				if v.has_space(main_good, int(crop.harvest[main_good])): kind = "reap"
			elif not b.sown:
				if v.afford({"muenzen": v.CROPS.get(b.get("next_crop", "korn"), v.CROPS.korn).seed}): kind = "sow"
			elif not b.get("tended", false) and b.progress < 0.7: kind = "tend"
		elif b.type == "Beeren" and b.progress >= 1.0 and v.has_space("beeren", 5):
			kind = "berries"
		if kind == "" or b.paused or v.reserved.has("b%d" % b.id): continue
		var priority: float = {"reap": 0.0, "berries": 0.0, "sow": 6.0, "tend": 14.0}[kind]
		var score := sqrt(_dist2(r, c)) + priority
		if not best.is_empty() and score >= best[0]: continue
		var spot := work_spot(v, r, c)
		if spot.is_empty(): continue
		best = [score, c, spot, kind]
	if best.is_empty(): return false
	var field: Dictionary = v.buildings[best[1]]
	var task := {"type": best[3], "target": field.id}
	if best[3] == "reap":
		task.anim = "reap" if v.crop_of(field).anim == "reap" else "plant"
		task.tool = "sickle" if task.anim == "reap" else "trowel"
	if best[3] == "sow": task.crop = field.get("next_crop", "korn")
	if best[3] == "tend": task.tool = "can"
	v.reserved["b%d" % field.id] = r.id
	_reserve_spot(v, r, task, best[2])
	return _start(v, r, task)

static func _job_idle(v, r: Dictionary) -> void:
	var roll := _rand(r, v, 3.1)
	var home: Vector2i = v.anchor_of(r.home)
	# Never stand on top of another woodling: crowded spots trigger a stroll
	# to a free place nearby.
	var crowded := false
	for other in v.residents:
		if other.id != r.id and not other.trapped and Vector2(other.x, other.y).distance_squared_to(Vector2(r.x, r.y)) < 0.16:
			crowded = true
			break
	if crowded: roll = 0.0
	if roll < 0.35 and home.x >= 0:
		# Short stroll to a free spot near home.
		for attempt in range(6):
			var c := home + Vector2i(int(_rand(r, v, attempt * 1.7) * 7.0) - 3, int(_rand(r, v, attempt * 2.9 + 1.0) * 7.0) - 2)
			var key := "c%d,%d" % [c.x, c.y]
			var taken := false
			for other in v.residents:
				if other.id != r.id and Vector2i(roundi(other.x), roundi(other.y)) == c: taken = true
			if v.walkable(c) and not taken and not v.reserved.has(key) and Nav.reachable(v, _cell(r), c) and c != _cell(r):
				var task := {"type": "stroll", "time": 2.0 + _rand(r, v, 9.0) * 3.0}
				_reserve_spot(v, r, task, [c, Vector2(c) + Vector2(_rand(r, v, 4.0) - 0.5, _rand(r, v, 5.0) - 0.5) * 0.5])
				_start(v, r, task)
				return
	_start(v, r, {"type": "idle", "time": 2.0 + _rand(r, v, 7.0) * 3.0, "look": roll > 0.62})

static func _nearest_building(v, r: Dictionary, types: Array, near: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		if not b.type in types: continue
		var spot_ok := false
		for e in v.entrances(c):
			if Nav.reachable(v, _cell(r), e): spot_ok = true; break
		if not spot_ok: continue
		var d := Vector2(c).distance_squared_to(Vector2(near))
		if d < best_d:
			best_d = d
			best = c
	return best

static func _rand(r: Dictionary, v, salt: float) -> float:
	return fposmod(sin(r.id * 12.9898 + v.elapsed * 0.7 + salt * 78.233) * 43758.5453, 1.0)

# ------------------------------------------------------------- walking

static func _walk_target(v, r: Dictionary, step_name: String) -> Vector2:
	var t: Dictionary = r.task
	match step_name:
		"go_work":
			return Vector2(t.spot_x, t.spot_y)
		"go_src":
			return Vector2(t.src_x, t.src_y)
		"go_home":
			if not t.has("home_x"):
				var home: Vector2i = v.anchor_of(r.home)
				var spot := work_spot(v, r, home, true) if home.x >= 0 else []
				if spot.is_empty(): return Vector2(-999, -999)
				t.home_x = spot[1].x
				t.home_y = spot[1].y
			return Vector2(t.home_x, t.home_y)
		"go_drop":
			if not t.has("drop_x"):
				var target := Vector2i(-1, -1)
				if t.has("drop") and v.anchor_of(t.drop).x >= 0:
					target = v.anchor_of(t.drop)
				else:
					var kind: String = r.carry.keys()[0] if not r.carry.is_empty() else "getreide"
					target = _nearest_building(v, r, STORES.get(kind, ["Haus"]), _cell(r))
				var spot := work_spot(v, r, target, true) if target.x >= 0 else []
				if spot.is_empty():
					# No reachable store: hand the goods over right here
					# instead of stranding them (never an economic dead end).
					t.drop_x = r.x
					t.drop_y = r.y
				else:
					t.drop_x = spot[1].x
					t.drop_y = spot[1].y
					t.drop_face = [v.buildings[target].id]
			return Vector2(t.drop_x, t.drop_y)
	return Vector2(-999, -999)

## Moves the resident towards target. Returns true on arrival.
static func _move(v, r: Dictionary, target: Vector2, dt: float) -> bool:
	var pos := Vector2(r.x, r.y)
	if pos.distance_to(target) < 0.02:
		r.x = target.x
		r.y = target.y
		return true
	var t: Dictionary = r.task
	if r.path.is_empty() or t.get("goal_x", -1.0) != target.x or t.get("goal_y", -1.0) != target.y:
		var here := _cell(r)
		if not v.walkable(here):
			var rescue := Nav.nearest_walkable(v, here)
			if rescue.x < 0: return false
			r.x = float(rescue.x)
			r.y = float(rescue.y)
			here = rescue
			pos = Vector2(r.x, r.y)
		var goal := Vector2i(roundi(target.x), roundi(target.y))
		var path: Array = []
		if goal != here:
			if not Nav.reachable(v, here, goal):
				r.task.goal_x = -2.0
				return _fail_path(v, r)
			path = Nav.waypoints(v, here, goal)
			if path.is_empty(): return _fail_path(v, r)
			# Skip the goal cell centre only if the straight line from the
			# previous waypoint to the exact spot touches free cells only.
			var prev: Vector2 = path[path.size() - 2] if path.size() >= 2 else pos
			if _segment_free(v, prev, target): path.pop_back()
			# Leave a work spot (off the cell centre) via the centre if the
			# direct line would clip a blocked corner.
			if not path.is_empty() and not _segment_free(v, pos, path[0]): path.push_front(Vector2(here))
		if not path.is_empty() or _segment_free(v, pos, target):
			path.append(target)
		else:
			path = [Vector2(here), target]
		r.path = path
		t.goal_x = target.x
		t.goal_y = target.y
	var carrying: bool = not r.carry.is_empty() or r.item in ["logs", "stone", "sack", "planks"]
	var budget := dt
	while budget > 0.0 and not r.path.is_empty():
		var next: Vector2 = r.path[0]
		var cell := _cell(r)
		var speed := SPEED_ROAD if v.has_road(cell) else SPEED_MEADOW
		if carrying: speed *= CARRY_FACTOR
		var seg := next - pos
		var length := seg.length()
		var reach := speed * budget
		if length <= reach:
			budget -= length / speed
			_advance(r, pos, next, length, dt)
			pos = next
			r.path.pop_front()
		else:
			var np := pos + seg / length * reach
			_advance(r, pos, np, reach, dt)
			pos = np
			budget = 0.0
	return r.path.is_empty()

static func _segment_free(v, a: Vector2, b: Vector2) -> bool:
	var steps := int(ceil(a.distance_to(b) * 8.0)) + 1
	for k in range(steps + 1):
		var p := a.lerp(b, float(k) / steps)
		if not v.walkable(Vector2i(roundi(p.x), roundi(p.y))): return false
	return true

static func _advance(r: Dictionary, from: Vector2, to: Vector2, length: float, dt: float) -> void:
	r.x = to.x
	r.y = to.y
	if length > 0.0001:
		var d := to - from
		_turn_towards(r, atan2(d.x - d.y, d.x + d.y), dt * 1.6)
	var carrying: bool = r.item in ["logs", "stone", "sack", "planks", "basket_grain", "basket_berries", "bread", "jar", "honey", "flour", "coins"]
	_set_anim(r, "carry_walk" if carrying else "walk")
	r.walk += length * AnimDefs.GROUND_PER_CELL / AnimDefs.WORLD_SCALE

static func _fail_path(v, r: Dictionary) -> bool:
	r.path = []
	r.task.goal_x = -5.0
	abort_task(v, r, "Kein Weg zum Ziel")
	r.blocked += 1
	r.think = 3.0
	return false

static func _turn_towards(r: Dictionary, angle: float, dt: float) -> float:
	var diff := wrapf(angle - r.facing, -PI, PI)
	var stepv := clampf(diff, -TURN_RATE * dt, TURN_RATE * dt)
	r.facing = wrapf(r.facing + stepv, -PI, PI)
	return absf(diff - stepv)

static func face_angle(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(d.x - d.y, d.x + d.y)

# ------------------------------------------------------------- actions

static func _set_anim(r: Dictionary, anim: String) -> void:
	if r.anim != anim:
		r.anim = anim
		r.at = 0.0
		r.ev = -1.0

static func _begin_step(v, r: Dictionary) -> void:
	var t: Dictionary = r.task
	var steps: Array = STEPS[t.type]
	if t.step >= steps.size(): return
	var name: String = steps[t.step]
	if name == "reap" and t.type == "reap":
		# The crop decides: sickle (grain, cabbage, flax ...) or digging.
		r.anim = t.get("anim", "reap")
		r.at = 0.0
		r.ev = -1.0
	elif STEP_ANIM.has(name):
		r.anim = STEP_ANIM[name]
		r.at = 0.0
		r.ev = -1.0
	elif name == "reap" and t.type == "reap":
		r.anim = t.get("anim", "reap")
		r.at = 0.0
		r.ev = -1.0
	elif name == "work":
		var b: Dictionary = v.building_by_id(t.target)
		r.anim = AnimDefs.WORK_ANIM.get(b.get("type", ""), "knead")
		r.at = 0.0
		r.ev = -1.0
	elif name == "idle":
		r.anim = "look" if t.get("look", false) else "idle"
		r.at = 0.0
		r.ev = -1.0
	t.passes = 0

## Object the resident works on (for orientation and effects).
static func _focus(v, r: Dictionary) -> Vector2:
	var t: Dictionary = r.task
	var id: int = t.get("target", -1)
	var steps: Array = STEPS[t.type]
	var name: String = steps[mini(t.step, steps.size() - 1)]
	if t.has("cell") and not (name == "putdown" and t.has("drop_face")): return Vector2(t.cell[0], t.cell[1])
	if name in ["putdown"] and t.has("drop_face"): id = t.drop_face[0]
	if name == "pickup" and t.type == "fetch" and t.has("src"): id = t.src
	if name in ["putdown"] and t.type in ["reap", "berries", "wood", "stone"] and not t.has("drop_face"): return Vector2(r.x, r.y) + Vector2(0.5, 0.5)
	var a: Vector2i = v.anchor_of(id)
	if a.x < 0: return Vector2(r.x, r.y) + Vector2(0.5, 0.5)
	var size: Vector2i = v.DEFS[v.buildings[a].type].size
	return Vector2(a) + Vector2(size - Vector2i.ONE) * 0.5

static func _action(v, r: Dictionary, name: String, dt: float) -> void:
	var t: Dictionary = r.task
	# Stand still and turn to face the work before the action starts.
	if name != "idle" and name != "rest":
		var focus := _focus(v, r)
		var remaining := _turn_towards(r, face_angle(Vector2(r.x, r.y), focus), dt)
		if remaining > 0.3 and r.at == 0.0:
			return
	elif name == "rest":
		_turn_towards(r, 0.7, dt)
	if name == "work":
		_work(v, r, dt)
		return
	if name == "idle":
		r.at += dt
		if r.at >= t.get("time", 3.0): t.step += 1; _begin_step(v, r)
		return
	if name == "rest":
		r.at += dt
		var rest_time := REST_TIME * (0.5 if v.has_special("kraeuter") else 1.0)
		r.energy = minf(1.0, r.energy + dt / rest_time)
		if r.at >= rest_time: t.step += 1; _begin_step(v, r)
		return
	var anim: String = r.anim
	var length := AnimDefs.length(anim)
	var loops: int = LOOPS.get(name, 1)
	if name == "angle": loops = int(t.get("loops", 3))
	if name == "chop" or name == "mine":
		loops = HITS_FACE if t.get("face", false) else (HITS_TREE if name == "chop" else HITS_ROCK)
	var end_time := length * loops
	var t0: float = r.get("ev", -1.0)
	var t1: float = minf(r.at + dt, end_time)
	for e in AnimDefs.events_between(anim, t0 if t0 >= 0.0 else -1.0, t1):
		_event(v, r, name, e[1], int(floor(e[0] / length + 0.0001)), loops)
		if r.task.is_empty() or r.task != t: return
	r.ev = t1
	r.at = t1
	if r.at >= end_time - 0.00001:
		t.step += 1
		_begin_step(v, r)
		if t.step >= STEPS[t.type].size(): _finish(v, r)

static func _emit(v, kind: String, r: Dictionary, data := {}) -> void:
	var e := {"type": kind, "rid": r.id, "x": r.x, "y": r.y}
	e.merge(data)
	v.events.append(e)
	if v.events.size() > MAX_EVENTS: v.events.pop_front()

## Action events: the only place where world state and goods change.
static func _event(v, r: Dictionary, step_name: String, event: String, pass_index: int, loops: int) -> void:
	var t: Dictionary = r.task
	var last := pass_index >= loops - 1
	# Digging crops (kneeling with a trowel) completes like a sickle cut.
	if t.type == "reap" and event == "plant": event = "cut"
	match event:
		"cast":
			var fx := _focus(v, r)
			_emit(v, "cast", r, {"tx": fx.x, "ty": fx.y})
		"catch":
			var fx := _focus(v, r)
			r.carry = {"fisch": LOAD_FISH}
			r.item = "fish"
			_emit(v, "catch", r, {"tx": fx.x, "ty": fx.y})
		"hit":
			t.hits = int(t.get("hits", 0)) + 1
			var target_a: Vector2i = v.anchor_of(t.target)
			var fx := _focus(v, r)
			_emit(v, "hit", r, {"kind": "wood" if t.type == "wood" else "stone", "tx": fx.x, "ty": fx.y, "bid": t.target})
			if last:
				if target_a.x < 0:
					abort_task(v, r, "Ziel verschwunden")
					return
				var b: Dictionary = v.buildings[target_a]
				if t.type == "wood":
					b.stock = maxi(0, int(b.stock) - 1)
					r.carry = {"holz": LOAD_WOOD + (2 if v.has_special("holz") else 0)}
					if b.stock == 0:
						b.progress = 0.0
						_emit(v, "fell", r, {"tx": fx.x, "ty": fx.y, "bid": b.id})
				elif t.get("face", false):
					r.carry = {"stein": LOAD_FACE}
				else:
					b.stock = maxi(0, int(b.stock) - 1)
					r.carry = {"stein": LOAD_STONE + (2 if v.has_special("stein") else 0)}
				v.reserved.erase("b%d" % t.target)
		"tool_out", "tool_in":
			pass
		"pickup":
			if t.type == "fetch":
				# Inputs leave the village stock exactly here; they are now
				# carried and either handed to the workshop or returned.
				var b: Dictionary = v.building_by_id(t.target)
				if b.is_empty():
					abort_task(v, r, "Werkstatt verschwunden")
					return
				var need := {}
				for k in v.DEFS[b.type].input: need[k] = v.DEFS[b.type].input[k] * int(t.cycles)
				if not v.afford(need):
					abort_task(v, r, "Waren fehlen")
					return
				v.exchange(need, -1)
				r.carry = need
				t.carry_inputs = true
			var kind: String = r.carry.keys()[0] if not r.carry.is_empty() else "holz"
			r.item = ITEM_FOR.get(kind, "sack")
			_emit(v, "pickup", r, {"kind": kind})
		"handover":
			var fx := _focus(v, r)
			if t.type == "fetch":
				var b: Dictionary = v.building_by_id(t.target)
				if b.is_empty():
					abort_task(v, r, "Werkstatt verschwunden")
					return
				b.supply = int(b.supply) + int(t.cycles)
				r.carry = {}
				t.erase("carry_inputs")
				v.reserved.erase("f%d" % t.target)
				_emit(v, "supply", r, {"tx": fx.x, "ty": fx.y, "bid": t.target})
			else:
				var goods: Dictionary = r.carry
				r.carry = {}
				v.receive(goods)
				_emit(v, "handover", r, {"goods": goods, "tx": fx.x, "ty": fx.y})
			r.item = ""
		"cut", "drop_in":
			var fx := _focus(v, r)
			_emit(v, event, r, {"tx": fx.x, "ty": fx.y, "bid": t.target})
			if t.type == "berries": r.item = "basket"
			if last: _complete_harvest(v, r)
		"pluck":
			var fx := _focus(v, r)
			_emit(v, "pluck", r, {"tx": fx.x, "ty": fx.y, "bid": t.target})
		"sow":
			var fx := _focus(v, r)
			_emit(v, "sow", r, {"tx": fx.x, "ty": fx.y})
			if last:
				var b: Dictionary = v.building_by_id(t.target)
				if not b.is_empty():
					var crop: Dictionary = v.CROPS.get(t.get("crop", "korn"), v.CROPS.korn)
					if v.afford({"muenzen": crop.seed}):
						v.exchange({"muenzen": crop.seed}, -1)
						b.crop = t.get("crop", "korn")
						b.sown = true
						b.progress = 0.0
						b.ripe_time = 0.0
				v.reserved.erase("b%d" % t.target)
		"water":
			var fx := _focus(v, r)
			_emit(v, "water", r, {"tx": fx.x, "ty": fx.y})
			if last:
				var b: Dictionary = v.building_by_id(t.target)
				if not b.is_empty(): b.tended = true
				v.reserved.erase("b%d" % t.target)
		"plant":
			var c := Vector2i(t.cell[0], t.cell[1])
			_emit(v, "plant", r, {"tx": c.x, "ty": c.y})
			if last:
				v.reserved.erase("p%d,%d" % [c.x, c.y])
				if v.can_place(c, "Wildbaum"):
					v.insert(c, "Wildbaum")
					var tree: Dictionary = v.buildings[c]
					tree.stock = 0
					tree.progress = 0.08

static func _complete_harvest(v, r: Dictionary) -> void:
	var t: Dictionary = r.task
	var b: Dictionary = v.building_by_id(t.target)
	v.reserved.erase("b%d" % t.target)
	if b.is_empty() or b.progress < 1.0:
		# Harvested meanwhile by hand or removed: nothing to carry.
		abort_task(v, r, "")
		return
	var goods: Dictionary = v.harvest_yield(b)
	b.progress = 0.0
	b.ripe_time = 0.0
	if b.type == "Feld":
		b.sown = false
		b.tended = false
	r.carry = goods
	r.item = ITEM_FOR.get(goods.keys()[0], "basket_grain")
	_emit(v, "harvested", r, {"bid": b.id, "goods": goods})

## Workshop work: the worker stands at the building and works while the
## building has a cycle running or supply waiting.
static func _work(v, r: Dictionary, dt: float) -> void:
	var t: Dictionary = r.task
	var b: Dictionary = v.building_by_id(t.target)
	if b.is_empty() or b.paused:
		t.step += 1
		_finish(v, r)
		return
	var inputs: Dictionary = v.DEFS[b.type].get("input", {})
	if not b.working and int(b.supply) <= 0 and not inputs.is_empty():
		t.step += 1
		_finish(v, r)
		return
	b.crew = int(b.get("crew", 0)) + 1
	var anim: String = r.anim
	var t0: float = r.get("ev", -1.0)
	var t1: float = r.at + dt
	for e in AnimDefs.events_between(anim, t0 if t0 >= 0.0 else -1.0, t1):
		_emit(v, "work", r, {"event": e[1], "btype": b.type, "bid": b.id, "tx": _focus(v, r).x, "ty": _focus(v, r).y})
	r.ev = t1
	r.at = t1

static func _finish(v, r: Dictionary) -> void:
	var t: Dictionary = r.task
	_release(v, r)
	if not r.carry.is_empty():
		# Should not happen in a finished task; never lose goods.
		v.receive(r.carry)
		r.carry = {}
	r.item = ""
	r.task = {}
	r.path = []
	r.think = 0.25 if t.get("type", "") != "idle" else 0.0
	_set_anim(r, "idle")

static func _release(v, r: Dictionary) -> void:
	var keys: Array = []
	for k in v.reserved:
		if v.reserved[k] == r.id: keys.append(k)
	for k in keys: v.reserved.erase(k)

## Cancels the current task cleanly: reservations are released, carried
## goods are credited once (inputs return to stock, products are delivered).
static func abort_task(v, r: Dictionary, reason: String) -> void:
	_release(v, r)
	if not r.carry.is_empty():
		v.receive(r.carry, r.task.get("carry_inputs", false))
		r.carry = {}
	r.item = ""
	r.task = {}
	r.path = []
	if reason != "": r.status = reason
	_set_anim(r, "idle")

## Called when the world changed (build, demolish, move, load).
static func _revalidate(v, r: Dictionary) -> void:
	r.path = []
	var here := _cell(r)
	if not v.walkable(here):
		var rescue := Nav.nearest_walkable(v, here)
		if rescue.x < 0:
			r.trapped = true
			abort_task(v, r, "Eingeschlossen")
			return
		r.x = float(rescue.x)
		r.y = float(rescue.y)
	if r.task.is_empty(): return
	var t: Dictionary = r.task
	t.erase("goal_x")
	if t.has("target") and v.anchor_of(t.target).x < 0:
		abort_task(v, r, "Ziel wurde entfernt")
		return
	if t.has("drop") and v.anchor_of(t.drop).x < 0:
		t.erase("drop")
		t.erase("drop_x")
	if t.has("drop_face") and v.anchor_of(t.drop_face[0]).x < 0:
		t.erase("drop_face")
		t.erase("drop_x")
	if t.has("src") and v.anchor_of(t.src).x < 0:
		t.erase("src")
	# The work spot must still touch the target (it may have been moved).
	if t.has("spot_cell") and t.has("target"):
		var cell := Vector2i(t.spot_cell[0], t.spot_cell[1])
		var a: Vector2i = v.anchor_of(t.target)
		if not v.walkable(cell) or not v.entrances(a).has(cell):
			v.reserved.erase("c%d,%d" % [cell.x, cell.y])
			var spot := work_spot(v, r, a)
			if spot.is_empty():
				abort_task(v, r, "Arbeitsplatz nicht erreichbar")
				return
			_reserve_spot(v, r, t, spot)
			var steps: Array = STEPS[t.type]
			# Walk again if the action had not finished yet.
			var go := steps.find("go_work")
			if go >= 0 and t.step > go and t.step < steps.size() and not steps[t.step].begins_with("go_"):
				if steps[t.step] in ["work", "chop", "mine", "reap", "pick", "sow", "water", "draw"]:
					t.step = go
					_begin_step(v, r)
	t.erase("home_x")
	if t.has("drop_x") and not t.has("drop_face"): t.erase("drop_x")

# ------------------------------------------------------------- persistence

const SAVE_KEYS := ["id", "home", "job", "x", "y", "facing", "anim", "at", "walk", "task", "carry", "item", "energy", "think", "variant", "ev", "status", "special"]

static func serialize(v) -> Array:
	var rows: Array = []
	for r in v.residents:
		var row := {}
		for k in SAVE_KEYS:
			if r.has(k): row[k] = r[k].duplicate(true) if (r[k] is Dictionary or r[k] is Array) else r[k]
		rows.append(row)
	return rows

## Restores residents. Invalid rows are dropped (and regenerated by
## sync_population) instead of rejecting a whole village save.
static func restore(v, rows: Variant) -> void:
	v.residents = []
	if not rows is Array: return
	var seen := {}
	for row in rows:
		if not row is Dictionary: continue
		var ok := true
		for k in ["id", "home", "job", "x", "y", "facing", "at", "walk", "energy", "think", "variant"]:
			var value: Variant = row.get(k)
			if not (value is int or value is float) or not is_finite(float(value)): ok = false
		if not ok or seen.has(int(row.id)): continue
		if not row.get("task", {}) is Dictionary or not row.get("carry", {}) is Dictionary: continue
		if not AnimDefs.ANIMS.has(str(row.get("anim", "idle"))): continue
		var x := float(row.x)
		var y := float(row.y)
		if x < -1 or y < -1 or x > v.SIZE.x or y > v.SIZE.y: continue
		var task: Dictionary = row.get("task", {})
		if not task.is_empty() and (not STEPS.has(str(task.get("type", ""))) or not (task.get("step") is int or task.get("step") is float)): task = {}
		var carry := {}
		var carry_ok := true
		for k in row.get("carry", {}):
			var amount: Variant = row.carry[k]
			if not v.INITIAL.has(k) or not (amount is int or amount is float) or amount < 0 or amount > 100000: carry_ok = false
			else: carry[k] = int(amount)
		if not carry_ok: continue
		if not task.is_empty(): task.step = int(task.step)
		for key in ["target", "drop", "src", "hits", "cycles", "passes"]:
			if task.has(key): task[key] = int(task[key])
		var r := {
			"id": int(row.id), "home": int(row.home), "job": int(row.job), "x": x, "y": y,
			"facing": float(row.facing), "anim": str(row.get("anim", "idle")), "at": maxf(0.0, float(row.at)),
			"walk": float(row.walk), "task": task, "carry": carry, "item": str(row.get("item", "")),
			"energy": clampf(float(row.energy), 0.0, 1.0), "think": float(row.think), "variant": int(row.variant),
			"ev": float(row.get("ev", -1.0)) if (row.get("ev") is float or row.get("ev") is int) else -1.0,
			"path": [], "rev": -1, "blocked": 0, "trapped": false, "status": str(row.get("status", "")),
		}
		if v.SPECIALISTS.has(str(row.get("special", ""))): r.special = str(row.special)
		seen[r.id] = true
		v.next_rid = maxi(v.next_rid, r.id + 1)
		v.residents.append(r)
	rebuild_reservations(v)

static func rebuild_reservations(v) -> void:
	v.reserved.clear()
	for r in v.residents:
		var t: Dictionary = r.task
		if t.is_empty(): continue
		if t.has("spot_cell"): v.reserved["c%d,%d" % [int(t.spot_cell[0]), int(t.spot_cell[1])]] = r.id
		if t.type in ["wood", "stone"] and not t.get("face", false) and r.carry.is_empty() and t.has("target"): v.reserved["b%d" % int(t.target)] = r.id
		if t.type in ["reap", "berries", "sow", "tend"] and r.carry.is_empty() and t.has("target"): v.reserved["b%d" % int(t.target)] = r.id
		if t.type == "fetch" and t.has("target"): v.reserved["f%d" % int(t.target)] = r.id
		if t.type == "plant" and t.has("cell"): v.reserved["p%d,%d" % [int(t.cell[0]), int(t.cell[1])]] = r.id
