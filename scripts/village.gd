extends RefCounted
## Pure simulation. Coordinates and save data never depend on the renderer.
## Resident behaviour lives in sim/residents.gd, path finding in
## sim/navigation.gd; both keep their state inside this model.
const Residents = preload("res://scripts/sim/residents.gd")
const Nav = preload("res://scripts/sim/navigation.gd")
const Content = preload("res://scripts/data/content.gd")

const NAMES := Content.NAMES
const SIZE := Vector2i(40, 30)
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const INITIAL := Content.INITIAL
const SCHEMA := 6
const CROPS := Content.CROPS
const PRICES := Content.PRICES
const BASE_STORAGE := 120
const SEASONS := Content.SEASONS
const SEASON_LENGTH := 720.0
const RESOURCE_GROUPS := Content.RESOURCE_GROUPS
const WINDOW_LIGHTS := Content.WINDOW_LIGHTS
const SPECIAL_HOUSES := Content.SPECIAL_HOUSES
const DECORATIONS := Content.DECORATIONS
const DEFS := Content.DEFS
const SPECIALISTS := Content.SPECIALISTS
const TREE_REGROW := 110.0
const ROCK_REGEN := 50.0
const CONTRACTS := Content.CONTRACTS
const QUESTS := Content.QUESTS
const WILD_TREES := Content.WILD_TREES
const WILD_ROCKS := Content.WILD_ROCKS

var resources: Dictionary = INITIAL.duplicate(true)
var buildings: Dictionary = {}
var occupied: Dictionary = {}
var road_masks: Dictionary = {}
var produced: Dictionary = {}
var id_index: Dictionary = {}
var next_id := 1
var revision := 0
var residents: Array = []
var next_rid := 1
var residents_rev := -1
var reserved: Dictionary = {}
var events: Array = []
var hungry := false
var nav_revision := -1
var nav_regions: Dictionary = {}
var nav_cache: Dictionary = {}
var nav_searches := 0
var expansion := 0
var contract_index := 0
var contract_time := 0.0
var workers: Dictionary = {}
var meals := 0
var xp := 0
var quest := 0
var wish: Dictionary = {}
var wishes_done := 0
var wish_skip_time := 0.0
var elapsed := 0.0
var gather_time := 0.0
var market_time := 0.0
var autosave_time := 0.0
var speed := 1.0
var moving := Vector2i(-1,-1)
var notice := "Willkommen in Mooswinkel. Dein Dorf beginnt mit einem kleinen Weg."

## Endless levels: total experience needed to reach `l`. Fast at first,
## steadily slower later, never ending.
static func xp_for_level(l: int) -> int:
	var total := 0.0
	for k in range(1, l): total += 100.0 * pow(k, 1.45)
	return int(total)

func level() -> int:
	var l := 1
	while xp >= xp_for_level(l + 1): l += 1
	return l

func level_progress() -> float:
	var l := level()
	var a := xp_for_level(l)
	return float(xp - a) / maxf(1.0, float(xp_for_level(l + 1) - a))

## Season index 0..3 and how far the switch to the next season has gone
## (last tenth of a season blends smoothly).
func season() -> int:
	return int(elapsed / SEASON_LENGTH) % 4

func season_day() -> int:
	return int(fmod(elapsed, SEASON_LENGTH) / 240.0) + 1

func season_weights() -> Array:
	var w := [0.0, 0.0, 0.0, 0.0]
	var t := fmod(elapsed, SEASON_LENGTH) / SEASON_LENGTH
	var now := season()
	var blend := clampf((t - 0.9) / 0.1, 0.0, 1.0)
	w[now] = 1.0 - blend
	w[(now + 1) % 4] += blend
	return w

func season_factor(key: String) -> float:
	var w := season_weights()
	var f := 0.0
	for i in range(4): f += w[i] * float(SEASONS[i][key])
	return f

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE.x and c.y < SIZE.y

func unlocked(c: Vector2i) -> bool:
	return inside(c) and (c.x < 30 or expansion >= 1) and (c.y < 24 or expansion >= 2)

func expansion_cost() -> Dictionary:
	return {"bretter":30,"stein":30,"muenzen":120} if expansion == 0 else {"bretter":60,"stein":60,"muenzen":250}

func expand() -> bool:
	if expansion >= 2: notice = "Alle Lichtungen sind erschlossen."; return false
	var required := 4 if expansion == 0 else 6
	if level() < required: notice = "Neue Lichtung ab Stufe %d." % required; return false
	if not afford(expansion_cost()): notice = "Für die Lichtung fehlen Vorräte."; return false
	exchange(expansion_cost(),-1)
	expansion += 1
	xp += 50
	revision += 1
	notice = "Eine neue Waldlichtung gehört jetzt zu Mooswinkel!"
	check_quests()
	return true

## Storage: every good except coins has a capacity. Vorratsscheunen add
## room per upgrade level. Stock above the limit (old saves) is kept, it
## just cannot grow further.
func capacity(k: String) -> int:
	if k == "muenzen": return 1 << 30
	var total := BASE_STORAGE
	for b in buildings.values():
		if DEFS[b.type].has("storage"): total += int(DEFS[b.type].storage) * int(b.tier)
	return total

func has_space(k: String, amount := 1) -> bool:
	return int(resources.get(k, 0)) + amount <= capacity(k) or k == "muenzen"

func _add(k: String, amount: int) -> int:
	var before: int = resources.get(k, 0)
	var after := before + amount
	if k != "muenzen": after = mini(after, maxi(before, capacity(k)))
	resources[k] = after
	return after - before

## What is missing for a cost, e.g. {"muenzen": 18}.
func missing(cost: Dictionary) -> Dictionary:
	var m := {}
	for k in cost:
		var gap: int = int(cost[k]) - int(resources.get(k, 0))
		if gap > 0: m[k] = gap
	return m

func missing_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	var m := missing(cost)
	for k in m: parts.append("%d %s" % [m[k], NAMES.get(k, k)])
	return "Es fehlen " + ", ".join(parts) + "." if not parts.is_empty() else ""

## Why a building cannot go on this cell ("" = possible). Same checks as
## place(), used for the live hint at the mouse cursor.
func placement_issue(c: Vector2i, kind: String) -> String:
	if not DEFS.has(kind): return "Unbekannt."
	if level() < DEFS[kind].level: return "Ab Dorfstufe %d." % DEFS[kind].level
	if DEFS[kind].has("special") and count(kind) > 0: return "Gibt es nur einmal im Dorf."
	if not can_place(c, kind): return "Kein freier Bauplatz."
	if DEFS[kind].get("near_water", false) and not near_water(c, DEFS[kind].size): return "Braucht Wasser in der Nähe."
	if not afford(DEFS[kind].cost): return missing_text(DEFS[kind].cost)
	return ""

## Petting or watching an animal: a small, rate limited bonus.
var animal_time := 0.0
func animal_bonus(label: String) -> bool:
	if animal_time > 0.001: return false
	xp += 3
	resources.muenzen += 1
	animal_time = 8.0
	notice = "%s freut sich über deinen Besuch. +3 Erfahrung, +1 Münze." % label
	return true

## Selling a chosen good directly from the store (no waiting time).
func sell_good(k: String, amount: int) -> int:
	if not PRICES.has(k): return 0
	amount = mini(amount, int(resources.get(k, 0)))
	if amount <= 0:
		notice = "Kein %s im Lager." % NAMES[k]
		return 0
	var price: int = amount * int(PRICES[k])
	if has_special("handel"): price = int(price * 1.3)
	resources[k] -= amount
	resources.muenzen += price
	notice = "%d %s für %d Münzen verkauft." % [amount, NAMES[k], price]
	return price

func near_water(c: Vector2i, size: Vector2i, radius := 4) -> bool:
	for y in range(c.y - radius, c.y + size.y + radius):
		for x in range(c.x - radius, c.x + size.x + radius):
			if water(Vector2i(x, y)): return true
	return false

func crop_of(b: Dictionary) -> Dictionary:
	return CROPS.get(b.get("crop", "korn"), CROPS.korn)

func grow_time(b: Dictionary) -> float:
	return float(crop_of(b).duration) if b.type == "Feld" else float(DEFS[b.type].duration)

func overripe(b: Dictionary) -> bool:
	return b.progress >= 1.0 and float(b.get("ripe_time", 0.0)) > grow_time(b)

func has_special(key: String) -> bool:
	for b in buildings.values():
		if DEFS[b.type].get("special","") == key: return true
	return false

func is_house(kind: String) -> bool:
	return kind == "Haus" or DEFS[kind].has("special")

func is_workplace(kind: String) -> bool:
	return DEFS[kind].has("output") or DEFS[kind].has("gather")

func anchor_of(id: int) -> Vector2i:
	return id_index.get(id, Vector2i(-1,-1))

func building_by_id(id: int) -> Dictionary:
	var a: Vector2i = id_index.get(id, Vector2i(-1,-1))
	return buildings.get(a, {})

func upgrade_cost(c: Vector2i) -> Dictionary:
	var a := anchor(c)
	if not buildings.has(a): return {}
	var b: Dictionary = buildings[a]
	var cost := {}
	for k in DEFS[b.type].cost: cost[k] = maxi(1,int(DEFS[b.type].cost[k]*(b.tier+1)*0.6))
	cost.bretter = cost.get("bretter",0)+b.tier*4
	if has_special("bau"):
		for k in cost: cost[k] = maxi(1,int(cost[k]*0.8))
	return cost

func upgrade(c: Vector2i) -> bool:
	var a := anchor(c)
	if not buildings.has(a): return false
	var b: Dictionary = buildings[a]
	if b.type in DECORATIONS: notice = "Diese Dekoration braucht keinen Ausbau."; return false
	if DEFS[b.type].has("special"): notice = "Besondere Häuser haben genau einen Bewohner und keinen Ausbau."; return false
	if b.tier >= 3: notice = "Die höchste Ausbaustufe ist erreicht."; return false
	if level() < b.tier+2: notice = "Nächster Ausbau ab Dorfstufe %d." % (b.tier+2); return false
	var cost := upgrade_cost(a)
	if not afford(cost): notice = "Ausbau nicht möglich: %s Tipp: Im Reiter Lager Waren verkaufen." % missing_text(cost); return false
	exchange(cost,-1)
	b.tier += 1
	xp += 25
	revision += 1
	if b.type == "Haus": notice = "%s ist jetzt auf Ausbaustufe %d: Platz für %d Waldlinge." % [DEFS[b.type].label,b.tier,b.tier*2]
	elif is_workplace(b.type): notice = "%s ist jetzt auf Ausbaustufe %d: %d Arbeitsplätze." % [DEFS[b.type].label,b.tier,b.tier]
	else: notice = "%s ist jetzt auf Ausbaustufe %d." % [DEFS[b.type].label,b.tier]
	return true

func toggle_production(c: Vector2i) -> void:
	var a := anchor(c)
	if buildings.has(a) and is_workplace(buildings[a].type):
		buildings[a].paused = not buildings[a].paused
		revision += 1
		notice = "Betrieb pausiert. Die Arbeitsplätze sind frei." if buildings[a].paused else "Betrieb fortgesetzt."

func contract() -> Dictionary:
	return CONTRACTS[contract_index % CONTRACTS.size()]

func deliver() -> bool:
	if contract_time > 0.001: notice = "Nächster Handelsauftrag in %d Sekunden." % ceili(contract_time); return false
	var q := contract()
	if not afford({q.kind:q.amount}): notice = "Für die Lieferung fehlen %d %s." % [q.amount,NAMES[q.kind]]; return false
	resources[q.kind] -= q.amount
	var coins: int = int(q.coins * (1.2 if has_special("handel") else 1.0))
	resources.muenzen += coins
	xp += q.xp
	contract_index += 1
	if CONTRACTS[contract_index % CONTRACTS.size()].level > level(): contract_index = 0
	contract_time = 30.0
	notice = "Lieferung abgeschlossen: +%d Münzen, +%d Erfahrung." % [coins,q.xp]
	return true

func entrances(c: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not buildings.has(c): return result
	for tile in footprint(c,buildings[c].type):
		for direction in DIRS:
			var next: Vector2i = tile+direction
			if walkable(next) and not result.has(next): result.append(next)
	return result

func water(c: Vector2i) -> bool:
	return c.x >= 24 and c.y < 11 and c.x + c.y > 28

func anchor(c: Vector2i) -> Vector2i:
	return occupied.get(c, Vector2i(-1,-1))

func footprint(c: Vector2i, kind: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(DEFS[kind].size.y):
		for x in range(DEFS[kind].size.x):
			cells.append(c + Vector2i(x,y))
	return cells

func can_place(c: Vector2i, kind: String, ignore := Vector2i(-1,-1)) -> bool:
	if not DEFS.has(kind): return false
	for p in footprint(c,kind):
		if not unlocked(p) or water(p): return false
		if occupied.has(p) and occupied[p] != ignore: return false
	return true

func afford(cost: Dictionary) -> bool:
	for k in cost:
		if resources.get(k,0) < cost[k]: return false
	return true

func exchange(items: Dictionary, sign_value: int) -> void:
	for k in items: resources[k] += items[k] * sign_value

func insert(c: Vector2i, kind: String, progress := 0.0, working := false, id := -1) -> void:
	if id < 0:
		id = next_id
	next_id = maxi(next_id, id + 1)
	var b := {"type":kind,"progress":progress,"working":working,"tier":1,"paused":false,"id":id,"supply":0,"crew":0}
	if kind == "Feld": b.sown = true; b.tended = false; b.crop = "korn"; b.next_crop = "korn"; b.ripe_time = 0.0
	if kind == "Wildbaum": b.stock = Residents.TREE_LOADS
	if kind == "Felsen": b.stock = Residents.ROCK_LOADS
	buildings[c] = b
	id_index[id] = c
	for p in footprint(c,kind): occupied[p] = c
	refresh_roads(c)
	revision += 1

func place(c: Vector2i, kind: String) -> bool:
	if not DEFS.has(kind): return false
	if level() < DEFS[kind].level:
		notice = "Dieses Gebäude wird auf Stufe %d frei." % DEFS[kind].level
		return false
	if DEFS[kind].get("near_water", false) and not near_water(c, DEFS[kind].size):
		notice = "%s braucht Wasser in der Nähe (höchstens 4 Felder entfernt)." % DEFS[kind].label
		return false
	if DEFS[kind].has("special") and count(kind) > 0:
		notice = "%s gibt es nur einmal im Dorf." % DEFS[kind].label
		return false
	if not can_place(c,kind):
		notice = "Hier ist kein freier Bauplatz: Ufer, Gebäude und Kartengrenze beachten."
		return false
	if not afford(DEFS[kind].cost):
		notice = "%s: %s Tipp: Im Reiter Lager Waren verkaufen." % [DEFS[kind].label, missing_text(DEFS[kind].cost)]
		return false
	exchange(DEFS[kind].cost,-1)
	insert(c,kind)
	var b: Dictionary = buildings[c]
	if kind == "Feld": b.sown = false
	if kind == "Wildbaum": b.stock = 0; b.progress = 0.1
	xp += 3 if kind == "Weg" else 12
	if DEFS[kind].has("special"):
		var sp: Dictionary = SPECIALISTS[DEFS[kind].special]
		notice = "%s, %s, zieht nach Mooswinkel! %s" % [sp.name,sp.role,sp.effect]
	elif kind == "Feld": notice = "Kornbeet angelegt. Ein freier Waldling sät es ein."
	elif kind == "Wildbaum": notice = "Jungbaum gepflanzt. In der Nähe einer Forsthütte wird er später geerntet."
	elif is_workplace(kind): notice = "%s gebaut. Ein freier Waldling übernimmt die Arbeit." % DEFS[kind].label
	else: notice = "%s gebaut." % DEFS[kind].label
	check_quests()
	return true

func remove(c: Vector2i, refund := true) -> bool:
	var a := anchor(c)
	if not buildings.has(a): return false
	var kind: String = buildings[a].type
	var id: int = buildings[a].id
	for p in footprint(a,kind): occupied.erase(p)
	buildings.erase(a)
	id_index.erase(id)
	road_masks.erase(a)
	refresh_roads(a)
	revision += 1
	if refund:
		for k in DEFS[kind].cost: resources[k] += int(DEFS[kind].cost[k] / 2)
	if kind == "Wildbaum" and refund:
		resources.holz += 2
		notice = "Baum entfernt: +2 Holz."
	elif kind == "Felsen":
		notice = "Findling beiseitegeräumt."
	else:
		notice = "Abgerissen. Die Hälfte der Baukosten wurde erstattet."
	return true

func move_building(from: Vector2i, to: Vector2i) -> bool:
	if not buildings.has(from): return false
	var b: Dictionary = buildings[from].duplicate(true)
	if not can_place(to,b.type,from):
		notice = "Hier ist zu wenig Platz zum Verschieben."
		return false
	remove(from,false)
	insert(to,b.type,b.progress,b.working,b.id)
	for k in b:
		if not k in ["crew"]: buildings[to][k] = b[k]
	notice = "Gebäude kostenlos versetzt."
	return true

func has_road(c: Vector2i) -> bool:
	return buildings.has(c) and buildings[c].type == "Weg"

func mask(c: Vector2i) -> int:
	var bits := 0
	for i in range(4):
		if has_road(c + DIRS[i]): bits |= 1 << i
	return bits

func refresh_roads(c: Vector2i) -> void:
	for p in [c,c+DIRS[0],c+DIRS[1],c+DIRS[2],c+DIRS[3]]:
		if has_road(p): road_masks[p] = mask(p)

func count(kind: String) -> int:
	var n := 0
	for b in buildings.values():
		if b.type == kind: n += 1
	return n

func population() -> int:
	var total := 0
	for b in buildings.values():
		if b.type == "Haus": total += 2*b.tier
		elif DEFS[b.type].has("special"): total += 1
	return total

func check_quests() -> void:
	_check_wish()
	while quest < QUESTS.size():
		var q: Dictionary = QUESTS[quest]
		var n: int = quest_progress(q)
		if n < q.goal or (q.has("extra") and count(q.extra) == 0): break
		resources.muenzen += q.coins
		xp += q.xp
		notice = "Auftrag erfüllt: %s! +%d Münzen, +%d XP" % [q.title,q.coins,q.xp]
		quest += 1

## After the introduction there is always one village wish. It is made
## from goods the village has already produced and buildings it can build,
## and grows with the village level. Endless by design.
func make_wish() -> void:
	var l := level()
	var options: Array = []
	for k in Content.WISH_TEXTS:
		if int(produced.get(k, 0)) > 0: options.append(k)
	var seed_value := wishes_done * 7919 + l * 104729
	if wishes_done % 3 == 2:
		var kinds: Array = []
		for k in Content.WISH_BUILD:
			if l >= DEFS[k].level: kinds.append(k)
		var kind: String = kinds[seed_value % kinds.size()]
		var amount := 1 + mini(6, l / 4)
		if kind in ["Haus"]: amount = 1
		wish = {"type": "build", "key": kind, "goal": count(kind) + amount, "title": "Neues für das Dorf: %d × %s" % [amount, DEFS[kind].label], "coins": 25 + l * 8, "xp": 40 + l * 12}
	else:
		if options.is_empty(): options = ["holz"]
		var key: String = options[seed_value % options.size()]
		var amount := int(ceil((10 + l * 3.5) / 5.0)) * 5
		if key in ["holz", "stein"]: amount *= 2
		# Never more than the store can hold: a full store must never block.
		amount = clampi(amount, 5, int(capacity(key) * 0.75) / 5 * 5)
		wish = {"type": "deliver", "key": key, "goal": amount, "title": "%s: %d %s liefern" % [Content.WISH_TEXTS[key], amount, NAMES[key]], "coins": 30 + l * 10, "xp": 50 + l * 15}

func wish_progress() -> Array:
	if wish.is_empty(): return [0, 0]
	if wish.type == "deliver": return [mini(int(resources.get(wish.key, 0)), int(wish.goal)), int(wish.goal)]
	var have := count(wish.key) if wish.type == "build" else int(produced.get(wish.key, 0))
	var need: int = wish.goal
	var start: int = int(wish.get("start", 0))
	return [mini(have, need) - start, need - start]

func skip_wish() -> bool:
	if wish_skip_time > 0.001: notice = "Ein neuer Wunsch ist in %d Sekunden möglich." % ceili(wish_skip_time); return false
	wishes_done += 1
	make_wish()
	_start_wish()
	wishes_done -= 1
	wish_skip_time = 120.0
	notice = "Neuer Dorfwunsch: %s" % wish.title
	return true

func _start_wish() -> void:
	if wish.type == "deliver":
		wish.start = 0
		return
	wish.start = count(wish.key) if wish.type == "build" else int(produced.get(wish.key, 0))

func _check_wish() -> void:
	if quest < QUESTS.size(): return
	if wish.is_empty():
		make_wish()
		_start_wish()
		return
	var p := wish_progress()
	if p[0] >= p[1]:
		# Delivery wishes take the goods from the store (frees room).
		if wish.type == "deliver": resources[wish.key] -= int(wish.goal)
		resources.muenzen += int(wish.coins)
		xp += int(wish.xp)
		notice = "Dorfwunsch erfüllt: %s! +%d Münzen, +%d Erfahrung" % [wish.title, wish.coins, wish.xp]
		wishes_done += 1
		make_wish()
		_start_wish()

func quest_progress(q: Dictionary) -> int:
	if q.has("expansion"): return expansion
	if q.has("product"): return int(produced.get(q.product,0))
	return count(q.kind)

## Harvest of a bed: crop table times upgrade level; overripe beds give
## half (rounded up) - nothing is ever lost completely.
func harvest_yield(b: Dictionary) -> Dictionary:
	var goods := {}
	var table: Dictionary = crop_of(b).harvest if b.type == "Feld" else DEFS[b.type].harvest
	for k in table:
		var amount: int = table[k] * b.tier
		if overripe(b): amount = int(ceil(amount / 2.0))
		goods[k] = amount
	return goods

## Goods arriving in the village stock. `returning` marks goods that are
## only put back (cancelled transport): they do not count as production.
func receive(goods: Dictionary, returning := false) -> void:
	for k in goods:
		var added := _add(k, int(goods[k]))
		if not returning: produced[k] = produced.get(k,0) + added
	if not returning and not goods.is_empty():
		xp += 2
		check_quests()

## Manual harvest by the player (right click). Instant; an unsown bed is
## sown by hand. A resident who had reserved the field gives the job up.
func harvest(c: Vector2i) -> bool:
	var a := anchor(c)
	if not buildings.has(a): return false
	var b: Dictionary = buildings[a]
	if not DEFS[b.type].has("harvest"): return false
	if b.type == "Feld" and not b.sown:
		var crop: Dictionary = CROPS.get(b.get("next_crop", "korn"), CROPS.korn)
		if not afford({"muenzen": crop.seed}):
			notice = "Für das Saatgut fehlen Münzen."
			return false
		exchange({"muenzen": crop.seed}, -1)
		b.crop = b.get("next_crop", "korn")
		b.sown = true
		b.progress = 0.0
		b.ripe_time = 0.0
		_release_field(b.id)
		notice = "%s von Hand gesät." % crop.label
		return true
	if b.progress < 1.0: return false
	_release_field(b.id)
	var yield_items := harvest_yield(b)
	b.progress = 0.0
	b.ripe_time = 0.0
	for k in yield_items:
		yield_items[k] = _add(k, yield_items[k])
		produced[k] = produced.get(k,0)+yield_items[k]
	if b.type == "Feld":
		# The player re-sows by hand with the chosen crop.
		b.tended = false
		b.crop = b.get("next_crop", b.get("crop", "korn"))
	xp += 3*b.tier
	var summary: Array[String] = []
	for k in yield_items: summary.append("%d %s" % [yield_items[k],NAMES[k]])
	notice = "%s geerntet: %s." % [crop_of(b).label if b.type == "Feld" else DEFS[b.type].label,", ".join(summary)]
	check_quests()
	return true

func _release_field(id: int) -> void:
	var key := "b%d" % id
	if not reserved.has(key): return
	var rid: int = reserved[key]
	for r in residents:
		if r.id == rid and r.carry.is_empty():
			Residents.abort_task(self, r, "")
	reserved.erase(key)

func gather() -> void:
	if gather_time > 0.001:
		notice = "Der Wald erholt sich noch: %d Sekunden." % ceili(gather_time)
		return
	_add("holz", 8)
	_add("stein", 3)
	_add("nahrung", 2)
	_add("muenzen", 4)
	gather_time = 12.0
	notice = "Waldspaziergang: +8 Holz, +3 Stein, +2 Nahrung, +4 Münzen."

func sell() -> void:
	if market_time > 0.001:
		notice = "Der Händler kehrt in %d Sekunden zurück." % ceili(market_time)
		return
	# The merchant takes the good the stores are fullest of (up to 10).
	var best := ""
	var best_fill := -1.0
	for k in PRICES:
		if int(resources.get(k, 0)) < 3: continue
		var fill := float(resources[k]) / float(capacity(k)) + float(PRICES[k]) * 0.001
		if fill > best_fill:
			best_fill = fill
			best = k
	if best == "":
		notice = "Der Händler kauft Erzeugnisse, sobald mindestens 3 Stück im Lager sind."
		return
	var amount := mini(10, int(resources[best]))
	var price: int = amount * int(PRICES[best])
	if has_special("handel"): price = int(price * 1.3)
	resources[best] -= amount
	resources.muenzen += price
	market_time = 5.0
	notice = "%d %s für %d Münzen verkauft." % [amount, NAMES[best], price]

func tick(delta: float) -> void:
	if delta <= 0: return
	# Bounded simulation steps keep production and action events identical
	# for long and short frames (and therefore for 1x, 2x and 4x speed).
	var remaining := delta
	while remaining > 0.000001:
		var step := minf(0.1,remaining)
		_step(step)
		remaining -= step
	check_quests()

func _step(delta: float) -> void:
	var previous_minute := int(elapsed/60)
	elapsed += delta
	if int(elapsed/60) > previous_minute:
		var needed := ceili(population()/2.0 * (0.75 if has_special("kraeuter") else 1.0))
		hungry = resources.nahrung < needed and needed > 0
		resources.nahrung = maxi(0,resources.nahrung-needed)
		meals += needed
	gather_time = maxf(0,gather_time-delta)
	market_time = maxf(0,market_time-delta)
	contract_time = maxf(0,contract_time-delta)
	wish_skip_time = maxf(0,wish_skip_time-delta)
	animal_time = maxf(0,animal_time-delta)
	for c in buildings: buildings[c].crew = 0
	Residents.step(self, delta)
	for c in buildings:
		var b: Dictionary = buildings[c]
		var d: Dictionary = DEFS[b.type]
		if b.type == "Wildbaum":
			if b.stock <= 0:
				b.progress = minf(1.0, b.progress + delta / TREE_REGROW * season_factor("trees"))
				if b.progress >= 1.0: b.stock = Residents.TREE_LOADS
			continue
		if b.type == "Felsen":
			if b.stock < Residents.ROCK_LOADS:
				b.progress += delta / ROCK_REGEN * (1.6 if has_special("stein") else 1.0)
				if b.progress >= 1.0: b.progress = 0.0; b.stock += 1
			continue
		if b.paused: continue
		if d.has("harvest"):
			if b.type == "Feld" and not b.sown: continue
			if b.progress >= 1.0:
				b.ripe_time = float(b.get("ripe_time", 0.0)) + delta
				continue
			var growth: float = (1 + 0.15*(b.tier-1)) * (1.2 if has_special("garten") else 1.0) * season_factor("growth")
			if b.get("tended", false): growth *= 1.35
			b.progress = minf(1,b.progress + delta*growth/grow_time(b))
			if b.progress > 0.999999: b.progress = 1.0
		elif d.has("output"):
			# Production needs a woodling at the workplace. Inputs were
			# brought in as `supply` and are consumed once per cycle.
			if b.crew <= 0: continue
			if not b.working:
				var room := true
				for k in d.output:
					if not has_space(k, int(d.output[k])): room = false
				if not room:
					b.status = "full"
					continue
				if d.input.is_empty():
					b.working = true
				elif b.supply > 0:
					b.supply -= 1
					b.working = true
			if b.working:
				var pace: float = (1+0.2*(b.tier-1)) * (0.75 if hungry else 1.0) * (1.0 + 0.25 * (mini(b.crew, b.tier) - 1))
				b.progress += delta*pace/d.duration
				if b.progress >= 0.999999:
					for k in d.output:
						var amount: int = d.output[k]
						if k == "brot" and has_special("brot"): amount += 1
						if k == "honig" and has_special("honig"): amount += 1
						amount = _add(k, amount)
						produced[k] = produced.get(k,0) + amount
					b.progress = maxf(0,b.progress-1)
					b.working = false
					xp += 2
					events.append({"type":"produced","bid":b.id,"x":float(c.x)+0.5,"y":float(c.y)+0.5})
					if events.size() > Residents.MAX_EVENTS: events.pop_front()

func walkable(c: Vector2i) -> bool:
	return unlocked(c) and not water(c) and (not occupied.has(c) or has_road(c))

func route(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	# Weighted 4-connected A*: roads cost 1, meadow costs 3. Buildings and
	# water block. (Residents use the 8-connected sim/navigation.gd.)
	var result: Array[Vector2i] = []
	if not walkable(start) or not walkable(goal): return result
	var open: Array[Vector2i] = [start]
	var costs := {start:0.0}
	var previous := {}
	var scores := {start:float(absi(goal.x-start.x)+absi(goal.y-start.y))}
	while not open.is_empty():
		var current := open[0]
		for p in open:
			if scores[p] < scores[current]: current = p
		open.erase(current)
		if current == goal:
			while current != start:
				result.push_front(current)
				current = previous[current]
			return result
		for direction in DIRS:
			var next: Vector2i = current + direction
			if not walkable(next): continue
			var cost: float = costs[current] + (1.0 if has_road(next) else 3.0)
			if cost < costs.get(next,INF):
				previous[next] = current
				costs[next] = cost
				scores[next] = cost + absi(goal.x-next.x)+absi(goal.y-next.y)
				if not open.has(next): open.append(next)
	return result

func seed() -> void:
	insert(Vector2i(10,9),"Haus")
	insert(Vector2i(15,8),"Forsthaus")
	for x in range(7,19): insert(Vector2i(x,12),"Weg")
	for y in range(9,12): insert(Vector2i(12,y),"Weg")
	insert(Vector2i(14,10),"Feld", 0.55)
	insert(Vector2i(15,10),"Feld", 0.3)
	insert(Vector2i(14,11),"Feld", 0.0)
	buildings[Vector2i(14,11)].sown = false
	insert(Vector2i(9,10),"Blumenbeet")
	add_wilderness(true)

## Natural trees and boulders. `everywhere` places all fixed positions (new
## village); otherwise only positions with free surroundings are used so a
## migrated village never gets an entrance or road blocked.
func add_wilderness(everywhere := false) -> void:
	for list in [WILD_TREES, WILD_ROCKS]:
		for c in list:
			var kind := "Wildbaum" if list == WILD_TREES else "Felsen"
			if not inside(c) or water(c) or occupied.has(c): continue
			if not everywhere:
				var crowded := false
				for oy in range(-1,2):
					for ox in range(-1,2):
						var n: Vector2i = c + Vector2i(ox,oy)
						if occupied.has(n) and not buildings[occupied[n]].type in ["Wildbaum","Felsen","Baum","Strauch","Blumenbeet"]: crowded = true
				if crowded: continue
			# Insert ignoring the unlocked area: wilderness also grows behind
			# the borders and becomes usable once the land is bought.
			var id := next_id
			next_id += 1
			var b := {"type":kind,"progress":0.0,"working":false,"tier":1,"paused":false,"id":id,"supply":0,"crew":0}
			b.stock = Residents.TREE_LOADS if kind == "Wildbaum" else Residents.ROCK_LOADS
			buildings[c] = b
			id_index[id] = c
			occupied[c] = c
	revision += 1

func serialize() -> Dictionary:
	var rows := []
	for c in buildings:
		var b: Dictionary = buildings[c]
		var row := {"x":c.x,"y":c.y,"type":b.type,"progress":b.progress,"working":b.working,"tier":b.tier,"paused":b.paused,"id":b.id,"supply":b.supply}
		if b.has("sown"): row.sown = b.sown; row.tended = b.get("tended", false); row.crop = b.get("crop", "korn"); row.next_crop = b.get("next_crop", "korn"); row.ripe_time = b.get("ripe_time", 0.0)
		if b.has("stock"): row.stock = b.stock
		rows.append(row)
	return {"version":SCHEMA,"expansion":expansion,"contract_index":contract_index,"contract_time":contract_time,"meals":meals,"resources":resources.duplicate(),"buildings":rows,"xp":xp,"quest":quest,"elapsed":elapsed,"produced":produced.duplicate(),"gather_time":gather_time,"market_time":market_time,"speed":speed,"next_id":next_id,"next_rid":next_rid,"wish":wish.duplicate(),"wishes_done":wishes_done,"wish_skip_time":wish_skip_time,"hungry":hungry,"residents":Residents.serialize(self)}

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high

func restore(data: Variant) -> bool:
	# Validate into a temporary model. A bad file must not partially destroy a village.
	if not data is Dictionary or not data.get("version") in [1, 2, 3, 4, 5, 6, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]: return false
	if not data.get("resources") is Dictionary or not data.get("buildings") is Array: return false
	var version := int(data.version)
	var candidate = get_script().new()
	var area: Variant = data.get("expansion",0)
	if not _number(area, 0, 2) or float(area) != floorf(float(area)): return false
	candidate.expansion = int(area)
	for extra in ["contract_index","contract_time","meals"]:
		if not _number(data.get(extra,0), 0, 100000000): return false
	for k in INITIAL:
		# Goods introduced in later versions start at zero in older saves.
		var value: Variant = data.resources.get(k, 0) if (version < SCHEMA or k in ["honig","beeren","marmelade"]) else data.resources.get(k)
		if not _number(value, 0, 100000000): return false
		candidate.resources[k] = int(value)
	var ids := {}
	for row in data.buildings:
		if not row is Dictionary or not DEFS.has(row.get("type","")): return false
		if not row.get("x") is float and not row.get("x") is int: return false
		if not row.get("y") is float and not row.get("y") is int: return false
		if float(row.x) != floorf(float(row.x)) or float(row.y) != floorf(float(row.y)): return false
		if not row.get("working",false) is bool: return false
		var c := Vector2i(int(row.x),int(row.y))
		var wild: bool = DEFS[row.type].get("wild", false)
		# Wilderness may also stand on still locked land.
		if wild:
			if not candidate.inside(c) or candidate.water(c) or candidate.occupied.has(c): return false
		elif not candidate.can_place(c,row.type): return false
		var progress: Variant = row.get("progress",0.0)
		if not _number(progress, 0, 1): return false
		var tier: Variant = row.get("tier",1)
		if not _number(tier, 1, 3) or float(tier) != floorf(float(tier)): return false
		if not row.get("paused",false) is bool: return false
		var id := -1
		if version >= 3:
			if not _number(row.get("id"), 1, 100000000) or ids.has(int(row.id)): return false
			id = int(row.id)
			ids[id] = true
			if not _number(row.get("supply", 0), 0, 1000): return false
			for flag in ["sown", "tended"]:
				if row.has(flag) and not row[flag] is bool: return false
			if row.has("stock") and not _number(row.stock, 0, 100): return false
		var working: bool = row.get("working",false) == true
		# 0.3 gatherers produced by themselves; their progress is replaced by
		# woodcutter and stone collector trips (nothing was reserved).
		var legacy_gatherer: bool = version < 3 and DEFS[row.type].has("gather")
		candidate.insert(c,row.type,0.0 if legacy_gatherer else float(progress),false if legacy_gatherer else working,id)
		var b: Dictionary = candidate.buildings[c]
		b.tier = int(tier)
		b.paused = row.get("paused",false)
		if version >= 3:
			b.supply = int(row.get("supply", 0))
			if b.has("sown"):
				b.sown = row.get("sown", true)
				b.tended = row.get("tended", false)
				var crop: String = str(row.get("crop", "korn"))
				var next_crop: String = str(row.get("next_crop", crop))
				if not CROPS.has(crop) or not CROPS.has(next_crop): return false
				b.crop = crop
				b.next_crop = next_crop
				if not _number(row.get("ripe_time", 0.0), 0, 100000000): return false
				b.ripe_time = float(row.get("ripe_time", 0.0))
			if b.has("stock"): b.stock = int(row.get("stock", b.stock))
	for k in ["xp","quest","elapsed","gather_time","market_time","speed"]:
		if not _number(data.get(k), 0, 100000000): return false
	if data.quest > QUESTS.size() or float(data.speed) not in [0.0,1.0,2.0,4.0]: return false
	var products: Variant = data.get("produced",{})
	if not products is Dictionary: return false
	for k in products:
		if not INITIAL.has(k) or not _number(products[k], 0, 1000000000): return false
	if version >= 3:
		if not _number(data.get("next_id", 1), 1, 100000000) or not _number(data.get("next_rid", 1), 1, 100000000): return false
		candidate.next_id = maxi(candidate.next_id, int(data.get("next_id", 1)))
		candidate.next_rid = int(data.get("next_rid", 1))
		Residents.restore(candidate, data.get("residents", []))
	else:
		# Migration from 0.2/0.3: add the forests and boulders the new
		# woodcutters and stone collectors need, without blocking anything.
		candidate.add_wilderness(false)
	expansion = candidate.expansion
	contract_index = int(data.get("contract_index",0))
	contract_time = float(data.get("contract_time",0))
	meals = int(data.get("meals",0))
	workers.clear()
	resources = candidate.resources
	buildings = candidate.buildings
	occupied = candidate.occupied
	road_masks = candidate.road_masks
	id_index = candidate.id_index
	next_id = candidate.next_id
	next_rid = candidate.next_rid
	residents = candidate.residents
	reserved = candidate.reserved
	hungry = data.get("hungry", false) == true
	events.clear()
	revision += 1
	residents_rev = -1
	nav_revision = -1
	xp = int(data.xp)
	if version < 4:
		# 0.2-0.4 used 100 experience per level: keep the player's level and
		# progress inside it on the new endless curve.
		var old_level := 1 + xp / 100
		var frac := float(xp % 100) / 100.0
		xp = xp_for_level(old_level) + int(frac * (xp_for_level(old_level + 1) - xp_for_level(old_level)))
	quest = int(data.quest)
	wish = {}
	var saved_wish: Variant = data.get("wish", {})
	if saved_wish is Dictionary and saved_wish.get("type", "") in ["build", "product", "deliver"] and _number(saved_wish.get("goal"), 0, 1000000000) and _number(saved_wish.get("coins"), 0, 1000000) and _number(saved_wish.get("xp"), 0, 1000000) and _number(saved_wish.get("start", 0), 0, 1000000000):
		var key: String = str(saved_wish.get("key", ""))
		if (saved_wish.type == "build" and DEFS.has(key)) or (saved_wish.type in ["product", "deliver"] and NAMES.has(key)):
			wish = {"type": saved_wish.type, "key": key, "goal": int(saved_wish.goal), "start": int(saved_wish.get("start", 0)), "coins": int(saved_wish.coins), "xp": int(saved_wish.xp), "title": str(saved_wish.get("title", ""))}
	wishes_done = int(data.get("wishes_done", 0)) if _number(data.get("wishes_done", 0), 0, 100000000) else 0
	wish_skip_time = float(data.get("wish_skip_time", 0.0)) if _number(data.get("wish_skip_time", 0.0), 0, 1000) else 0.0
	elapsed = float(data.elapsed)
	gather_time = float(data.gather_time)
	market_time = float(data.market_time)
	speed = float(data.speed)
	produced = products.duplicate()
	return true
