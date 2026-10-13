shader_type spatial;
uniform float motion_amount = 1.0;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec2 vUv;
 void vertex(){vUv=UV;VERTEX=VERTEX;}

      void fragment(){vec2 p=(vUv-.5)*2.;float r=length(p),a=atan(p.y,p.x);
        float wave=fract(r*3.-(TIME * motion_amount)*.7+sin(a*7.+(TIME * motion_amount))*.055);
        float ring=(1.-smoothstep(.035,.12,abs(wave-.45)))*(1.-smoothstep(.25,1.,r));
        float churn=(.5+.5*sin(a*11.+r*28.-(TIME * motion_amount)*5.))*(1.-smoothstep(.1,.48,r));
        vec4 result_color=vec4(.86,.97,.92,(ring*.42+churn*.48)*(1.-smoothstep(.82,1.,r))); ALBEDO=result_color.rgb; ALPHA=result_color.a;
        
        
      }