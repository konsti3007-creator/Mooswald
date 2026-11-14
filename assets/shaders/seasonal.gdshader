shader_type canvas_item;
// Seasonal look for the painted sprites (trees, buildings, decorations).
// Weights for spring/autumn/winter come from the simulation clock and blend
// smoothly at season changes. Foliage is detected by hue (yellow-green to
// blue-green, saturated), so painted leaves of every shade take part.
//   spring: light blossoms on foliage
//   autumn: foliage turns ochre, orange and red (varied per patch)
//   winter: foliage dulls, snow on upward edges of roofs and crowns
uniform float spring = 0.0;
uniform float autumn = 0.0;
uniform float winter = 0.0;
// 1.0 for trees and bushes, lower for buildings (moss roofs change less).
uniform float foliage = 1.0;
uniform float snow_depth = 5.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	if (col.a > 0.01) {
		vec3 hsv = rgb2hsv(col.rgb);
		// Hue 0.15 (yellow-green) .. 0.45 (teal-green), saturation > 0.2.
		float leafy = smoothstep(0.13, 0.19, hsv.x) * (1.0 - smoothstep(0.42, 0.50, hsv.x)) * smoothstep(0.18, 0.32, hsv.y);
		float green = leafy * foliage;
		vec2 cell = floor(world_pos / 7.0);
		float n = hash(cell);
		float lum = dot(col.rgb, vec3(0.3, 0.55, 0.15));
		// Autumn: ochre, orange and red patches, keeping the painted light.
		vec3 fall = mix(vec3(0.93, 0.62, 0.20), vec3(0.80, 0.30, 0.13), n);
		fall = mix(fall, vec3(0.95, 0.80, 0.30), step(0.72, hash(cell + 3.1)));
		col.rgb = mix(col.rgb, fall * (0.45 + hsv.z * 0.75), green * autumn * 0.9);
		// Winter: duller, cooler foliage.
		vec3 cold = mix(vec3(lum), vec3(0.42, 0.52, 0.48) * (0.55 + lum), 0.55);
		col.rgb = mix(col.rgb, cold, green * winter * 0.75);
		// Spring blossoms.
		float blossom = step(0.93, hash(floor(world_pos / 4.0))) * green;
		col.rgb = mix(col.rgb, mix(vec3(1.0, 0.80, 0.87), vec3(1.0, 0.97, 0.93), n), blossom * spring);
		// Snow on edges facing up: opaque pixel with transparency above it.
		if (winter > 0.01) {
			vec2 up = vec2(0.0, -TEXTURE_PIXEL_SIZE.y * snow_depth);
			float above = texture(TEXTURE, UV + up).a;
			float above2 = texture(TEXTURE, UV + up * 2.0).a;
			float edge = clamp((1.0 - above) + (1.0 - above2) * 0.6, 0.0, 1.0);
			float flakes = step(0.78, hash(floor(world_pos / 3.0))) * leafy * 0.8;
			float snow = clamp(edge + flakes, 0.0, 1.0) * winter;
			col.rgb = mix(col.rgb, vec3(0.95, 0.97, 1.0) * (0.86 + lum * 0.18), snow);
		}
	}
	COLOR = col;
}
