shader_type spatial;
uniform float motion_amount = 1.0;
render_mode cull_disabled;
uniform bool pond = false;
uniform vec2 weather = vec2(0.0);
varying vec3 world_position;
float water_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float water_noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(water_hash(i),water_hash(i+vec2(1,0)),f.x),mix(water_hash(i+vec2(0,1)),water_hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float is_pond=pond?1.0:0.0;
    float bank=mix(abs(UV.x-.5)*2.0,length(UV-.5)*2.0,is_pond);
    vec2 p=mix(vec2(UV.x*6.4,UV.y),world_position.xz,is_pond);
    p.y-=(TIME * motion_amount)*mix(.9,.12,is_pond);
    float shallow=smoothstep(.42,1.0,bank);
    vec3 water_color=mix(vec3(.0212,.2122,.2384),vec3(.2423,.5841,.5089),shallow*.72);
    water_color=mix(water_color,water_color*vec3(.6,.7,.94),weather.y*.55);
    water_color=mix(water_color,water_color*vec3(.8,.92,.95),weather.x*.4);
    float foam=smoothstep(.79,.93,water_noise(p*vec2(9.0,.85)))*smoothstep(.55,.8,water_noise(p*vec2(3.0,2.8)+vec2(11,7)));
    float edge=smoothstep(.86,.98,bank);
    ALBEDO=mix(water_color,vec3(.84,.95,.91),foam*(.09+edge*.10));
    ROUGHNESS=.32; METALLIC=0.0; CLEARCOAT=.22; CLEARCOAT_ROUGHNESS=.42;
    float h=sin(p.y*7.4+water_noise(vec2(p.x*1.8,p.y*.6))*3.2)*.0065+(water_noise(p*vec2(4,3))-.5)*.014;
    vec3 dx=dFdx(world_position),dy=dFdy(world_position),up=normalize(cross(dx,dy));
    if(up.y<0.0)up=-up;
    vec3 rx=cross(dy,up),ry=cross(up,dx);
    float area=dot(dx,rx);
    vec3 gradient=(rx*dFdx(h)+ry*dFdy(h))/max(abs(area),.000001)*sign(area);
    NORMAL=normalize((VIEW_MATRIX*vec4(normalize(up-gradient*.86),0)).xyz);
}
