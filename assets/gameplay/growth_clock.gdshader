shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 point = (UV - vec2(0.5)) * 192.0;
	float radius = length(point);
	float edge = max(fwidth(radius), 0.25);
	float ring = 1.0 - smoothstep(4.5 - edge, 4.5 + edge, abs(radius - 69.0));
	float angle = mod(atan(point.x, -point.y) + 6.28318530718, 6.28318530718);
	float end_angle = progress * 6.28318530718;
	vec2 end_point = vec2(sin(end_angle), -cos(end_angle)) * 69.0;
	float caps = min(length(point - vec2(0.0, -69.0)), length(point - end_point));
	float completed = max(ring * step(angle, end_angle), (1.0 - smoothstep(4.5 - edge, 4.5 + edge, caps)) * step(0.00001, progress));
	vec3 cream = vec3(0.980392, 0.952941, 0.870588);
	vec3 track = vec3(0.843137, 0.874510, 0.776471);
	vec3 green = vec3(0.325490, 0.470588, 0.313725);
	// ALBEDO expects linear color; the original canvas palette is sRGB.
	vec3 color = mix(mix(cream, track, ring), green, completed);
	ALBEDO = mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), color));
	ALPHA = 1.0 - smoothstep(84.0 - edge, 84.0 + edge, radius);
}
