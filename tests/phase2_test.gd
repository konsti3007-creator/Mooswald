extends SceneTree
## Storage limits, crop varieties, overripe beds, fishing and smokehouse.
const Model = preload("res://scripts/village.gd")
const Residents = preload("res://scripts/sim/residents.gd")
var checks := 0
var failures := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	storage()
	crops()
	fishing()
	smokehouse()
	migration()
	hints()
	animals_and_pens()
	print("MOOSWINKEL PHASE2: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func run(v, seconds: float) -> Dictionary:
	var counts := {}
	var t := 0.0
	while t < seconds:
		v.tick(0.1)
		t += 0.1
		for e in v.events: counts[e.type] = counts.get(e.type, 0) + 1
		v.events.clear()
	return counts

func storage() -> void:
	var m = Model.new()
	verify(m.capacity("holz") == Model.BASE_STORAGE, "Base storage")
	m.resources.holz = Model.BASE_STORAGE - 2
	m.receive({"holz": 10})
	verify(m.resources.holz == Model.BASE_STORAGE, "Stock never grows beyond capacity")
	verify(m.produced.holz == 2, "Only stored goods count as produced")
	m.resources.holz = 999
	m.receive({"holz": 5})
	verify(m.resources.holz == 999, "Old oversized stock is kept, not cut")
	m.xp = Model.xp_for_level(3)
	m.resources.stein = 100
	m.resources.muenzen = 500
	m.resources.holz = 100
	verify(m.place(Vector2i(5,5), "Lager"), "Storage barn can be built")
	verify(m.capacity("holz") == Model.BASE_STORAGE + 150, "Barn adds room")
	m.resources.bretter = 50
	verify(m.upgrade(Vector2i(5,5)) and m.capacity("holz") == Model.BASE_STORAGE + 300, "Barn upgrade adds more room")
	verify(m.resources.muenzen > 1000000 or m.capacity("muenzen") > 1000000, "Coins are unlimited")
	# A full store stops the woodcutter instead of wasting work.
	var w = Model.new()
	w.insert(Vector2i(4,4), "Haus")
	w.insert(Vector2i(9,4), "Forsthaus")
	w.insert(Vector2i(12,8), "Wildbaum")
	w.resources.holz = Model.BASE_STORAGE
	var counts := run(w, 60.0)
	verify(counts.get("hit", 0) == 0, "No chopping while the wood store is full")
	# Merchant sells the fullest good in batches.
	var s = Model.new()
	s.resources.holz = 110
	s.resources.brot = 4
	var coins: int = s.resources.muenzen
	s.sell()
	verify(s.resources.holz == 100 and s.resources.muenzen == coins + 10, "Merchant takes 10 of the fullest good")

func crops() -> void:
	var m = Model.new()
	m.insert(Vector2i(4,4), "Haus")
	m.place(Vector2i(8,6), "Feld")
	var bed: Dictionary = m.buildings[Vector2i(8,6)]
	verify(bed.crop == "korn", "Beds start with grain")
	bed.next_crop = "karotten"
	m.resources.muenzen = 100
	run(m, 30.0)
	verify(bed.sown and bed.crop == "karotten", "Woodling sows the chosen crop")
	verify(m.resources.muenzen <= 100 - Model.CROPS.karotten.seed, "Seed costs coins")
	bed.progress = 1.0
	var start: int = m.resources.karotten
	var dug := false
	for i in range(500):
		m.tick(0.1)
		m.events.clear()
		for r in m.residents:
			if r.anim == "plant" and r.task.get("type", "") == "reap": dug = true
		if m.resources.karotten > start: break
	verify(dug, "Carrots are dug out kneeling, not cut with the sickle")
	verify(m.resources.karotten == start + 5, "Carrot harvest delivered once")
	# Overripe: half yield, never nothing.
	var o = Model.new()
	o.insert(Vector2i(8,6), "Feld", 1.0)
	var b2: Dictionary = o.buildings[Vector2i(8,6)]
	b2.crop = "kuerbis"
	o.tick(Model.CROPS.kuerbis.duration + 1.0)
	verify(o.overripe(b2), "Bed becomes overripe after its growing time")
	var y: Dictionary = o.harvest_yield(b2)
	verify(y.kuerbis == 2 and y.nahrung == 3, "Overripe gives half, rounded up")
	verify(o.harvest(Vector2i(8,6)) and o.resources.kuerbis == 2, "Overripe harvest pays half once")
	# Growth time per crop.
	var g = Model.new()
	g.elapsed = Model.SEASON_LENGTH + 1.0
	g.insert(Vector2i(2,2), "Feld")
	g.buildings[Vector2i(2,2)].crop = "korn"
	g.insert(Vector2i(4,2), "Feld")
	g.buildings[Vector2i(4,2)].crop = "kuerbis"
	g.tick(10.0)
	verify(g.buildings[Vector2i(4,2)].progress < g.buildings[Vector2i(2,2)].progress * 0.5, "Pumpkins grow slower than grain")
	# Manual sowing pays the seed.
	var h = Model.new()
	h.place(Vector2i(3,3), "Feld")
	h.buildings[Vector2i(3,3)].next_crop = "kohl"
	var c0: int = h.resources.muenzen
	verify(h.harvest(Vector2i(3,3)) and h.buildings[Vector2i(3,3)].crop == "kohl" and h.resources.muenzen == c0 - Model.CROPS.kohl.seed, "Manual sowing uses the chosen crop and its seed")

func angler_village():
	var v = Model.new()
	v.xp = Model.xp_for_level(5)
	v.insert(Vector2i(19,13), "Haus")
	verify(v.place(Vector2i(25,12), "Angler"), "Angler hut near the pond")
	return v

func fishing() -> void:
	var far = Model.new()
	far.xp = Model.xp_for_level(5)
	verify(not far.place(Vector2i(5,15), "Angler"), "Angler hut needs water nearby")
	var v = angler_village()
	var start: int = v.resources.fisch
	var saw := {}
	var counts := {}
	for i in range(1200):
		v.tick(0.1)
		for e in v.events: counts[e.type] = counts.get(e.type, 0) + 1
		v.events.clear()
		for r in v.residents: saw[r.anim] = true
	verify(saw.has("cast") and saw.has("fish_wait") and saw.has("reel"), "Angler casts, waits and reels in")
	verify(counts.get("catch", 0) >= 1, "Fish are caught")
	verify(v.resources.fisch - start == counts.get("handover", 0) * Residents.LOAD_FISH, "Each delivered catch pays exactly once")
	# Winter: fewer catches than summer.
	var summer = angler_village()
	summer.elapsed = Model.SEASON_LENGTH + 1.0
	var winter = angler_village()
	winter.elapsed = Model.SEASON_LENGTH * 3 + 1.0
	var a := run(summer, 300.0)
	var b := run(winter, 300.0)
	verify(a.get("catch", 0) > b.get("catch", 0), "Fishing is slower in winter (%d vs %d)" % [a.get("catch", 0), b.get("catch", 0)])
	# Save while waiting for a bite.
	var w = angler_village()
	var guard := 0
	while guard < 2000:
		w.tick(0.1)
		w.events.clear()
		guard += 1
		var waiting := false
		for r in w.residents:
			if r.anim == "fish_wait": waiting = true
		if waiting: break
	var loaded = Model.new()
	verify(loaded.restore(JSON.parse_string(JSON.stringify(w.serialize()))), "Save while fishing loads")
	run(w, 60.0)
	run(loaded, 60.0)
	verify(w.resources.fisch == loaded.resources.fisch, "Loaded fishing trip pays the same")

func smokehouse() -> void:
	var v = Model.new()
	v.xp = Model.xp_for_level(6)
	v.insert(Vector2i(4,4), "Haus")
	v.insert(Vector2i(9,4), "Raeucherei")
	v.resources.fisch = 12
	v.resources.holz = 20
	run(v, 120.0)
	verify(v.resources.raeucherfisch >= 3, "Smokehouse turns fish into smoked fish with a worker")
	verify(v.resources.fisch <= 9, "Smokehouse uses fish")

func migration() -> void:
	var old = Model.new()
	old.seed()
	var data: Dictionary = JSON.parse_string(JSON.stringify(old.serialize()))
	data.version = 4
	for row in data.buildings:
		row.erase("crop")
		row.erase("next_crop")
		row.erase("ripe_time")
	for k in ["karotten", "fisch", "raeucherfisch", "kohl"]: data.resources.erase(k)
	var n = Model.new()
	verify(n.restore(data), "Version 4 save loads")
	var beds := 0
	for b in n.buildings.values():
		if b.type == "Feld" and b.crop == "korn": beds += 1
	verify(beds == 3, "Old beds keep growing grain")
	verify(n.resources.fisch == 0, "New goods start at zero")

func hints() -> void:
	var m = Model.new()
	m.xp = Model.xp_for_level(5)
	m.resources.muenzen = 22
	verify(m.missing_text(Model.DEFS.Angler.cost) == "Es fehlen 18 Münzen.", "Exact missing amount is named")
	verify(m.placement_issue(Vector2i(25,12), "Angler") == "Es fehlen 18 Münzen.", "Cursor hint names the missing coins")
	verify(m.placement_issue(Vector2i(5,15), "Angler") == "Braucht Wasser in der Nähe.", "Cursor hint names missing water")
	verify(not m.place(Vector2i(25,12), "Angler") and m.notice.contains("18 Münzen"), "Build message names what is missing")
	m.resources.bretter = 100
	var paid: int = m.sell_good("bretter", 10)
	verify(paid == 10 * Model.PRICES.bretter and m.resources.bretter == 90 and m.resources.muenzen == 22 + paid, "Direct sale of a chosen good")
	verify(m.place(Vector2i(25,12), "Angler"), "After selling the angler hut can be built")
	m.insert(Vector2i(3,3), "Haus")
	m.resources.muenzen = 0
	verify(not m.upgrade(Vector2i(3,3)) and m.notice.contains("Münzen"), "Upgrade message names missing coins")

func animals_and_pens() -> void:
	var v = Model.new()
	v.xp = Model.xp_for_level(9)
	v.resources.holz = 100
	v.resources.bretter = 50
	v.resources.muenzen = 500
	v.insert(Vector2i(4,4), "Haus")
	verify(v.place(Vector2i(9,4), "Huehnerhof"), "Chicken yard (3x3) can be built")
	verify(v.occupied.size() >= 13, "Enclosure occupies 3x3 cells")
	v.resources.getreide = 20
	run(v, 150.0)
	verify(v.resources.eier >= 4, "Shepherd feeds the hens: grain becomes eggs")
	verify(v.resources.getreide < 20, "Feed is used")
	var n = Model.new()
	n.insert(Vector2i(9,4), "Huehnerhof")
	n.resources.getreide = 20
	run(n, 60.0)
	verify(n.resources.eier == 0, "No shepherd: no eggs")
	var k = Model.new()
	k.xp = Model.xp_for_level(9)
	k.insert(Vector2i(4,4), "Haus")
	k.insert(Vector2i(9,4), "Kaeserei")
	k.resources.milch = 9
	run(k, 120.0)
	verify(k.resources.kaese >= 2, "Cheese dairy makes cheese from milk")
	verify(k.animal_bonus("Ein Hase") and not k.animal_bonus("Ein Hase"), "Animal bonus has a cooldown")
	var data: Dictionary = JSON.parse_string(JSON.stringify(v.serialize()))
	var w = Model.new()
	verify(w.restore(data) and w.count("Huehnerhof") == 1, "Enclosure saved and loaded")
