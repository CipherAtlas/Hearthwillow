shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec2 vUv;
varying float vSeed;
   
      void vertex(){vUv=UV;vSeed=UV2.x;vec3 p=VERTEX;
        p.x+=sin(TIME*2.2+UV.y*5.0+UV2.x)*UV.y*UV.y*.09;
        p.z+=cos(TIME*1.7+UV.y*6.0+UV2.x)*UV.y*.06;
        VERTEX=p;}
  
      float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
      float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
      void fragment(){
        float y=vUv.y;
        float n=noise(vec2(vUv.x*4.0+vSeed,y*4.8-TIME*2.2));
        float fine=noise(vec2(vUv.x*9.0-vSeed,y*9.0-TIME*3.6));
        float curl=sin(y*6.5-TIME*2.5+vSeed)*.10*y;
        float body=.46*pow(1.0-y,.7)-abs(vUv.x-.5+curl)+(n-.5)*.21+(fine-.5)*.055;
        float alpha=smoothstep(-.025,.065,body)*smoothstep(0.0,.12,y)*(1.0-smoothstep(.85,1.0,y))*.72;
        float core=smoothstep(.02,.28,body)*(1.0-y*.6);
        vec3 color=mix(vec3(.96,.19,.025),vec3(1.0,.66,.12),smoothstep(-.02,.13,body));
        color=mix(color,vec3(1.0,.94,.62),core);
        vec4 result_color=vec4(color,alpha); ALBEDO=result_color.rgb; ALPHA=result_color.a;
      }