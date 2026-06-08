shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D dissolve_texture;

void fragment() {
	vec4 main_color = texture(TEXTURE, UV);
	vec4 noise_color = texture(dissolve_texture, UV);
	
	if (noise_color.r < dissolve_amount) {
		discard;
	}
	
	COLOR = main_color;
}
