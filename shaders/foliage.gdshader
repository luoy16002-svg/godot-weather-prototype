shader_type spatial;
// Placeholder foliage that bends with the global wind. Displacement grows with height above the
// object's base, plus a small per-object flutter so a forest does not move in lockstep.

global uniform vec3 wind;
global uniform float wetness;
uniform vec3 albedo : source_color = vec3(0.23, 0.42, 0.2);
uniform float stiffness = 1.0;

void vertex() {
	// Height above the ground in world space, so trunk and canopy (separate meshes) bend together.
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float height = max((MODEL_MATRIX * vec4(VERTEX, 1.0)).y, 0.0);
	float speed = length(wind);
	float flutter = sin(TIME * (1.5 + speed * 0.25) + world_origin.x * 0.7 + world_origin.z * 0.4);
	vec3 bend = wind * 0.0032 * height * height / stiffness;
	bend += normalize(wind + vec3(0.0001)) * flutter * speed * 0.004 * height;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(bend, 0.0)).xyz;
}

void fragment() {
	ALBEDO = albedo * mix(1.0, 0.7, wetness);
	ROUGHNESS = mix(0.85, 0.35, wetness);
	SPECULAR = mix(0.3, 0.6, wetness);
}
