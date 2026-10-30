shader_type canvas_item;
render_mode unshaded;
// Read only the copied base level: old WebGL drivers reject the engine's
// same-texture mipmap generation. Bilinear taps approximate a Gaussian blur.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 tint : source_color;
uniform float blur = 2.5;
uniform float amount = 1.0;

void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE * exp2(blur) * 0.6;
	vec4 background = vec4(0.0);
	for (int y = -2; y <= 2; y++) {
		float wy = y == 0 ? 6.0 : (abs(y) == 1 ? 4.0 : 1.0);
		for (int x = -2; x <= 2; x++) {
			float wx = x == 0 ? 6.0 : (abs(x) == 1 ? 4.0 : 1.0);
			background += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * step_size) * wx * wy / 256.0;
		}
	}
	COLOR = vec4(mix(background.rgb, tint.rgb, tint.a), amount * COLOR.a);
}
