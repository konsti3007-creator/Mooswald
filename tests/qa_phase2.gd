extends "res://scripts/game.gd"
## Visual QA for phase 2: crop varieties, angler, storage barn, smokehouse.

func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	await get_tree().process_frame
	tips.hide()
	village = Model.new()
	village.seed()
	village.elapsed = Model.SEASON_LENGTH + 30.0  # summer
	village.xp = Model.xp_for_level(7)
	village.resources.muenzen = 3000
	village.resources.bretter = 200
	village.resources.stein = 200
	village.resources.holz = 100
	village.resources.fisch = 30
	for row in [[Vector2i(19,13),"Haus"],[Vector2i(16,14),"Haus"],[Vector2i(25,12),"Angler"],[Vector2i(21,16),"Raeucherei"],[Vector2i(8,15),"Lager"]]:
		village.place(row[0], row[1])
	var crops := Model.CROPS.keys()
	for i in range(crops.size()):
		var c := Vector2i(9 + i, 18)
		village.insert(c, "Feld", [1.0, 0.8, 0.55, 0.3][i % 4])
		village.buildings[c].crop = crops[i]
	for x in range(8, 24): village.place(Vector2i(x, 13), "Weg")
	world.rebuild()
	village.tick(20.0)
	world.rebuild()
	for panel in layout_panels.values(): panel.visible = false
	camera.position = cell_pos(Vector2i(15, 14))
	camera.zoom = Vector2.ONE * 0.85
	for k in range(60): await get_tree().process_frame
	_shot("p2_overview")
	camera.position = world.grid_to_screen(Vector2(12.5, 18.0)) + Vector2(0, -20)
	camera.zoom = Vector2.ONE * 2.2
	for k in range(20): await get_tree().process_frame
	_shot("p2_beds")
	village.elapsed = Model.SEASON_LENGTH * 2 + 30.0
	for k in range(30): await get_tree().process_frame
	_shot("p2_beds_autumn")
	village.elapsed = Model.SEASON_LENGTH + 60.0
	var wanted := ["cast", "fish_wait", "reel"]
	var guard := 0
	while not wanted.is_empty() and guard < 3000:
		guard += 1
		village.tick(0.05)
		await get_tree().process_frame
		for r in village.residents:
			if r.anim in wanted:
				camera.position = world.grid_to_screen(Vector2(r.x, r.y) + Vector2(0.4, -0.4)) + Vector2(0, -24)
				camera.zoom = Vector2.ONE * 2.4
				await get_tree().process_frame
				await get_tree().process_frame
				_shot("p2_" + r.anim)
				wanted.erase(r.anim)
				break
	print("phase2 captures done, missing: ", wanted)
	get_tree().quit()

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://build/qa/%s.png" % name)
