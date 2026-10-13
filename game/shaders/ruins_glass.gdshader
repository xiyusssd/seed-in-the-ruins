shader_type spatial;
render_mode cull_disabled, depth_draw_never;
// Dry mineral deposits at the frame; residual rain beads on the clear glass.
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment() {
    vec2 pane = UV;
    float edge = pow(abs(pane.x - 0.5) * 2.0, 8.0) + pow(abs(pane.y - 0.5) * 2.0, 10.0);
    float trails = pow(0.5 + 0.5 * sin(pane.x * 143.0 + sin(pane.x * 31.0) * 4.0), 22.0);
    float fade = smoothstep(0.1, 0.9, pane.y);
    vec2 grid=pane*vec2(26.,31.);vec2 cell=floor(grid);
    vec2 center=vec2(.25+hash2(cell)*.5,.25+hash2(cell+7.)*.5);
    float bead=(1.-smoothstep(.04,.15,length((fract(grid)-center)*vec2(1.0,.65))))*step(.80,hash2(cell+13.));
    float grazing=pow(1.-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.,1.),5.);
    float deposits=clamp(edge*.5+trails*fade*.13,0.,1.);
    ALBEDO = mix(vec3(.66,.72,.69),vec3(.51,.48,.39),deposits);
    ROUGHNESS = .11 + deposits*.43;
    SPECULAR = .50;
    vec2 water_normal=(fract(grid)-center)*bead*.20;
    NORMAL_MAP=normalize(vec3(water_normal,1.))*.5+.5;NORMAL_MAP_DEPTH=.3;
    ALPHA = clamp(.045 + deposits*.16 + bead*.10 + grazing*.15,0.,.32);
}
