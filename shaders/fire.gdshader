shader_type spatial;
// Animated pixel-art flame card: unshaded, HDR-bright so it blooms, frames
// stepped from TIME (no script needed). Works in Forward+ and Compatibility.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D strip : source_color, filter_nearest;
uniform float frames = 6.0;
uniform float fps = 10.0;
uniform float energy = 2.2;
uniform float phase = 0.0;

void fragment() {
	float f = floor(mod(TIME * fps + phase, frames));
	vec4 c = texture(strip, vec2((UV.x + f) / frames, UV.y));
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * energy;
}
