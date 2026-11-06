shader_type canvas_item;
render_mode unshaded;
// 时之君主 dial: one retained 760 x 740 quad centred on the real dial. Bezel,
// enamel, chapter ring, openwork movement and state tints only; colliders,
// hands and the core stay crisp vectors drawn above the bricks.
uniform float clock=0.0;
uniform float rise=1.0;
uniform float shift=0.0;
uniform float phase=1.0;
uniform float stall=0.0;
uniform float freeze=0.0;
uniform float rewind=0.0;
uniform float midnight=0.0;
uniform float haste=0.0;
uniform float crack=0.0;
uniform float spin=0.0;
uniform float lit_angle=0.0;
uniform bool light_theme=false;
uniform vec4 face : source_color=vec4(0.04,0.06,0.13,1.0);
uniform vec4 rim : source_color=vec4(0.85,0.68,0.31,1.0);
uniform vec4 brass : source_color=vec4(0.91,0.75,0.38,1.0);
uniform vec4 brass_deep : source_color=vec4(0.54,0.42,0.16,1.0);
uniform vec4 gem : source_color=vec4(0.44,0.78,1.0,1.0);
uniform vec4 weak : source_color=vec4(1.0,0.42,0.35,1.0);
uniform vec4 stop : source_color=vec4(0.56,0.75,0.94,1.0);
uniform vec4 ghost : source_color=vec4(0.66,0.8,0.97,1.0);
varying vec2 point;
void vertex(){point=VERTEX;}
float hash(float n){return fract(sin(n*127.1)*43758.5453);}
float band(float x,float a,float b,float w){return smoothstep(a-w,a+w,x)*(1.0-smoothstep(b-w,b+w,x));}
float angdiff(float a,float b){return abs(mod(a-b+PI,TAU)-PI);}
// Gear silhouette with six-spoke window; returns coverage.
float gear(vec2 p,float r,float teeth,float ang,float w){
	float a=atan(p.y,p.x);float l=length(p);
	float edge=r*(0.87+0.13*smoothstep(-0.3,0.3,cos(teeth*(a-ang))));
	float body=1.0-smoothstep(edge-w,edge+w,l);
	float spokes=smoothstep(0.62,0.8,abs(cos(3.0*(a-ang))));
	float window=band(l,r*0.3,r*0.68,w)*(1.0-spokes);
	float hub=1.0-smoothstep(r*0.11-w,r*0.11+w,l);
	return clamp(body*(1.0-window)*(1.0-hub),0.0,1.0);
}
void fragment(){
	vec2 q=point/vec2(1.0,0.95);
	float r=length(q);
	float a=atan(q.x,-q.y);
	float sweep=fract(a/TAU+1.0);
	float w=max(fwidth(r),0.6)*1.1;
	float t=clock;
	float k=clamp(rise,0.0,1.0);
	float traced=smoothstep(sweep,sweep+0.04,k*1.18);
	float face_in=smoothstep(0.3,0.8,k);
	float fade=1.0-smoothstep(0.55,1.0,crack);
	vec3 col=vec3(0.0);float alpha=0.0;
	// Outer astrolabe halo: faint, so the corner masonry keeps its contrast.
	float zodiac_a=mod(a+spin*0.06,TAU/12.0)-TAU/24.0;
	float lobe=band(length(vec2(zodiac_a*361.0,r-361.0)),8.0,10.5,w);
	float ray_a=abs(mod(a-spin*0.03,TAU/24.0)-TAU/48.0)*r;
	float long_ray=step(0.5,fract((a-spin*0.03)/(TAU/12.0)+0.25));
	float rays=(1.0-smoothstep(0.4,0.4+w,ray_a))*band(r,340.0,mix(352.0,384.0,long_ray),w);
	float halo=max(max(band(r,333.0,336.5,w),band(r,386.0,388.0,w)*0.7),max(lobe,rays*0.8));
	if(r>324.0){
		col=light_theme?brass_deep.rgb:brass.rgb;
		alpha=halo*(light_theme?0.42:0.34)*traced*fade;
		col=mix(col,weak.rgb,midnight*0.5);
		COLOR=vec4(col,alpha);
	}else{
	// Bezel, lit from the upper left, with a knurled outer edge.
	vec2 n=q/max(r,0.001);
	float light=dot(n,normalize(vec2(-0.6,-0.8)));
	float profile=sin(clamp((r-298.0)/24.0,0.0,1.0)*PI);
	vec3 bezel=mix(brass_deep.rgb,brass.rgb,0.45+0.55*(0.5+0.5*light)*profile);
	bezel+=vec3(1.0,0.95,0.82)*pow(max(0.0,light),8.0)*profile*0.4;
	bezel*=mix(1.0,0.84+0.16*(0.5+0.5*sin(a*240.0)),band(r,313.0,322.0,w));
	bezel=mix(bezel,brass_deep.rgb*0.55,max(band(r,296.5,299.0,w),band(r,320.5,323.5,w)));
	bezel=mix(bezel,weak.rgb,clamp(phase-2.0,0.0,1.0)*0.18*(0.6+0.4*sin(t*2.4))*profile);
	// Enamel face, deeper toward the rim; engraved guilloché sunburst.
	vec3 enamel=mix(face.rgb*1.9+vec3(0.025,0.035,0.07),face.rgb*0.92,smoothstep(0.0,262.0,r));
	float gu=(0.5+0.5*sin(a*96.0+sin(r*0.085)*2.2))*(0.5+0.5*sin(r*0.62));
	enamel*=0.88+0.18*gu;
	// Openwork movement (phase two onward): lattice windows reveal turning gears.
	float open=clamp(phase-1.0,0.0,1.0);
	if(open>0.0){
		float lattice=smoothstep(0.25,0.4,0.5+0.5*cos(a*6.0+r*0.012))*band(r,74.0,236.0,w*3.0);
		float g1=gear(q-vec2(-118.0,96.0),62.0,14.0,spin*0.5,w);
		float g2=gear(q-vec2(112.0,104.0),56.0,12.0,-spin*0.58,w);
		float g3=gear(q-vec2(64.0,-80.0),44.0,10.0,spin*0.8,w);
		float g4=gear(q-vec2(-86.0,-62.0),36.0,9.0,-spin*0.98,w);
		float gears=max(max(g1,g2),max(g3,g4));
		vec3 well=face.rgb*0.35;
		vec3 metal=mix(brass_deep.rgb*0.8,brass.rgb*0.85,0.5+0.5*dot(n,vec2(-0.6,-0.8)));
		enamel=mix(enamel,mix(well,metal,gears),lattice*open*0.92);
		enamel=mix(enamel,brass.rgb*0.7,band(lattice,0.45,0.55,0.05)*open*0.35);
	}
	// Midnight drains the enamel to a starfield.
	vec2 cell=floor(q/18.0);
	float star=step(0.93,hash(cell.x*17.0+cell.y*131.0))*(0.6+0.4*sin(t*2.0+hash(cell.x+cell.y*7.0)*20.0));
	enamel=mix(enamel,face.rgb*0.45+vec3(star)*0.9,midnight*0.85);
	// Inner sub-dial ring, counter-rotating.
	float sub_a=abs(mod(a-spin*0.4,TAU/12.0)-TAU/24.0)*r;
	enamel=mix(enamel,brass.rgb,band(r,104.0,106.0,w)*0.6+band(r,88.0,103.0,w)*(1.0-smoothstep(0.6,0.6+w,sub_a))*0.7);
	// Chapter ring with sixty ticks, glowing toward the lit numeral.
	float minute_i=mod(floor(sweep*60.0+0.5),5.0);
	float tick_d=abs(mod(a,TAU/60.0)-TAU/120.0)*r;
	float major=step(minute_i,0.5);
	float ticks=(1.0-smoothstep(mix(0.5,1.3,major),mix(0.5,1.3,major)+w,tick_d))*band(r,mix(281.0,266.0,major),295.0,w);
	vec3 chapter=face.rgb*0.55;
	chapter=mix(chapter,brass.rgb*(0.75+0.25*major),ticks*smoothstep(sweep,sweep+0.02,k*1.1));
	float lit=exp(-pow(angdiff(a,lit_angle)/0.2,2.0))*(1.0-midnight);
	chapter+=gem.rgb*lit*0.5*band(r,262.0,296.0,w);
	vec3 dial=mix(enamel,chapter,band(r,262.0,296.0,w));
	dial=mix(dial,brass.rgb,band(r,260.0,262.5,w)*0.8);
	// State light: stall bloom, frozen time, rewind ripples, haste streaks.
	dial+=gem.rgb*exp(-r/80.0)*stall*0.75+brass.rgb*band(r,262.0,296.0,w)*ticks*stall*0.4;
	float lum=dot(dial,vec3(0.3,0.59,0.11));
	dial=mix(dial,mix(vec3(lum),stop.rgb,0.45)*1.1,freeze*0.8);
	dial+=stop.rgb*freeze*0.25*pow(0.5+0.5*sin(a*18.0+r*0.05),12.0)*step(r,262.0);
	dial=mix(dial,ghost.rgb,rewind*0.22*(0.5+0.5*sin(r*0.07+t*9.0)));
	dial+=gem.rgb*haste*0.22*pow(fract(sweep*12.0-t*1.6),6.0)*band(r,110.0,260.0,w);
	// Phase shift: a bright arm sweeps twice, then a flash from the centre.
	float arm=fract(sweep-fract(shift*2.0));
	dial+=gem.rgb*exp(-arm*14.0)*band(r,36.0,296.0,w)*sin(clamp(shift,0.0,1.0)*PI)*0.9;
	dial+=vec3(1.0,0.93,0.75)*exp(-r/140.0)*smoothstep(0.78,0.9,shift)*(1.0-smoothstep(0.9,1.0,shift))*0.8;
	// Glass highlight.
	vec2 g=q-vec2(-70.0,-120.0);
	dial+=vec3(1.0)*0.05*(1.0-smoothstep(150.0,230.0,length(g*vec2(1.0,1.7))))*step(r,262.0);
	// Death fractures.
	float cracks=0.0;
	for(int i=0;i<7;i++){
		float ang=hash(float(i)+1.3)*TAU;
		float d=abs(sin(a-ang-sin(r*0.04+float(i))*0.07))*r;
		cracks=max(cracks,(1.0-smoothstep(0.0,1.8,d))*step(r,crack*420.0));
	}
	dial=mix(dial,vec3(1.0,0.96,0.85),cracks*0.85);
	vec3 final_col=mix(dial,bezel,band(r,297.0,323.0,w));
	float inner=(1.0-smoothstep(297.0-w,297.0+w,r))*face_in;
	float outer=band(r,297.0,323.0,w)*traced;
	COLOR=vec4(final_col,max(inner,outer)*fade);
	}
}
