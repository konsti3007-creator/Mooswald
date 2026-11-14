extends "res://scripts/game.gd"
## Visual QA for phase 3: enclosures, herd animals, shepherds, wild animals.

func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	await get_tree().process_frame
	tips.hide()
	village = Model.new()
	village.seed()
	village.elapsed = Model.SEASON_LENGTH + 30.0
	village.xp = Model.xp_for_level(9)
	village.resources.muenzen = 3000
	village.resources.bretter = 100
	village.resources.stein = 100
	village.resources.holz = 300
	village.resources.getreide = 100
	for row in [[Vector2i(7,14),"Haus"],[Vector2i(16,14),"Haus"],[Vector2i(19,13),"Haus"],[Vector2i(9,16),"Huehnerhof"],[Vector2i(13,16),"Schafweide"],[Vector2i(17,19),"Ziegenstall"],[Vector2i(21,16),"Kaeserei"]]:
		if not village.place(row[0], row[1]): print("could not place ", row, " ", village.notice)
	for x in range(8, 24): village.place(Vector2i(x, 13), "Weg")
	world.rebuild()
	village.tick(30.0)
	for panel in layout_panels.values(): panel.visible = false
	camera.position = cell_pos(Vector2i(15, 15))
	camera.zoom = Vector2.ONE * 0.95
	for k in range(240): await get_tree().process_frame
	_shot("p3_overview")
	camera.position = world.grid_to_screen(Vector2(10, 17)) + Vector2(0, -20)
	camera.zoom = Vector2.ONE * 2.0
	for k in range(30): await get_tree().process_frame
	_shot("p3_huehner")
	camera.position = world.grid_to_screen(Vector2(14, 17)) + Vector2(0, -20)
	for k in range(30): await get_tree().process_frame
	_shot("p3_schafe")
	camera.position = world.grid_to_screen(Vector2(27, 9)) + Vector2(0, -10)
	camera.zoom = Vector2.ONE * 1.6
	for k in range(30): await get_tree().process_frame
	_shot("p3_teich")
	village.elapsed = Model.SEASON_LENGTH + 240.0 * 0.62  # evening -> night
	camera.position = world.grid_to_screen(Vector2(14, 17)) + Vector2(0, -20)
	camera.zoom = Vector2.ONE * 2.0
	for k in range(120): await get_tree().process_frame
	_shot("p3_nacht")
	print("produced eier ", village.produced.get("eier", 0), " wolle ", village.produced.get("wolle", 0), " milch ", village.produced.get("milch", 0))
	get_tree().quit()

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://build/qa/%s.png" % name)
