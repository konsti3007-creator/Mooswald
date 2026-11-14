extends Node
## Self-synthesised sounds (no third-party audio). Short action sounds are
## generated once at startup as 16-bit mono samples and played through a
## small pool of positional players on the "SFX" bus.

const RATE := 22050
var streams: Dictionary = {}
var pool: Array[AudioStreamPlayer2D] = []
var next := 0
var last_played: Dictionary = {}

func _ready() -> void:
	streams.chop = _make(0.22, func(t, n): return (_noise_burst(t, n, 0.035) * 0.7 + sin(TAU * 150.0 * t) * exp(-t * 30.0) * 0.8))
	streams.pick = _make(0.28, func(t, n): return (sin(TAU * 1850.0 * t) * 0.45 + sin(TAU * 2770.0 * t) * 0.3) * exp(-t * 26.0) + _noise_burst(t, n, 0.012) * 0.5)
	streams.fall = _make(0.9, func(t, n): return n.randf_range(-1, 1) * 0.35 * exp(-t * 3.0) * (1.0 - exp(-t * 20.0)) + sin(TAU * 70.0 * t) * exp(-maxf(t - 0.55, 0.0) * 12.0) * (0.7 if t > 0.55 else 0.0))
	streams.swish = _make(0.25, func(t, n): return n.randf_range(-1, 1) * 0.4 * sin(PI * t / 0.25))
	streams.rustle = _make(0.3, func(t, n): return n.randf_range(-1, 1) * 0.22 * sin(PI * t / 0.3) * (0.6 + 0.4 * sin(TAU * 23.0 * t)))
	streams.splash = _make(0.35, func(t, n): return n.randf_range(-1, 1) * 0.25 * exp(-t * 8.0) + sin(TAU * (600.0 + 900.0 * t) * t) * 0.08 * exp(-t * 10.0))
	streams.lift = _make(0.16, func(t, n): return sin(TAU * 220.0 * t) * 0.3 * exp(-t * 18.0))
	streams.drop = _make(0.2, func(t, n): return (sin(TAU * 110.0 * t) * 0.7 + n.randf_range(-1, 1) * 0.2) * exp(-t * 22.0))
	streams.done = _make(0.55, func(t, n): return (sin(TAU * 784.0 * t) * exp(-t * 7.0) + (sin(TAU * 1047.0 * t) * exp(-(t - 0.12) * 7.0) if t > 0.12 else 0.0)) * 0.22)
	streams.work_stroke = _make(0.22, func(t, n): return n.randf_range(-1, 1) * 0.25 * sin(PI * t / 0.22) * (0.5 + 0.5 * sin(TAU * 90.0 * t)))
	streams.work_press = _make(0.14, func(t, n): return sin(TAU * 90.0 * t) * 0.4 * exp(-t * 25.0))
	streams.work_bubble = _make(0.12, func(t, n): return sin(TAU * (500.0 + 900.0 * t) * t) * 0.2 * exp(-t * 20.0))
	streams.work_stir = streams.work_bubble
	for i in range(10):
		var player := AudioStreamPlayer2D.new()
		player.bus = "SFX"
		player.max_distance = 1400.0
		player.attenuation = 1.4
		add_child(player)
		pool.append(player)

func _noise_burst(t: float, n: RandomNumberGenerator, length: float) -> float:
	return n.randf_range(-1, 1) * exp(-t / length)

func _make(seconds: float, fn: Callable) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.stereo = false
	var count := int(seconds * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 4711
	for i in range(count):
		var t := float(i) / RATE
		var value: float = fn.call(t, noise)
		# Tiny fade in/out avoids clicks.
		value *= minf(1.0, i / 40.0) * minf(1.0, (count - i) / 80.0)
		bytes.encode_s16(i * 2, int(clampf(value, -1, 1) * 32767))
	wave.data = bytes
	return wave

func play(kind: String, at: Vector2, speed: float) -> void:
	if not streams.has(kind): return
	# Avoid machine-gun repetition at high game speed.
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(kind, 0)) < 70: return
	last_played[kind] = now
	var player := pool[next]
	next = (next + 1) % pool.size()
	player.stream = streams[kind]
	player.global_position = at
	player.pitch_scale = randf_range(0.92, 1.08) * (1.0 if speed <= 1.0 else 1.06)
	player.volume_db = -4.0
	player.play()

## Calm forest ambience: wind noise and a few soft bird chirps (12 s loop).
static func ambience() -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.stereo = false
	wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wave.loop_end = RATE * 12
	var bytes := PackedByteArray()
	bytes.resize(wave.loop_end * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 5319
	var smooth := 0.0
	for i in range(wave.loop_end):
		var t := float(i) / RATE
		smooth = smooth * 0.96 + noise.randf_range(-1, 1) * 0.04
		var value := smooth * 0.16 * (0.8 + 0.2 * sin(TAU * t / 12.0))
		for start in [1.2, 3.7, 6.3, 8.8]:
			var since: float = t - start
			if since >= 0 and since < 0.5:
				var envelope := sin(since * PI / 0.5) * sin(since * 34) * 0.08
				value += sin(TAU * (2200 * since + 500 * since * since)) * envelope
		bytes.encode_s16(i * 2, int(clampf(value, -1, 1) * 32767))
	wave.data = bytes
	return wave
