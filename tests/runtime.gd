extends SceneTree
## Integration with the real main scene: UI signals, mouse building,
## picking a house by its picture, real save files, backup recovery,
## residents walking on legal ground and the quit dialog.
const Game = preload("res://main.tscn")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func click(game, button: int, world_pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = game.get_canvas_transform() * world_pos
	game._unhandled_input(e)

## Exact integers and identities; timers/positions compared rounded
## (JSON stores decimal fractions with finite precision).
func summary(v) -> String:
	var rows: Array = []
	for r in v.residents: rows.append([r.id, r.home, r.job, snappedf(r.x, 0.001), snappedf(r.y, 0.001), r.task.get("type", ""), r.task.get("step", -1), r.carry])
	var bs: Array = []
	for c in v.buildings: bs.append([c, v.buildings[c].type, v.buildings[c].id, v.buildings[c].tier, snappedf(v.buildings[c].progress, 0.001)])
	return JSON.stringify([v.resources, v.xp, v.quest, rows, bs, snappedf(v.elapsed, 0.01)])

func run() -> void:
	for path in ["user://village_v1.json", "user://village_v1.json.bak", "user://village_v1.json.tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var game = Game.instantiate()
	root.add_child(game)
	await process_frame
	game.tips.hide()
	game.village = game.Model.new()
	game.village.seed()
	game.world.rebuild()
	game._update_ui()
	for y in range(game.Model.SIZE.y):
		for x in range(game.Model.SIZE.x):
			var c := Vector2i(x, y)
			check(game.world_cell(game.cell_pos(c)) == c, "Isometric coordinate round trip")
	game.category = "Wohnen"
	game._catalog()
	game.catalog.get_child(0).pressed.emit()
	check(game.selected == "Haus", "Catalog selection signal")
	click(game, MOUSE_BUTTON_LEFT, game.cell_pos(Vector2i(3, 10)))
	check(game.village.buildings.has(Vector2i(3, 10)), "Mouse event builds the selected house")
	game.category = "Bewohner"
	game._catalog()
	check(game.catalog.get_child_count() == game.Model.SPECIAL_HOUSES.size(), "Special houses listed in their own category")
	# Picking: clicking high up on the roof (a different ground cell) still
	# selects the house.
	game.world.update(0.016, 0.0)
	await process_frame
	game.mode = "Info"
	var roof: Vector2 = game.world.sort_point(Vector2i(10, 9), "Haus") + Vector2(0, -95)
	check(game.world_cell(roof) != Vector2i(10, 9) and game.village.anchor(game.world_cell(roof)) != Vector2i(10, 9), "Roof point lies over another ground cell")
	click(game, MOUSE_BUTTON_LEFT, roof)
	check(game.inspected == Vector2i(10, 9) and game.right_tabs.current_tab == 1, "Clicking the roof selects the house")
	click(game, MOUSE_BUTTON_RIGHT, game.cell_pos(Vector2i(3, 10)))
	check(game.inspected == Vector2i(3, 10), "Right click selects and opens building info")
	game._paint_roads(Vector2i(8, 0), Vector2i(12, 3))
	for x in range(8, 13): check(game.village.has_road(Vector2i(x, 0)), "Drag drawing fills horizontal gaps")
	for y in range(4): check(game.village.has_road(Vector2i(12, y)), "Drag drawing fills vertical gaps")
	check(game.ambient.stream.data.size() > 0, "Generated ambient sound contains samples")
	check(game.sfx.streams.has("chop") and game.sfx.streams.has("pick"), "Action sounds synthesised")
	check(game.quit_dialog != null and game.quit_dialog.ok_button_text.begins_with("Speichern"), "Quit dialog saves before closing")
	# Residents walk and work for 60 game seconds on legal ground.
	var saw_work := false
	for i in range(600):
		game.village.tick(0.1)
		game.world.update(0.016, 0.1)
		for r in game.village.residents:
			if not r.trapped and not game.village.walkable(Vector2i(roundi(r.x), roundi(r.y))): check(false, "Resident stays on legal ground: %s at %.2f,%.2f %s step %s" % [r.anim, r.x, r.y, r.task.get("type",""), str(r.task.get("step",""))])
			if r.anim in ["chop", "reap", "sow", "water"]: saw_work = true
	check(saw_work, "Residents perform real work actions")
	check(game.world.resident_nodes.size() == game.village.residents.size(), "Every resident has a view")
	# Real files: save, load, backup recovery.
	game.dark = true
	game._save()
	check(FileAccess.file_exists(game.SAVE), "Save file created")
	var snapshot: String = summary(game.village)
	game.village.resources.holz = 999
	game.dark = false
	check(game._load(true), "Load file")
	check(game.dark, "Display settings restored")
	check(summary(game.village) == snapshot, "Actual file round trip including residents")
	game.village.tick(2)
	game._save()
	check(FileAccess.file_exists(game.SAVE + ".bak"), "Backup created")
	var corrupt := FileAccess.open(game.SAVE, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(game._load(true), "Corrupt primary falls back to backup")
	check(summary(game.village) == snapshot, "Backup state intact")
	for path in [game.SAVE, game.SAVE + ".bak", game.SAVE + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("MOOSWINKEL RUNTIME: picking, building, residents, save/load, backup: %d failures" % failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
