extends SceneTree
const Model = preload("res://scripts/village.gd")
var checks := 0
var failures: Array[String] = []

func verify(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures.append(message)
  push_error(message)

func _initialize() -> void:
 roads()
 construction()
 economy()
 persistence()
 navigation()
 print("MOOSWINKEL TESTS: %d checks, %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)

func roads() -> void:
 var c := Vector2i(10,10)
 for bits in range(16):
  var m = Model.new()
  m.insert(c,"Weg")
  for i in range(4):
   if bits & (1<<i): m.insert(c+Model.DIRS[i],"Weg")
  verify(m.mask(c) == bits,"4-bit mask %d" % bits)
  verify(m.road_masks[c] == bits,"Cached mask %d" % bits)
  for i in range(4):
   if bits & (1<<i):
    verify(m.mask(c+Model.DIRS[i]) & (1<<((i+2)%4)) != 0,"Reciprocal edge")
    m.remove(c+Model.DIRS[i],false)
    verify(m.road_masks[c] == (bits & ~(1<<i)),"Demolition refresh")
    m.insert(c+Model.DIRS[i],"Weg")
  verify(m.move_building(c,Vector2i(20,20)),"Move road")
  for i in range(4):
   if bits & (1<<i): verify(m.road_masks[c+Model.DIRS[i]] == 0,"Move refreshes old neighbors")

func construction() -> void:
 var m = Model.new()
 verify(m.place(Vector2i(3,3),"Haus"),"House placement")
 verify(m.occupied.size() == 4,"2x2 footprint")
 var before: Dictionary = m.resources.duplicate()
 verify(not m.place(Vector2i(4,4),"Feld"),"Overlap rejected")
 verify(not m.place(Vector2i(29,23),"Haus"),"Boundary rejected")
 verify(not m.place(Vector2i(27,4),"Haus"),"Water rejected")
 verify(m.resources == before,"Invalid placement costs nothing")
 verify(m.move_building(Vector2i(3,3),Vector2i(4,3)),"Self-overlap move allowed")
 verify(m.resources == before,"Moving is free")
 verify(not m.occupied.has(Vector2i(3,3)),"Old cells released")
 verify(m.occupied.size() == 4,"Move footprint preserved")
 verify(m.remove(Vector2i(5,4)),"Demolition via non-anchor cell")
 verify(m.occupied.is_empty(),"All footprint cells released")
 verify(m.resources.holz == before.holz+6,"Half refund")
 verify(not m.place(Vector2i(2,2),"Baeckerei"),"Progress lock")
 m.resources.muenzen = 0
 verify(not m.place(Vector2i(2,2),"Feld"),"Cannot overspend")

func economy() -> void:
 var m = Model.new()
 m.insert(Vector2i(1,1),"Feld")
 m.tick(12)
 verify(is_equal_approx(m.buildings[Vector2i(1,1)].progress,0.5*m.season_factor("growth")),"Half-grown crop (spring growth factor)")
 verify(not m.harvest(Vector2i(1,1)),"No early harvest")
 m.tick(12)
 verify(m.harvest(Vector2i(1,1)),"Ripe crop harvested")
 verify(m.resources.getreide == 6,"Crop yield")
 verify(not m.harvest(Vector2i(1,1)),"No double harvest")
 # 0.4: workshops need a woodling who fetches inputs and works on site.
 m.insert(Vector2i(10,3),"Haus")
 m.insert(Vector2i(3,3),"Muehle")
 m.insert(Vector2i(6,6),"Baeckerei")
 m.resources.getreide = 12
 var paused: Dictionary = m.serialize()
 m.tick(0)
 verify(JSON.stringify(m.serialize()) == JSON.stringify(paused),"Pause consumes no production inputs")
 for i in range(1200): m.tick(0.1); m.events.clear()
 verify(m.produced.get("mehl",0) >= 3,"Flour production")
 verify(m.resources.brot >= 3,"Grain to flour to bread")
 var bread: int = m.resources.brot
 m.resources.mehl = 0
 m.resources.getreide = 0
 for i in range(400): m.tick(0.1); m.events.clear()
 verify(m.resources.brot <= bread + 6,"Production stalls without inputs (after at most two buffered cycles)")
 var coins_before_sale: int = m.resources.muenzen
 m.sell()
 verify(m.resources.muenzen > coins_before_sale,"Market consumes products and pays")
 var coins: int = m.resources.muenzen
 m.sell()
 verify(m.resources.muenzen == coins,"Market cooldown")
 for k in m.resources: m.resources[k] = 0
 for i in range(10): m.gather(); m.tick(12)
 verify(m.resources.holz >= 80 and m.resources.muenzen >= 40,"Recovery from zero without payments")
 m.gather()
 var wood: int = m.resources.holz
 m.gather()
 verify(m.resources.holz == wood,"Gather cooldown")
 # The full quest chain is played by tests/campaign.gd with residents.

func persistence() -> void:
 var m = Model.new()
 m.seed()
 m.insert(Vector2i(3,10),"Saegewerk")
 m.tick(5)
 m.gather()
 m.speed = 4
 var encoded := JSON.stringify(m.serialize())
 var loaded = Model.new()
 verify(loaded.restore(JSON.parse_string(encoded)),"JSON round trip")
 verify(loaded.resources == m.resources,"Resources restored")
 verify(loaded.occupied == m.occupied,"Footprints restored")
 verify(loaded.road_masks == m.road_masks,"Road cache rebuilt")
 verify(loaded.speed == 4 and loaded.gather_time == m.gather_time,"Settings and timers restored")
 loaded.buildings[Vector2i(3,10)].working = m.buildings[Vector2i(3,10)].working
 verify(loaded.buildings[Vector2i(3,10)].working == m.buildings[Vector2i(3,10)].working,"Production state restored")
 m.tick(11)
 loaded.tick(11)
 verify(loaded.resources == m.resources,"Reserved inputs not charged twice after load")
 var good: Dictionary = loaded.serialize()
 var broken: Dictionary = good.duplicate(true)
 broken.buildings.append(broken.buildings[0])
 verify(not loaded.restore(broken),"Overlapping save rejected")
 verify(loaded.serialize() == good,"Invalid load leaves live game intact")
 broken = good.duplicate(true)
 broken.resources.holz = -1
 verify(not loaded.restore(broken),"Negative resources rejected")
 verify(not loaded.restore({}),"Wrong schema rejected")
 broken = good.duplicate(true)
 broken.erase("xp")
 verify(not loaded.restore(broken),"Missing numeric fields rejected")
 broken = good.duplicate(true)
 broken.buildings[0].x = 1.5
 verify(not loaded.restore(broken),"Fractional grid coordinates rejected")
 broken = good.duplicate(true)
 broken.buildings[0].type = "unknown"
 verify(not loaded.restore(broken),"Unknown asset rejected")
 broken = good.duplicate(true)
 broken.produced = {"brot":-9}
 verify(not loaded.restore(broken),"Invalid totals rejected")

func navigation() -> void:
 var m = Model.new()
 m.insert(Vector2i(5,5),"Haus")
 var path: Array[Vector2i] = m.route(Vector2i(3,5),Vector2i(8,5))
 verify(not path.is_empty(),"Route around house exists")
 var last := Vector2i(3,5)
 for c in path:
  verify(m.walkable(c),"Path avoids buildings and water")
  verify(absi(c.x-last.x)+absi(c.y-last.y) == 1,"Path has no diagonal jumps")
  last = c
 verify(last == Vector2i(8,5),"Route reaches destination")
 verify(m.route(Vector2i(3,5),Vector2i(5,5)).is_empty(),"Blocked destination rejected")
 # A longer connected road must beat the direct grassy shortcut.
 var road = Model.new()
 for c in [Vector2i(1,1),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(4,2),Vector2i(5,2),Vector2i(5,1)]: road.insert(c,"Weg")
 var preferred: Array[Vector2i] = road.route(Vector2i(1,1),Vector2i(5,1))
 verify(preferred.size() == 6,"Road preference outweighs short meadow route")
 for c in preferred: verify(road.has_road(c),"Connected roads preferred")

