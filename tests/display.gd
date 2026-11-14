extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, label: String) -> void:
 if not ok: failures += 1; push_error(label)
func run() -> void:
 var game = preload("res://main.tscn").instantiate()
 root.add_child(game)
 await create_timer(0.4).timeout
 check(root.mode == Window.MODE_FULLSCREEN,"Fullscreen startup")
 root.mode = Window.MODE_WINDOWED
 root.size = Vector2i(1024,768)
 await create_timer(0.6).timeout
 game._layout_ui()
 await process_frame
 var extent: Vector2 = game.get_viewport_rect().size
 for key in ["top","right","bottom","left"]:
  var panel: Control = game.layout_panels[key]
  check(panel.position.x >= 0 and panel.position.y >= 0,"Panel starts inside viewport")
  check(panel.position.x+panel.size.x <= extent.x+2,"Panel fits horizontally")
  check(panel.position.y+panel.size.y <= extent.y+2,"Panel fits vertically")
 root.get_texture().get_image().save_png("res://build/layout-4-3.png")
 print("DISPLAY 4:3: physical ",root.size," logical ",extent)
 var event := InputEventKey.new()
 event.keycode = KEY_F11
 event.pressed = true
 game._unhandled_input(event)
 await create_timer(0.5).timeout
 check(root.mode == Window.MODE_FULLSCREEN,"F11 enables fullscreen")
 game._unhandled_input(event)
 await create_timer(0.3).timeout
 check(root.mode == Window.MODE_WINDOWED,"F11 restores window mode")
 print("MOOSWINKEL DISPLAY: ",failures," failures")
 quit(0 if failures == 0 else 1)

