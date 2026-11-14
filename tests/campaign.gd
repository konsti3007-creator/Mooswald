extends SceneTree
## Full playthrough with the real resident simulation: a simple player bot
## builds only with earned goods (walks in the forest, trade contracts,
## residents' work) and must finish all village quests, including both land
## expansions. Also prints balance timings for the test report.
const Model = preload("res://scripts/village.gd")
var v
var failures := 0
var log_lines: Array[String] = []
var wish_seen := -1
var wish_since := 0.0
var skipped := 0

func verify(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	v = Model.new()
	v.seed()
	var limit := 5.0 * 3600.0
	var last_level := 1
	var quest_times := {}
	var last_quest := -1
	var quests_done_at := -1.0
	while v.elapsed < limit and (v.quest < Model.QUESTS.size() or v.wishes_done - skipped < 6):
		bot_turn()
		for i in range(20): v.tick(0.1)
		v.events.clear()
		if v.level() != last_level:
			last_level = v.level()
			log_lines.append("  Stufe %d nach %d min" % [last_level, int(v.elapsed / 60)])
		if v.quest >= Model.QUESTS.size() and quests_done_at < 0: quests_done_at = v.elapsed
		if v.quest != last_quest:
			last_quest = v.quest
			quest_times[v.quest] = v.elapsed
			log_lines.append("Auftrag %d erreicht nach %d s (Stufe %d, %d Waldlinge)" % [v.quest, int(v.elapsed), v.level(), v.population()])
	for line in log_lines: print(line)
	verify(v.quest == Model.QUESTS.size(), "All quests completed in a resident-driven playthrough (reached %d)" % v.quest)
	verify(v.wishes_done - skipped >= 6, "Endless village wishes keep coming and can be fulfilled (%d)" % v.wishes_done)
	verify(v.elapsed < limit, "Campaign and six wishes within five game hours")
	print("Einfuehrung fertig nach %d min, Wuensche erfuellt: %d (getauscht: %d), Spielzeit %d min, Stufe %d" % [int(quests_done_at / 60), v.wishes_done - skipped, skipped, int(v.elapsed / 60), v.level()])
	var trapped := 0
	for r in v.residents:
		if r.trapped: trapped += 1
	verify(trapped == 0, "Bot village has no trapped residents")
	print("Bestand am Ende: ", v.resources)
	for k in ["karotten", "fisch", "raeucherfisch", "eier"]:
		verify(int(v.produced.get(k, 0)) > 0, "Campaign produced %s" % k)
	verify(v.count("Lager") >= 1, "Campaign built a storage barn")
	print("MOOSWINKEL CAMPAIGN: %d quests + %d wishes in %d s game time, %d failures" % [v.quest, v.wishes_done, int(v.elapsed), failures])
	quit(0 if failures == 0 else 1)

func free_ring(c: Vector2i, kind: String) -> bool:
	if not v.can_place(c, kind): return false
	var size: Vector2i = Model.DEFS[kind].size
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			var n := c + Vector2i(x, y)
			if x >= 0 and y >= 0 and x < size.x and y < size.y: continue
			if not v.unlocked(n) or v.water(n): return false
			if v.occupied.has(n) and not v.has_road(n): return false
	return true

func spot(kind: String, center := Vector2i(13, 14)) -> Vector2i:
	for radius in range(0, 22):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius: continue
				var c := center + Vector2i(dx, dy)
				if free_ring(c, kind): return c
	return Vector2i(-1, -1)

func build(kind: String, center := Vector2i(13, 14)) -> bool:
	if v.level() < Model.DEFS[kind].level or not v.afford(Model.DEFS[kind].cost): return false
	var c := spot(kind, center)
	return c.x >= 0 and v.place(c, kind)

func road() -> void:
	# Extend the main road eastwards/westwards along row 12 and column 12.
	for c in [Vector2i(6, 12), Vector2i(5, 12), Vector2i(19, 12), Vector2i(20, 12), Vector2i(12, 13), Vector2i(12, 14), Vector2i(12, 15), Vector2i(12, 16), Vector2i(12, 17), Vector2i(4, 12), Vector2i(21, 12), Vector2i(12, 18), Vector2i(12, 19), Vector2i(13, 19), Vector2i(14, 19), Vector2i(11, 19), Vector2i(10, 19)]:
		if v.can_place(c, "Weg") and v.afford(Model.DEFS.Weg.cost):
			v.place(c, "Weg")
			return

func bot_turn() -> void:
	v.gather()
	v.deliver()
	# Workers first: every workplace needs a woodling.
	var idle := 0
	var vacant := false
	for r in v.residents:
		if r.job < 0: idle += 1
	for b in v.buildings.values():
		if v.is_workplace(b.type) and not b.paused:
			var crew := 0
			for r in v.residents:
				if r.job == b.id: crew += 1
			if crew < b.tier: vacant = true
	if (vacant or idle < 1) and v.count("Haus") < 9: build("Haus", Vector2i(8, 15))
	if v.quest >= 4 and v.count("Steinbruch") == 0: build("Steinbruch", Vector2i(21, 14))
	if v.level() >= 3 and v.count("HausHolz") == 0: build("HausHolz", Vector2i(10, 6))
	match v.quest:
		0: build("Haus", Vector2i(8, 15))
		1: build("Feld", Vector2i(15, 15))
		2: road()
		4:
			if v.count("Saegewerk") == 0: build("Saegewerk")
			if v.count("Muehle") == 0: build("Muehle")
		5:
			if v.count("Baeckerei") == 0: build("Baeckerei")
			if v.count("Feld") < 6: build("Feld", Vector2i(15, 15))
		6:
			if v.count("Brunnen") == 0: build("Brunnen", Vector2i(10, 17))
			build("Blumenbeet", Vector2i(10, 17))
		7: build("Beeren", Vector2i(16, 18))
		8: build("Imkerei")
		9:
			if v.count("Kochhaus") == 0: build("Kochhaus")
			if v.count("Beeren") < 4: build("Beeren", Vector2i(16, 18))
		10: build("Gasthaus")
		11: v.expand()
		12: build("Laterne", Vector2i(13, 16))
		13: v.expand()
	if not v.wish.is_empty() and v.wish.type == "build": build(v.wish.key, Vector2i(14, 18))
	# Like a player: exchange a wish that does not move for a long time.
	if not v.wish.is_empty():
		var p: Array = v.wish_progress()
		if p[0] != wish_seen:
			wish_seen = p[0]
			wish_since = v.elapsed
		elif v.elapsed - wish_since > 600.0 and v.skip_wish():
			wish_since = v.elapsed
			skipped += 1
	# Phase 2 content: storage, fishing, smokehouse, crop variety.
	var full := false
	for k in v.resources:
		if k != "muenzen" and v.resources[k] >= v.capacity(k) - 5: full = true
	if full and v.count("Lager") < 2: build("Lager", Vector2i(9, 18))
	if v.level() >= 3 and v.count("Angler") == 0 and v.afford(Model.DEFS.Angler.cost) and v.can_place(Vector2i(25, 12), "Angler"): v.place(Vector2i(25, 12), "Angler")
	if v.level() >= 5 and v.count("Raeucherei") == 0: build("Raeucherei", Vector2i(20, 16))
	if v.level() >= 4 and v.count("Huehnerhof") == 0: build("Huehnerhof", Vector2i(6, 18))
	var i := 0
	for b in v.buildings.values():
		if b.type == "Feld":
			var options: Array = []
			for k in Model.CROPS:
				if v.level() >= Model.CROPS[k].level: options.append(k)
			# Half the beds stay on grain (flour and bread need it).
			b.next_crop = "korn" if (b.id + i) % 2 == 0 else options[(b.id + i) % options.size()]
			i += 1
	# Sell surplus to keep coins flowing.
	if v.resources.muenzen < 150: v.sell()
