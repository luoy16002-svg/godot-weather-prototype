shader_type spatial;
// Ground that darkens and turns glossy as it gets wet, with puddles forming in low noise areas.

global uniform float wetness;
uniform vec3 dry_color : source_color = vec3(0.36, 0.42, 0.28);
uniform sampler2D puddle_noise : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 uv = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz * 0.035;
	float n = texture(puddle_noise, uv).r;
	float puddle = smoothstep(0.62, 0.7, n + wetness * 0.25) * smoothstep(0.35, 0.9, wetness);
	vec3 wet_color = dry_color * 0.55;
	ALBEDO = mix(mix(dry_color, wet_color, wetness), vec3(0.08, 0.1, 0.12), puddle);
	ROUGHNESS = mix(mix(0.95, 0.45, wetness), 0.04, puddle);
	SPECULAR = mix(0.25, 0.8, max(wetness * 0.6, puddle));
	METALLIC = 0.0;
}
