"""Translate the source village's small GLSL effects into saved Godot shaders."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'assets/village/manifest.json').read_text())
shaders = ROOT / 'assets/shaders'
shaders.mkdir(exist_ok=True)


def clean(source):
    source = re.sub(r'#include\s*<[^>]+>', '', source)
    source = re.sub(r'uniform\s+float\s+time\s*;', '', source)
    source = re.sub(r'\btime\b', 'TIME', source)
    source = re.sub(r'\batan\s*\(', 'atan(', source)
    # Godot's shader functions do not permit the implicit double literals GLSL accepts.
    return source


def spatial(material):
    vertex, fragment = clean(material['vertexShader']), clean(material['fragmentShader'])
    declarations = []
    for source in [vertex, fragment]:
        for declaration in re.findall(r'(?:varying|uniform)\s+\w+\s+\w+\s*;', source):
            if declaration not in declarations:
                declarations.append(declaration)
    vertex = re.sub(r'(?:varying|uniform|attribute)\s+\w+\s+\w+\s*;', '', vertex)
    fragment = re.sub(r'(?:varying|uniform)\s+\w+\s+\w+\s*;', '', fragment)
    vertex = vertex.replace('void main()', 'void vertex()')
    vertex = re.sub(r'gl_Position\s*=\s*projectionMatrix\s*\*\s*modelViewMatrix\s*\*\s*vec4\((\w+),\s*1(?:\.0*)?\)\s*;', r'VERTEX=\1;', vertex)
    vertex = re.sub(r'\bposition\b', 'VERTEX', vertex)
    vertex = re.sub(r'\buv\b', 'UV', vertex)
    vertex = re.sub(r'\bflameSeed\b', 'UV2.x', vertex)
    fragment = fragment.replace('void main()', 'void fragment()')
    fragment = re.sub(r'gl_FragColor\s*=\s*([^;]+);', r'vec4 result_color=\1; ALBEDO=result_color.rgb; ALPHA=result_color.a;', fragment)
    return 'shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never;\n' + '\n'.join(declarations) + '\n' + vertex + '\n' + fragment


def points(material):
    vertex, fragment = clean(material['vertexShader']), clean(material['fragmentShader'])
    declarations = []
    for source in [vertex, fragment]:
        for declaration in re.findall(r'(?:varying|uniform)\s+\w+\s+\w+\s*;', source):
            if declaration not in declarations:
                declarations.append(declaration)
    vertex = re.sub(r'(?:varying|uniform)\s+\w+\s+\w+\s*;', '', vertex)
    fragment = re.sub(r'(?:varying|uniform)\s+\w+\s+\w+\s*;', '', fragment)
    vertex = vertex.replace('void main()', 'void vertex()').replace('modelViewMatrix', 'MODELVIEW_MATRIX').replace('projectionMatrix', 'PROJECTION_MATRIX')
    vertex = re.sub(r'\bposition\b', 'VERTEX', vertex)
    vertex = vertex.replace('gl_Position', 'POSITION').replace('gl_PointSize=', 'float point_size=')
    # Four repeated seeds become a screen-facing quad with the source's pixel size.
    end = vertex.rfind('}')
    vertex = vertex[:end] + '\nPOSITION.xy+=(UV-.5)*point_size*2.0/VIEWPORT_SIZE*POSITION.w;\n' + vertex[end:]
    fragment = fragment.replace('void main()', 'void fragment()').replace('gl_PointCoord', 'UV')
    fragment = re.sub(r'gl_FragColor\s*=\s*([^;]+);', r'vec4 result_color=\1; ALBEDO=result_color.rgb; ALPHA=result_color.a;', fragment)
    mode = ', blend_add' if material.get('additive') else ''
    return 'shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never' + mode + ';\n' + '\n'.join(declarations) + '\n' + vertex + '\n' + fragment


for i, material in enumerate(manifest['materials']):
    if material.get('fragmentShader'):
        (shaders / f'original_{i}.gdshader').write_text(points(material) if material.get('points') else spatial(material))

sky = clean(manifest['sky']['fragmentShader'])
sky = re.sub(r'varying\s+vec3\s+direction\s*;', '', sky)
helper_start = sky.index('vec3 mountainHorizon(')
helper_end = sky.index('void main()')
helper = sky[helper_start:helper_end]
for name in ['rain', 'dusk', 'night']:
    helper = re.sub(r'\b' + name + r'\b', 'mountain_' + name, helper)
sky = sky[:helper_start] + helper + sky[helper_end:]
sky = re.sub(r'\bsky\b', 'sky_color', sky)
sky = sky.replace('void main()', 'void sky()').replace('normalize(direction)', 'normalize(EYEDIR)')
sky = sky.replace('gl_FragColor=vec4(sky_color,1.);', 'COLOR=sky_color;')
sky_tone = '''
vec3 source_aces(vec3 value) {
    mat3 input_matrix=mat3(vec3(.59719,.076,.0284),vec3(.35458,.90834,.13383),vec3(.04823,.01566,.83777));
    mat3 output_matrix=mat3(vec3(1.60475,-.10208,-.00327),vec3(-.53108,1.10813,-.07276),vec3(-.07367,-.00605,1.07602));
    value=input_matrix*(value*1.02/.6);
    value=(value*(value+.0245786)-.000090537)/(value*(.983729*value+.4329510)+.238081);
    return clamp(output_matrix*value,vec3(0),vec3(1));
}
vec3 source_srgb(vec3 value) {
    return mix(value*12.92,1.055*pow(max(value,vec3(0)),vec3(1.0/2.4))-.055,step(vec3(.0031308),value));
}
'''
sky = sky.replace('COLOR=sky_color;', '\n#if CURRENT_RENDERER == RENDERER_COMPATIBILITY\nCOLOR=source_srgb(source_aces(sky_color));\n#else\nCOLOR=sky_color;\n#endif\n')
(shaders / 'village_sky.gdshader').write_text('shader_type sky;\n' + sky_tone + sky)

# Water retains the source's UV-distance flow, bank palette and restrained foam.
(shaders / 'water.gdshader').write_text('''shader_type spatial;
render_mode cull_disabled;
uniform bool pond = false;
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
    p.y-=TIME*mix(.9,.12,is_pond);
    float shallow=smoothstep(.42,1.0,bank);
    vec3 water_color=mix(vec3(.0212,.2122,.2384),vec3(.2423,.5841,.5089),shallow*.72);
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
''')

(shaders / 'foliage.gdshader').write_text('''shader_type spatial;
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
''')

(shaders / 'surface.gdshader').write_text('''shader_type spatial;
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
''')
print('Prepared original sky, flame, waterfall, water and foliage shaders.')

(shaders / 'garden_breeze.gdshader').write_text(r'''shader_type spatial;
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
''')
