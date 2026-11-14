extends SceneTree
## Endless progression, seasons and village wishes.
const Model = preload("res://scripts/village.gd")
var checks := 0
var failures := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	levels()
	seasons()
	wishes()
	crowding()
	print("MOOSWINKEL ENDLESS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func levels() -> void:
	var m = Model.new()
	verify(m.level() == 1, "Start at level 1")
	var last := 0
	var growing := true
	for l in range(2, 200):
		var need: int = Model.xp_for_level(l) - Model.xp_for_level(l - 1)
		if need <= last: growing = false
		last = need
	verify(growing, "Each level needs more experience than the last")
	m.xp = Model.xp_for_level(150) + 1
	verify(m.level() == 150, "Levels continue far beyond any end level")
	m.xp = Model.xp_for_level(7)
	verify(m.level() == 7 and is_equal_approx(m.level_progress(), 0.0), "Level threshold exact")
	# Old saves keep their level on the new curve.
	var old = Model.new()
	old.seed()
	var data: Dictionary = JSON.parse_string(JSON.stringify(old.serialize()))
	data.version = 3
	data.xp = 1764
	var n = Model.new()
	verify(n.restore(data), "Version 3 save loads")
	verify(n.level() == 18, "Old level 18 stays level 18 after migration")

func seasons() -> void:
	var m = Model.new()
	verify(m.season() == 0, "Game starts in spring")
	var names: Array = []
	for i in range(4):
		m.elapsed = i * Model.SEASON_LENGTH + 10.0
		names.append(Model.SEASONS[m.season()].name)
	verify(names == ["Frühling", "Sommer", "Herbst", "Winter"], "Seasons cycle through the year")
	m.elapsed = 4 * Model.SEASON_LENGTH + 10.0
	verify(m.season() == 0, "Year repeats")
	m.elapsed = Model.SEASON_LENGTH * 0.95
	var w: Array = m.season_weights()
	verify(w[0] > 0.0 and w[1] > 0.0 and is_equal_approx(w[0] + w[1], 1.0), "Season change blends smoothly")
	# Growth is slower in winter than in summer.
	var summer = Model.new()
	summer.elapsed = Model.SEASON_LENGTH + 5.0
	summer.insert(Vector2i(3,3), "Beeren")
	summer.tick(10.0)
	var winter = Model.new()
	winter.elapsed = Model.SEASON_LENGTH * 3 + 5.0
	winter.insert(Vector2i(3,3), "Beeren")
	winter.tick(10.0)
	verify(winter.buildings[Vector2i(3,3)].progress < summer.buildings[Vector2i(3,3)].progress * 0.5, "Winter slows growth")
	var data: Dictionary = JSON.parse_string(JSON.stringify(winter.serialize()))
	var loaded = Model.new()
	verify(loaded.restore(data) and loaded.season() == 3, "Season survives saving")

func wishes() -> void:
	var m = Model.new()
	m.seed()
	m.quest = Model.QUESTS.size()
	m.produced = {"getreide": 10, "holz": 40}
	m.check_quests()
	verify(not m.wish.is_empty(), "A wish appears after the last quest")
	var start: Dictionary = m.wish.duplicate()
	var coins: int = m.resources.muenzen
	# Fulfil it.
	if m.wish.type != "build":
		m.resources[m.wish.key] = 0
		m.receive({m.wish.key: int(m.wish.goal)})
	else:
		for i in range(10):
			for y in range(14, 28):
				for x in range(2, 28):
					if m.count(m.wish.key) < int(m.wish.goal) and m.can_place(Vector2i(x, y), m.wish.key): m.insert(Vector2i(x, y), m.wish.key)
		m.check_quests()
	verify(m.wishes_done == 1, "Wish fulfilled once")
	verify(m.resources.muenzen >= coins + int(start.coins), "Wish reward paid")
	verify(not m.wish.is_empty() and m.wish != start, "The next wish follows immediately")
	var paid: int = m.resources.muenzen
	m.check_quests()
	verify(m.resources.muenzen == paid, "No double reward")
	var titles := {}
	for i in range(30):
		m.wishes_done += 1
		m.make_wish()
		titles[m.wish.title] = true
	verify(titles.size() >= 5, "Wishes vary")
	m.xp = Model.xp_for_level(40)
	m.make_wish()
	verify(int(m.wish.coins) > int(start.coins), "Wishes grow with the village")
	var before: Dictionary = m.wish.duplicate()
	verify(m.skip_wish() and m.wish != before, "A wish can be exchanged")
	verify(not m.skip_wish(), "Exchanging has a cooldown")
	var data: Dictionary = JSON.parse_string(JSON.stringify(m.serialize()))
	var n = Model.new()
	verify(n.restore(data) and n.wish.title == m.wish.title and n.wishes_done == m.wishes_done, "Wish saved and loaded")

func crowding() -> void:
	# Several idle woodlings around one house end up on separate spots.
	var m = Model.new()
	m.insert(Vector2i(10,10), "Haus")
	m.insert(Vector2i(13,10), "Haus")
	m.buildings[Vector2i(10,10)].tier = 3
	m.revision += 1
	for i in range(400):
		m.tick(0.1)
		m.events.clear()
	var stacked := 0
	for a in m.residents:
		for b in m.residents:
			if a.id < b.id and Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) < 0.2 and a.task.get("type", "") in ["idle", ""] and b.task.get("type", "") in ["idle", ""]: stacked += 1
	verify(stacked == 0, "Idle woodlings do not stand on top of each other")
