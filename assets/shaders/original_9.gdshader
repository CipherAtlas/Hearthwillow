shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec2 scale;
varying float vAge;

        void vertex(){float age=fract(VERTEX.x+TIME*.085);vAge=age;
          vec3 p=vec3(VERTEX.y*scale.x*.6+sin(age*6.0+VERTEX.x*19.0)*age*scale.x*.3,
            -scale.y*.25+age*scale.y*2.9,VERTEX.z*scale.x*.4);
          vec4 mv=MODELVIEW_MATRIX*vec4(p,1.0);POSITION=PROJECTION_MATRIX*mv;
          float point_size=clamp((18.0+age*52.0)*scale.x/max(1.0,-mv.z),1.0,80.0);
POSITION.xy+=(UV-.5)*point_size*2.0/VIEWPORT_SIZE*POSITION.w;
}
void fragment(){float d=length(UV-.5)*2.0;
        float a=pow(max(0.0,1.0-d),2.0)*sin(vAge*3.14159)*.12;
        vec4 result_color=vec4(vec3(.43,.46,.44),a); ALBEDO=result_color.rgb; ALPHA=result_color.a;}