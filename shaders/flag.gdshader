shader_type spatial;
render_mode cull_disabled;
// A cloth flag: waves travel from the pole (UV.x = 0) to the free edge; amplitude and speed
// follow the wind strength. The flag node itself is turned to face down-wind.

global uniform vec3 wind;
uniform vec3 color : source_color = vec3(0.75, 0.16, 0.12);

void vertex() {
	float s = clamp(length(wind) / 22.0, 0.0, 1.0);
	float along = UV.x;
	float wave = sin(along * 9.0 - TIME * (3.0 + s * 9.0)) * along * (0.05 + s * 0.22);
	VERTEX.z += wave;
	VERTEX.y -= (1.0 - s) * along * along * 0.55; // hangs limp when calm
}

void fragment() {
	ALBEDO = color;
	ROUGHNESS = 0.8;
}
