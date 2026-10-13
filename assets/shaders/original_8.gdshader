shader_type spatial;
uniform float motion_amount = 1.0;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform vec2 scale;
varying float vAge;

        void vertex(){float age=fract(VERTEX.x+(TIME * motion_amount)*.21);vAge=age;
          vec3 p=vec3(VERTEX.y*scale.x*.6+sin(age*6.0+VERTEX.x*19.0)*age*scale.x*.3,
            -scale.y*.25+age*scale.y*2.2,VERTEX.z*scale.x*.4);
          vec4 mv=MODELVIEW_MATRIX*vec4(p,1.0);POSITION=PROJECTION_MATRIX*mv;
          float point_size=clamp((2.0+VERTEX.x*3.0)*scale.x/max(1.0,-mv.z),1.0,80.0);
POSITION.xy+=(UV-.5)*point_size*2.0/VIEWPORT_SIZE*POSITION.w;
}
void fragment(){float d=length(UV-.5)*2.0;
        float a=pow(max(0.0,1.0-d),1.4)*sin(vAge*3.14159)*.8;
        vec4 result_color=vec4(vec3(1.0,.53,.12),a); ALBEDO=result_color.rgb; ALPHA=result_color.a;}