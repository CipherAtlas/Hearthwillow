shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_texture = false;
uniform bool vertex_colors = true;
uniform float sway = .17;
uniform bool tree = false;
varying vec3 instance_origin;
void vertex() {
    instance_origin=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;
    float weight=tree?pow(clamp(VERTEX.y/8.0,0.0,1.0),2.0):pow(max(0.0,VERTEX.y),2.0);
    float wave=sin(TIME*1.2+instance_origin.x*.31+instance_origin.z*.24+VERTEX.y*1.8);
    float slow=sin(TIME*.23)*.5+.5;
    float gust=pow(max(0.0,sin(TIME*.61-.7)),3.0);
    float wind=.22+slow*.18+gust*.34;
    VERTEX.x+=weight*wave*wind*sway;
    VERTEX.z+=weight*sin(TIME*.83+instance_origin.x*.19+VERTEX.y)*wind*sway*.36;
}
void fragment() {
    vec4 vertex_tint=vertex_colors?COLOR:vec4(1);
    if(OUTPUT_IS_SRGB)vertex_tint.rgb=pow(max(vertex_tint.rgb,vec3(0)),vec3(1.0/2.2));
    vec4 base=tint*vertex_tint;
    if(has_texture)base*=texture(surface_texture,UV);
    ALBEDO=base.rgb; ROUGHNESS=1.0;
}
