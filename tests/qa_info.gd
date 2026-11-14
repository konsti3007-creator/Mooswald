extends "res://scripts/game.gd"
## Visual QA: catalog descriptions, cost hints at the cursor, sale buttons.

func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	tips.hide()
	village.speed = 0
	category = "Handwerk"
	selected = "Angler"
	mode = "Bauen"
	_catalog()
	right_tabs.current_tab = 3
	camera.position = cell_pos(Vector2i(22, 12))
	camera.zoom = Vector2.ONE
	for k in range(10): await get_tree().process_frame
	get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.55, 0.55))
	for k in range(20): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://build/qa/info_catalog.png")
	category = "Bewohner"
	selected = "HausKraeuter"
	_catalog()
	_update_ui()
	for k in range(10): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://build/qa/info_bewohner.png")
	get_tree().quit()
