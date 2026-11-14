extends "res://scripts/game.gd"
## Visual QA: the same village in spring, summer, autumn and winter.

func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	await get_tree().process_frame
	tips.hide()
	village = Model.new()
	village.seed()
	village.xp = Model.xp_for_level(7)
	village.resources.muenzen = 2000
	village.resources.bretter = 200
	village.resources.stein = 200
	village.resources.holz = 300
	for row in [[Vector2i(7,14),"Haus"],[Vector2i(4,10),"HausHolz"],[Vector2i(9,15),"Saegewerk"],[Vector2i(13,14),"Muehle"],[Vector2i(17,14),"Baeckerei"],[Vector2i(16,17),"Beeren"],[Vector2i(17,17),"Beeren"],[Vector2i(10,13),"Laterne"],[Vector2i(7,11),"Haus"]]:
		village.place(row[0], row[1])
	for x in range(8, 22): village.place(Vector2i(x, 13), "Weg")
	village.tick(40.0)
	world.rebuild()
	for panel in layout_panels.values(): panel.visible = false
	camera.position = cell_pos(Vector2i(13, 11))
	camera.zoom = Vector2.ONE * 1.0
	dark = true  # keep the night overlay away for comparison
	var names := ["fruehling", "sommer", "herbst", "winter"]
	for i in range(4):
		village.elapsed = i * Model.SEASON_LENGTH + 100.0
		village.speed = 1
		for k in range(150):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://build/qa/season_%s.png" % names[i])
	get_tree().quit()
