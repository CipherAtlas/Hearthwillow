shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying float fade;
 
      void vertex(){float age=fract(TIME*.65+VERTEX.z),angle=VERTEX.y*6.28318;
        vec3 p=vec3((VERTEX.x-.5)*2.9+cos(angle)*age*1.6,-.06+sin(age*3.14159)*(1.+VERTEX.x),1.1+sin(angle)*age*1.3+age*.7);
        vec4 mv=MODELVIEW_MATRIX*vec4(p,1.);fade=sin(age*3.14159)*.55;
        POSITION=PROJECTION_MATRIX*mv;float point_size=clamp((45.+VERTEX.y*55.)/max(1.,-mv.z),1.,14.);
      
POSITION.xy+=(UV-.5)*point_size*2.0/VIEWPORT_SIZE*POSITION.w;
}
void fragment(){float r=length(UV-.5)*2.;
      vec4 result_color=vec4(.86,.98,.95,(1.-smoothstep(.15,1.,r))*fade); ALBEDO=result_color.rgb; ALPHA=result_color.a;
      
      
    }