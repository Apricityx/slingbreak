shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 tint : source_color;
uniform float blur = 2.5;
uniform float amount = 1.0;
void fragment() {
	vec4 background = textureLod(screen_texture, SCREEN_UV, blur);
	COLOR = vec4(mix(background.rgb, tint.rgb, tint.a), amount * COLOR.a);
}
