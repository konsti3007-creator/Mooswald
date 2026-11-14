extends Node2D
## Visual representation of one resident. Reads the resident's simulation
## state (animation name, animation clock, walked distance, facing) and
## shows the matching frame of the rig. Contains no game logic.
##
## The node only re-records its drawing when the visible frame changes
## (animation, frame index, quantised direction, carried item or tool),
## so large villages stay cheap.

const Rig = preload("res://scripts/anim/woodling_rig.gd")
const AnimDefs = preload("res://scripts/anim/anim_defs.gd")

static var rig = Rig.new()

var resident: Dictionary = {}
var world  # world_view.gd
var key := ""
var selected := false
var bubble := ""
var display_dir := 0.0

func setup(r: Dictionary, w) -> void:
	resident = r
	world = w
	display_dir = _quantise(r.facing)

static func _quantise(angle: float) -> float:
	var step := TAU / AnimDefs.DIRECTIONS
	return roundf(angle / step) * step

func frame_info() -> Array:
	var r := resident
	var anim: String = r.anim
	if not AnimDefs.ANIMS.has(anim): anim = "idle"
	var frame := 0
	if AnimDefs.ANIMS[anim].has("cycle"):
		frame = AnimDefs.frame_at_distance(anim, r.walk)
	else:
		frame = AnimDefs.frame_at(anim, r.at)
	return [anim, frame]

func refresh(time: float) -> void:
	var r := resident
	position = world.grid_to_screen(Vector2(r.x, r.y))
	display_dir = _quantise(r.facing)
	var info := frame_info()
	var b := ""
	if r.get("trapped", false): b = "!"
	elif r.anim == "rest" and int(time * 1.5) % 2 == 0: b = "z"
	elif r.anim == "rest": b = "Z"
	elif r.task.is_empty() and r.get("blocked", 0) > 0: b = "?"
	var item: String = r.get("item", "")
	var tool: String = r.task.get("tool", "") if not r.task.is_empty() else ""
	var winter: bool = world.season_w[3] > 0.5
	var k := "%s|%d|%.2f|%s|%s|%s|%s|%s" % [info[0], info[1], display_dir, item, tool, b, selected, winter]
	visible = not r.get("trapped", false)
	if k != key:
		key = k
		bubble = b
		queue_redraw()

func _draw() -> void:
	var r := resident
	var info := frame_info()
	var anim: String = info[0]
	var extra := {}
	var item: String = r.get("item", "")
	if anim in ["cast", "fish_wait", "reel"]: item = ""
	if item != "": extra.item = item
	var t: Dictionary = r.task
	var tool: String = t.get("tool", "") if not t.is_empty() else ""
	if anim in ["walk", "carry_walk", "idle", "look"] and tool in ["axe", "pick", "rod"] and item == "":
		extra.back_tool = tool
	if anim in ["draw_tool", "stow_tool"]: extra.tool = tool if tool != "" else "axe"
	if anim == "pick": extra.fill = float(t.get("passes", 0)) / 3.0
	var pose := Rig.pose(anim, info[1], extra)
	if anim in ["saw", "knead", "stir", "pour", "bees", "serve"]: pose.prop = anim
	if world.season_w[3] > 0.5: pose.scarf = true
	if selected:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, 15.0, 0, TAU, 28, Color(1, 0.95, 0.6, 0.9), 2.0, true)
		draw_set_transform(Vector2.ZERO)
	rig.draw(self, pose, display_dir, AnimDefs.WORLD_SCALE, int(r.variant))
	if bubble != "":
		var at := Vector2(0, -78)
		draw_circle(at, 9.0, Color("fff4d9"))
		draw_arc(at, 9.0, 0, TAU, 20, Color("4b2f1e"), 1.2, true)
		var col := Color("b0433a") if bubble in ["!", "?"] else Color("4d6b8a")
		draw_string(ThemeDB.fallback_font, at + Vector2(-4, 5), bubble, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, col)
