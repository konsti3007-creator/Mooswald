extends SceneTree
const Model = preload("res://scripts/village.gd")
var checks := 0
var failures := 0

func verify(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error(label)

func _initialize() -> void:
 upgrades()
 chains()
 land()
 contracts()
 time_and_food()
 legacy()
 campaign()
 print("MOOSWINKEL EXPANSION: %d checks, %d failures" % [checks,failures])
 quit(0 if failures == 0 else 1)

func upgrades() -> void:
 var m = Model.new()
 m.insert(Vector2i(5,5),"Haus")
 m.xp = Model.xp_for_level(6)
 m.resources.bretter = 100
 m.resources.muenzen = 1000
 var before: int = m.resources.bretter
 verify(m.upgrade(Vector2i(6,6)),"Upgrade through footprint")
 verify(m.population() == 4,"House upgrade increases population")
 verify(m.resources.bretter < before,"Upgrade costs boards")
 verify(m.upgrade(Vector2i(5,5)),"Tier three upgrade")
 verify(not m.upgrade(Vector2i(5,5)),"Maximum tier enforced")
 verify(m.population() == 6,"Tier three housing")
 verify(m.move_building(Vector2i(5,5),Vector2i(7,7)),"Upgraded house moves")
 verify(m.buildings[Vector2i(7,7)].tier == 3,"Move preserves upgrade")
 var n = Model.new()
 verify(n.restore(JSON.parse_string(JSON.stringify(m.serialize()))),"Upgraded save roundtrip")
 verify(n.population() == 6,"Upgrade persists")
 m.insert(Vector2i(10,10),"Saegewerk")
 m.resources.holz = 100
 m.tick(4)
 var b: Dictionary = m.buildings[Vector2i(10,10)]
 var progress: float = b.progress
 m.toggle_production(Vector2i(10,10))
 m.tick(20)
 verify(is_equal_approx(progress,b.progress),"Pause preserves production")
 m.move_building(Vector2i(10,10),Vector2i(12,10))
 verify(m.buildings[Vector2i(12,10)].paused,"Move preserves pause")
 m.toggle_production(Vector2i(12,10))
 m.tick(12)
 verify(m.resources.bretter > before-30,"Resumed production completes")

func chains() -> void:
 var m = Model.new()
 m.insert(Vector2i(2,2),"Beeren")
 m.insert(Vector2i(4,4),"Imkerei")
 m.insert(Vector2i(7,4),"Kochhaus")
 m.tick(30)
 verify(m.harvest(Vector2i(2,2)),"Berries can be harvested")
 verify(m.resources.beeren == 5,"Berry yield")
 m.insert(Vector2i(12,8),"Haus")
 m.insert(Vector2i(15,8),"Haus")
 m.resources.honig = 4
 for i in range(1500): m.tick(0.1); m.events.clear()
 verify(m.produced.get("marmelade",0) >= 3,"Honey and berries become jam (with workers)")
 m.insert(Vector2i(10,4),"Gasthaus")
 m.insert(Vector2i(18,8),"Haus")
 m.resources.brot = 2
 m.resources.marmelade = 1
 var coins: int = m.resources.muenzen
 for i in range(1500): m.tick(0.1); m.events.clear()
 verify(m.resources.muenzen >= coins+30,"Inn converts meals to income (with a worker)")
 verify(m.resources.brot == 0,"Inn consumes bread")
 # 0.3 had an optional +25 % presence bonus; since 0.4 a woodling is
 # required at the workplace (tests/residents_test.gd, workshops()).

func land() -> void:
 var m = Model.new()
 verify(not m.can_place(Vector2i(32,16),"Haus"),"East initially locked")
 verify(not m.can_place(Vector2i(15,26),"Haus"),"South initially locked")
 verify(not m.walkable(Vector2i(32,16)),"Locked land blocks navigation")
 verify(not m.expand(),"Low level cannot expand")
 m.xp = Model.xp_for_level(8)
 m.resources.bretter = 200
 m.resources.stein = 200
 m.resources.muenzen = 1000
 verify(m.expand(),"Eastern clearing unlocked")
 verify(m.can_place(Vector2i(32,16),"Haus"),"East can be built")
 verify(not m.can_place(Vector2i(15,26),"Haus"),"South stays locked until second purchase")
 verify(m.expand(),"Southern clearing unlocked")
 verify(m.can_place(Vector2i(15,26),"Haus"),"South can be built")
 verify(not m.expand(),"Cannot buy a third expansion")
 verify(m.place(Vector2i(32,16),"Haus"),"Build in unlocked area")
 var n = Model.new()
 verify(n.restore(JSON.parse_string(JSON.stringify(m.serialize()))),"Expanded land save")
 verify(n.expansion == 2 and n.anchor(Vector2i(33,17)) == Vector2i(32,16),"Expansion and outer building persist")
 var bad: Dictionary = m.serialize()
 bad.expansion = 0
 verify(not n.restore(bad),"Save cannot place houses on locked land")

func contracts() -> void:
 var m = Model.new()
 verify(not m.deliver(),"No free delivery without goods")
 m.resources.getreide = 12
 var coins: int = m.resources.muenzen
 verify(m.deliver(),"Contract delivery")
 verify(m.resources.getreide == 6 and m.resources.muenzen == coins+18,"Contract exchanges goods exactly")
 verify(not m.deliver(),"Contract cooldown")
 m.tick(30)
 verify(m.contract_index == 0,"Locked contract tier cycles to accessible task")
 verify(m.deliver(),"Accessible contract repeats")
 var n = Model.new()
 verify(n.restore(JSON.parse_string(JSON.stringify(m.serialize()))),"Trade cooldown saved")
 verify(n.contract_time == m.contract_time,"Trade cooldown restored")

func time_and_food() -> void:
 # Frame-size independence of work and payouts: tests/residents_test.gd.
 var food = Model.new()
 food.insert(Vector2i(4,4),"Haus")
 food.tick(60)
 verify(food.resources.nahrung == 11,"Household eats once per minute")
 food.resources.nahrung = 0
 food.tick(60)
 verify(food.resources.nahrung == 0,"Food never becomes negative")
 food.tick(0)
 verify(is_equal_approx(food.elapsed,120.0),"Pause stops clock")

func legacy() -> void:
 var m = Model.new()
 m.seed()
 var data: Dictionary = m.serialize()
 data.version = 1
 data.resources.erase("beeren")
 data.resources.erase("honig")
 data.resources.erase("marmelade")
 for row in data.buildings:
  row.erase("tier")
  row.erase("paused")
 for key in ["expansion","contract_index","contract_time","meals"]: data.erase(key)
 var n = Model.new()
 verify(n.restore(JSON.parse_string(JSON.stringify(data))),"Version one save migrates")
 verify(n.resources.honig == 0 and n.expansion == 0,"Migration defaults are safe")
 verify(n.buildings[Vector2i(10,9)].tier == 1,"Old building gets tier one")

func campaign() -> void:
 # 0.4: played with the resident simulation in tests/campaign.gd.
 pass
