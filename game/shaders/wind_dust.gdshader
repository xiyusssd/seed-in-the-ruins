shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float wind_clock = 0.0;
uniform float gust = 0.5;
uniform float opacity = 0.10;
uniform vec4 dust_tint : source_color = vec4(.67,.59,.43,1.0);
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);}
void vertex(){
 // Keep instance scale while facing the camera; shadows and collision are disabled on the node.
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
}
void fragment(){
 vec2 uv=UV*2.0-1.0;
 float edge=(1.0-smoothstep(.35,1.0,abs(uv.x)))*(1.0-smoothstep(.18,1.0,abs(uv.y)));
 float cloud=noise(UV*vec2(8,3)+vec2(-wind_clock*.45,wind_clock*.08));
 ALBEDO=dust_tint.rgb;
 ALPHA=edge*smoothstep(.15,.7,cloud)*opacity*(.45+gust*.55);
}
