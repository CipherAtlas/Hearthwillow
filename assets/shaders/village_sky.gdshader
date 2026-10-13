shader_type sky;

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
  uniform float rain; uniform float dusk; uniform float night; uniform vec3 sunDirection;
      float hash(vec3 p){p=fract(p*.3183099+vec3(.13,.37,.71));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
      float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
        return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
        mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
      float fbm(vec3 p){float f=0.,a=.55;for(int i=0;i<5;i++){f+=noise(p)*a;p=p*2.03+vec3(1.7,3.1,2.4);a*=.48;}return f;}
      
  float mountainPeak(float angle, float frequency, float phase) {
    return 1.-abs(2.*fract((angle*frequency+phase)/6.28318530718)-1.);
  }
  float mountainRidge(float angle, float layer) {
    float phase=layer*1.83;
    return .05+layer*.035+sin(angle*3.+phase)*.028
      +mountainPeak(angle,7.,phase)*.04
      +mountainPeak(angle,13.,-phase*.7)*.085
      +mountainPeak(angle,29.,phase*.4)*.016;
  }
  vec3 mountainHorizon(vec3 sky_color, vec3 d, float mountain_rain, float mountain_dusk, float mountain_night) {
    vec2 bearing=length(d.xz)>.0001 ? normalize(d.xz) : vec2(0.,1.);
    float angle=atan(bearing.x,bearing.y);
    vec3 mist=mix(vec3(.55,.67,.59),vec3(.38,.37,.45),mountain_dusk);
    mist=mix(mist,vec3(.46,.52,.54),mountain_rain*.65);
    mist=mix(mist,vec3(.018,.03,.054),mountain_night);
    if(d.y<-.06) return mist;
    for(int band=2;band>=0;band--) {
      float layer=float(band);
      vec3 cragPosition=vec3(bearing*50.,layer*11.);
      float crestDetail=noise(cragPosition)*.004+noise(cragPosition*2.2)*.0015;
      float ridge=mountainRidge(angle,layer)+crestDetail;
      if(d.y>ridge+.002) continue;
      float edge=1.-smoothstep(ridge-.001,ridge+.001,d.y);
      float depth=max(ridge-d.y,0.);
      vec3 surface=vec3(bearing*34.,d.y*110.+layer*13.);
      float rockMass=noise(surface), brush=noise(surface*1.7);
      float faceAngle=angle+depth*1.2*sin(angle*13.-layer*1.281);
      float slope=(mountainRidge(faceAngle+.002,layer)-mountainRidge(faceAngle-.002,layer))/.004;
      float illumination=clamp(.52-slope*.58+(rockMass-.5)*.20,.08,.95);
      float planes=.22+smoothstep(.30,.40,illumination)*.32+smoothstep(.64,.74,illumination)*.34;
      float face=mix(illumination,planes,.6);
      // Broad painted planes carry the form; smaller marks stay below their contrast.
      float ravinePhase=angle*53.+depth*27.+rockMass*3.+sin(angle*17.+layer)*2.;
      float ravines=pow(.5+.5*sin(ravinePhase),8.);
      float strata=pow(.5+.5*sin(d.y*160.+rockMass*7.+sin(angle*31.)*2.),12.);
      float relief=.96+(brush-.5)*.12-ravines*.17-strata*.04;
      vec3 shadow=mix(vec3(.12,.24,.20),vec3(.27,.33,.47),layer*.5);
      vec3 light=mix(vec3(.38,.49,.31),vec3(.54,.59,.70),layer*.5);
      float stone=smoothstep(.065,.16,d.y)*(1.-layer*.4);
      shadow=mix(shadow,vec3(.19,.29,.34),stone*.65);
      light=mix(light,vec3(.43,.51,.52),stone*.65);
      vec3 rock=mix(shadow,light,face)*relief;
      rock=mix(rock,rock*vec3(1.2,.85,.82),mountain_dusk*.75);
      rock=mix(rock,mist,mountain_rain*.42);
      rock=mix(rock,mix(vec3(.009,.017,.029),vec3(.033,.045,.069),layer*.5)*relief,mountain_night);
      float snowDepth=.014+rockMass*.018+ravines*.012;
      float snow=smoothstep(.15,.205,ridge)*(1.-smoothstep(snowDepth-.002,snowDepth+.002,depth+(brush-.5)*.005));
      vec3 snowColor=mix(vec3(.88,.88,.75),vec3(.80,.61,.56),mountain_dusk);
      snowColor=mix(snowColor,vec3(.50,.57,.60),mountain_rain*.6);
      snowColor=mix(snowColor,vec3(.075,.10,.16),mountain_night);
      snowColor=mix(snowColor*vec3(.66,.77,.94),snowColor,face);
      rock=mix(rock,snowColor,snow);
      float haze=(1.-smoothstep(-.035,.09,d.y))*.88+layer*.075;
      rock=mix(rock,mist,clamp(haze,0.,.95));
      sky_color=mix(sky_color,rock,edge);
    }
    return sky_color;
  }

      void sky(){
        vec3 d=normalize(EYEDIR);float elevation=max(d.y,0.);
        vec3 horizon=mix(vec3(.28,.60,.84),vec3(.33,.30,.42),dusk);
        vec3 zenith=mix(vec3(.045,.28,.72),vec3(.025,.045,.12),dusk);
        vec3 sky_color=mix(horizon,zenith,pow(clamp(elevation*1.7,0.,1.),.55));
        sky_color=mix(sky_color,mix(vec3(.48,.55,.59),vec3(.22,.30,.38),elevation),rain*.88);
        float sun=max(dot(d,sunDirection),0.);
        sky_color+=vec3(1.,.69,.29)*pow(sun,12.)*.5*(1.-rain)*(1.-dusk*.8);
        sky_color+=vec3(1.,.87,.59)*pow(sun,1500.)*4.*(1.-rain)*(1.-dusk);
        vec3 p=d*vec3(5.5,18.,5.5)+vec3(TIME*.006,0.,TIME*.003);
        float mass=fbm(p),detail=fbm(p*2.8+2.1);
        float cloud=smoothstep(.56-rain*.17,.73-rain*.17,mass+detail*.12);
        cloud*=smoothstep(-.035,.09,d.y);
        vec3 shade=mix(vec3(.42,.56,.72),vec3(.27,.30,.39),dusk);
        vec3 lit=mix(vec3(1.,.93,.76),vec3(.79,.55,.49),dusk);
        vec3 cloudColor=mix(shade,lit,smoothstep(.36,.7,mass)+sun*.2);
        cloudColor=mix(cloudColor,vec3(.43,.49,.54),rain*.7);
        sky_color=mix(sky_color,cloudColor,cloud*.94);
        if(night>.001){
        vec3 nightSky=mix(vec3(.0015,.003,.012),vec3(.0001,.0003,.003),pow(clamp(elevation*1.7,0.,1.),.7));
        vec3 galacticNormal=normalize(vec3(.6,.5,.3));
        float latitude=dot(d,galacticNormal);
        float band=exp(-pow(latitude/.18,2.))*smoothstep(.005,.14,d.y);
        float dust=fbm(d*26.+vec3(4.,1.,8.));
        float filaments=fbm(d*72.+vec3(2.,9.,3.));
        float galaxy=band*smoothstep(.27,.64,dust+filaments*.22);
        float rift=smoothstep(.46,.67,fbm(d*45.+vec3(8.,3.,1.)))*.72;
        nightSky+=band*vec3(.008,.012,.032);
        nightSky+=galaxy*(1.-rift)*mix(vec3(.18,.3,.65),vec3(.48,.14,.48),smoothstep(-.3,.3,d.x));
        nightSky+=band*pow(max(filaments-.4,0.),2.)*vec3(.3,.48,.72);
        vec3 starCell=floor(d*165.);
        float starSeed=hash(starCell);
        vec3 starOffset=fract(d*165.)-.5;
        float star=(1.-smoothstep(.06,.23,length(starOffset)))*step(.93,starSeed);
        star*=smoothstep(.005,.12,d.y)*(1.-rain*.8);
        nightSky+=star*mix(vec3(.68,.81,1.),vec3(1.,.88,.68),hash(starCell+7.))*mix(.85,2.7,starSeed);
        vec3 moonDirection=normalize(vec3(-.15,.23,-.96));
        float moonDot=max(dot(d,moonDirection),0.);
        float moonDisc=smoothstep(.99954,.99969,moonDot);
        float moonDetail=fbm(d*150.);
        nightSky+=vec3(.16,.18,.28)*pow(moonDot,220.);
        nightSky=mix(nightSky,vec3(.91,.94,1.)*(.88+moonDetail*.12),moonDisc);
        nightSky=mix(nightSky,vec3(.012,.014,.028),cloud*.08);
        sky_color=mix(sky_color,nightSky,night);
        }
        if(d.y<.32) sky_color=mountainHorizon(sky_color,d,rain,dusk,night);
        
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
COLOR=source_srgb(source_aces(sky_color));
#else
COLOR=sky_color;
#endif

        
        
      }