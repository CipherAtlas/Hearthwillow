shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(1);
uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D shoulder_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_texture = false;
uniform bool vertex_colors = false;
uniform bool foot_shade = false;
uniform int surface_mode = 0;
uniform vec2 uv_scale = vec2(1);
uniform vec2 uv_offset = vec2(0);
uniform float surface_roughness = 1.0;
varying vec3 world_position;
float meadow_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float meadow_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(meadow_hash(i),meadow_hash(i+vec2(1,0)),f.x),mix(meadow_hash(i+vec2(0,1)),meadow_hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
    vec3 base=tint.rgb;
    if(has_texture)base*=texture(surface_texture,UV*uv_scale+uv_offset).rgb;
    if(surface_mode!=2 && vertex_colors)base*=COLOR.rgb;
    if(surface_mode==1){
        float meadow=dot(base,vec3(.2126,.7152,.0722));
        float patch=meadow_noise(world_position.xz*.065)*.7+meadow_noise(world_position.xz*.21)*.3;
        base=mix(vec3(.16,.28,.035),vec3(.38,.51,.10),patch)*(.68+meadow*1.8);
    } else if(surface_mode==2){
        float edge=1.0-COLOR.r;
        float breakup=sin(world_position.x*19.0+sin(world_position.z*11.0))*sin(world_position.z*23.0);
        float blend=smoothstep(.1,.85,edge+breakup*.12);
        float detail=texture(shoulder_texture,world_position.xz*.3).g;
        vec3 soil=vec3(.21,.31,.065)*(.75+detail);
        if(OUTPUT_IS_SRGB)soil=pow(soil,vec3(1.0/2.2));
        base=mix(base,soil,blend);
    }
    float grain=sin(world_position.x*3.7+sin(world_position.z*2.3))*sin(world_position.y*4.1+world_position.z*1.8);
    base*=.985+grain*.015;
    if(foot_shade)base*=mix(.86,1.0,smoothstep(.06,1.4,world_position.y));
    ALBEDO=base; ROUGHNESS=surface_roughness;
}
