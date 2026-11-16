extends "res://scripts/game.gd"
## Visual QA 0.8: new interface, individual specialist houses, night lights.

func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	await get_tree().process_frame
	tips.hide()
	village = Model.new()
	village.seed()
	village.elapsed = Model.SEASON_LENGTH + 20.0
	village.xp = Model.xp_for_level(8)
	for k in ["muenzen", "bretter", "stein", "holz"]: village.resources[k] = 3000 if k == "muenzen" else 400
	var spots := [Vector2i(7,14), Vector2i(10,15), Vector2i(13,15), Vector2i(16,15), Vector2i(19,15), Vector2i(7,17), Vector2i(10,18), Vector2i(13,18)]
	for i in range(Model.SPECIAL_HOUSES.size()):
		if not village.place(spots[i], Model.SPECIAL_HOUSES[i]): print("not placed ", Model.SPECIAL_HOUSES[i], " ", village.notice)
	village.place(Vector2i(17,18), "Huehnerhof")
	village.place(Vector2i(4,12), "Laterne")
	village.place(Vector2i(11,13), "Laterne")
	for x in range(6, 22): village.place(Vector2i(x, 13), "Weg")
	village.resources.holz = 120
	village.resources.muenzen = 340
	world.rebuild()
	village.tick(20.0)
	camera.position = cell_pos(Vector2i(13, 15))
	camera.zoom = Vector2.ONE * 0.9
	open_drawer("Bewohner")
	selected = "HausKraeuter"
	_catalog()
	_update_ui()
	for k in range(90): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://build/qa/v08_day.png")
	drawer_open = false
	drawer.visible = false
	village.elapsed = Model.SEASON_LENGTH + 240.0 * (22.0 - 7.0) / 24.0
	for k in range(90): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://build/qa/v08_night.png")
	get_tree().quit()
