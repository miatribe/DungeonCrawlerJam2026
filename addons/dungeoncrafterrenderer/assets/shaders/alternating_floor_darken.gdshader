shader_type spatial;

uniform sampler2D texture_albedo : source_color;
uniform float darken = 0.9;
uniform float cell_world_size = 2.0;

void fragment() {
	vec4 alb_tex = texture(texture_albedo, UV);
	ALBEDO = alb_tex.rgb;

	// Use the instance origin so each floor tile gets a single checker value.
	vec2 tile_index = floor(MODEL_MATRIX[3].xz / cell_world_size);
	float checker = mod(tile_index.x + tile_index.y, 2.0);
	if (checker < 0.0) {
		checker += 2.0;
	}

	if (checker < 0.5) {
		ALBEDO = alb_tex.rgb * darken;
	}
}
