// Lit pixel-art billboard for HD-2D characters and foliage.
// - nearest filtering keeps texels crisp
// - alpha scissor so sprites cast and receive real shadows
// - wrapped (half-lambert) diffuse so a flat card never goes black
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

uniform sampler2D sheet : source_color, filter_nearest;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0); // uv offset.xy, size.zw within sheet
uniform float flip_h = 0.0;
uniform float wrap = 0.55;           // 0 = lambert, 1 = fully flat
uniform vec3 tint : source_color = vec3(1.0);
uniform float flash = 0.0;           // hit-flash toward white

void fragment() {
	vec2 uv = UV;
	if (flip_h > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec4 c = texture(sheet, region.xy + uv * region.zw);
	ALBEDO = mix(c.rgb * tint, vec3(1.0), flash);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	// Cards face the camera; bend the normal upward so overhead light reads.
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.35));
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += w * ATTENUATION * LIGHT_COLOR / PI;
}
