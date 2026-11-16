extends Node2D
## Renders the village. Layers:
##   ground   – terrain, water bed, roads; re-recorded only when the world changes
##   water    – animated waves and reeds (cheap, every frame)
##   objects  – y-sorted buildings, nature and woodlings (correct front/back order)
##   overlay  – build preview, selection, effects, night light, birds
## Occluding buildings and trees in front of the selection fade out.

const Model = preload("res://scripts/village.gd")
const WoodlingView = preload("res://scripts/view/woodling_view.gd")
const AnimDefs = preload("res://scripts/anim/anim_defs.gd")
const AnimalsView = preload("res://scripts/view/animals_view.gd")
const TILE := Vector2(72, 36)

class Layer extends Node2D:
	var painter: Callable
	func _draw() -> void:
		painter.call(self)

class ObjectNode extends Node2D:
	var world
	var cell := Vector2i.ZERO
	var data: Dictionary = {}
	var fade := 1.0
	var rect := Rect2()
	var pick_tex: Texture2D
	func _draw() -> void:
		world.draw_object(self)

var game  # game.gd (village, art, settings)
var ground: Layer
var water_layer: Layer
var objects: Node2D
var overlay: Layer
var building_nodes: Dictionary = {}  # id -> ObjectNode
var resident_nodes: Dictionary = {}  # rid -> WoodlingView
var scenery_nodes: Array = []
var ground_revision := -1
var visual_time := 0.0
var particles: Array = []
var shakes: Dictionary = {}  # building id -> remaining shake time
var pulses: Dictionary = {}  # building id -> remaining "produced" glow
var terrain: FastNoiseLite
var sparks: Array = []
var selected_resident := -1
var focus_rect := Rect2()
var mat_foliage: ShaderMaterial
var mat_building: ShaderMaterial
var mat_ground: ShaderMaterial
var season_w := [1.0, 0.0, 0.0, 0.0]
var weather_timer := 0.0
var animals_view
var lights: Layer
var night := 0.0
var fireflies: Array = []
var pen_fronts: Dictionary = {}
const FOLIAGE_TYPES := ["Wildbaum", "Baum", "Scenery", "Strauch", "Blumenbeet", "Beeren", "Feld"]

func setup(owner_game) -> void:
	game = owner_game
	terrain = FastNoiseLite.new()
	terrain.seed = 1407
	terrain.frequency = 0.035
	for i in range(28): sparks.append(Vector2(randf_range(-650, 700), randf_range(140, 1100)))
	ground = Layer.new()
	ground.painter = _paint_ground
	ground.z_index = -20
	add_child(ground)
	water_layer = Layer.new()
	water_layer.painter = _paint_water
	water_layer.z_index = -19
	add_child(water_layer)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	var sprite_shader: Shader = load("res://assets/shaders/seasonal.gdshader")
	mat_foliage = ShaderMaterial.new()
	mat_foliage.shader = sprite_shader
	mat_foliage.set_shader_parameter("foliage", 1.0)
	mat_building = ShaderMaterial.new()
	mat_building.shader = sprite_shader
	mat_building.set_shader_parameter("foliage", 0.35)
	mat_building.set_shader_parameter("snow_depth", 8.0)
	mat_ground = ShaderMaterial.new()
	mat_ground.shader = load("res://assets/shaders/seasonal_ground.gdshader")
	ground.material = mat_ground
	water_layer.material = mat_ground
	overlay = Layer.new()
	overlay.painter = _paint_overlay
	overlay.z_index = 20
	add_child(overlay)
	animals_view = AnimalsView.new(self)
	# Night lights are drawn additively over the darkened world.
	lights = Layer.new()
	lights.painter = _paint_lights
	lights.z_index = 22
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lights.material = add
	add_child(lights)
	for i in range(46): fireflies.append(Vector2(randf_range(-1300, 1500), randf_range(-100, 1500)))

func village():
	return game.village

static func cell_pos(c: Vector2i) -> Vector2:
	return Vector2((c.x - c.y) * TILE.x / 2, (c.x + c.y) * TILE.y / 2)

static func grid_to_screen(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * TILE.x / 2, (p.x + p.y) * TILE.y / 2)

func diamond(c: Vector2i, size := Vector2i.ONE) -> PackedVector2Array:
	var p := cell_pos(c) + Vector2(0, -TILE.y / 2)
	return PackedVector2Array([p, p + Vector2(size.x * TILE.x / 2, size.x * TILE.y / 2), p + Vector2((size.x - size.y) * TILE.x / 2, (size.x + size.y) * TILE.y / 2), p + Vector2(-size.y * TILE.x / 2, size.y * TILE.y / 2)])

## Sort point of an object: centre of its footprint, slightly forward.
func sort_point(c: Vector2i, kind: String) -> Vector2:
	var size: Vector2i = Model.DEFS[kind].size
	# Enclosures: the back part sorts at the back corner, so the animals
	# and the front fence (own node) are drawn over the pasture.
	if Model.DEFS[kind].get("pen", false): return cell_pos(c) + Vector2(0, -14)
	var center := Vector2(c) + Vector2(size - Vector2i.ONE) * 0.5
	var offset := 4.0 if size == Vector2i.ONE else 10.0
	return grid_to_screen(center) + Vector2(0, offset)

# ------------------------------------------------------------- sync

func rebuild() -> void:
	for n in building_nodes.values(): n.queue_free()
	for n in resident_nodes.values(): n.queue_free()
	for n in scenery_nodes: n.queue_free()
	building_nodes.clear()
	resident_nodes.clear()
	for n in pen_fronts.values(): n.queue_free()
	pen_fronts.clear()
	if animals_view: animals_view.reset()
	scenery_nodes.clear()
	particles.clear()
	ground_revision = -1
	sync()

func sync() -> void:
	var v = village()
	var seen := {}
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		if b.type == "Weg": continue
		seen[b.id] = true
		var node: ObjectNode = building_nodes.get(b.id)
		if node == null:
			node = ObjectNode.new()
			node.world = self
			node.material = mat_foliage if b.type in FOLIAGE_TYPES else mat_building
			building_nodes[b.id] = node
			objects.add_child(node)
		node.cell = c
		node.data = b
		node.position = sort_point(c, b.type)
	for id in building_nodes.keys():
		if not seen.has(id):
			building_nodes[id].queue_free()
			building_nodes.erase(id)
	# Front fences of enclosures.
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		if not Model.DEFS[b.type].get("pen", false): continue
		var front: ObjectNode = pen_fronts.get(b.id)
		if front == null:
			front = ObjectNode.new()
			front.world = self
			front.material = mat_building
			pen_fronts[b.id] = front
			objects.add_child(front)
		front.cell = c
		front.data = {"type": "PenFront", "id": -b.id, "kind": b.type}
		var size: Vector2i = Model.DEFS[b.type].size
		front.position = cell_pos(c + size - Vector2i.ONE) + Vector2(0, 20)
	for id in pen_fronts.keys():
		if not seen.has(id):
			pen_fronts[id].queue_free()
			pen_fronts.erase(id)
	var rseen := {}
	for r in v.residents:
		rseen[r.id] = true
		var view: Node2D = resident_nodes.get(r.id)
		if view == null:
			view = WoodlingView.new()
			resident_nodes[r.id] = view
			objects.add_child(view)
		if view.resident != r: view.setup(r, self)
	for id in resident_nodes.keys():
		if not rseen.has(id):
			resident_nodes[id].queue_free()
			resident_nodes.erase(id)
	_sync_scenery()
	if ground_revision != v.revision:
		ground_revision = v.revision
		ground.queue_redraw()

## Dense forest edge beyond the purchasable land (purely decorative).
func _sync_scenery() -> void:
	var v = village()
	var wanted: Array = []
	for i in range(62):
		var c: Vector2i
		if i < 22: c = Vector2i(-1 - i % 2, i)
		elif i < 44: c = Vector2i(i - 22, -1 - i % 2)
		else: c = Vector2i(30 + (i - 44) % 10, 24 + (i - 44) / 10 * 3)
		if not v.unlocked(c) and not v.occupied.has(c): wanted.append(c)
	if wanted.size() == scenery_nodes.size(): return
	for n in scenery_nodes: n.queue_free()
	scenery_nodes.clear()
	for c in wanted:
		var node := ObjectNode.new()
		node.world = self
		node.material = mat_foliage
		node.cell = c
		node.data = {"type": "Scenery", "id": -1}
		node.position = grid_to_screen(Vector2(c)) + Vector2(0, 4)
		objects.add_child(node)
		scenery_nodes.append(node)

func update(delta: float, game_delta: float) -> void:
	visual_time += delta
	var v = village()
	sync()
	season_w = v.season_weights()
	animals_view.update(game_delta, fmod(v.elapsed / 240 * 24 + 7, 24), season_w[3])
	for m in [mat_foliage, mat_building, mat_ground]:
		m.set_shader_parameter("spring", season_w[0])
		m.set_shader_parameter("autumn", season_w[2])
		m.set_shader_parameter("winter", season_w[3])
	_weather(delta)
	_consume_events(v)
	for id in shakes.keys():
		shakes[id] -= delta
		if shakes[id] <= 0: shakes.erase(id)
	for id in pulses.keys():
		pulses[id] -= delta
		if pulses[id] <= 0: pulses.erase(id)
	for p in particles:
		p.t += game_delta if p.get("game", true) else delta
		p.vel.y += p.get("grav", 160.0) * (game_delta if p.get("game", true) else delta)
		p.pos += p.vel * (game_delta if p.get("game", true) else delta)
	particles = particles.filter(func(p): return p.t < p.life)
	_update_focus(v)
	for node in building_nodes.values():
		var target := 1.0
		if focus_rect.size.x > 0 and node.rect.size.x > 0 and node.rect.intersects(focus_rect) and node.position.y > focus_rect.end.y - 6 and node.data.type in ["Wildbaum", "Baum", "Haus", "Forsthaus", "Saegewerk", "Muehle", "Baeckerei", "Steinbruch", "Imkerei", "Kochhaus", "Gasthaus", "Laterne"]:
			target = 0.38
		node.fade = move_toward(node.fade, target, delta * 4.0)
		node.modulate.a = node.fade
		node.queue_redraw()
	for view in resident_nodes.values():
		view.selected = view.resident.id == selected_resident
		view.refresh(visual_time)
	water_layer.queue_redraw()
	overlay.queue_redraw()
	night = night_factor(fmod(v.elapsed / 240 * 24 + 7, 24))
	lights.queue_redraw()

## Screen rect of what the player is looking at (selection or build cursor):
## objects in front of it become transparent.
func _update_focus(v) -> void:
	focus_rect = Rect2()
	if selected_resident >= 0:
		for r in v.residents:
			if r.id == selected_resident:
				var p := grid_to_screen(Vector2(r.x, r.y))
				focus_rect = Rect2(p - Vector2(16, 70), Vector2(32, 72))
	elif v.buildings.has(game.inspected):
		var b: Dictionary = v.buildings[game.inspected]
		var node: ObjectNode = building_nodes.get(b.id)
		if node: focus_rect = node.rect.grow(-6)
	elif game.mode in ["Bauen", "Bewegen"] and v.inside(game.hover) and not v.occupied.has(game.hover) and (game.mode == "Bewegen" or game.selected != "Weg"):
		var p := cell_pos(game.hover)
		focus_rect = Rect2(p - Vector2(30, 60), Vector2(60, 70))

# ------------------------------------------------------------- events -> effects

func _consume_events(v) -> void:
	if v.events.is_empty(): return
	for e in v.events:
		var at := grid_to_screen(Vector2(e.get("tx", e.x), e.get("ty", e.y)))
		var me := grid_to_screen(Vector2(e.x, e.y))
		match e.type:
			"hit":
				if e.kind == "wood":
					shakes[e.bid] = 0.32
					_burst(at + Vector2(0, -14), 7, [Color("c99a5c"), Color("e7c48c"), Color("8a5a32")], 60.0, 0.5, 2.2)
					if randf() < 0.6: _leaf(at + Vector2(randf_range(-30, 30), -80))
					game.play_sfx("chop", at)
				else:
					shakes[e.bid] = 0.15
					_burst(at + Vector2(0, -8), 6, [Color("b8bcb6"), Color("8f948f"), Color("d9dcd6")], 55.0, 0.45, 2.0)
					_burst(at + Vector2(0, -12), 4, [Color("ffe9a0"), Color("fff6d0")], 90.0, 0.25, 1.4)
					_dust(at + Vector2(0, -2), 3)
					game.play_sfx("pick", at)
			"fell":
				shakes[e.bid] = 0.8
				for i in range(6): _leaf(at + Vector2(randf_range(-40, 40), randf_range(-110, -50)))
				game.play_sfx("fall", at)
			"cast", "catch":
				for i in range(3): particles.append({"pos": at, "vel": Vector2.ZERO, "t": -i * 0.18, "life": 1.1, "col": Color(0.9, 0.97, 1.0, 0.8), "size": 3.0, "grav": 0.0, "ring": true})
				_burst(at + Vector2(0, -2), 5, [Color(0.85, 0.95, 1.0, 0.9)], 40.0, 0.5, 1.6)
				game.play_sfx("splash", at)
			"cut":
				_burst(at + Vector2(0, -6), 6, [Color("e7c46a"), Color("d0a64a")], 45.0, 0.6, 1.8)
				game.play_sfx("swish", at)
			"pluck":
				shakes[e.bid] = 0.18
				game.play_sfx("rustle", at)
			"drop_in":
				_burst(me + Vector2(-6, -18), 2, [Color("b3283a")], 20.0, 0.3, 1.6)
			"sow":
				_burst(me + Vector2(10, -16), 7, [Color("d9c27a"), Color("b8954a")], 40.0, 0.7, 1.2, 90.0)
			"water":
				_burst(at + Vector2(0, -10), 6, [Color("9fd0e8"), Color("c8e6f2")], 30.0, 0.55, 1.5, 220.0)
				game.play_sfx("splash", at)
			"plant":
				_dust(at, 3)
			"pickup":
				game.play_sfx("lift", me)
			"handover", "supply":
				_dust(me + Vector2(0, -2), 2)
				game.play_sfx("drop", me)
				if e.type == "handover" and e.has("goods"):
					var text := ""
					for k in e.goods: text += "+%d %s  " % [e.goods[k], Model.NAMES.get(k, k)]
					particles.append({"pos": me + Vector2(0, -70), "vel": Vector2(0, -16), "t": 0.0, "life": 1.6, "text": text.strip_edges(), "grav": 0.0, "game": false})
			"harvested":
				shakes[e.bid] = 0.25
			"produced":
				pulses[e.bid] = 1.0
				game.play_sfx("done", at)
			"work":
				match e.event:
					"stroke": _burst(at + Vector2(randf_range(-6, 6), -6), 3, [Color("e8cf9c"), Color("d2b47c")], 30.0, 0.5, 1.3)
					"press": _burst(at + Vector2(0, -4), 3, [Color(1, 1, 0.96, 0.8)], 18.0, 0.6, 2.2, 0.0)
					"pour": _burst(at + Vector2(0, -16), 5, [Color(1, 0.98, 0.9, 0.9)], 20.0, 0.8, 2.0, 20.0)
					"bubble": _burst(at + Vector2(0, -8), 2, [Color("e05a6a"), Color("f2a3ab")], 12.0, 0.6, 2.0, -20.0)
					"bees":
						for i in range(3): particles.append({"pos": at + Vector2(randf_range(-10, 10), -20), "vel": Vector2(randf_range(-20, 20), randf_range(-20, -5)), "t": 0.0, "life": 1.4, "col": Color("e8b830"), "size": 1.4, "grav": 0.0, "bee": true})
					"wipe": pass
				if e.event in ["stroke", "press", "stir", "bubble"] and randf() < 0.5: game.play_sfx("work_" + str(e.event), at)
	v.events.clear()

## Seasonal weather around the camera: blossom petals in spring, butterflies
## in summer, falling leaves in autumn, snowflakes in winter.
func _weather(delta: float) -> void:
	weather_timer -= delta
	if weather_timer > 0.0: return
	weather_timer = 0.08
	var cam: Vector2 = game.camera.position
	var half: Vector2 = get_viewport_rect().size / game.camera.zoom * 0.6
	var at := cam + Vector2(randf_range(-half.x, half.x), -half.y - 20.0)
	var heavy: float = season_w[3]
	if heavy > 0.3:
		for i in range(2 + int(heavy * 3.0)):
			var p := cam + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, -half.y * 0.2))
			particles.append({"pos": p, "vel": Vector2(randf_range(-12, 6), randf_range(28, 46)), "t": 0.0, "life": 14.0, "col": Color(1, 1, 1, 0.85), "size": randf_range(1.2, 2.6), "grav": 0.0, "game": false, "flake": true})
	elif season_w[2] > 0.3 and randf() < 0.55:
		particles.append({"pos": at, "vel": Vector2(randf_range(-20, 20), 26), "t": 0.0, "life": 16.0, "col": [Color("d9922e"), Color("b9532a"), Color("e3bf4a")][randi() % 3], "size": 2.8, "grav": 0.0, "game": false, "leaf": true})
	elif season_w[0] > 0.3 and randf() < 0.35:
		particles.append({"pos": at, "vel": Vector2(randf_range(-10, 22), 18), "t": 0.0, "life": 16.0, "col": Color("f6cfe0"), "size": 2.2, "grav": 0.0, "game": false, "leaf": true})
	elif season_w[1] > 0.5 and randf() < 0.05:
		var p := cam + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		particles.append({"pos": p, "vel": Vector2(randf_range(-18, 18), randf_range(-6, 6)), "t": 0.0, "life": 9.0, "col": [Color("f4e27a"), Color("e9a6c8"), Color("ffffff")][randi() % 3], "size": 2.0, "grav": 0.0, "game": false, "butterfly": true})
	if particles.size() > 900: particles = particles.slice(particles.size() - 900)

func _burst(at: Vector2, n: int, colors: Array, speed: float, life: float, size: float, grav := 160.0) -> void:
	for i in range(n):
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		particles.append({"pos": at, "vel": Vector2(cos(a), sin(a)) * speed * randf_range(0.5, 1.2), "t": 0.0, "life": life * randf_range(0.7, 1.2), "col": colors[i % colors.size()], "size": size * randf_range(0.7, 1.2), "grav": grav})

func _dust(at: Vector2, n: int) -> void:
	for i in range(n):
		particles.append({"pos": at + Vector2(randf_range(-6, 6), 0), "vel": Vector2(randf_range(-14, 14), randf_range(-10, -4)), "t": 0.0, "life": 0.8, "col": Color(0.86, 0.8, 0.66, 0.5), "size": 3.0, "grav": 0.0, "dust": true})

func _leaf(at: Vector2) -> void:
	particles.append({"pos": at, "vel": Vector2(randf_range(-14, 14), 10), "t": 0.0, "life": 2.2, "col": [Color("8fae4a"), Color("c7b248"), Color("6f9a3f")][randi() % 3], "size": 2.6, "grav": 8.0, "leaf": true})

# ------------------------------------------------------------- ground

func _paint_ground(ci: CanvasItem) -> void:
	var v = village()
	for y in range(-3, Model.SIZE.y + 3):
		for x in range(-3, Model.SIZE.x + 3):
			var c := Vector2i(x, y)
			var p := cell_pos(c)
			if v.water(c):
				ci.draw_colored_polygon(diamond(c), Color("69aaa0") if (x + y) % 2 else Color("6eafa3"))
				continue
			var poly := diamond(c)
			var colors := PackedColorArray()
			for vertex in poly:
				var variation := terrain.get_noise_2d(vertex.x, vertex.y) * 0.09
				var base := Color(0.52 + variation, 0.69 + variation, 0.32 + variation)
				if not v.unlocked(c): base = base.darkened(0.2)
				colors.append(base)
			ci.draw_polygon(poly, colors)
			if not v.inside(c): continue
			if not v.occupied.has(c):
				if (x * 13 + y * 7) % 9 == 0:
					for i in range(3):
						var flower := p + Vector2(i * 7 - 8, i % 2 * 4)
						ci.draw_line(flower, flower + Vector2(0, -5), Color("648753"), 1)
						ci.draw_circle(flower + Vector2(0, -6), 1.8, Color("f7e7ae") if i % 2 else Color("e1a5a1"))
				if (x * 17 + y * 3) % 7 == 0: ci.draw_line(p + Vector2(-7, 1), p + Vector2(-5, -3), Color("789b5e"), 1, true)
				if (x * 5 + y * 11) % 6 == 0:
					for i in range(4): ci.draw_line(p + Vector2(8 + i * 2, 4), p + Vector2(7 + i * 2.6, -1 - i % 2 * 2), Color("6f9450"), 1, true)
				if (x * 19 + y * 11) % 23 == 0:
					ci.draw_texture_rect(game.art["Blumenbeet"], Rect2(p - Vector2(24, 31), Vector2(48, 54)), false, Color(0.9, 1, 0.85, 0.7))
				if (x * 11 + y * 7) % 47 == 0:
					ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 1), p + Vector2(-6, -7), p + Vector2(2, -10), p + Vector2(10, -2), p + Vector2(6, 5)]), Color("a6ae91"))
					ci.draw_line(p + Vector2(-5, -6), p + Vector2(2, -8), Color("c6c8ac"), 2, true)
			# Soft muddy shore along the pond instead of a hard grid edge.
			for direction in Model.DIRS:
				if v.water(c + direction):
					var edge_mid := (p + cell_pos(c + direction)) * 0.5
					ci.draw_circle(edge_mid, 9.0, Color("8e9a62"))
					ci.draw_circle(edge_mid + Vector2(0, 2), 6.0, Color("a7a274"))
	# Water bed with soft rounded banks.
	for y in range(Model.SIZE.y):
		for x in range(Model.SIZE.x):
			var c := Vector2i(x, y)
			if v.water(c):
				var p := cell_pos(c)
				for direction in Model.DIRS:
					if not v.water(c + direction) and v.inside(c + direction):
						var edge_mid := (p + cell_pos(c + direction)) * 0.5
						ci.draw_circle(edge_mid.lerp(p, 0.25), 10.0, Color("78b3a6"))
	if game.grid:
		for y in range(Model.SIZE.y):
			for x in range(Model.SIZE.x):
				var d := diamond(Vector2i(x, y))
				ci.draw_polyline(d + PackedVector2Array([d[0]]), Color("375f3833"), 1, true)
	# Unlocked border: a soft line so the player sees the buildable land.
	for y in range(Model.SIZE.y):
		for x in range(Model.SIZE.x):
			var c := Vector2i(x, y)
			if v.unlocked(c):
				for i in range(4):
					var n: Vector2i = c + Model.DIRS[i]
					if v.inside(n) and not v.unlocked(n):
						var d := diamond(c)
						var a: Vector2 = d[i]
						var b: Vector2 = d[(i + 1) % 4]
						ci.draw_line(a, b, Color(1, 0.95, 0.7, 0.35), 2.0, true)
	for c in v.road_masks: _road(ci, c, true)
	for c in v.road_masks:
		if v.has_road(c + Vector2i.RIGHT) and v.has_road(c + Vector2i.DOWN) and v.has_road(c + Vector2i.ONE):
			ci.draw_colored_polygon(PackedVector2Array([cell_pos(c), cell_pos(c + Vector2i.RIGHT), cell_pos(c + Vector2i.ONE), cell_pos(c + Vector2i.DOWN)]), Color("dbc795"))
	for c in v.road_masks: _road(ci, c, false)
	# Flat crop beds belong to the ground (characters always stand on top).
	for c in v.buildings:
		var b: Dictionary = v.buildings[c]
		if b.type == "Feld": _field_bed(ci, c)

func _road(ci: CanvasItem, c: Vector2i, border: bool) -> void:
	var v = village()
	var p := cell_pos(c)
	var color := Color("a08e62") if border else Color("dbc795")
	var width := 24.0 if border else 20.0
	ci.draw_circle(p, width / 2, color)
	var bits: int = v.road_masks[c]
	for i in range(4):
		if bits & (1 << i): ci.draw_line(p, (p + cell_pos(c + Model.DIRS[i])) / 2, color, width, true)
	if not border:
		ci.draw_circle(p + Vector2(-4, 2), 1.4, Color("bdab80"))
		ci.draw_line(p + Vector2(3, -3), p + Vector2(7, -2), Color("efdfb1"), 1, true)

func _field_bed(ci: CanvasItem, c: Vector2i) -> void:
	var d := diamond(c)
	var inner := PackedVector2Array()
	var center := cell_pos(c)
	for p in d: inner.append(center + (p - center) * 0.86)
	ci.draw_colored_polygon(inner, Color("7a5a3a"))
	for i in range(4):
		var t := (i + 0.5) / 4.0
		var a: Vector2 = inner[0].lerp(inner[3], t)
		var b: Vector2 = inner[1].lerp(inner[2], t)
		ci.draw_line(a, b, Color("5f4329"), 2.0, true)
		ci.draw_line(a + Vector2(0, -1.5), b + Vector2(0, -1.5), Color("94704a"), 1.0, true)

func _paint_water(ci: CanvasItem) -> void:
	var v = village()
	for y in range(0, 11):
		for x in range(18, Model.SIZE.x):
			var c := Vector2i(x, y)
			if not v.water(c): continue
			var p := cell_pos(c)
			var wave := sin(visual_time * 1.4 + x + y) * 3
			ci.draw_line(p + Vector2(-10, wave), p + Vector2(10, wave), Color("a5d1bd88"), 1, true)
			if (x * 3 + y * 7) % 9 == 0:
				ci.draw_arc(p, 8, 0.3, 5.8, 16, Color("759951"), 3, true)
				ci.draw_circle(p + Vector2(0, -2), 2, Color("e6c3b2"))
			for direction in Model.DIRS:
				var n: Vector2i = c + direction
				if not v.water(n) and v.inside(n) and not v.occupied.has(n):
					var reed_base := (p + cell_pos(n)) * 0.5
					for i in range(3):
						var reed := reed_base + Vector2(i * 6 - 6, i % 2 * 3)
						ci.draw_line(reed, reed + Vector2(sin(visual_time + i + x) * 2, -12 - i % 2 * 5), Color("7a8b4f"), 2, true)
						ci.draw_line(reed + Vector2(0, -12), reed + Vector2(0, -17), Color("9a7850"), 3, true)

# ------------------------------------------------------------- objects

func draw_object(node: ObjectNode) -> void:
	var b: Dictionary = node.data
	var kind: String = b.type
	var origin := node.position if kind in ["Scenery", "PenFront"] else sort_point(node.cell, kind)
	# Node-local drawing: shift so that cell coordinates line up.
	var shift := -origin
	if kind == "PenFront":
		_pen_fence(node, b.kind, -node.position, true)
		return
	if Model.DEFS.has(kind) and Model.DEFS[kind].get("pen", false):
		_pen_back(node, b, shift)
		return
	match kind:
		"Scenery":
			_sprite(node, Vector2(0, -4), "Baum", Color(0.84, 0.96, 0.76), 1.0)
			return
		"Wildbaum":
			_wild_tree(node, b, shift)
			return
		"Felsen":
			_boulder(node, b, shift)
			return
	var c := node.cell
	var p := cell_pos(c) + shift
	var big: bool = Model.DEFS[kind].size.x > 1
	if kind == "Feld":
		_field_crop(node, b, p)
	else:
		var wobble := Vector2.ZERO
		if shakes.has(b.id) and kind == "Beeren": wobble = Vector2(sin(visual_time * 60.0) * 1.5, 0)
		_sprite_at(node, c, kind, shift + wobble)
	if Model.DEFS[kind].has("sign"): _emblem(node, p, Model.DEFS[kind].sign)
	if b.tier > 1:
		for i in range(b.tier):
			node.draw_circle(p + Vector2(i * 7 - 4, -112 if big else -60), 2.3, Color("ffe49b"))
	if kind == "Beeren":
		if b.progress < 1.0:
			# Bushes visibly lose their berries after picking and refill.
			var hide: float = 1.0 - b.progress
			node.draw_colored_polygon(_blob(p + Vector2(0, -26), 30, 18), Color(0.32, 0.5, 0.25, 0.55 * hide))
		else:
			node.draw_circle(p + Vector2(0, -60 + sin(visual_time * 3) * 2), 5, Color("ffedab"))
	var d: Dictionary = Model.DEFS[kind]
	if d.has("duration") and kind != "Feld":
		var at := p + Vector2(-18, 25 if big else 14)
		node.draw_line(at, at + Vector2(36, 0), Color("506749"), 4)
		node.draw_line(at, at + Vector2(36 * b.progress, 0), Color("e9d58a"), 3)
	if kind == "Angler":
		# Drying nets and a fish rack beside the hut.
		var n0 := p + Vector2(52, -6)
		node.draw_line(n0, n0 + Vector2(0, -30), Color("6b4a2a"), 2.0, true)
		node.draw_line(n0 + Vector2(22, 10), n0 + Vector2(22, -20), Color("6b4a2a"), 2.0, true)
		for i in range(5):
			node.draw_line(n0 + Vector2(0, -28 + i * 6), n0 + Vector2(22, -18 + i * 6), Color(0.85, 0.82, 0.7, 0.7), 0.8, true)
			node.draw_line(n0 + Vector2(i * 5, -28 + i * 2.5), n0 + Vector2(i * 5, -4 + i * 2.5), Color(0.85, 0.82, 0.7, 0.6), 0.8, true)
	if kind == "Lager":
		for i in range(3):
			var cr := p + Vector2(48 + i * 10, -2 - i * 4)
			node.draw_rect(Rect2(cr - Vector2(6, 10), Vector2(12, 10)), Color("a07040"))
			node.draw_rect(Rect2(cr - Vector2(6, 10), Vector2(12, 10)), Color("5a3a22"), false, 1.0)
			node.draw_line(cr - Vector2(6, 5), cr + Vector2(6, -5), Color("5a3a22"), 1.0)
	if kind in ["Baeckerei", "Kochhaus", "Gasthaus", "Raeucherei"] and b.working and b.crew > 0:
		for i in range(3):
			var phase := fmod(visual_time * 0.5 + i * 0.3, 1)
			node.draw_circle(p + Vector2(34 + sin(phase * 4) * 5, -100 - phase * 35), 4 + phase * 5, Color(0.95, 0.94, 0.85, (1 - phase) * 0.35))
	if kind == "Muehle":
		var hub := p + Vector2(-5, -78)
		var turning: bool = b.working and b.crew > 0 and not b.paused
		for i in range(4):
			var a: float = visual_time * (1.2 if turning else 0.0) + i * PI / 2
			node.draw_line(hub, hub + Vector2(cos(a), sin(a)) * 29, Color("5c6c54"), 3, true)
			node.draw_line(hub + Vector2(cos(a), sin(a)) * 12, hub + Vector2(cos(a), sin(a)) * 28, Color("efe5c6"), 8, true)
		node.draw_circle(hub, 4, Color("c7a16e"))
	if pulses.has(b.id):
		var a: float = pulses[b.id]
		node.draw_circle(p + Vector2(0, -60 - (1.0 - a) * 30), 6 + (1.0 - a) * 6, Color(1, 0.92, 0.55, a * 0.6))
	if game.show_status: _status_icon(node, b, p, big)

## In-world state markers: waiting for goods, no worker, paused, working.
func _status_icon(node: ObjectNode, b: Dictionary, p: Vector2, big: bool) -> void:
	var v = village()
	var state: String = game.building_state(b)
	var icon := ""
	var col := Color.WHITE
	match state:
		"paused": icon = "II"; col = Color("8a8f86")
		"no_worker": icon = "?"; col = Color("c0563f")
		"waiting": icon = "…"; col = Color("d39a3a")
		"blocked": icon = "!"; col = Color("c0563f")
		"done": icon = "✓"; col = Color("6c9a45")
		"full": icon = "voll"; col = Color("8a5a2a")
		"trapped": icon = "!"; col = Color("c0563f")
	if icon == "": return
	var at := p + Vector2(28 if big else 14, -128 if big else -64)
	var wide := 16.0 if icon.length() > 2 else 10.0
	node.draw_rect(Rect2(at - Vector2(wide, 10), Vector2(wide * 2, 20)), Color("fff4d9"))
	node.draw_rect(Rect2(at - Vector2(wide, 10), Vector2(wide * 2, 20)), col, false, 2.0)
	node.draw_string(ThemeDB.fallback_font, at + Vector2(-wide, 5), icon, HORIZONTAL_ALIGNMENT_CENTER, wide * 2, 12 if icon.length() > 2 else 13, col)

## Hanging sign that tells which woodling lives in a special house.
func _emblem(node: ObjectNode, p: Vector2, sign: String) -> void:
	var at := p + Vector2(-46, -40)
	node.draw_line(at + Vector2(-8, -16), at + Vector2(8, -16), Color("6b4426"), 2.0, true)
	node.draw_line(at + Vector2(0, -16), at + Vector2(0, -12), Color("6b4426"), 1.4, true)
	node.draw_circle(at, 12.5, Color("4b2f1e"))
	node.draw_circle(at, 11.0, Color("f4e2b4"))
	node.draw_circle(at + Vector2(-3, -3), 6.0, Color(1, 1, 1, 0.25))
	var ink := Color("5a3a22")
	match sign:
		"axe":
			node.draw_line(at + Vector2(-5, 6), at + Vector2(4, -5), Color("8a5a32"), 2.2, true)
			node.draw_colored_polygon(PackedVector2Array([at + Vector2(1, -7), at + Vector2(7, -4), at + Vector2(5, 1), at + Vector2(1, -2)]), Color("8d969b"))
		"sprout":
			node.draw_line(at + Vector2(0, 7), at + Vector2(0, -2), Color("5f8a3a"), 2.0, true)
			node.draw_colored_polygon(_blob(at + Vector2(-4, -3), 4.5, 2.6), Color("7fb04a"))
			node.draw_colored_polygon(_blob(at + Vector2(4, -5), 4.5, 2.6), Color("8fc057"))
		"pick":
			node.draw_line(at + Vector2(-5, 6), at + Vector2(4, -4), Color("8a5a32"), 2.2, true)
			node.draw_arc(at + Vector2(3, -3), 7.0, PI * 1.05, PI * 1.95, 8, Color("7a8287"), 2.4, true)
		"hammer":
			node.draw_line(at + Vector2(-4, 7), at + Vector2(3, -3), Color("8a5a32"), 2.2, true)
			node.draw_rect(Rect2(at + Vector2(-1, -8), Vector2(9, 5)), Color("7a8287"))
		"bread":
			node.draw_colored_polygon(_blob(at + Vector2(0, 1), 8.0, 5.0), Color("c98a43"))
			for i in range(3): node.draw_line(at + Vector2(-4 + i * 4, -2), at + Vector2(-2 + i * 4, 3), Color("ecc890"), 1.2, true)
		"bee":
			node.draw_colored_polygon(_blob(at, 6.0, 4.2), Color("e3b02f"))
			node.draw_line(at + Vector2(-1, -4), at + Vector2(-1, 4), ink, 1.6)
			node.draw_line(at + Vector2(3, -3.5), at + Vector2(3, 3.5), ink, 1.6)
			node.draw_colored_polygon(_blob(at + Vector2(-2, -6), 3.0, 2.0), Color(1, 1, 1, 0.8))
		"leaf":
			node.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -8), at + Vector2(6, 0), at + Vector2(0, 8), at + Vector2(-6, 0)]), Color("6f9a5a"))
			node.draw_line(at + Vector2(0, -7), at + Vector2(0, 7), Color("b8d49a"), 1.0, true)
		"fish":
			node.draw_colored_polygon(PackedVector2Array([at + Vector2(-7, 0), at + Vector2(0, -4), at + Vector2(5, 0), at + Vector2(0, 4)]), Color("7f9fb8"))
			node.draw_colored_polygon(PackedVector2Array([at + Vector2(4, 0), at + Vector2(8, -4), at + Vector2(8, 4)]), Color("6f8a9c"))
			node.draw_circle(at + Vector2(-4, -1), 0.9, ink)
		"crate":
			node.draw_rect(Rect2(at - Vector2(6, 5), Vector2(12, 10)), Color("a07040"))
			node.draw_rect(Rect2(at - Vector2(6, 5), Vector2(12, 10)), ink, false, 1.2)
			node.draw_line(at + Vector2(-6, -5), at + Vector2(6, 5), ink, 1.0)
		"smoke":
			node.draw_colored_polygon(PackedVector2Array([at + Vector2(-6, 3), at + Vector2(0, 0), at + Vector2(5, 3), at + Vector2(0, 6)]), Color("b98a5a"))
			for i in range(3): node.draw_circle(at + Vector2(-2 + i * 3, -3 - i * 2), 2.0 + i * 0.6, Color(0.6, 0.6, 0.6, 0.8))
		"cheese":
			node.draw_colored_polygon(PackedVector2Array([at + Vector2(-7, 4), at + Vector2(7, 4), at + Vector2(5, -4), at + Vector2(-3, -6)]), Color("f0c84a"))
			for q in [Vector2(-2, 0), Vector2(3, 1), Vector2(0, -3)]: node.draw_circle(at + q, 1.1, Color("c99a2a"))
		"coin":
			node.draw_circle(at, 7.0, Color("d9aa2f"))
			node.draw_circle(at, 5.0, Color("efc94f"))
			node.draw_line(at + Vector2(0, -3), at + Vector2(0, 3), Color("a87a1a"), 1.6)

## Enclosure: pasture ground, back fence, little shelter and a hay rack.
func _pen_back(node: ObjectNode, b: Dictionary, shift: Vector2) -> void:
	var c := node.cell
	var size: Vector2i = Model.DEFS[b.type].size
	var d := diamond(c, size)
	var center := (d[0] + d[2]) * 0.5
	var inner := PackedVector2Array()
	for p in d: inner.append(center + (p - center) * 0.94 + shift)
	var ground := Color("c9b77a") if b.type == "Huehnerhof" else Color("86a85a")
	node.draw_colored_polygon(inner, ground)
	var seed: int = b.id * 31
	for i in range(14):
		var t := Vector2(fmod(sin(seed + i * 1.7) * 43758.5, 1.0), fmod(sin(seed + i * 2.3) * 24634.6, 1.0)).abs()
		var p: Vector2 = inner[0].lerp(inner[1], t.x).lerp(inner[3].lerp(inner[2], t.x), t.y)
		node.draw_circle(p, 3.0, ground.darkened(0.12) if i % 2 else ground.lightened(0.1))
	_pen_fence(node, b.type, shift, false)
	# Shelter in the back corner.
	var top: Vector2 = d[0] + shift + Vector2(0, 26)
	var wall := PackedVector2Array([top + Vector2(-22, 0), top + Vector2(22, 0), top + Vector2(22, -18), top + Vector2(-22, -18)])
	node.draw_colored_polygon(wall, Color("9a6a3c"))
	node.draw_polyline(wall + PackedVector2Array([wall[0]]), Color("4b2f1e"), 1.2, true)
	node.draw_rect(Rect2(top + Vector2(-6, -12), Vector2(12, 12)), Color("4a3020"))
	var roof := PackedVector2Array([top + Vector2(-27, -16), top + Vector2(27, -16), top + Vector2(18, -30), top + Vector2(-18, -30)])
	node.draw_colored_polygon(roof, Color("7a8a4a") if b.type != "Huehnerhof" else Color("b0703a"))
	node.draw_polyline(roof + PackedVector2Array([roof[0]]), Color("4b2f1e"), 1.2, true)
	# Hay / feed.
	var hay := top + Vector2(30, 10)
	node.draw_colored_polygon(_blob(hay, 10, 6), Color("e2c76a"))
	for i in range(4): node.draw_line(hay + Vector2(-7 + i * 4, 2), hay + Vector2(-5 + i * 4, -5), Color("c9a84a"), 1.0, true)
	node.rect = Rect2(d[3] + shift + node.position + Vector2(0, -60), Vector2(d[1].x - d[3].x, d[2].y - d[0].y + 60))
	if pulses.has(b.id):
		var a: float = pulses[b.id]
		node.draw_circle(center + shift + Vector2(0, -30 - (1.0 - a) * 30), 6 + (1.0 - a) * 6, Color(1, 0.92, 0.55, a * 0.6))
	if game.show_status: _status_icon(node, b, d[0] + shift + Vector2(0, 90), true)
	if b.tier > 1:
		for i in range(b.tier): node.draw_circle(d[0] + shift + Vector2(i * 7 - 4, -6), 2.3, Color("ffe49b"))

## Wooden fence along the back (left/top/right) or front edges.
func _pen_fence(node: ObjectNode, kind: String, shift: Vector2, front: bool) -> void:
	var c := node.cell
	var size: Vector2i = Model.DEFS[kind].size
	var d := diamond(c, size)
	var edges: Array = [[d[1], d[2]], [d[2], d[3]]] if front else [[d[3], d[0]], [d[0], d[1]]]
	var wood := Color("8a5a32")
	for e in edges:
		var a: Vector2 = e[0] + shift
		var b: Vector2 = e[1] + shift
		for rail in [8.0, 15.0]:
			node.draw_line(a + Vector2(0, -rail), b + Vector2(0, -rail), Color("4b2f1e"), 3.0, true)
			node.draw_line(a + Vector2(0, -rail), b + Vector2(0, -rail), wood.lightened(0.15), 1.8, true)
		var posts := size.x * 2
		for i in range(posts + 1):
			var p := a.lerp(b, float(i) / posts)
			node.draw_line(p, p + Vector2(0, -19), Color("4b2f1e"), 4.0, true)
			node.draw_line(p, p + Vector2(0, -19), wood, 2.6, true)
	if front:
		node.rect = Rect2(d[3] + shift + node.position + Vector2(0, -20), Vector2(d[1].x - d[3].x, 40))

## 0 by day, 1 at night, smooth at dusk (18-20 h) and dawn (5-7 h).
static func night_factor(hour: float) -> float:
	if hour >= 20.0 or hour < 5.0: return 1.0
	if hour >= 18.0: return (hour - 18.0) / 2.0
	if hour < 7.0: return 1.0 - (hour - 5.0) / 2.0
	return 0.0

func art_key(kind: String) -> String:
	var d: Dictionary = Model.DEFS.get(kind, {})
	return d.get("art", kind)

func _glow(ci: CanvasItem, at: Vector2, radius: float, col: Color, strength: float) -> void:
	for i in range(6):
		var t := float(i) / 6.0
		ci.draw_circle(at, radius * (1.0 - t * 0.82), Color(col.r, col.g, col.b, strength * (0.05 + t * 0.07)))

## Additive light: lit windows, lanterns, glowing ovens, woodlings' little
## lamps on night walks and fireflies.
func _paint_lights(ci: CanvasItem) -> void:
	if night < 0.02: return
	var v = village()
	var flicker := 0.92 + 0.08 * sin(visual_time * 7.3)
	var warm := Color(1.0, 0.72, 0.32)
	for node in building_nodes.values():
		if node.rect.size.x <= 0 or node.modulate.a < 0.5: continue
		var key := art_key(node.data.type)
		if not Model.WINDOW_LIGHTS.has(key): continue
		var lantern := key == "Laterne"
		for uv in Model.WINDOW_LIGHTS[key]:
			var at: Vector2 = node.rect.position + uv * node.rect.size
			var phase: float = sin(visual_time * 2.1 + at.x * 0.05) * 0.06
			if lantern:
				_glow(ci, at, 46.0, warm, night * flicker)
				ci.draw_set_transform(at + Vector2(0, 46), 0, Vector2(1, 0.45))
				_glow(ci, Vector2.ZERO, 60.0, warm, night * 0.7)
				ci.draw_set_transform(Vector2.ZERO)
			else:
				_glow(ci, at, 20.0, warm, night * (0.9 + phase))
				ci.draw_circle(at, 3.2, Color(1.0, 0.85, 0.5, 0.55 * night))
	for view in resident_nodes.values():
		if view.visible and view.resident.anim in ["walk", "carry_walk"]:
			_glow(ci, view.position + Vector2(8, -30), 22.0, warm, night * 0.55)
	for i in range(fireflies.size()):
		var base: Vector2 = fireflies[i]
		var p := base + Vector2(sin(visual_time * 0.33 + i) * 30, cos(visual_time * 0.47 + i * 1.3) * 16)
		var blink := maxf(0.0, sin(visual_time * 1.6 + i * 2.1))
		if blink <= 0.05: continue
		ci.draw_circle(p, 5.0, Color(0.75, 1.0, 0.35, 0.12 * blink * night))
		ci.draw_circle(p, 1.8, Color(0.95, 1.0, 0.6, 0.8 * blink * night))

## Little hearts when the player says hello to an animal.
func hearts(at: Vector2) -> void:
	for i in range(4):
		particles.append({"pos": at + Vector2(randf_range(-8, 8), -24), "vel": Vector2(randf_range(-8, 8), -22), "t": 0.0, "life": 1.3, "col": Color("e8606a"), "size": 2.6, "grav": 0.0, "game": false, "heart": true})

func _blob(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(14):
		var a := float(i) / 14.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _sprite_size(kind: String) -> Vector2:
	var big: bool = Model.DEFS[kind].size.x > 1
	var size := Vector2(176, 176) if big else Vector2(95, 95)
	if kind == "Baum": size = Vector2(145, 155)
	if kind == "Laterne": size = Vector2(76, 100)
	return size

func _sprite_at(node: ObjectNode, c: Vector2i, kind: String, shift: Vector2, tint := Color.WHITE, scale := 1.0) -> void:
	var big: bool = Model.DEFS[kind].size.x > 1
	var size := _sprite_size(kind) * scale
	var p := cell_pos(c) + Vector2(0, 24 if big else 3) + shift
	var rect := Rect2(p - Vector2(size.x / 2, size.y - 17 * scale), size)
	node.draw_texture_rect(game.art[kind], rect, false, tint)
	node.rect = Rect2(rect.position + node.position, rect.size)
	node.pick_tex = game.art[kind]

func _sprite(node: ObjectNode, at: Vector2, kind: String, tint: Color, scale: float) -> void:
	var size := _sprite_size(kind) * scale
	var rect := Rect2(at - Vector2(size.x / 2, size.y - 17 * scale), size)
	node.draw_texture_rect(game.art[kind], rect, false, tint)
	node.rect = Rect2(rect.position + node.position, rect.size)

func _wild_tree(node: ObjectNode, b: Dictionary, shift: Vector2) -> void:
	var p := cell_pos(node.cell) + shift + Vector2(0, 3)
	var variant: int = (b.id * 7919) % 5
	var tint: Color = [Color(0.86, 1.0, 0.82), Color(0.8, 0.95, 0.78), Color(0.92, 1.0, 0.86), Color(0.84, 0.98, 0.9), Color(0.95, 0.98, 0.8)][variant]
	var grown: bool = b.stock > 0
	var growth: float = 1.0 if grown else float(b.progress)
	# Stump stays visible under young trees: sustainable forestry made visible.
	if not grown:
		node.draw_set_transform(p, 0, Vector2(1, 0.5))
		node.draw_circle(Vector2.ZERO, 10.0, Color(0.2, 0.25, 0.15, 0.25))
		node.draw_set_transform(Vector2.ZERO)
		var stump := p + Vector2(-9, -2)
		node.draw_rect(Rect2(stump + Vector2(-5, -8), Vector2(10, 8)), Color("6e4a2c"))
		node.draw_set_transform(stump + Vector2(0, -8), 0, Vector2(1, 0.5))
		node.draw_circle(Vector2.ZERO, 5.0, Color("4b2f1e"))
		node.draw_circle(Vector2.ZERO, 4.2, Color("d9b47a"))
		node.draw_arc(Vector2.ZERO, 2.4, 0, TAU, 12, Color("b88d58"), 0.8, true)
		node.draw_set_transform(Vector2.ZERO)
	var shake := 0.0
	if shakes.has(b.id): shake = sin(visual_time * 55.0) * shakes[b.id] * 6.0
	if growth < 0.15:
		# Fresh sapling.
		var s := p + Vector2(6, 0)
		node.draw_line(s, s + Vector2(0, -12), Color("6b4a2a"), 2.0, true)
		node.draw_colored_polygon(_blob(s + Vector2(-3, -12), 4.0, 2.6), Color("8fbf4f"))
		node.draw_colored_polygon(_blob(s + Vector2(3, -14), 4.0, 2.6), Color("79ab43"))
		node.rect = Rect2(node.position + s - Vector2(8, 20), Vector2(16, 20))
		return
	var scale := 1.0 if grown else lerpf(0.32, 0.85, (growth - 0.15) / 0.85)
	var size := Vector2(145, 155) * scale * (0.92 + variant * 0.04)
	var rect := Rect2(p - Vector2(size.x / 2, size.y - 17 * scale), size)
	if shake != 0.0:
		node.draw_set_transform(p, shake * 0.01, Vector2.ONE)
		rect.position -= p
	node.draw_texture_rect(game.art["Baum"], rect, false, tint)
	node.draw_set_transform(Vector2.ZERO)
	node.rect = Rect2(p - Vector2(size.x / 2, size.y - 17 * scale) + node.position, size)
	if grown and b.stock < 3:
		# Lighter canopy after each load: the tree is being worked.
		for i in range(3 - int(b.stock)):
			node.draw_line(p + Vector2(-4 + i * 4, -6), p + Vector2(-2 + i * 4, -14), Color("e4c48e"), 2.0, true)

func _boulder(node: ObjectNode, b: Dictionary, shift: Vector2) -> void:
	var p := cell_pos(node.cell) + shift + Vector2(0, 4)
	var amount: float = float(b.stock) / 6.0
	var size: float = lerpf(0.45, 1.0, amount)
	var off := Vector2.ZERO
	if shakes.has(b.id): off = Vector2(sin(visual_time * 70.0) * 1.2, 0)
	p += off
	node.draw_set_transform(p, 0, Vector2(1, 0.5))
	node.draw_circle(Vector2.ZERO, 26.0 * size, Color(0.2, 0.25, 0.15, 0.28))
	node.draw_set_transform(Vector2.ZERO)
	var seed: int = b.id * 13
	var pts := PackedVector2Array()
	for i in range(11):
		var a := PI + float(i) / 10.0 * PI
		var rr := 1.0 + 0.12 * sin(a * 3.0 + seed)
		pts.append(p + Vector2(cos(a) * 25.0 * rr, sin(a) * 30.0 * rr) * size)
	pts.append(p + Vector2(22, 6) * size)
	pts.append(p + Vector2(-22, 6) * size)
	var cols := PackedColorArray()
	for i in range(pts.size()):
		cols.append(Color("a8aca2") if pts[i].x < p.x else Color("858a80"))
	node.draw_polygon(pts, cols)
	var outline := pts.duplicate()
	outline.append(pts[0])
	node.draw_polyline(outline, Color("4b4a3e"), 1.4, true)
	node.draw_line(p + Vector2(-6, -18) * size, p + Vector2(4, -8) * size, Color("6f7468"), 1.4, true)
	node.draw_line(p + Vector2(8, -22) * size, p + Vector2(14, -12) * size, Color("6f7468"), 1.2, true)
	node.draw_colored_polygon(_blob(p + Vector2(-8, -24) * size, 10 * size, 4 * size), Color("7fa04a"))
	node.draw_circle(p + Vector2(-12, -14) * size, 4 * size, Color(1, 1, 1, 0.12))
	if amount < 0.5:
		for i in range(5):
			node.draw_circle(p + Vector2(-20 + i * 9, 6 + (i % 2) * 3), 3.0, Color("9a9e94"))
	node.rect = Rect2(p - Vector2(26, 36) * size + node.position, Vector2(52, 40) * size)

## Bed with its crop: every variety has its own plants, growing in four
## stages. Overripe beds droop and turn brownish (half harvest).
func _field_crop(node: ObjectNode, b: Dictionary, p: Vector2) -> void:
	var v = village()
	node.rect = Rect2(p - Vector2(36, 34) + node.position, Vector2(72, 44))
	if not b.sown:
		for i in range(5):
			node.draw_circle(p + Vector2(-14 + i * 7, -2 + (i % 2) * 3), 1.2, Color("a98256"))
		return
	var crop: String = b.get("crop", "korn")
	var stage := mini(3, int(b.progress * 4))
	var old: bool = v.overripe(b)
	var sway := sin(visual_time * 1.6 + node.cell.x) * 1.2
	if shakes.has(b.id): sway += sin(visual_time * 45.0) * 2.0
	var leaf := Color("6f9a46") if not old else Color("8f8a4a")
	for row in range(3):
		for col in range(4):
			var base := p + Vector2((col - row) * 8 - 3, (col + row) * 4 - 8)
			var g := 0.35 + 0.65 * float(stage) / 3.0
			match crop:
				"korn", "flachs":
					var h := 3.0 + stage * 4.0
					var color := Color("e7c169") if stage >= 3 else (Color("b9c25a") if stage == 2 else Color("64874b"))
					if crop == "flachs" and stage >= 2: color = Color("7f9a5a")
					if old: color = Color("b39a5a")
					var top := base + Vector2(sway, -h)
					node.draw_line(base, top, color.darkened(0.15), 2, true)
					node.draw_line(base + Vector2(0, -h / 2), base + Vector2(-3, -h / 2 - 3), color, 1.5, true)
					if stage >= 2:
						var head := Color("7f9fd8") if crop == "flachs" and stage == 3 else color
						node.draw_circle(top, 2.2 if stage == 3 else 1.6, head)
				"karotten", "zwiebeln", "kartoffeln":
					var n := 3 + stage
					for i in range(n):
						var ang := -PI * 0.5 + (i - n * 0.5) * 0.35
						var len := (3.0 + stage * 2.5) * (0.8 if crop == "kartoffeln" else 1.0)
						var tip := base + Vector2(cos(ang) * len * 0.6 + sway * 0.5, sin(ang) * len)
						node.draw_line(base, tip, leaf if crop != "zwiebeln" else Color("7fa65a"), 1.2, true)
					if crop == "karotten" and stage == 3: node.draw_circle(base + Vector2(0, 1), 1.8, Color("e98a2e"))
					if crop == "zwiebeln" and stage >= 2: node.draw_circle(base + Vector2(0, 0.5), 1.4 + stage * 0.4, Color("d9a35a"))
					if crop == "kartoffeln" and stage >= 2: node.draw_circle(base + Vector2(1, -5 - stage), 1.0, Color("f2eee0"))
				"kohl":
					var r := 1.5 + 3.0 * g
					node.draw_circle(base + Vector2(0, -r * 0.6), r, Color("6f9a7a") if not old else Color("9a9a6a"))
					node.draw_circle(base + Vector2(-0.6, -r * 0.8), r * 0.6, Color("a9c9a0"))
				"kuerbis":
					if row == 1 and col in [1, 2]:
						var r2 := 1.5 + 4.0 * g
						var c2 := Color("e5782a") if stage >= 2 else Color("8aa04a")
						if old: c2 = Color("b56a3a")
						node.draw_circle(base + Vector2(0, -r2 * 0.5), r2, c2)
						node.draw_line(base + Vector2(0, -r2 * 1.4), base + Vector2(1, -r2 * 1.9), Color("6b4a2a"), 1.2, true)
					else:
						node.draw_circle(base + Vector2(sway * 0.3, -2), 1.6 + g * 1.5, leaf)
				"sonnenblumen":
					if (row + col) % 2 == 0:
						var h2 := 4.0 + stage * 7.0
						var top2 := base + Vector2(sway, -h2)
						node.draw_line(base, top2, Color("5f8a3a"), 1.8, true)
						if stage >= 2:
							node.draw_circle(top2, 3.2, Color("f2c330") if not old else Color("b9963a"))
							node.draw_circle(top2, 1.4, Color("6b4426"))
	if b.get("tended", false) and stage < 3:
		node.draw_circle(p + Vector2(18, 2), 2.0, Color(0.6, 0.8, 0.95, 0.6))
	if b.progress >= 1.0:
		var tint := Color("ffedab") if not old else Color("d9a06a")
		node.draw_circle(p + Vector2(0, -36 + sin(visual_time * 3) * 2), 5, tint)

# ------------------------------------------------------------- overlay

func _paint_overlay(ci: CanvasItem) -> void:
	var v = village()
	var hover: Vector2i = game.hover
	if v.inside(hover) and game.mode in ["Bauen", "Bewegen"]:
		var kind: String = v.buildings[game.moving].type if v.buildings.has(game.moving) else game.selected
		var valid: bool = v.can_place(hover, kind, game.moving) and (game.mode == "Bewegen" or v.placement_issue(hover, kind) == "")
		var color := Color("b5e8a080") if valid else Color("e7867588")
		ci.draw_colored_polygon(diamond(hover, Model.DEFS[kind].size), color)
		if not valid and game.mode == "Bauen":
			# Say why, right at the cursor.
			var why: String = v.placement_issue(hover, kind)
			if why != "":
				var at := cell_pos(hover) + Vector2(-90, 34)
				ci.draw_rect(Rect2(at - Vector2(4, 15), Vector2(188, 21)), Color(1, 0.96, 0.85, 0.92))
				ci.draw_string(ThemeDB.fallback_font, at, why, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color("8a2f25"))
		if kind != "Weg" and game.art.has(kind):
			var big: bool = Model.DEFS[kind].size.x > 1
			var size := _sprite_size(kind)
			var p := cell_pos(hover) + Vector2(0, 24 if big else 3)
			ci.draw_texture_rect(game.art[kind], Rect2(p - Vector2(size.x / 2, size.y - 17), size), false, Color(1, 1, 1, 0.55))
	if v.buildings.has(game.inspected):
		var poly := diamond(game.inspected, Model.DEFS[v.buildings[game.inspected].type].size)
		ci.draw_polyline(poly + PackedVector2Array([poly[0]]), Color("fff1b2"), 2, true)
		# Work radius of foresters and stone collectors.
		var b: Dictionary = v.buildings[game.inspected]
		if b.type in ["Forsthaus", "Steinbruch"]:
			var center := grid_to_screen(Vector2(game.inspected) + Vector2(0.5, 0.5))
			ci.draw_set_transform(center, 0, Vector2(1, 0.5))
			ci.draw_arc(Vector2.ZERO, 8.0 * 50.9, 0, TAU, 64, Color(1, 0.95, 0.7, 0.45), 2.0, true)
			ci.draw_set_transform(Vector2.ZERO)
	for p in particles:
		var a: float = 1.0 - p.t / p.life
		if p.has("text"):
			ci.draw_string(ThemeDB.fallback_font, p.pos + Vector2(-40, 0), p.text, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(1, 0.97, 0.82, a))
			continue
		var col: Color = p.col
		if p.get("dust", false):
			ci.draw_circle(p.pos, p.size * (1.0 + p.t * 2.5), Color(col.r, col.g, col.b, col.a * a))
		elif p.get("leaf", false):
			var wob := sin(p.t * 6.0) * 6.0
			ci.draw_colored_polygon(PackedVector2Array([p.pos + Vector2(wob, 0), p.pos + Vector2(wob + 3, 1.5), p.pos + Vector2(wob, 3), p.pos + Vector2(wob - 3, 1.5)]), Color(col.r, col.g, col.b, a))
		elif p.get("heart", false):
			var hp: Vector2 = p.pos
			ci.draw_circle(hp + Vector2(-1.4, 0), 1.8, Color(col.r, col.g, col.b, a))
			ci.draw_circle(hp + Vector2(1.4, 0), 1.8, Color(col.r, col.g, col.b, a))
			ci.draw_colored_polygon(PackedVector2Array([hp + Vector2(-3.1, 0.6), hp + Vector2(3.1, 0.6), hp + Vector2(0, 4.0)]), Color(col.r, col.g, col.b, a))
		elif p.get("ring", false):
			if p.t < 0.0: continue
			ci.draw_set_transform(p.pos, 0, Vector2(1, 0.45))
			ci.draw_arc(Vector2.ZERO, 3.0 + p.t * 16.0, 0, TAU, 20, Color(col.r, col.g, col.b, a * 0.8), 1.2, true)
			ci.draw_set_transform(Vector2.ZERO)
		elif p.get("flake", false):
			var drift: float = sin(p.t * 1.7 + p.size * 3.0) * 8.0
			ci.draw_circle(p.pos + Vector2(drift, 0), p.size, Color(1, 1, 1, 0.85 * minf(1.0, a * 3.0)))
		elif p.get("butterfly", false):
			var flap: float = absf(sin(p.t * 16.0)) * 3.0
			var bp: Vector2 = p.pos + Vector2(sin(p.t * 2.0) * 10.0, cos(p.t * 2.6) * 6.0)
			ci.draw_colored_polygon(PackedVector2Array([bp, bp + Vector2(-flap - 1, -2.5), bp + Vector2(-flap, 1.5)]), col)
			ci.draw_colored_polygon(PackedVector2Array([bp, bp + Vector2(flap + 1, -2.5), bp + Vector2(flap, 1.5)]), col)
		elif p.get("bee", false):
			var bp: Vector2 = p.pos + Vector2(sin(p.t * 14.0) * 4.0, cos(p.t * 11.0) * 3.0)
			ci.draw_circle(bp, p.size, col)
			ci.draw_circle(bp + Vector2(-1, -1.5), 1.0, Color(1, 1, 1, 0.6))
		else:
			ci.draw_rect(Rect2(p.pos - Vector2(p.size, p.size) * 0.5, Vector2(p.size, p.size * 0.7)), Color(col.r, col.g, col.b, col.a * minf(1.0, a * 1.5)))
	if night > 0.01:
		# Dusk and night: a deep blue veil; the lights layer glows on top.
		var veil := night * (0.22 if game.dark else 0.5)
		ci.draw_rect(Rect2(Vector2(-2600, -1400), Vector2(5800, 5000)), Color(0.03, 0.06, 0.2, veil))
	if night < 0.5:
		for i in range(4):
			var bird := Vector2(fmod(visual_time * 18 + i * 370, 1600) - 800, 200 + i * 180 + sin(visual_time + i) * 12)
			var flap := sin(visual_time * 6 + i) * 4
			ci.draw_polyline(PackedVector2Array([bird + Vector2(-7, -flap), bird, bird + Vector2(7, -flap)]), Color("52694088"), 1.7, true)

## Building under the mouse, judged by its painted picture (roof, walls,
## tree crown) rather than only the ground cell. Front-most wins.
func building_at(world_pos: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_y := -INF
	for node in building_nodes.values():
		if node.rect.size.x <= 0 or not node.rect.has_point(world_pos) or node.position.y <= best_y: continue
		if node.pick_tex != null and not _opaque(node.pick_tex, node.rect, world_pos): continue
		best_y = node.position.y
		best = node.cell
	return best

var _pick_images: Dictionary = {}

## Pixel-exact hit test against the painted picture (alpha > 0.3).
func _opaque(tex: Texture2D, rect: Rect2, world_pos: Vector2) -> bool:
	var uv := (world_pos - rect.position) / rect.size
	var region := Rect2(Vector2.ZERO, tex.get_size())
	var source: Texture2D = tex
	if tex is AtlasTexture:
		region = tex.region
		source = tex.atlas
	if not _pick_images.has(source):
		var img: Image = source.get_image()
		if img == null: return true
		if img.is_compressed(): img.decompress()
		_pick_images[source] = img
	var image: Image = _pick_images[source]
	var px := Vector2i(region.position + uv * region.size)
	if px.x < 0 or px.y < 0 or px.x >= image.get_width() or px.y >= image.get_height(): return false
	return image.get_pixelv(px).a > 0.3

## Resident under the mouse (feet within the figure's silhouette).
func resident_at(world_pos: Vector2) -> int:
	var best := -1
	var best_d := 26.0
	for view in resident_nodes.values():
		if not view.visible: continue
		var feet: Vector2 = view.position
		var center := feet + Vector2(0, -30)
		var d := Vector2((world_pos.x - center.x), (world_pos.y - center.y) * 0.6).length()
		if d < best_d:
			best_d = d
			best = view.resident.id
	return best
