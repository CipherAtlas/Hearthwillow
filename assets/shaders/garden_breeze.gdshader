shader_type spatial;
render_mode cull_disabled;
void vertex() {
    vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
    float phase=origin.x*.8+origin.z*.6;
    float height=max(0.0,VERTEX.y);
    VERTEX.x+=sin(TIME*1.3+phase+VERTEX.y)*.025*height;
    VERTEX.z+=sin(TIME*.9+phase)*.018*height;
}
void fragment() {
    ALBEDO=COLOR.rgb;
    ROUGHNESS=.75;
}
