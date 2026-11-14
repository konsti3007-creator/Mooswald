extends SceneTree
## Rules of the resident work system. Visual quality is checked separately
## (rig sheets, in-game captures); these tests only prove the game rules.
const Model = preload("res://scripts/village.gd")
const Residents = preload("res://scripts/sim/residents.gd")
const Nav = preload("res://scripts/sim/navigation.gd")
var checks := 0
var failures := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	woodcutting()
	speeds()
	save_mid_action()
	interruptions()
	fields()
	workshops()
	navigation()
	specialists()
	migration()
	print("MOOSWINKEL RESIDENTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

## Small village: one house, one lodge, one tree.
func forest_village():
	var v = Model.new()
	v.insert(Vector2i(4,4), "Haus")
	v.insert(Vector2i(9,4), "Forsthaus")
	v.insert(Vector2i(12,8), "Wildbaum")
	v.resources.holz = 0  # room in the store for several trips
	return v

func run(v, seconds: float, dt := 0.1) -> Dictionary:
	var counts := {}
	var wood := 0
	var t := 0.0
	while t < seconds - 0.00001:
		v.tick(dt)
		t += dt
		for e in v.events:
			counts[e.type] = counts.get(e.type, 0) + 1
			if e.type == "handover": wood += int(e.goods.get("holz", 0))
		v.events.clear()
	counts.wood = wood
	return counts

func woodcutting() -> void:
	var v = forest_village()
	var start: int = v.resources.holz
	var saw_chop := false
	var credited_before_handover := false
	var counts := {}
	for i in range(900):
		var before: int = v.resources.holz
		v.tick(0.1)
		var handovers := 0
		for e in v.events:
			counts[e.type] = counts.get(e.type, 0) + 1
			if e.type == "handover": handovers += 1
		v.events.clear()
		if v.resources.holz != before and handovers == 0: credited_before_handover = true
		for r in v.residents:
			if r.anim == "chop": saw_chop = true
	verify(saw_chop, "Woodcutter plays the chop animation")
	verify(not credited_before_handover, "Wood is credited only in the handover event")
	verify(counts.get("hit", 0) >= 4, "Axe hits are action events")
	verify(v.resources.holz - start == counts.get("handover", 0) * Residents.LOAD_WOOD, "Exactly one load per delivered trip")
	var tree: Dictionary = v.buildings[Vector2i(12,8)]
	verify(tree.stock < Residents.TREE_LOADS or counts.get("fell", 0) > 0, "Tree stock is used up by trips")
	verify(counts.get("fell", 0) >= 1, "Tree is felled after its last load")
	# Regrowth: stump -> sapling -> grown.
	tree.stock = 0
	tree.progress = 0.0
	for r in v.residents: Residents.abort_task(v, r, "")
	v.reserved.clear()
	var w = Model.new()
	w.insert(Vector2i(12,8), "Wildbaum")
	w.buildings[Vector2i(12,8)].stock = 0
	w.buildings[Vector2i(12,8)].progress = 0.0
	w.tick(Model.TREE_REGROW + 1)
	verify(w.buildings[Vector2i(12,8)].stock == Residents.TREE_LOADS, "Felled trees regrow")

func speeds() -> void:
	# 1x, 2x and 4x frame sizes: every delivered trip pays exactly one load.
	for factor in [1.0, 2.0, 4.0]:
		var v = forest_village()
		var start: int = v.resources.holz
		var counts := run(v, 240.0, factor / 60.0)
		verify(counts.get("handover", 0) >= 3, "Trips complete at %dx" % int(factor))
		verify(v.resources.holz - start == counts.wood, "No double reward at %dx" % int(factor))
		verify(counts.get("hit", 0) >= counts.get("handover", 0) * Residents.HITS_TREE, "Every load needs its hits at %dx" % int(factor))
	# Pause: nothing moves, nothing is paid.
	var p = forest_village()
	run(p, 20.0)
	var snapshot: Dictionary = p.serialize()
	p.tick(0)
	verify(JSON.stringify(p.serialize()) == JSON.stringify(snapshot), "Pause changes nothing")

func save_mid_action() -> void:
	var v = forest_village()
	var guard := 0
	while guard < 3000:
		v.tick(0.1)
		v.events.clear()
		guard += 1
		var r: Dictionary = v.residents[0] if v.residents[0].job >= 0 else v.residents[1]
		if r.anim == "chop" and int(r.task.get("hits", 0)) == 2: break
	verify(guard < 3000, "Reached the middle of a chopping action")
	var loaded = Model.new()
	verify(loaded.restore(JSON.parse_string(JSON.stringify(v.serialize()))), "Save during chopping loads")
	var a := run(v, 60.0)
	var b := run(loaded, 60.0)
	verify(v.resources.holz == loaded.resources.holz, "Loaded game pays the same as the original")
	verify(a.get("hit", 0) == b.get("hit", 0), "Hits are neither repeated nor skipped after loading")
	# Save while carrying.
	var c = forest_village()
	guard = 0
	while guard < 3000:
		c.tick(0.1)
		c.events.clear()
		guard += 1
		var carrying := false
		for r in c.residents:
			if not r.carry.is_empty() and r.anim == "carry_walk": carrying = true
		if carrying: break
	var held: int = c.resources.holz
	var d = Model.new()
	verify(d.restore(JSON.parse_string(JSON.stringify(c.serialize()))), "Save while carrying loads")
	verify(d.resources.holz == held, "Carried goods are not yet in the stock")
	var counts := run(d, 40.0)
	verify(d.resources.holz == held + counts.wood, "Carried load is delivered exactly once after loading")

func interruptions() -> void:
	# Demolish the lodge while the woodcutter carries wood.
	var v = forest_village()
	var guard := 0
	while guard < 3000:
		v.tick(0.1)
		v.events.clear()
		guard += 1
		var carrying := false
		for r in v.residents:
			if not r.carry.is_empty(): carrying = true
		if carrying: break
	var before: int = v.resources.holz
	v.remove(Vector2i(9,4), false)
	run(v, 30.0)
	verify(v.resources.holz == before + Residents.LOAD_WOOD, "Cancelled transport credits the load once")
	var reserved_by_dead := false
	for k in v.reserved:
		var found := false
		for r in v.residents:
			if r.id == v.reserved[k]: found = true
		if not found: reserved_by_dead = true
	verify(not reserved_by_dead, "No orphan reservations")
	for r in v.residents: verify(r.job < 0, "Workers of a demolished lodge are free again")
	# Moving the target workshop: the worker walks to the new place.
	var m = forest_village()
	run(m, 12.0)
	verify(m.move_building(Vector2i(9,4), Vector2i(9,10)), "Lodge moved during work")
	var counts := run(m, 120.0)
	verify(counts.get("handover", 0) >= 1, "Work continues after moving the building")
	# A building placed on top of a walking resident: rescued to free ground.
	var s = forest_village()
	run(s, 5.0)
	var r: Dictionary = s.residents[0]
	var cell := Vector2i(roundi(r.x), roundi(r.y))
	s.insert(cell, "Blumenbeet")
	run(s, 1.0)
	verify(s.walkable(Vector2i(roundi(r.x), roundi(r.y))), "Resident is moved off a newly built object")
	# Enclosed house: residents are marked as trapped, not lost.
	var e = Model.new()
	e.insert(Vector2i(5,5), "Haus")
	for y in range(4,8):
		for x in range(4,8):
			if not e.occupied.has(Vector2i(x,y)): e.insert(Vector2i(x,y), "Strauch")
	run(e, 2.0)
	var trapped := 0
	for t in e.residents:
		if t.trapped: trapped += 1
	verify(trapped == 2, "Residents of an enclosed house are detected")

func fields() -> void:
	var v = Model.new()
	v.insert(Vector2i(4,4), "Haus")
	v.place(Vector2i(8,6), "Feld")
	var field: Dictionary = v.buildings[Vector2i(8,6)]
	verify(not field.sown, "New beds wait for sowing")
	run(v, 30.0)
	verify(field.sown, "A free woodling sows the bed")
	field.progress = 1.0
	var start: int = v.resources.getreide
	var changed_early := false
	var counts := {}
	for i in range(600):
		var was: float = field.progress
		v.tick(0.1)
		var harvested_now := false
		for e in v.events:
			counts[e.type] = counts.get(e.type, 0) + 1
			if e.type == "harvested": harvested_now = true
		if field.progress < was and not harvested_now: changed_early = true
		v.events.clear()
		if counts.get("handover", 0) > 0: break
	verify(counts.get("cut", 0) >= 3, "Reaping uses several sickle strokes")
	verify(counts.get("harvested", 0) == 1, "Field is harvested exactly once")
	verify(not changed_early, "Plant state changes only when the harvest is complete")
	verify(v.resources.getreide == start + 6, "Harvest is delivered exactly once")
	# Manual harvest while a resident has reserved the bed: no double yield.
	var m = Model.new()
	m.insert(Vector2i(4,4), "Haus")
	m.insert(Vector2i(8,6), "Feld", 1.0)
	var guard := 0
	while not m.reserved.has("b%d" % m.buildings[Vector2i(8,6)].id) and guard < 200:
		m.tick(0.1)
		guard += 1
	var grain: int = m.resources.getreide
	verify(m.harvest(Vector2i(8,6)), "Manual harvest of a reserved bed")
	run(m, 30.0)
	verify(m.resources.getreide == grain + 6, "Reserved bed pays once after manual harvest")
	# Berries: picking animation, different from reaping.
	var b = Model.new()
	b.insert(Vector2i(4,4), "Haus")
	b.insert(Vector2i(8,6), "Beeren", 1.0)
	var picked := false
	for i in range(400):
		b.tick(0.1)
		b.events.clear()
		for r in b.residents:
			if r.anim == "pick": picked = true
	verify(picked, "Berries use the picking animation")
	verify(b.resources.beeren == 5, "Berries delivered once")

func workshops() -> void:
	var v = Model.new()
	v.xp = Model.xp_for_level(3)
	v.insert(Vector2i(4,4), "Haus")
	v.insert(Vector2i(9,4), "Saegewerk")
	v.resources.holz = 30
	var counts := run(v, 120.0)
	verify(counts.get("supply", 0) >= 1, "Worker fetches inputs and brings them to the workshop")
	verify(v.resources.bretter >= 4, "Sawmill produces with a worker")
	var n = Model.new()
	n.insert(Vector2i(9,4), "Saegewerk")
	n.resources.holz = 30
	run(n, 60.0)
	verify(n.resources.bretter == 0 and n.resources.holz == 30, "No worker: nothing is used or produced")
	# Paused workshops release their worker.
	v.toggle_production(Vector2i(9,4))
	run(v, 1.0)
	for r in v.residents: verify(r.job < 0, "Pause frees the workplace")

func navigation() -> void:
	var v = Model.new()
	v.insert(Vector2i(5,3), "Haus")
	v.insert(Vector2i(5,5), "Haus")
	var path: Array = Nav.waypoints(v, Vector2i(3,4), Vector2i(9,4))
	verify(not path.is_empty(), "Path around houses")
	var last := Vector2(3,4)
	for p in path:
		var steps := int(ceil(last.distance_to(p) * 4))
		for k in range(1, steps + 1):
			var q: Vector2 = last.lerp(p, float(k) / steps)
			verify(v.walkable(Vector2i(roundi(q.x), roundi(q.y))), "Smoothed path stays on free ground")
		last = p
	verify(Nav.waypoints(v, Vector2i(3,4), Vector2i(5,3)).is_empty(), "Blocked goal rejected")
	var road = Model.new()
	for c in [Vector2i(1,1),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(4,2),Vector2i(5,2),Vector2i(5,1)]: road.insert(c,"Weg")
	road.insert(Vector2i(3,1), "Strauch")
	var cells: Array = Nav.cells(road, Vector2i(1,1), Vector2i(5,1))
	var on_road := 0
	for c in cells:
		if road.has_road(c): on_road += 1
	verify(on_road >= cells.size() - 1, "Residents prefer connected roads")

func specialists() -> void:
	var v = forest_village()
	v.xp = Model.xp_for_level(3)
	v.resources.muenzen = 500
	v.resources.holz = 40
	verify(v.place(Vector2i(4,8), "HausHolz"), "Special house can be built")
	verify(not v.place(Vector2i(4,12), "HausHolz"), "Special house is unique")
	verify(v.population() == 3, "Special house brings exactly one resident")
	run(v, 1.0)
	var specialist: Dictionary = {}
	for r in v.residents:
		if r.get("special", "") == "holz": specialist = r
	verify(not specialist.is_empty(), "The named specialist moved in")
	var start: int = v.resources.holz
	var counts := run(v, 200.0)
	verify(counts.get("handover", 0) > 0 and (v.resources.holz - start) % (Residents.LOAD_WOOD + 2) == 0, "Holzmeisterin: 2 wood more per trip")
	var data: Dictionary = JSON.parse_string(JSON.stringify(v.serialize()))
	var w = Model.new()
	verify(w.restore(data), "Specialist save loads")
	var kept := false
	for r in w.residents:
		if r.get("special", "") == "holz": kept = true
	verify(kept, "Specialist identity is saved")

func migration() -> void:
	var path := "res://tests/fixtures/village_v2_player.json"
	if not FileAccess.file_exists(path):
		verify(false, "Real 0.3 save fixture present")
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var v = Model.new()
	verify(v.restore(data), "Real 0.3 player save migrates")
	verify(v.resources.holz == int(data.resources.holz), "Migrated resources unchanged")
	var houses := 0
	for row in data.buildings:
		if row.type == "Haus": houses += 1
	verify(v.count("Haus") == houses, "All houses kept")
	run(v, 60.0)
	verify(v.residents.size() == v.population(), "Residents created for migrated houses")
	verify(v.count("Wildbaum") > 0, "Forest added for woodcutters")
	var again = Model.new()
	verify(again.restore(JSON.parse_string(JSON.stringify(v.serialize()))), "Migrated village saves in the new format")
