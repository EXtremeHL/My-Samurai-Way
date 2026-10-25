shader_type spatial;
// The stream. Day: the scrolling pixel water texture. Night: dark ink-blue
// water with moon glints and the warm streaks of lanterns reflected in it.
// Reflections are faked (no SSR), so the look is identical in Forward+ and
// in the Compatibility renderer used by the web build.

uniform sampler2D water_tex : source_color, filter_nearest, repeat_enable;
uniform float texels_per_metre = 32.0;
uniform float tex_size = 32.0;
uniform float flow_speed = 0.12;
uniform float night = 0.0;                     // 0 day .. 1 night
uniform vec3 day_tint : source_color = vec3(1.0);
uniform vec3 night_tint : source_color = vec3(0.10, 0.16, 0.30);
uniform vec3 moon_color : source_color = vec3(0.75, 0.85, 1.0);
uniform float glint_amount = 1.0;
// up to 6 reflected lights: xyz = world position, w = strength
uniform vec4 lights[6];
uniform vec3 light_color : source_color = vec3(1.0, 0.62, 0.3);
uniform float pixel = 0.03125;                 // snap reflections to the art's texel grid

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// pixel-snapped world coords keep every effect on the same grid as the textures
	vec2 wp = floor(world_pos.xz / pixel) * pixel;
	vec2 uv = wp * texels_per_metre / tex_size;
	uv.y -= TIME * flow_speed;
	vec3 base = texture(water_tex, uv).rgb;
	vec3 col = mix(base * day_tint, base * night_tint, night);

	// ripple field moving downstream (towards the camera)
	float flow = wp.y + TIME * 0.6;
	float ripple = sin(flow * 9.0 + sin(wp.x * 5.0 + TIME * 0.7) * 1.6) * 0.5 + 0.5;

	vec3 emit = vec3(0.0);
	// moon glints: sparse cells that twinkle along the ripples
	vec2 cell = floor(vec2(wp.x * 10.0, flow * 5.0));
	float h = hash(cell);
	float tw = step(0.975, h) * step(0.6, ripple) * (0.5 + 0.5 * sin(TIME * 2.2 + h * 40.0));
	emit += moon_color * tw * 0.75 * night * glint_amount;
	// a faint cold sheen on the ripple crests, so the stream reads as moving water
	emit += moon_color * smoothstep(0.85, 1.0, ripple) * 0.05 * night;

	// lantern reflections: vertical streaks below each light, broken by ripples
	for (int i = 0; i < 6; i++) {
		vec4 L = lights[i];
		if (L.w <= 0.0) {
			continue;
		}
		float dz = wp.y - L.z;                       // + = towards the camera
		// each row of the reflection is pushed sideways by the ripples, so the
		// streak wobbles and frays instead of stacking up like bricks
		float row = floor(dz * 8.0);
		float wob = (hash(vec2(row, float(i))) - 0.5) * 0.14 * smoothstep(0.0, 2.0, dz)
				+ 0.05 * sin(flow * 3.0 + float(i) * 1.7);
		float dx = abs(wp.x - L.x - wob);
		float along = smoothstep(-0.2, 0.25, dz) * (1.0 - smoothstep(0.4, 2.8, dz));
		float width = mix(0.12, 0.2, smoothstep(0.0, 2.5, dz));
		float across = 1.0 - smoothstep(width * 0.45, width, dx);
		float fray = 0.55 + 0.45 * ripple;
		emit += light_color * across * along * fray * L.w * 0.8 * night;
	}

	ALBEDO = col;
	ROUGHNESS = mix(0.15, 0.08, night);
	SPECULAR = 0.7;
	EMISSION = emit;
}
