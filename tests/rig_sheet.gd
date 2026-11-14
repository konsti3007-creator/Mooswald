extends SceneTree
## Visual QA: renders contact sheets (8 directions x all frames) of woodling
## animations with the real rig and OpenGL renderer.
## Usage: godot --path . --script res://tests/rig_sheet.gd -- --anims=walk,chop --out=build/qa
const Rig = preload("res://scripts/anim/woodling_rig.gd")
const AnimDefs = preload("res://scripts/anim/anim_defs.gd")

class Sheet extends Node2D:
	var anim := "walk"
	var scale_value := 3.2
	var rig = Rig.new()
	var cell := Vector2(150, 175)
	var palette := 0
	var zoom_frame := -1
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(2000, 1600)), Color("8fb36a"))
		if zoom_frame >= 0:
			for d in range(8):
				var o := Vector2(160 + (d % 4) * 300, 380 + (d / 4) * 420)
				draw_set_transform(o)
				var ex := {}
				if anim == "carry_walk" or anim == "carry_idle": ex = {"item": "logs"}
				rig.draw(self, Rig.pose(anim, zoom_frame, ex), float(d) / 8.0 * TAU, 7.0, palette)
				draw_set_transform(Vector2.ZERO)
			return
		var frames := AnimDefs.frame_count(anim)
		for d in range(8):
			var facing := float(d) / 8.0 * TAU
			for k in range(frames):
				var origin := Vector2(90 + k * cell.x, 150 + d * cell.y)
				draw_set_transform(origin)
				var extra := {}
				if anim == "carry_walk" or anim == "carry_idle": extra = {"item": ["logs", "stone", "basket_grain", "sack"][d % 4]}
				rig.draw(self, Rig.pose(anim, k, extra), facing, scale_value, palette)
				draw_set_transform(Vector2.ZERO)
		for d in range(8):
			draw_string(ThemeDB.fallback_font, Vector2(4, 110 + d * cell.y), ["S", "SO", "O", "NO", "N", "NW", "W", "SW"][d], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(8, 18), anim, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var anims := ["walk"]
	var out := "res://build/qa"
	var palette := 0
	var zoom := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--anims="): anims = a.trim_prefix("--anims=").split(",")
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--palette="): palette = int(a.trim_prefix("--palette="))
		if a.begins_with("--zoom="): zoom = int(a.trim_prefix("--zoom="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1300, 1500)
	var sheet := Sheet.new()
	sheet.palette = palette
	sheet.zoom_frame = zoom
	root.add_child(sheet)
	for anim in anims:
		sheet.anim = anim
		sheet.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(out.path_join(("zoom_%s.png" if zoom >= 0 else "sheet_%s.png") % anim))
		print("sheet ", anim)
	quit(0)
