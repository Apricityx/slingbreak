shader_type canvas_item;
render_mode unshaded;
// V5 relic eye: an obsidian almond socket with gilded rims and spines, a pearl
// globe, a layered iris whose pupil opens onto a starfield, and a twelve-crystal
// ward ring drawn on the real 57 px collider. Everything stays inside the
// original 360 x 168 carrier; no screen texture, particles or CPU uploads.
uniform float clock=0.0;
uniform float opening=1.0;
uniform float presence=1.0;
uniform float spread=0.0;
uniform float morph=0.0;
uniform float stage=1.0;
uniform float charge=0.0;
uniform float flash=0.0;
uniform float ritual=0.0;
uniform float upper_lid=1.0;
uniform float lower_lid=1.0;
uniform float focus=0.0;
uniform float fracture=0.0;
uniform float recoil=0.0;
uniform float rift_open=1.0;
uniform float emergence=1.0;
uniform float heat=0.0;
uniform float laser_pulse=0.0;
uniform float ward=1.0;
uniform float ward_show=1.0;
uniform float ward_flash=0.0;
uniform float dilate=0.0;
uniform float damage=0.0;
uniform bool light_theme=false;
uniform vec2 wound=vec2(0.0,1.0);
uniform vec2 look=vec2(0.0);
uniform vec4 violet : source_color=vec4(0.61,0.45,1.0,1.0);
varying vec2 point;
void vertex(){point=VERTEX;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*0.56+noise(p*2.07+13.7)*0.28+noise(p*4.13-8.4)*0.16;}
float mask(float d){return 1.0-smoothstep(-0.75,0.75,d);}
float segment(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));}
// Tapered spine: full width w at the root a, a fine point at the tip b.
float spine(vec2 p,vec2 a,vec2 b,float w){vec2 v=b-a;float h=clamp(dot(p-a,v)/dot(v,v),0.0,1.0);return length(p-a-v*h)-w*(1.0-h);}
// Almond profile: rounded centre, fine canthus points.
float almond(float x,float w){return pow(max(0.0,1.0-pow(x/w,2.0)),0.7);}
float stars(vec2 p,float cell){
 vec2 id=floor(p/cell);vec2 q=mod(p,cell)-cell*(0.18+vec2(hash(id),hash(id+37.0))*0.64);
 float spark=exp(-length(q)*2.2)+0.2*exp(-abs(q.x)*5.0-abs(q.y)*0.4)+0.2*exp(-abs(q.y)*5.0-abs(q.x)*0.4);
 return spark*step(0.74,hash(id+84.1))*(0.65+0.35*sin(clock*1.6+hash(id)*18.0));
}
void fragment(){
 vec2 p=point;float t=clock;float ex=abs(p.x);
 vec3 ink=mix(violet.rgb,vec3(0.88,0.36,0.80),clamp(stage-1.0,0.0,1.0));
 ink=mix(ink,vec3(1.0,0.60,0.24),clamp(stage-2.0,0.0,1.0));
 vec3 gold=vec3(0.97,0.80,0.50);
 vec3 cyan=vec3(0.38,0.84,1.0);
 vec3 crimson=vec3(1.0,0.10,0.16);
 vec3 hot=mix(ink,crimson,heat);
 // Halo: a soft elliptical well of deep space behind the relic.
 float hr=length(p/vec2(178.0,82.0));
 float halo=1.0-smoothstep(0.40,1.0,hr/max(0.05,rift_open));
 float theta=atan(p.y*2.1,p.x);
 float cloud=fbm(p*vec2(0.018,0.034)+vec2(t*0.05,-t*0.03));
 vec3 space=mix(vec3(0.02,0.012,0.06),hot*0.40,cloud*0.85*(1.0-hr*0.6));
 space+=vec3(0.75,0.86,1.0)*(stars(p+vec2(t*1.2,0),17.0)+stars(p-vec2(t*0.5,6),29.0)*0.7)*0.75;
 float rays=pow(0.5+0.5*sin(theta*9.0+t*0.22),7.0)*smoothstep(0.25,0.5,hr)*(1.0-smoothstep(0.5,0.98,hr));
 space+=hot*rays*(0.20+0.55*ritual+0.4*heat);
 vec4 col=vec4(space,halo*(light_theme?0.80:0.92));
 // Socket shells part vertically during transformation, exposing a lit seam.
 float shell=spread*16.0;
 float reveal=smoothstep(0.05,0.6,emergence);
 float h_up=shell+10.0+44.0*almond(ex,158.0);
 float h_dn=shell+8.0+36.0*almond(ex,150.0);
 float socket=max(p.y<0.0?-p.y-h_up:p.y-h_dn,ex-158.0);
 float seam=mask(abs(p.y)-shell*almond(ex,150.0));
 // Gilded spines crown the upper shell and steady the lower one.
 float spines=1e4;
 for(int i=0;i<7;i++){
  float x=-132.0+44.0*float(i);
  vec2 root=vec2(x,-(shell+6.0+44.0*almond(abs(x),158.0)));
  float len=mix(22.0,13.0,abs(x)/132.0);
  vec2 tip=root+normalize(vec2(x*0.006+sin(t*0.7+float(i))*0.05,-1.0))*len;
  spines=min(spines,spine(p,root,tip,5.5));
 }
 for(int j=0;j<5;j++){
  float x=-96.0+48.0*float(j);
  vec2 root=vec2(x,shell+4.0+36.0*almond(abs(x),150.0));
  spines=min(spines,spine(p,root,root+normalize(vec2(x*0.004,1.0))*mix(18.0,12.0,abs(x)/96.0),4.5));
 }
 vec3 spine_col=mix(vec3(0.05,0.035,0.10),hot*0.6,0.25)+gold*exp(-abs(spines)*0.9)*0.75;
 col=mix(col,vec4(spine_col,1),mask(spines)*reveal);
 float depth=clamp(-socket/22.0,0.0,1.0);
 vec3 lid=mix(vec3(0.17,0.13,0.28),vec3(0.035,0.025,0.075),depth);
 lid+=hot*(0.10+0.35*ritual)*pow(0.5+0.5*sin(socket*0.55),8.0);
 lid+=vec3(0.62,0.56,0.86)*0.30*exp(-abs(socket)*0.35)*step(p.y,0.0);
 lid+=hot*exp(-abs(socket)*1.1)*0.9;
 col=mix(col,vec4(lid,1),mask(socket)*(1.0-seam)*reveal);
 col.rgb+=mix(hot,vec3(1),0.45)*seam*mask(socket)*morph*1.4;
 // Eye aperture and pearl globe; recoil nudges the contents along the wound.
 vec2 e=p-wound*recoil*4.0;
 float ap_up=(1.2+opening*upper_lid*37.0)*almond(abs(e.x),112.0);
 float ap_dn=(1.2+opening*lower_lid*31.0)*almond(abs(e.x),112.0);
 float eye_d=max(e.y<0.0?-e.y-ap_up:e.y-ap_dn,abs(e.x)-112.0);
 float globe=sqrt(max(0.0,1.0-pow(e.x/122.0,2.0)-pow(e.y/48.0,2.0)));
 vec3 sclera=mix(vec3(0.20,0.18,0.38),vec3(0.89,0.87,0.97),globe);
 float veins=pow(max(0.0,1.0-abs(fbm(e*0.05+3.0)-0.5)*9.0),4.0)*smoothstep(38.0,108.0,abs(e.x));
 sclera=mix(sclera,mix(ink,crimson,0.4+0.6*heat)*0.75,veins*(0.12+0.4*heat+0.35*damage));
 // Iris: warm core, violet stroma, dark limbal ring, gilded collarette.
 vec2 q=e-look;float r=length(q);float a=atan(q.y,q.x);float n=r/42.0;
 float fib=noise(vec2(a*20.0,r*0.1-t*0.05));
 float streak=pow(abs(sin(a*30.0+fib*4.0+r*0.05)),3.0);
 vec3 iris=mix(gold*1.05,ink,smoothstep(0.25,0.9,n));
 iris*=0.48+0.36*fib+0.30*streak;
 iris=mix(iris,mix(vec3(1.0,0.78,0.52),crimson,smoothstep(0.1,0.8,n)),heat*0.88);
 iris+=cyan*exp(-abs(r-33.0)*0.5)*0.25*(1.0-heat);
 iris*=1.0-0.78*smoothstep(0.82,1.0,n);
 float pw=mix(6.5,22.0,dilate)*(1.0-0.22*focus);
 float ph=mix(29.0,24.5,dilate);
 float pd=(length(q/vec2(pw,ph))-1.0)*min(pw,ph);
 iris+=gold*exp(-abs(pd-3.0)*0.8)*(0.45+0.4*dilate);
 vec3 abyss=vec3(0.006,0.004,0.02);
 abyss+=ink*0.35*pow(0.5+0.5*sin(a*2.0-r*0.32+t*0.9),6.0)*dilate*(1.0-smoothstep(4.0,24.0,r));
 abyss+=vec3(0.8,0.9,1.0)*stars(q*1.5+vec2(t*2.0,0),8.0)*dilate*0.9;
 abyss+=crimson*exp(-r*0.13)*heat*(0.7+laser_pulse*0.8);
 abyss+=gold*exp(-r*0.11)*charge*1.2;
 iris=mix(iris,abyss,mask(pd));
 float hl=exp(-length((q-vec2(-14,-15))*vec2(0.32,0.46))*1.3)*0.95+exp(-length(q-vec2(11,12))*0.55)*0.35;
 iris+=vec3(0.95,0.97,1.0)*hl;
 vec3 globe_col=mix(sclera,iris,mask(r-42.0));
 globe_col*=0.42+0.58*smoothstep(0.0,15.0,e.y+ap_up);
 // Break wound and accumulated phase damage: glowing fissures in the globe.
 vec2 w=vec2(dot(e,wound),dot(e,vec2(-wound.y,wound.x)));
 float cut=min(segment(w,vec2(46,0),vec2(14,9)),segment(w,vec2(14,9),vec2(-32,-5)));
 cut=min(cut,segment(w,vec2(14,9),vec2(-4,30)));
 float scar=min(segment(e,vec2(-104,4),vec2(-62,-9)),segment(e,vec2(-62,-9),vec2(-48,6)))+(1.0-step(0.3,damage))*1e3;
 scar=min(scar,min(segment(e,vec2(98,-6),vec2(60,8)),segment(e,vec2(60,8),vec2(52,-12)))+(1.0-step(0.62,damage))*1e3);
 float crack=max(mask(cut-1.5)*max(fracture,morph),mask(scar-1.1));
 globe_col=mix(globe_col,mix(hot,vec3(1),0.35)*1.3,crack);
 float eye_mask=mask(eye_d)*reveal;
 col=mix(col,vec4(globe_col,1),eye_mask);
 col.rgb+=gold*exp(-abs(eye_d)*0.85)*0.95*reveal;
 col.rgb+=crimson*exp(-abs(eye_d)*0.25)*heat*0.45;
 // Ward: twelve crystals on the 57 px collider; lit count follows the meter.
 float wr=length(p);float cell=6.2831853/12.0;
 float wa=mod(atan(p.x,-p.y)+t*0.22,6.2831853);
 float idx=floor(wa/cell);
 float dt=(mod(wa,cell)-cell*0.5)*57.0;float dr=wr-57.0;
 float crystal=(abs(dr)/6.5+abs(dt)/9.0-1.0)*5.5;
 float lit=step(idx+0.5,ward*12.0);
 vec3 shard=mix(mix(cyan,ink,0.45),vec3(1),exp(-abs(crystal+3.0)*0.6)*0.6)*(1.0+ward_flash);
 float ring=exp(-abs(dr)*1.1)*0.45;
 vec4 wardc=vec4(mix(cyan,ink,0.5),ring*ward);
 wardc=mix(wardc,vec4(shard,1),mask(crystal)*lit);
 wardc=mix(wardc,vec4(ink*0.8,0.65),exp(-abs(crystal)*1.2)*(1.0-lit)*(1.0-mask(crystal)*0.6));
 col.rgb=mix(col.rgb,wardc.rgb,wardc.a*ward_show);
 col.a=max(col.a,wardc.a*ward_show);
 col.rgb+=vec3(0.85,0.9,1.0)*flash*exp(-length(p)*0.022)*0.6;
 col.a*=presence*(1.0-smoothstep(172.0,180.0,ex))*(1.0-smoothstep(77.0,84.0,abs(p.y)));
 COLOR=col;
}
