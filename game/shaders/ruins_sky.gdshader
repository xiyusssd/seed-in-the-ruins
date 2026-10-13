shader_type sky;
uniform bool linear_pipeline = false;
uniform vec3 sun_direction = vec3(0.44,0.62,0.65);
uniform float recovery : hint_range(0.0,1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
 vec3 d=normalize(EYEDIR);
 float elevation=max(d.y,0.0);
 vec3 top=mix(vec3(0.36,0.36,0.30),vec3(0.43,0.48,0.44),recovery);
 vec3 horizon=mix(vec3(0.63,0.59,0.48),vec3(0.76,0.71,0.57),recovery);
 vec3 col=mix(horizon,top,pow(elevation,0.45));
 if(d.y>0.02) {
  vec2 uv=d.xz/(d.y+0.26)*1.5+vec2(TIME*0.004,TIME*0.0011);
  float n=noise(uv)*0.65+noise(uv*2.05)*0.23+noise(uv*4.1)*0.12;
  float clouds=smoothstep(0.52,0.72,n)*smoothstep(0.03,0.23,d.y);
  col=mix(col,vec3(0.77,0.74,0.63),clouds*0.4);
 }
 float sun=max(dot(d,normalize(sun_direction)),0.0);
 col+=vec3(0.19,0.13,0.055)*pow(sun,40.0);
 col=mix(col,vec3(1.0,0.94,0.79),smoothstep(0.9993,0.9998,sun));
 if(d.y<0.0) col=mix(horizon,vec3(0.19,0.26,0.27),min(-d.y*3.0,1.0));
 COLOR=linear_pipeline ? pow(max(col,vec3(0.0)),vec3(2.2)) : col;
}
