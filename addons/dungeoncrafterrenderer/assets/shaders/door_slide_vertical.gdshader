shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform sampler2D texture_albedo : source_color;
uniform float slide = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.y -= slide;

	vec4 tex = vec4(0.0);
	if (uv.y < 0.0 || uv.y > 1.0) {
		tex = vec4(0.0);
	} else {
		tex = texture(texture_albedo, uv);
	}

	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}
