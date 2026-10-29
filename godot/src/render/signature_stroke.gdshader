shader_type canvas_item;
render_mode unshaded;

// Stroke geometry is shared across effect radii. UV holds the miter offset;
// CUSTOM0 holds end-cap direction, authored width and inner/feather role.
// Ordinary CanvasItem primitives have no CUSTOM0 marker and pass through.
uniform float board_scale = 0.52;
void vertex() {
	if (CUSTOM0.w > 0.5) {
		float radius = max(length(MODEL_MATRIX[0].xy) / board_scale, 0.001);
		float width = CUSTOM0.z / radius;
		float base = width <= 2.50001 ? width * 0.5 :
			(width <= 5.00001 ? mix(width * 0.5, width - 0.625, (width - 2.5) / 2.5) : width - 0.625);
		float border = 1.25 * min(1.0, base);
		VERTEX += UV * (base * 0.5 + (CUSTOM0.w > 1.5 ? border : 0.0)) + CUSTOM0.xy * border;
		UV = vec2(0.0);
	}
}
