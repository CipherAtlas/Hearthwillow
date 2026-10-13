shader_type canvas_item;
uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
	vec3 scene = textureLod(scene_texture, SCREEN_UV, 1.0).rgb;
	COLOR = vec4(mix(scene, vec3(0.0745, 0.1686, 0.1373), 0.2), 1.0);
}
