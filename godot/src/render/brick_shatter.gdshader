shader_type canvas_item;
render_mode unshaded;
// Normal brick break: one instance per event. UV.x = piece index, UV.y = kind
// (0 silhouette flash, 1 brick fragment, 2 spark, 3 shock arc). Instance color
// carries the brick fill and the launch heading (alpha = angle / TAU).
// INSTANCE_CUSTOM = (age, seed, brick width, brick height).
uniform bool dark=false;
uniform bool reduced=false;
uniform float pixel=1.923077;
uniform vec3 edge_light=vec3(0.204,0.255,0.184);
uniform vec3 edge_dark=vec3(0.788,0.827,0.741);
const float LIFE=0.5;
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

void vertex() {
	float t=INSTANCE_CUSTOM.x,seed=INSTANCE_CUSTOM.y,index=UV.x;
	vec2 size=INSTANCE_CUSTOM.zw,p=VERTEX,center=vec2(0.0),axis=vec2(1.0,0.0);
	float heading=COLOR.a*6.283185307;
	vec2 push=vec2(cos(heading),sin(heading));
	fill=COLOR.rgb;kind=UV.y;variant=hash(seed*3.7+index*1.93);fade=0.0;heat=0.0;extent=vec2(0.0);
	if(kind<0.5) {
		// The brick itself pops: a white-hot afterimage that swells and cools
		// to its own colour within ~0.12 s. Confirms *which* brick broke.
		float swell=1.0+0.2*(1.0-exp(-t*30.0));
		extent=size*0.5*swell;
		heat=exp(-t*26.0);fade=exp(-t*16.0)*(1.0-step(0.2,t));
		sample_point=p*(extent+vec2(pixel*2.0));
	} else if(kind<1.5) {
		// 4x2 grid cut of the real brick. Each chunk leaves its own cell, so the
		// break reads as the block coming apart, not a generic particle puff.
		vec2 cell=vec2(mod(index,4.0),floor(index/4.0));
		vec2 home=(cell-vec2(1.5,0.5))*size/vec2(4.0,2.0);
		float r=hash(seed+index*7.31),s=hash(seed*1.7+index*3.11);
		vec2 out_dir=normalize(home*vec2(1.0,1.6)+vec2((r-0.5)*14.0,(s-0.5)*10.0)+vec2(0.0001));
		// Uneven launch speeds: some chunks barely drop out, others fly. Strong
		// drag then real gravity gives a heavy arc instead of a confetti ring.
		float speed=mix(60.0,330.0,r*r);
		vec2 velocity=(out_dir*speed+push*(40.0+90.0*s)+vec2(0.0,-150.0+60.0*s))*(reduced ? 0.6 : 1.0);
		center=home+velocity*(1.0-exp(-t*6.0))/6.0+vec2(0.0,520.0*t*t);
		float spin=(r-0.5)*(5.0+speed*0.02)*(1.0-exp(-t*4.0))+(s-0.5)*0.6;
		axis=vec2(cos(spin),sin(spin));
		float shrink=1.0-smoothstep(0.26,LIFE,t);
		extent=size/vec2(4.0,2.0)*vec2(0.3+0.32*s,0.3+0.28*(1.0-r))*mix(0.3,1.0,shrink);
		fade=shrink;heat=exp(-t*20.0);
		sample_point=p*(extent+vec2(pixel*1.5));
		if(reduced && mod(index,2.0)>0.5)fade=0.0;
	} else if(kind<2.5) {
		// Hot sparks: short, quick, aligned with motion. Gone by 0.3 s.
		float r=hash(seed*2.3+index*5.7),angle=seed+index*2.39996+(r-0.5)*0.6;
		vec2 dir=normalize(vec2(cos(angle),sin(angle))+push*0.7);
		float travel=(70.0+70.0*r)*(1.0-exp(-t*11.0));
		center=dir*(size.y*0.3+travel)+vec2(0.0,90.0*t*t);
		axis=dir;
		fade=1.0-smoothstep(0.1,0.26,t);heat=exp(-t*9.0);
		extent=vec2(2.0+14.0*exp(-t*12.0),1.5);
		sample_point=p*(extent+vec2(pixel*1.5));
		if(reduced && index>1.5)fade=0.0;
	} else {
		// Broken shock arc: thins and opens while expanding. Never a fixed ring.
		float grow=1.0-exp(-t*16.0);
		float radius=size.x*0.4+34.0*grow;
		extent=vec2(radius+6.0);
		fade=(1.0-smoothstep(0.02,0.18,t))*(reduced ? 0.5 : 1.0);
		heat=radius;
		sample_point=p*(extent+vec2(pixel));
	}
	VERTEX=center+axis*sample_point.x+vec2(-axis.y,axis.x)*sample_point.y;
	COLOR=vec4(1.0);
}

void fragment() {
	vec3 edge=dark ? edge_dark : edge_light;
	vec3 hot=dark ? vec3(1.0,0.96,0.86) : vec3(1.0,0.99,0.94);
	// ink is premultiplied; over() composites a straight-alpha layer on top.
	vec4 ink=vec4(0.0);
	if(fade<=0.001)discard;
	if(kind<0.5) {
		float d=box(sample_point,extent,6.0);
		ink=over(ink,vec4(mix(fill,hot,heat),fade*0.95*aa(d)));
		// Thin ink rim keeps the pop legible on pale bricks in light theme.
		ink=over(ink,vec4(dark ? hot : edge,fade*heat*0.8*aa(abs(d+0.75)-0.75)));
	} else if(kind<1.5) {
		// Chunky shard: chamfered box with one random diagonal cut, so no two
		// fragments share a silhouette.
		float r=variant;
		vec2 n=normalize(vec2(r<0.5 ? 1.0 : -1.0,1.0-2.0*step(0.25,abs(r-0.5))));
		float d=max(box(sample_point,extent,1.2),dot(sample_point,n)-dot(extent,abs(n))*mix(0.35,0.7,fract(r*7.0)));
		vec3 tone=mix(fill,hot,heat*0.85);
		// Top-lit chunk: lighter face, darker lower lip, crisp outline.
		tone*=mix(1.1,0.84,clamp(sample_point.y/extent.y*0.5+0.5,0.0,1.0));
		ink=over(ink,vec4(edge,fade*0.9*aa(d)));
		ink=over(ink,vec4(tone,fade*aa(d+1.1)));
	} else if(kind<2.5) {
		float along=clamp(sample_point.x,-extent.x,extent.x);
		float d=length(sample_point-vec2(along,0.0))-extent.y;
		vec3 warm=dark ? vec3(1.0,0.78,0.36) : vec3(0.74,0.38,0.08);
		float tip=smoothstep(-extent.x,extent.x,sample_point.x);
		ink=over(ink,vec4(mix(warm,hot,heat*tip*(dark ? 1.0 : 0.4)),fade*aa(d)*mix(0.3,1.0,tip)));
	} else {
		float radius=heat,width=mix(1.6,0.5,1.0-fade);
		float d=abs(length(sample_point)-radius)-width;
		float angle=atan(sample_point.y,sample_point.x);
		// Four irregular gaps so the arc reads as a shockwave, not a target.
		float gaps=smoothstep(-0.2,0.35,sin(angle*4.0+variant*6.283)+0.35);
		ink=over(ink,vec4(dark ? hot : edge,fade*0.4*aa(d)*gaps));
	}
	COLOR=vec4(ink.rgb/max(ink.a,0.00001),ink.a);
}
