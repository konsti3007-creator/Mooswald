shader_type canvas_item;
// Seasonal ground: recolours the cached terrain, roads and water without
// redrawing them. Grass turns lush (spring), golden (summer end/autumn) or
// snowy (winter); water freezes over in winter.
uniform float spring = 0.0;
uniform float autumn = 0.0;
uniform float winter = 0.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	float green = clamp((col.g - max(col.r, col.b)) * 4.0, 0.0, 1.0);
	float water = clamp((col.b - col.r) * 6.0, 0.0, 1.0) * step(col.r, 0.5);
	float lum = dot(col.rgb, vec3(0.3, 0.55, 0.15));
	float n = noise(world_pos / 90.0) * 0.6 + noise(world_pos / 23.0) * 0.4;
	// Spring: fresher green.
	col.rgb = mix(col.rgb, col.rgb * vec3(0.98, 1.03, 0.96), green * spring);
	// Autumn: golden and russet patches.
	vec3 fall = mix(vec3(0.66, 0.62, 0.30), vec3(0.62, 0.45, 0.24), n);
	col.rgb = mix(col.rgb, fall * (0.75 + lum * 0.5), green * autumn * 0.75);
	// Winter: dormant grass first, then snow cover with a few bare patches.
	col.rgb = mix(col.rgb, mix(vec3(lum), vec3(0.55, 0.58, 0.45), 0.6) * (0.8 + lum * 0.4), green * winter * 0.8);
	float snow = smoothstep(0.25, 0.45, n + 0.2) * winter;
	col.rgb = mix(col.rgb, vec3(0.92, 0.94, 0.98) - vec3(0.06) * noise(world_pos / 9.0), snow * (0.5 + 0.5 * green) * 0.95);
	col.rgb = mix(col.rgb, vec3(0.78, 0.88, 0.94), water * winter * 0.75);
	COLOR = col;
}
