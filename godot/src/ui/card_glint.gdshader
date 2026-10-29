shader_type canvas_item;
render_mode unshaded;

uniform float progress = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.97, 0.85, 0.8);

void fragment() {
	// A diagonal, feathered band crosses the card, with no hard rectangle edges.
	float diagonal = UV.x + (UV.y - 0.5) * 0.32;
	float center = mix(-0.45, 1.45, progress);
	float sheen = max(0.0, 1.0 - abs(diagonal - center) / 0.2);
	COLOR = vec4(tint.rgb, tint.a * sheen * COLOR.a);
}
