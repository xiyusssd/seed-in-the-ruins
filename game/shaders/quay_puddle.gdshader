shader_type spatial;
render_mode cull_disabled, depth_draw_never;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*2.-1.;
 float edge=length(p*vec2(1.,1.10))+(noise2(UV*5.)-.5)*.22;
 ALBEDO=vec3(.045,.065,.062);
 ROUGHNESS=.09;METALLIC=0.0;SPECULAR=.65;
 vec2 ripple=vec2(0.0);
 for(int i=0;i<3;i++){
  float seed=float(i);
  vec2 centre=vec2(.24+hash2(vec2(seed,3.))*.52,.24+hash2(vec2(seed,9.))*.52);
  vec2 delta=UV-centre;
  float radius=length(delta);
  float age=mod(TIME+seed*1.73,5.7);
  float ring=exp(-pow((radius-age*.095)*75.,2.))*exp(-age*2.8);
  ripple+=normalize(delta+vec2(.00001))*ring*.015*sin(radius*120.-age*12.);
 }
 float footprint=max(length(dFdx(UV)),length(dFdy(UV)));
 ripple*=1.-smoothstep(.009,.035,footprint);
 NORMAL_MAP=normalize(vec3(ripple,1.))*.5+.5;NORMAL_MAP_DEPTH=.5;
 ALPHA=(1.-smoothstep(.62,.95,edge))*.72;
}
