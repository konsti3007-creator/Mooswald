extends RefCounted
## Single source of truth for animation timing and action events.
##
## The simulation (residents.gd) uses these tables to decide WHEN an action
## event (hit, harvest, handover ...) happens. The renderer (woodling_view.gd)
## uses the very same tables to decide WHICH frame is shown. Both therefore
## stay in lockstep at every game speed, after pause and after loading.
##
## durations: seconds per frame at 1x speed (frames may differ in length:
##            wind-up slow, strike fast).
## events:    frame index -> event name. The event fires at the START of that
##            frame, exactly once per pass through the frame.
## cycle:     distance-driven animations (walking) advance one full cycle per
##            `cycle` rig units of ground distance instead of by time.

const DIRECTIONS := 8
## On-screen size of one rig unit at zoom 1, and the ground distance of one
## grid cell in the same screen units (iso cell diagonal, unsquashed).
const WORLD_SCALE := 1.3
const GROUND_PER_CELL := 50.91

const ANIMS := {
	"idle": {"durations": [0.34, 0.34, 0.34, 0.34, 0.34, 0.34, 0.12, 0.34], "loop": true},
	"look": {"durations": [0.30, 0.30, 0.45, 0.30, 0.30, 0.30, 0.45, 0.30], "loop": true},
	"rest": {"durations": [0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6], "loop": true},
	"walk": {"frames": 8, "cycle": 18.0, "loop": true},
	"carry_walk": {"frames": 8, "cycle": 15.0, "loop": true},
	"carry_idle": {"durations": [0.4, 0.4, 0.4, 0.4], "loop": true},
	"draw_tool": {"durations": [0.10, 0.12, 0.12, 0.12], "events": {2: "tool_out"}},
	"stow_tool": {"durations": [0.10, 0.12, 0.12, 0.10], "events": {2: "tool_in"}},
	"chop": {"durations": [0.14, 0.14, 0.14, 0.18, 0.06, 0.16, 0.14, 0.12], "events": {5: "hit"}, "loop": true},
	"mine": {"durations": [0.14, 0.15, 0.15, 0.20, 0.06, 0.18, 0.14, 0.12], "events": {5: "hit"}, "loop": true},
	"sow": {"durations": [0.16, 0.16, 0.18, 0.12, 0.10, 0.18, 0.16, 0.16], "events": {4: "sow"}, "loop": true},
	"water": {"durations": [0.18, 0.18, 0.22, 0.22, 0.22, 0.22, 0.18, 0.18], "events": {3: "water"}, "loop": true},
	"reap": {"durations": [0.16, 0.14, 0.14, 0.16, 0.07, 0.15, 0.16, 0.16], "events": {5: "cut"}, "loop": true},
	"pick": {"durations": [0.14, 0.14, 0.16, 0.12, 0.14, 0.14, 0.14, 0.14], "events": {3: "pluck", 6: "drop_in"}, "loop": true},
	"pickup": {"durations": [0.10, 0.10, 0.12, 0.14, 0.12, 0.10], "events": {3: "pickup"}},
	"putdown": {"durations": [0.10, 0.10, 0.12, 0.14, 0.12, 0.10], "events": {3: "handover"}},
	"saw": {"durations": [0.13, 0.13, 0.13, 0.13, 0.13, 0.13, 0.13, 0.13], "events": {2: "stroke", 6: "stroke"}, "loop": true},
	"pour": {"durations": [0.20, 0.20, 0.22, 0.24, 0.24, 0.22, 0.20, 0.20], "events": {4: "pour"}, "loop": true},
	"knead": {"durations": [0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15], "events": {2: "press", 6: "press"}, "loop": true},
	"stir": {"durations": [0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20], "events": {0: "bubble", 4: "bubble"}, "loop": true},
	"bees": {"durations": [0.24, 0.24, 0.26, 0.30, 0.30, 0.26, 0.24, 0.24], "events": {4: "bees"}, "loop": true},
	"serve": {"durations": [0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20], "events": {3: "wipe"}, "loop": true},
	"plant": {"durations": [0.16, 0.16, 0.18, 0.20, 0.20, 0.18, 0.16, 0.16], "events": {4: "plant"}, "loop": true},
	"cast": {"durations": [0.16, 0.16, 0.18, 0.22, 0.07, 0.20, 0.18, 0.18], "events": {5: "cast"}},
	"fish_wait": {"durations": [0.32, 0.32, 0.32, 0.20, 0.32, 0.32, 0.32, 0.32], "events": {3: "bob"}, "loop": true},
	"reel": {"durations": [0.14, 0.14, 0.14, 0.14, 0.16, 0.16, 0.10, 0.24], "events": {6: "catch"}},
}

## Workshop types -> work animation and tool shown while working.
const WORK_ANIM := {
	"Saegewerk": "saw", "Muehle": "pour", "Baeckerei": "knead",
	"Imkerei": "bees", "Kochhaus": "stir", "Gasthaus": "serve", "Raeucherei": "stir",
	"Huehnerhof": "sow", "Schafweide": "knead", "Ziegenstall": "knead", "Kaeserei": "stir",
}

static func frame_count(anim: String) -> int:
	var d: Dictionary = ANIMS[anim]
	if d.has("durations"): return d.durations.size()
	return int(d.frames)

static func length(anim: String) -> float:
	var d: Dictionary = ANIMS[anim]
	if not d.has("durations"): return 1.0
	var total := 0.0
	for v in d.durations: total += v
	return total

## Start time of a frame inside one pass of the animation.
static func frame_start(anim: String, frame: int) -> float:
	var d: Dictionary = ANIMS[anim]
	var t := 0.0
	for i in range(frame): t += d.durations[i]
	return t

## Frame shown at time t (time-driven animations).
static func frame_at(anim: String, t: float) -> int:
	var d: Dictionary = ANIMS[anim]
	if not d.has("durations"): return 0
	var total := length(anim)
	var local := fmod(maxf(t, 0.0), total) if d.get("loop", false) else clampf(t, 0.0, total - 0.0001)
	var acc := 0.0
	for i in range(d.durations.size()):
		acc += d.durations[i]
		if local < acc - 0.000001: return i
	return d.durations.size() - 1

## Frame for distance-driven animations.
static func frame_at_distance(anim: String, dist: float) -> int:
	var d: Dictionary = ANIMS[anim]
	var frames := int(d.frames)
	var u := fposmod(dist / float(d.cycle), 1.0)
	return int(floor(u * frames + 0.0001)) % frames

## All events crossed when an animation clock advances from t0 (exclusive)
## to t1 (inclusive). Loops are unrolled, so a long frame at 4x speed still
## reports every event exactly once, in order. Returns [[time, name], ...].
static func events_between(anim: String, t0: float, t1: float) -> Array:
	var result: Array = []
	var d: Dictionary = ANIMS[anim]
	if not d.has("events") or t1 <= t0: return result
	var total := length(anim)
	var loop: bool = d.get("loop", false)
	var first_pass := int(floor(t0 / total)) if loop else 0
	var last_pass := int(floor(t1 / total)) if loop else 0
	for p in range(first_pass, last_pass + 1):
		var frames: Array = d.events.keys()
		frames.sort()
		for f in frames:
			var at: float = p * total + frame_start(anim, f)
			# An event at t=0 of the very first pass belongs to the start.
			if (at > t0 or (at == 0.0 and t0 < 0.0)) and at <= t1:
				result.append([at, d.events[f]])
	return result
