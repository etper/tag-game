shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 glow_color : source_color = vec4(1.0, 0.1, 0.1, 1.0);
uniform float fresnel_power = 3.0;
uniform float glow_strength = 4.0;

void fragment() {
	float fresnel = pow(
		1.0 - dot(NORMAL, VIEW),
		fresnel_power
	);

	ALBEDO = glow_color.rgb;
	EMISSION = glow_color.rgb * fresnel * glow_strength;
	ALPHA = fresnel;
}