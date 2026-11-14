extends SceneTree
## Visual QA: every animal species in 8 directions and its animations.
const Rig = preload("res://scripts/anim/animal_rig.gd")

class Sheet extends Node2D:
	var rig = Rig.new()
	var mode := 0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(2000, 1600)), Color("8fb36a"))
		var species := Rig.SPECIES.keys()
		for i in range(species.size()):
			var sp: String = species[i]
			for j in range(8):
				draw_set_transform(Vector2(110 + j * 150, 120 + i * 120))
				if mode == 0:
					rig.draw(self, sp, "walk", 2, float(j) / 8.0 * TAU, 3.2)
				else:
					var anims := [["idle", 0], ["idle", 6], ["graze", 1], ["graze", 5], ["sleep", 0], ["walk", 0], ["walk", 2], ["walk", 4]]
					if sp == "ente": anims[4] = ["swim", 2]
					rig.draw(self, sp, anims[j][0], anims[j][1], 0.785, 3.2)
				draw_set_transform(Vector2.ZERO)
			draw_string(ThemeDB.fallback_font, Vector2(4, 125 + i * 120), sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1300, 1000)
	var sheet := Sheet.new()
	root.add_child(sheet)
	for mode in [0, 1]:
		sheet.mode = mode
		sheet.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/qa/animals_%d.png" % mode)
	quit(0)
