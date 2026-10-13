shader_type spatial;
uniform float motion_amount = 1.0;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec2 vUv;
 
      void vertex(){vUv=UV; vec3 p=VERTEX;
        float free=sin(UV.y*3.14159);
        p.z+=free*(sin(UV.y*26.+(TIME * motion_amount)*6.+UV.x*8.)*.065+sin(UV.y*43.+(TIME * motion_amount)*10.)*.025);
        p.x+=free*sin(UV.y*18.+(TIME * motion_amount)*3.+UV.x*5.)*.045;
        VERTEX=p;}
 
      float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
      float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
        return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
      void fragment(){
        vec2 flow=vec2(vUv.x*18.,vUv.y*32.+(TIME * motion_amount)*7.2);
        float bands=noise(flow+vec2(noise(flow*.45)*1.5,0.));
        float fine=noise(flow*vec2(2.4,1.7)+vec2(3.,(TIME * motion_amount)*1.5));
        float threads=pow(.5+.5*sin(vUv.x*29.+noise(flow*.7)*4.),4.);
        float lip=smoothstep(.89,1.,vUv.y),impact=1.-smoothstep(.02,.2,vUv.y);
        float foam=clamp(smoothstep(.58,.85,bands)*.28+threads*fine*.38+lip*.45+impact*.6,0.,1.);
        vec3 c=mix(vec3(.16,.5,.53),vec3(.46,.8,.79),bands*.6+fine*.2);
        c=mix(c,vec3(.9,.98,.94),foam);
        float edge=smoothstep(0.,.055,vUv.x)*(1.-smoothstep(.945,1.,vUv.x));
        vec4 result_color=vec4(c,edge*(.83+foam*.17)); ALBEDO=result_color.rgb; ALPHA=result_color.a;
      
      
      }