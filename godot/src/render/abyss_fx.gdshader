shader_type canvas_item;
render_mode unshaded;
uniform float age=0.0;
uniform float duration=1.0;
uniform float strength=1.0;
uniform float seed=0.0;
uniform int mode=0;
uniform bool reduced=false;
uniform float beam_length=600.0;
uniform vec4 ink : source_color=vec4(0.65,0.50,0.94,1.0);
uniform vec4 core : source_color=vec4(0.94,0.91,1.0,1.0);
varying vec2 local;
void vertex(){local=VERTEX;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=local;
 float envelope=smoothstep(0.0,0.035,age)*(1.0-smoothstep(duration*0.55,duration,age));
 vec3 color=ink.rgb;
 float alpha=0.0;
 if(mode==6){
  // Finite, endpoint-capped laser. Layered white core, crimson sheath,
  // traveling bands and a compact incandescent contact flare.
  float d=abs(p.y);
  float launch=1.0+exp(-age*25.0)*1.4;
  float wave=sin(p.x*0.065-age*24.0)*0.8;
  float core_mask=exp(-abs(p.y-wave)*1.0);
  float body=1.0-smoothstep(3.5*launch,6.0*launch,d);
  float halo=exp(-d*0.12)*0.34;
  float rim=1.0-smoothstep(7.0,10.0,d);
  float along=smoothstep(8.0,24.0,p.x)*(1.0-smoothstep(beam_length-1.0,beam_length+2.0,p.x));
  float bands=pow(max(0.0,sin(p.x*0.09-age*22.0)),7.0)*0.25;
	  float filaments=pow(max(0.0,sin(p.x*0.035-age*17.0+noise(vec2(p.x*0.018,age))*2.0)),10.0);
  color=mix(vec3(0.22,0.015,0.09),ink.rgb,body);
  color=mix(color,core.rgb,core_mask*0.95);
	  color+=ink.rgb*(bands+filaments*0.35)*body;
	  alpha=(rim*0.8+halo+core_mask*0.5+filaments*0.22)*along;
  float contact=exp(-length((p-vec2(beam_length-2.0,0))*vec2(0.15,0.20)));
  float spark=exp(-abs(p.x-beam_length)*0.65-abs(p.y)*0.08)*0.8;
  color=mix(color,core.rgb,clamp(contact+spark,0.0,1.0));
	  float contact_ring=exp(-abs(length(p-vec2(beam_length,0))-8.0)*0.45)*exp(-age*9.0);
	  alpha=max(alpha,(contact+spark+contact_ring)*0.95)*strength;
 }else if(mode==7){
  // Infection snaps a red contact into a purple, broken rectangular corona.
  float k=clamp(age/duration,0.0,1.0);
  vec2 q=abs(p)-vec2(51.0,25.0)*(1.0+k*0.65);
  float edge=abs(max(q.x,q.y));
  float corona=exp(-edge*0.6)*(0.35+noise(p*0.1)*0.65)*exp(-age*5.0);
  float flash=exp(-length(p*vec2(0.5,1.0))*0.07)*exp(-age*20.0);
  color=mix(vec3(0.60,0.27,1.0),core.rgb,flash);
  alpha=(corona+flash)*smoothstep(0.0,0.015,age)*strength;
 }else if(mode==4){
  // A single engraved cutting face: fast spearhead, hard dark edge and a
  // restrained inner filament. The same face survives on a light board.
  float tip=mix(60.0,1040.0,smoothstep(0.0,0.08,age));
  float width=mix(12.0,5.0,clamp(age*5.0,0.0,1.0));
  float wedge=min(1.0,max(0.0,(tip-p.x)/70.0));
  float d=abs(p.y)-width*wedge;
  float body=1.0-smoothstep(-1.0,1.0,d);
  float rim=1.0-smoothstep(1.0,3.5,d);
  float spine=exp(-abs(p.y)*0.9);
  float flow=0.65+0.35*sin(p.x*0.04-age*15.0);
  color=mix(ink.rgb*0.22,mix(ink.rgb,core.rgb,spine),body);
  alpha=rim*(0.65+spine*0.3)*strength*smoothstep(38.0,60.0,p.x)*(1.0-smoothstep(tip-12.0,tip,p.x));
  color+=core.rgb*spine*flow*0.16;
 }else if(mode==5){
  // Contact-originating split, never a radial ring. Two offset fracture lips
  // travel out across the seal and die before the exposure pose takes over.
  float k=smoothstep(0.0,0.12,age);
  float cut=abs(p.y-(p.x>0.0?p.x*0.22:-p.x*0.12));
  float reach=mix(8.0,115.0,k);
  float edge=1.0-smoothstep(1.0,4.0,abs(cut-age*30.0));
  float fill=exp(-cut*0.24)*exp(-age*22.0);
  alpha=(edge*exp(-age*8.0)+fill)*smoothstep(0.0,0.015,age)*(1.0-smoothstep(reach-20.0,reach,abs(p.x)))*strength;
  color=mix(ink.rgb,core.rgb,clamp(fill+edge*0.75,0.0,1.0));
 }else if(mode==2){
  // Narrow, layered cut with traveling energy inside; no solid wall of light.
  float x=p.x;
  float width=5.5+noise(vec2(x*0.022,age*1.8))*4.0;
  float turbulence=noise(vec2(x*0.025-age*3.0,age))*2.0-1.0;
  float d=abs(p.y-turbulence*(reduced?0.4:2.0));
  float edge=exp(-d*0.085)*0.26;
  float body=(1.0-smoothstep(width,width+4.0,d))*0.60;
  float sheath=exp(-abs(d-(12.0+sin(x*0.045-age*7.0)*2.0))*0.95)*0.20;
  float spine=exp(-d*0.9)*0.8;
  float pulse=0.55+0.45*noise(vec2(x*0.04-age*9.0,2.0));
  color=mix(ink.rgb,core.rgb,spine);
  alpha=(edge+body*pulse+spine*0.75+sheath)*smoothstep(0.0,0.08,age)*strength;
  alpha*=smoothstep(0.0,25.0,x)*(1.0-smoothstep(1020.0,1100.0,x));
 }else{
  float r=length(p);
  float a=atan(p.y,p.x);
  float n=noise(p*0.035+seed);
  if(mode==1){
   // Inward-moving diamond shards assemble into a seal, then release.
   float k=clamp(age/duration,0.0,1.0);
   float radius=mix(112.0,22.0,k*k);
   float angular=pow(max(0.0,cos(a*8.0+seed)),18.0);
   float blade=exp(-abs(r-radius)*0.16)*angular;
   float mist=exp(-r*0.025)*(0.15+n*0.16)*k;
   alpha=(blade*0.85+mist)*envelope;
   color=mix(ink.rgb,core.rgb,blade*0.6);
  }else if(mode==3){
   // Six faceted petals unfurl at the resolved ritual / crystal site.
   float k=clamp(age/duration,0.0,1.0);
   float sector=6.283185/6.0;
   float theta=mod(a+sector*0.5,sector)-sector*0.5;
   vec2 q=vec2(cos(theta),sin(theta))*r;
   float center=mix(12.0,76.0,sqrt(k));
   float diamond=abs(q.x-center)*0.52+abs(q.y)*1.6;
   float petal=(1.0-smoothstep(11.0,13.0,diamond))*(1.0-k);
   float bevel=exp(-abs(diamond-11.0)*1.3)*petal;
   float nucleus=exp(-length(p*vec2(0.65,1.3))*0.06)*exp(-age*12.0);
   color=mix(ink.rgb,core.rgb,clamp(bevel+nucleus,0.0,1.0));
   alpha=(petal*0.7+bevel*0.35+nucleus)*envelope;
  }else{
   // Broken pressure crescents and planar flash; the front never stalls as a ring.
   float k=clamp(age/duration,0.0,1.0);
   float wave=r-(14.0+sqrt(k)*100.0);
   float broken=smoothstep(0.25,0.8,noise(vec2(a*9.0+seed,k*3.0)));
   float crescent=exp(-abs(wave)*0.34)*broken*exp(-age*4.5);
   float diamond=abs(p.x)*0.55+abs(p.y)*1.3;
   float core_flash=exp(-diamond*0.08)*exp(-age*18.0);
   float arms=pow(max(0.0,cos(a*6.0+seed)),28.0)*exp(-r*0.024)*exp(-age*8.0);
   float veil=exp(-r*0.035)*(0.12+n*0.12)*exp(-age*6.0);
   alpha=(core_flash+arms*0.65+crescent*0.8+veil)*envelope;
   color=mix(ink.rgb,core.rgb,clamp(core_flash*2.0+arms,0.0,1.0));
  }
  alpha*=strength*(1.0-smoothstep(125.0,155.0,r));
 }
 COLOR=vec4(color,clamp(alpha*(reduced?0.7:1.0),0.0,0.88));
}
