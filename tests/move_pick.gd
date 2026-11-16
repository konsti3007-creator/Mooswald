extends SceneTree
## Diagnosis loop: move buildings through real mouse events.
const Game = preload("res://main.tscn")

func click(game, button: int, world_pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = game.get_canvas_transform() * world_pos
	game._unhandled_input(e)
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = e.position
	game._unhandled_input(up)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Game.instantiate()
	root.add_child(game)
	await process_frame
	game.tips.hide()
	game.village.speed = 0
	game.world.update(0.016, 0.0)
	await process_frame
	var v = game.village
	var tried := {}
	var ok := 0
	var bad := 0
	for c in v.buildings.keys():
		if not v.buildings.has(c): continue
		var b: Dictionary = v.buildings[c]
		if tried.has(b.type) or b.type == "Weg": continue
		tried[b.type] = true
		var size: Vector2i = v.DEFS[b.type].size
		# free target nearby
		var target := Vector2i(-1, -1)
		for r in range(2, 12):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var t: Vector2i = c + Vector2i(dx, dy)
					if target.x < 0 and v.can_place(t, b.type, c) and t != c: target = t
		if target.x < 0: continue
		game.mode = "Bewegen"
		game.moving = Vector2i(-1, -1)
		# click on the ground cell of the building (as a player would on its picture)
		var node = game.world.building_nodes.get(b.id)
		var at: Vector2 = node.rect.get_center() if node != null and node.rect.size.x > 0 else game.cell_pos(c + size / 2)
		click(game, MOUSE_BUTTON_LEFT, at)
		if game.moving != c:
			game.moving = Vector2i(-1, -1)
			continue  # another picture is in front here: correct to pick that one
		var picked: Vector2i = game.moving
		click(game, MOUSE_BUTTON_LEFT, game.cell_pos(target))
		var moved: bool = v.buildings.has(target) and v.buildings[target].type == b.type and not v.buildings.has(c) or (target == c)
		if moved: ok += 1
		else:
			bad += 1
			print("MOVE FAIL ", b.type, " from ", c, " picked ", picked, " target ", target, " notice: ", v.notice)
		game.world.update(0.016, 0.0)
		await process_frame
	print("MOVE RESULT ok=", ok, " bad=", bad)
	# Roof clicks over occupied ground (needs real rendering for picture rects).
	for k in range(5): await process_frame
	var roof_ok := 0
	var roof_bad := 0
	for c in v.buildings.keys():
		if not v.buildings.has(c): continue
		var b: Dictionary = v.buildings[c]
		if not v.DEFS[b.type].size.x > 1 or v.DEFS[b.type].get("pen", false): continue
		var node = game.world.building_nodes.get(b.id)
		if node == null or node.rect.size.x <= 0: continue
		for dy in range(20, 80, 6):
			var roof: Vector2 = node.rect.position + Vector2(node.rect.size.x * 0.5, dy)
			var under: Vector2i = game.world_cell(roof)
			if node.pick_tex != null and not game.world._opaque(node.pick_tex, node.rect, roof): continue
			if v.occupied.has(under) and v.anchor(under) != c and v.buildings[v.anchor(under)].type != "Weg":
				game.mode = "Bewegen"
				game.moving = Vector2i(-1, -1)
				click(game, MOUSE_BUTTON_LEFT, roof)
				var front = game.world.building_nodes.get(v.buildings.get(game.moving, {}).get("id", -1))
				var occluded: bool = front != null and front.position.y > node.position.y and (front.pick_tex == null or game.world._opaque(front.pick_tex, front.rect, roof))
				if game.moving == c or occluded: roof_ok += 1
				else:
					roof_bad += 1
					print("ROOF PICK FAIL ", b.type, " at ", c, " got ", game.moving, " (", v.buildings.get(game.moving, {}).get("type", "-"), ")")
				game.mode = "Info"
				game.moving = Vector2i(-1, -1)
				break
	print("ROOF RESULT ok=", roof_ok, " bad=", roof_bad)
	quit()
