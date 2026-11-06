shader_type canvas_item;
render_mode unshaded;
// 熔炉巨像 body: one retained world-space quad behind the masonry. Torso,
// pedestal, arms, pauldrons and crucible head are SDF plates lit from the upper
// left. Heat drives the seams; phase two strips the chest armour to a molten
// lattice, phase three cracks the iron red-hot. Colliders are vector strokes.
uniform float clock=0.0;
uniform float rise=1.0;
uniform float shift=0.0;
uniform float phase=1.0;
uniform float heat=0.0;
uniform float vent=0.0;
uniform float cool=0.0;
uniform float beat=0.0;
uniform float crack=0.0;
uniform float tilt=0.0;
uniform vec2 bellows=vec2(0.0);
uniform vec2 fist_l=vec2(196.0,652.0);
uniform vec2 fist_r=vec2(584.0,652.0);
uniform bool light_theme=false;
uniform vec4 iron : source_color=vec4(0.1,0.08,0.07,1.0);
uniform vec4 iron_light : source_color=vec4(0.44,0.4,0.36,1.0);
uniform vec4 soot : source_color=vec4(0.03,0.02,0.02,1.0);
uniform vec4 ember : source_color=vec4(1.0,0.55,0.23,1.0);
uniform vec4 molten : source_color=vec4(1.0,0.75,0.38,1.0);
uniform vec4 core : source_color=vec4(1.0,0.96,0.84,1.0);
uniform vec4 weak : source_color=vec4(1.0,0.42,0.29,1.0);
uniform vec4 smoke : source_color=vec4(0.42,0.38,0.35,1.0);
varying vec2 point;
void vertex(){point=VERTEX;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);}
float box(vec2 p,vec2 b,float r){vec2 q=abs(p)-b+r;return length(max(q,0.0))+min(max(q.x,q.y),0.0)-r;}
float capsule(vec2 p,vec2 a,vec2 b,float ra,float rb){vec2 pa=p-a;vec2 ba=b-a;float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);return length(pa-ba*h)-mix(ra,rb,h);}
vec2 elbow(int side){return side==0?vec2(176.0,466.0):vec2(604.0,466.0);}
vec2 head_local(vec2 p){vec2 q=p-vec2(390.0,150.0);float c=cos(-tilt);float s=sin(-tilt);return vec2(c*q.x-s*q.y,s*q.x+c*q.y);}
// Parts back to front: 0 pedestal, 1 torso, 2-3 arms, 4-5 pauldrons, 6 head.
float part(int id,vec2 p){
	if(id==0)return box(p-vec2(390.0,672.0),vec2(156.0,24.0),10.0);
	if(id==1){vec2 q=p-vec2(390.0,430.0);float hw=mix(170.0,128.0,clamp((q.y+215.0)/430.0,0.0,1.0));
		return box(vec2(q.x*170.0/hw,q.y),vec2(170.0,215.0),40.0)*hw/170.0;}
	if(id==2||id==3){int side=id-2;vec2 sh=side==0?vec2(244.0,300.0):vec2(536.0,300.0);vec2 f=side==0?fist_l:fist_r;
		return min(capsule(p,sh,elbow(side),34.0,27.0),capsule(p,elbow(side),f,27.0,33.0));}
	if(id==4||id==5){vec2 c=id==4?vec2(262.0,262.0):vec2(518.0,262.0);return length((p-c)*vec2(1.0,1.12))-52.0;}
	vec2 h=head_local(p);
	float bowl=max(length(h-vec2(0.0,-8.0))-62.0,-h.y-38.0);
	float lip=box(h-vec2(0.0,-42.0),vec2(80.0,8.0),5.0);
	float pool=(length((h-vec2(0.0,-50.0))/vec2(72.0,11.0))-1.0)*10.0;
	return min(min(min(bowl,lip),pool),box(h-vec2(0.0,66.0),vec2(30.0,22.0),6.0));
}
vec2 grad(int id,vec2 p){vec2 e=vec2(1.5,0.0);return normalize(vec2(part(id,p+e)-part(id,p-e),part(id,p+e.yx)-part(id,p-e.yx))+1e-5);}
float seam(float x,float at,float w){return 1.0-smoothstep(0.0,w,abs(x-at));}
void fragment(){
	vec2 p=point;
	float t=clock;
	float k=clamp(rise,0.0,1.0);
	float shown=smoothstep(0.0,0.3,k)*(1.0-smoothstep(0.62,1.0,crack));
	// The ignition front climbs from the pedestal to the crucible.
	float lit=smoothstep(-60.0,60.0,p.y-mix(900.0,-120.0,smoothstep(0.3,0.85,k)))*(1.0-crack);
	float open=clamp(phase-1.0,0.0,1.0);
	float hot=clamp(phase-2.0,0.0,1.0);
	float surge=sin(clamp(shift,0.0,1.0)*PI);
	float pulse=0.5+0.5*sin(t*2.6);
	float glow_amt=lit*clamp(0.22+0.78*heat+vent*0.6+beat*0.5+surge*0.6+hot*0.25*pulse,0.0,1.6)*(1.0-cool*0.6);
	vec3 fire=mix(ember.rgb,molten.rgb,clamp(heat*0.8+vent,0.0,1.0));
	fire=mix(fire,weak.rgb,beat*0.6);
	int top=-1;float dist=1e3;float nearest=1e3;
	for(int i=0;i<7;i++){float v=part(i,p);nearest=min(nearest,v);if(v<0.0){top=i;dist=v;}}
	if(top<0){
		// Outside: furnace heat haze and a soft contact shadow under the pedestal.
		float haze=exp(-length((p-vec2(390.0,420.0))*vec2(1.0,0.8))/170.0)*glow_amt*0.35;
		// Heat shimmer rising off the crucible.
		vec2 above=p-vec2(390.0,96.0);
		haze+=exp(-length(above*vec2(1.0,1.6))/46.0)*step(above.y,8.0)*lit*(0.3+0.4*heat+vent*0.5)*(0.8+0.2*noise(vec2(p.x*0.04,p.y*0.04+t*1.5)));
		float shadow=exp(-max(nearest,0.0)/16.0)*0.35;
		vec3 col=mix(soot.rgb,fire,haze/(haze+shadow*0.5+1e-4));
		COLOR=vec4(col,clamp(haze+shadow*(light_theme?0.5:0.8),0.0,1.0)*shown);
	}else{
	vec2 n=grad(top,p);
	float light=dot(n,normalize(vec2(-0.6,-0.8)));
	float rim=smoothstep(-16.0,0.0,dist);
	float grain=noise(p*0.09)*0.6+noise(p*0.31)*0.4;
	vec3 base=mix(iron.rgb,iron_light.rgb,0.12+0.14*grain);
	vec3 col=base;
	col=mix(col,iron_light.rgb*1.15,rim*max(light,0.0)*0.85);
	col=mix(col,soot.rgb,rim*max(-light,0.0)*0.7);
	float glowing=0.0;
	if(top==1){
		vec2 q=p-vec2(390.0,430.0);
		float fr=length(q-vec2(0.0,-10.0));
		// Horizontal armour courses and a centre keel, riveted along each seam.
		float rows=max(max(seam(q.y,-120.0,2.2),seam(q.y,-40.0,2.2)),max(seam(q.y,90.0,2.2),seam(q.y,160.0,2.2)));
		float keel=seam(q.x,0.0,2.0)*step(84.0,fr);
		float lines=max(rows,keel)*step(84.0,fr);
		col=mix(col,soot.rgb,lines*0.8);
		glowing=max(glowing,lines*0.55);
		vec2 rv=vec2(mod(q.x+14.0,28.0)-14.0,0.0);
		float rivet=0.0;
		for(int j=0;j<4;j++){float y=float[4](-108.0,-28.0,102.0,172.0)[j];rivet=max(rivet,1.0-smoothstep(3.0,4.5,length(vec2(rv.x,q.y-y))));}
		col=mix(col,iron_light.rgb*1.3,rivet*step(90.0,fr)*0.8);
		// Phase two: the upper chest plates are gone, exposing ribs over fire.
		float bay=step(70.0,abs(q.x))*step(abs(q.x),150.0)*step(-170.0,q.y)*step(q.y,-50.0)*open;
		float ribs=smoothstep(0.35,0.5,abs(fract(q.y/24.0)-0.5));
		col=mix(col,mix(fire*0.9,base*0.8,ribs),bay);
		glowing=max(glowing,bay*(1.0-ribs)*0.6);
		// Phase three: red-hot cracks wander through the iron.
		float web=abs(noise(q*0.028+3.1)-0.5)+abs(noise(q*0.06-1.7)-0.5)*0.5;
		float cracks=(1.0-smoothstep(0.015,0.05,web))*max(hot,crack*1.2);
		glowing=max(glowing,cracks*(crack>0.0?(1.0-crack)*1.5:1.0));
		// Furnace frame and door grate; the bars slide apart while venting.
		float frame=step(fr,76.0)*step(54.0,fr);
		vec3 framecol=mix(soot.rgb,iron_light.rgb,0.35+0.4*max(0.0,dot((q-vec2(0.0,-10.0))/max(fr,1.0),vec2(-0.6,-0.8))));
		float bolt=1.0-smoothstep(3.5,5.0,length(vec2(mod(atan(q.y+10.0,q.x)+PI/12.0,PI/6.0)-PI/12.0,0.0)*fr+vec2(0.0,fr-65.0)));
		framecol=mix(framecol,iron_light.rgb*1.4,bolt);
		col=mix(col,framecol,frame);
		if(fr<54.0){
			vec2 c=q-vec2(0.0,-10.0);
			float spread=smoothstep(0.0,1.0,vent);
			float gx=sign(c.x)*max(0.0,abs(c.x)-spread*30.0)/(1.0-spread*0.55);
			float bars=smoothstep(0.32,0.42,abs(fract(gx/13.0)-0.5))*step(abs(c.x),54.0-spread*12.0);
			float flame=noise(vec2(c.x*0.06,c.y*0.05+t*1.8))*0.6+0.4;
			vec3 inside=mix(fire,core.rgb,clamp(vent*0.8+heat*0.3+beat*0.4,0.0,1.0)*smoothstep(54.0,0.0,fr));
			vec3 grill=mix(soot.rgb*1.4,iron.rgb,0.5+0.5*-c.y/54.0);
			float light_in=clamp(0.35*lit+glow_amt*flame,0.0,1.4);
			col=mix(inside*light_in,grill,bars*(1.0-spread*0.9));
			glowing=0.0;
		}
	}
	if(top==2||top==3){
		float bands=seam(fract((p.y-280.0)/46.0),0.5,0.04);
		col=mix(col,soot.rgb,bands*0.7);
		glowing=max(glowing,bands*0.3*open);
	}
	if(top==4||top==5){
		int side=top-4;vec2 c=(top==4?vec2(262.0,262.0):vec2(518.0,262.0));
		float r=length((p-c)*vec2(1.0,1.12));
		col=mix(col,soot.rgb,max(seam(r,36.0,1.8),seam(r,20.0,1.6))*0.8);
		// Phase two: the pauldron becomes a bellows, its vents draw on the fire.
		float draw=side==0?bellows.x:bellows.y;
		float vents=step(r,34.0)*smoothstep(0.3,0.45,abs(fract(atan(p.y-c.y,p.x-c.x)/TAU*10.0)-0.5))*open;
		col=mix(col,fire*(0.5+draw),vents);
		glowing=max(glowing,vents*(0.4+draw*1.4));
	}
	if(top==6){
		vec2 h=head_local(p);
		// Crucible: molten pool under the rim, slit eyes and an engraved visor.
		// Molten surface seen from just below the rim, churning slowly.
		float pool=1.0-smoothstep(0.9,1.0,length((h-vec2(0.0,-50.0))/vec2(72.0,11.0)));
		float churn=noise(vec2(h.x*0.05+t*0.7,h.y*0.2))*0.6+noise(vec2(h.x*0.12-t*1.1,h.y*0.4))*0.4;
		col=mix(col,mix(fire,core.rgb,clamp(0.15+0.5*churn+0.3*heat,0.0,1.0)),pool*max(lit,0.15));
		glowing=max(glowing,pool*0.7);
		// Mouth grille under the eyes.
		float mouth=step(abs(h.x),26.0)*step(30.0,h.y)*step(h.y,48.0)*smoothstep(0.3,0.45,abs(fract(h.x/8.0)-0.5));
		col=mix(col,mix(soot.rgb,fire*0.7,glow_amt*0.6),mouth);
		glowing=max(glowing,mouth*0.4);
		float eye=(1.0-smoothstep(0.0,2.5,box(vec2(abs(h.x)-24.0,h.y-6.0),vec2(14.0,3.5),2.0)));
		col=mix(col,mix(fire,core.rgb,0.4),eye*lit);
		glowing=max(glowing,eye*1.2);
		col=mix(col,soot.rgb,max(seam(h.y,-22.0,1.8),seam(h.y,30.0,1.8))*step(abs(h.x),52.0)*0.8);
	}
	// Seam glow, cooled to grey after a missed counter; death bleaches to slag.
	col+=fire*glowing*glow_amt*0.9;
	col=mix(col,smoke.rgb*0.8,cool*0.25*glowing);
	col=mix(col,mix(smoke.rgb*0.6,soot.rgb,0.4),crack*0.75);
	col=mix(col,soot.rgb*0.6,smoothstep(-2.6,-0.4,dist));
	col=mix(col,core.rgb,surge*0.18*smoothstep(260.0,0.0,length(p-vec2(390.0,420.0))));
	COLOR=vec4(col,shown);
	}
}
