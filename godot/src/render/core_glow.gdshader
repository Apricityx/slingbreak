shader_type canvas_item;
render_mode unshaded;

uniform vec4 tint : source_color;
uniform float sigma = 9.0;
uniform float extent = 55.0;

void fragment() {
	vec2 point = abs((UV - vec2(0.5)) * extent * 2.0);
	// Rounded 42px square. A Gaussian falloff outside the silhouette leaves
	// the vector face crisp while avoiding visible stacked halo rectangles.
	vec2 corner = point - vec2(17.0);
	float distance = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - 4.0;
	float outside = max(distance, 0.0);
	float halo = 0.5 * exp(-0.5 * outside * outside / (sigma * sigma));
	COLOR = vec4(tint.rgb, tint.a * halo);
}
