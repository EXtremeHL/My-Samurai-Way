// Screen-space vignette + very light film grain: the HD-2D "diorama" frame.
shader_type canvas_item;

uniform float strength = 0.45;
uniform float radius = 0.78;
uniform vec3 tint : source_color = vec3(0.05, 0.03, 0.08);

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= 1.6;
	float d = length(uv);
	float v = smoothstep(radius * 0.55, radius, d);
	COLOR = vec4(tint, v * strength);
}
