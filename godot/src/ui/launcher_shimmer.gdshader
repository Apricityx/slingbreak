shader_type canvas_item;
// CSS launcher-shimmer: 2.2 seconds, traverse during the first 75%, then hold.
void fragment() {
	float p = min(mod(TIME, 2.2) / 1.65, 1.0);
	float x = UV.x - mix(-1.0, 1.0, p) + (UV.y - 0.5) * 0.025;
	float alpha = max(0.0, 1.0 - abs(x - 0.5) / 0.3) * 0.5;
	COLOR = vec4(1.0, 1.0, 1.0, alpha);
}
