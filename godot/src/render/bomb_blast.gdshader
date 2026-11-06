shader_type canvas_item;
render_mode unshaded;
// Bomb brick blast: one instance per event. UV.x = piece index, UV.y = kind
// (0 core flash, 1 fireball lobe, 2 shock ring, 3 flame jet, 4 casing chunk,
// 5 ember, 6 smoke puff). Instance color carries the bomb brick fill.
// INSTANCE_CUSTOM = (age, seed, damage radius, intensity).
uniform bool dark=false;
uniform bool reduced=false;
uniform float pixel=1.923077;
uniform vec3 edge_light=vec3(0.204,0.255,0.184);
uniform vec3 edge_dark=vec3(0.788,0.827,0.741);
varying vec2 sample_point;
varying vec2 extent;
varying float kind;
varying float fade;
varying float heat;
varying vec3 fill;
varying float variant;

float hash(float n) { return fract(sin(n*12.9898)*43758.5453); }
float box(vec2 p,vec2 b,float r) { vec2 q=abs(p)-b+r; return length(max(q,0.0))+min(max(q.x,q.y),0.0)-r; }
float aa(float d) { return 1.0-smoothstep(-pixel*0.5,pixel*0.5,d); }
vec4 over(vec4 a,vec4 b) { return vec4(b.rgb*b.a+a.rgb*(1.0-b.a),b.a+a.a*(1.0-b.a)); }
// Blackbody-ish ramp: 1 white-hot, 0.75 yellow, 0.5 orange, 0.25 red, 0 soot.
vec3 fire(float h) {
	vec3 soot=dark ? vec3(0.22,0.16,0.14) : vec3(0.30,0.20,0.16);
	vec3 c=mix(soot,vec3(0.72,0.14,0.04),smoothstep(0.0,0.3,h));
	c=mix(c,vec3(1.0,0.46,0.08),smoothstep(0.25,0.55,h));
	c=mix(c,vec3(1.0,0.80,0.25),smoothstep(0.5,0.8,h));
	return mix(c,vec3(1.0,0.98,0.88),smoothstep(0.78,1.0,h));
}

void vertex() {
	float t=INSTANCE_CUSTOM.x,seed=INSTANCE_CUSTOM.y,R=INSTANCE_CUSTOM.z,power=INSTANCE_CUSTOM.w,index=UV.x;
	vec2 p=VERTEX,center=vec2(0.0),axis=vec2(1.0,0.0);
	fill=COLOR.rgb;kind=UV.y;variant=hash(seed*3.7+index*1.93+kind*0.71);fade=0.0;heat=0.0;extent=vec2(1.0);
	float r=hash(seed+index*7.31+kind*2.3),s=hash(seed*1.7+index*3.11+kind*1.1);
	float angle=seed+index*2.39996+(r-0.5)*0.7;
	vec2 dir=vec2(cos(angle),sin(angle));
	if(kind<0.5) {
		// White-hot core: a fast swell to ~0.4 R, collapsing by 0.16 s.
		float radius=R*(0.18+0.24*(1.0-exp(-t*40.0)))*power;
		extent=vec2(radius);
		heat=1.0;fade=exp(-t*14.0)*(1.0-step(0.18,t));
	} else if(kind<1.5) {
		// Billowing lobes push out fast, then drift up while they cool. They
		// stay inside the damage radius so the fire reads the actual blast.
		float travel=R*(0.18+0.3*r)*(1.0-exp(-t*9.0))*power;
		center=dir*travel+vec2(0.0,-R*0.35*t*t);
		float radius=R*(0.2+0.14*s)*(0.55+0.45*(1.0-exp(-t*12.0)))*(1.0+0.35*t)*power;
		extent=vec2(radius);
		heat=exp(-t*(2.6+1.2*s));fade=(1.0-smoothstep(0.28,0.6+0.12*s,t))*mix(0.45,1.0,smoothstep(0.15,0.6,heat));
		axis=vec2(cos(seed+index),sin(seed+index));
	} else if(kind<2.5) {
		// Crisp shock front, landing on the true damage radius at ~0.2 s.
		float radius=R*(0.25+0.78*(1.0-exp(-t*11.0)));
		extent=vec2(radius+8.0);
		heat=radius;fade=(1.0-smoothstep(0.08,0.34,t))*(reduced ? 0.6 : 1.0);
	} else if(kind<3.5) {
		// Flame tongues lash out and retract within 0.25 s.
		float length_=R*(0.45+0.4*r)*(1.0-exp(-t*30.0))*exp(-t*3.0)*power;
		axis=dir;center=dir*(R*0.12+length_*0.5);
		extent=vec2(length_*0.5,R*(0.07+0.04*s));
		heat=exp(-t*6.0);fade=1.0-smoothstep(0.1,0.26,t);
		if(reduced && index>2.5)fade=0.0;
	} else if(kind<4.5) {
		// Heavy casing chunks: ballistic with drag, tumbling, hot then cool.
		float speed=mix(260.0,560.0,r)*(reduced ? 0.65 : 1.0);
		vec2 velocity=dir*speed+vec2(0.0,-220.0*s);
		center=velocity*(1.0-exp(-t*3.2))/3.2+vec2(0.0,620.0*t*t);
		float spin=(r-0.5)*12.0*t+s*6.283;
		axis=vec2(cos(spin),sin(spin));
		float shrink=1.0-smoothstep(0.5,0.85,t);
		extent=vec2(9.0+7.0*s,6.0+5.0*r)*mix(0.4,1.0,shrink)*power;
		fade=shrink;heat=exp(-t*7.0);
		if(reduced && index>2.5)fade=0.0;
	} else if(kind<5.5) {
		// Embers: fast streaks aligned with motion, slowing and falling.
		float speed=mix(420.0,900.0,r*r);
		vec2 velocity=dir*speed;
		vec2 at=velocity*(1.0-exp(-t*5.5))/5.5+vec2(0.0,260.0*t*t);
		vec2 moving=velocity*exp(-t*5.5)+vec2(0.0,520.0*t);
		center=at;axis=normalize(moving+vec2(0.0001));
		extent=vec2(2.0+clamp(length(moving)*0.035,0.0,22.0),1.6);
		fade=1.0-smoothstep(0.3+0.25*s,0.55+0.3*s,t);heat=exp(-t*(2.5+2.0*r));
		if(reduced && mod(index,2.0)>0.5)fade=0.0;
	} else {
		// Smoke rolls up out of the fire after 0.15 s and dissolves by 1.1 s.
		float travel=R*(0.12+0.32*r)*(1.0-exp(-t*4.0));
		center=dir*travel+vec2(0.0,-R*(0.25+0.3*s)*t);
		extent=vec2(R*(0.2+0.12*s)*(0.6+0.9*t));
		fade=smoothstep(0.08,0.28,t)*(1.0-smoothstep(0.55,1.08,t))*(reduced ? 0.55 : 0.8);
		heat=exp(-t*5.0);
		axis=vec2(cos(seed*2.0+index),sin(seed*2.0+index));
	}
	sample_point=p*(extent+vec2(pixel*1.5));
	// Spent pieces collapse to a point: no rasterised quad, no fragment cost.
	if(fade<=0.002)sample_point=vec2(0.0);
	VERTEX=center+axis*sample_point.x+vec2(-axis.y,axis.x)*sample_point.y;
	COLOR=vec4(1.0);
}

void fragment() {
	if(fade<=0.002)discard;
	vec3 edge=dark ? edge_dark : edge_light;
	// ink is premultiplied; over() composites a straight-alpha layer on top.
	vec4 ink=vec4(0.0);
	float radius=length(sample_point);
	if(kind<0.5) {
		float glow=1.0-smoothstep(0.0,extent.x,radius);
		ink=over(ink,vec4(dark ? vec3(1.0,0.97,0.88) : vec3(1.0,0.86,0.5),fade*glow*glow));
		ink=over(ink,vec4(vec3(1.0,0.99,0.95),fade*aa(radius-extent.x*0.45)));
	} else if(kind<1.5) {
		// Lumpy lobe: angular wobble breaks the disc; hotter towards its heart.
		float a=atan(sample_point.y,sample_point.x);
		float d=radius-extent.x*(0.86+0.08*sin(a*3.0+variant*6.283)+0.05*sin(a*5.0-variant*4.0));
		float h=heat*(0.75+0.25*(1.0-radius/extent.x));
		ink=over(ink,vec4(fire(h*0.55),fade*0.9*aa(d)));
		ink=over(ink,vec4(fire(h),fade*aa(d+extent.x*0.14)));
	} else if(kind<2.5) {
		float front=heat;
		// Only the band near the front is shaded; the interior exits early.
		if(radius<front-10.0)discard;
		float d=abs(radius-front)-mix(2.6,0.8,1.0-fade);
		float a=atan(sample_point.y,sample_point.x);
		float gaps=smoothstep(-0.3,0.3,sin(a*5.0+variant*6.283)+0.55);
		float trail=smoothstep(front-10.0,front,radius)*(1.0-step(front,radius));
		vec3 tone=dark ? vec3(1.0,0.86,0.6) : vec3(0.62,0.24,0.08);
		ink=over(ink,vec4(tone,fade*0.18*trail));
		ink=over(ink,vec4(tone,fade*0.85*aa(d)*gaps));
	} else if(kind<3.5) {
		// Tapered tongue: wide at the root, a point at the tip.
		float along=sample_point.x/extent.x*0.5+0.5;
		float d=abs(sample_point.y)-extent.y*(1.0-along)*(0.6+0.4*(1.0-along));
		d=max(d,abs(sample_point.x)-extent.x);
		ink=over(ink,vec4(fire(heat*(1.0-along*0.45)),fade*aa(d)*(1.0-along*0.6)));
	} else if(kind<4.5) {
		// Chunk of the bomb shell: chamfered box with one diagonal cut.
		vec2 n=normalize(vec2(variant<0.5 ? 1.0 : -1.0,1.0-2.0*step(0.25,abs(variant-0.5))));
		float d=max(box(sample_point,extent,1.5),dot(sample_point,n)-dot(extent,abs(n))*mix(0.4,0.75,fract(variant*7.0)));
		vec3 tone=mix(fill*mix(1.1,0.75,clamp(sample_point.y/extent.y*0.5+0.5,0.0,1.0)),vec3(1.0,0.62,0.2),heat*0.8);
		ink=over(ink,vec4(edge,fade*0.9*aa(d)));
		ink=over(ink,vec4(tone,fade*aa(d+1.2)));
	} else if(kind<5.5) {
		float along=clamp(sample_point.x,-extent.x,extent.x);
		float d=length(sample_point-vec2(along,0.0))-extent.y;
		float tip=smoothstep(-extent.x,extent.x,sample_point.x);
		vec3 tone=dark ? fire(0.55+0.45*heat) : fire(0.35+0.45*heat);
		ink=over(ink,vec4(tone,fade*aa(d)*mix(0.25,1.0,tip)));
	} else {
		float a=atan(sample_point.y,sample_point.x);
		float edge_r=extent.x*(0.82+0.1*sin(a*4.0+variant*6.283));
		float body=1.0-smoothstep(edge_r*0.55,edge_r,radius);
		vec3 tone=dark ? vec3(0.32,0.27,0.25) : vec3(0.46,0.40,0.36);
		ink=over(ink,vec4(mix(tone,vec3(0.82,0.36,0.12),heat*0.6),fade*body));
	}
	COLOR=vec4(ink.rgb/max(ink.a,0.00001),ink.a);
}
