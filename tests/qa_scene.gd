extends "res://scripts/game.gd"
## Visual QA scene (not part of the game package): builds a test village,
## lets the residents work and captures the overview, close-ups of real
## in-game actions and a frame sequence of a walking woodling.

var out := "res://build/qa"

func _ready() -> void:
	super._ready()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	village = Model.new()
	village.seed()
	village.xp = Model.xp_for_level(7)
	village.resources.muenzen = 2000
	village.resources.bretter = 200
	village.resources.stein = 200
	village.resources.holz = 300
	village.resources.getreide = 40
	village.resources.mehl = 20
	village.resources.honig = 10
	village.resources.beeren = 20
	for row in [[Vector2i(7,14),"Haus"],[Vector2i(4,10),"HausHolz"],[Vector2i(9,15),"Saegewerk"],[Vector2i(13,14),"Muehle"],[Vector2i(17,14),"Baeckerei"],[Vector2i(20,13),"Steinbruch"],[Vector2i(4,13),"HausGarten"],[Vector2i(16,17),"Beeren"],[Vector2i(17,17),"Beeren"],[Vector2i(10,13),"Laterne"],[Vector2i(7,11),"Haus"],[Vector2i(23,16),"HausHandel"]]:
		village.place(row[0], row[1])
	for x in range(8, 22): village.place(Vector2i(x, 13), "Weg")
	await get_tree().process_frame
	await get_tree().process_frame
	tips.hide()
	world.rebuild()
	inspected = Vector2i(-1, -1)
	village.speed = 1
	village.tick(70.0)
	world.rebuild()
	_update_ui()
	camera.position = cell_pos(Vector2i(14, 11))
	camera.zoom = Vector2.ONE * 0.9
	await get_tree().create_timer(1.5).timeout
	_shot("overview")
	# Close-ups: follow residents doing different actions.
	for panel in layout_panels.values(): panel.visible = false
	var wanted := ["chop", "carry_walk", "reap", "sow", "saw", "mine", "pick", "walk", "putdown", "water"]
	var shots := 0
	var guard := 0
	while not wanted.is_empty() and guard < 1400:
		guard += 1
		await get_tree().process_frame
		for r in village.residents:
			if r.anim in wanted and not r.get("trapped", false):
				camera.position = world.grid_to_screen(Vector2(r.x, r.y)) + Vector2(0, -30)
				camera.zoom = Vector2.ONE * 2.6
				await get_tree().process_frame
				await get_tree().process_frame
				_shot("action_" + r.anim)
				wanted.erase(r.anim)
				shots += 1
				break
		village.tick(0.05)
	# Walking sequence (12 consecutive game frames) of one woodling.
	var walker: Dictionary = {}
	guard = 0
	while walker.is_empty() and guard < 600:
		guard += 1
		village.tick(0.05)
		await get_tree().process_frame
		for r in village.residents:
			if r.anim == "walk": walker = r; break
	if not walker.is_empty():
		var strip := Image.create(12 * 220, 260, false, Image.FORMAT_RGBA8)
		for i in range(12):
			camera.position = world.grid_to_screen(Vector2(walker.x, walker.y)) + Vector2(0, -30)
			camera.zoom = Vector2.ONE * 2.6
			await get_tree().process_frame
			await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			var center := img.get_size() / 2
			strip.blit_rect(img, Rect2i(center - Vector2i(110, 150), Vector2i(220, 260)), Vector2i(i * 220, 0))
			village.tick(1.0 / 15.0)
		strip.save_png(out.path_join("walk_strip.png"))
	print("QA captures: ", shots)
	get_tree().quit()

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
