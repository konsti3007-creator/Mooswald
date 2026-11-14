extends "res://scripts/game.gd"
var capture_frames := 0

func _ready() -> void:
 for bits in range(16):
  var c := Vector2i(5+(bits%4)*5,5+(bits/4)*5)
  village.insert(c,"Weg")
  for i in range(4):
   if bits & (1<<i): village.insert(c+Model.DIRS[i],"Weg")

func _process(_delta: float) -> void:
 capture_frames += 1
 queue_redraw()
 if capture_frames == 4:
  get_viewport().get_texture().get_image().save_png("res://build/roads-16.png")
  get_tree().quit()

func _draw() -> void:
 draw_rect(Rect2(0,0,1366,824),Color("f5efdc"))
 draw_string(ThemeDB.fallback_font,Vector2(35,40),"MOOSWINKEL · Alle 16 Wegverbindungen · N=1 / O=2 / S=4 / W=8",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("2b493b"))
 for bits in range(16):
  var c := Vector2i(5+(bits%4)*5,5+(bits/4)*5)
  var offset := Vector2(180+(bits%4)*325,145+(bits/4)*185)-cell_pos(c)
  draw_set_transform(offset)
  for y in range(-1,2):
   for x in range(-1,2): draw_colored_polygon(diamond(c+Vector2i(x,y)),Color("91b273"))
  for road in village.road_masks:
   if absi(road.x-c.x)+absi(road.y-c.y) <= 1: _road(road,true)
  for road in village.road_masks:
   if absi(road.x-c.x)+absi(road.y-c.y) <= 1: _road(road,false)
  draw_set_transform(Vector2.ZERO)
  draw_string(ThemeDB.fallback_font,Vector2(125+(bits%4)*325,220+(bits/4)*185),"Maske %02d" % bits,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("2b493b"))
