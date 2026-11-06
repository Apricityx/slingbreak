shader_type canvas_item;
render_mode unshaded;
uniform int effect=0;
uniform bool dark=false;
uniform bool reduced=false;
uniform float pixel=1.0;
varying vec2 local;
varying vec4 tint;
varying float shape;
varying float fade;
varying float flash;
varying float role;
varying float element;
varying float width;

vec2 arc_point(float n,float count,float reach,float seed,float age) {
	float wobble=(n>0.0 && n<count) ? sin(seed+n*4.7+age*(reduced ? 0.0 : 24.0))*(reduced ? 3.0 : 9.0) : 0.0;
	return vec2(reach*n/count,wobble);
}
void vertex() {
	vec2 p=VERTEX;
	float t=INSTANCE_CUSTOM.x,seed=INSTANCE_CUSTOM.y,reach=INSTANCE_CUSTOM.z,age=t*INSTANCE_CUSTOM.w;
	float i=UV.x,k=UV.y,motion=reduced ? 0.25 : 1.0;
	float grow=1.0-exp(-age*30.0);
	role=COLOR.a;element=k;
	fade=1.0-smoothstep(0.15,1.0,t);flash=exp(-age*38.0);
	tint=vec4(COLOR.rgb,1.0);shape=0.0;width=1.0;local=p;
	if(effect==0) {
		// Each bee is aligned to one successfully emitted homing child.
		vec2 center=vec2(12.0+grow*(62.0+sin(seed*2.0)*19.0)+t*24.0*motion,0.0);
		if(k<0.5) {VERTEX=p*vec2(11.0,9.0);tint=vec4(1.0,0.94,0.6,flash);shape=1.0;}
		else if(k<1.5) {VERTEX=center+p*vec2(11.0,4.0);shape=2.0;}
		else if(k<2.5) {
			float side=i<0.5 ? -1.0 : 1.0;
			VERTEX=center+vec2(-3.0,side*(5.0+grow*3.0))+p*vec2(7.0,4.0);
			tint=vec4(dark ? vec3(0.9,0.96,0.73) : vec3(0.4,0.53,0.22),0.75);shape=3.0;
		} else {VERTEX=vec2(center.x-23.0,0.0)+p*vec2(12.0*(1.0-t),1.5);shape=4.0;tint.a=0.6;}
	} else if(effect==1) {
		float impact=step(0.8,role);
		if(k<0.5) {
			float rail=i-1.0;
			vec2 center=vec2((impact>0.5 ? 12.0 : 25.0)+grow*12.0,rail*7.0*(1.0-t*0.7));
			VERTEX=center+p*vec2((impact>0.5 ? 48.0 : 38.0)*(1.0-t*0.65),i==1.0 ? 2.5 : 1.5);
			shape=4.0;tint=vec4(i==1.0 ? vec3(0.92,1.0,1.0) : vec3(0.26,0.69,0.72),1.0);
		} else if(k<1.5) {
			float side=mod(i,2.0)<0.5 ? -1.0 : 1.0;
			vec2 center=vec2((i-2.0)*8.0,side*(8.0+grow*(12.0+i*3.0)*motion));
			VERTEX=center+p*vec2(7.0*(1.0-t)+1.0,3.0);shape=3.0;tint=vec4(0.42,0.85,0.9,impact);
		} else {VERTEX=p*(5.0+flash*15.0);shape=1.0;tint=vec4(0.95,1.0,1.0,flash);}
	} else if(effect==2) {
		bool hot=role>0.8;
		if(k<0.5) {VERTEX=p*(5.0+flash*14.0);shape=1.0;tint=vec4(hot ? vec3(1.0,0.9,0.63) : vec3(0.75,0.96,1.0),flash);}
		else {
			float count=reduced ? 4.0 : 8.0;
			float angle=seed+i*6.2831853/count;
			vec2 axis=vec2(cos(angle),sin(angle)),normal=vec2(-axis.y,axis.x);
			float travel=9.0+grow*(hot ? 44.0 : 28.0)*motion;
			vec2 center=axis*travel+vec2(age*age*24.0*motion,0.0);
			VERTEX=center+axis*p.x*(hot ? 13.0 : 17.0)*(1.0-t*0.6)+normal*p.y*5.0;
			shape=3.0;tint=vec4(hot && mod(i,2.0)<0.5 ? vec3(1.0,0.56,0.19) : vec3(0.38,0.8,0.94),1.0);
		}
	} else {
		bool die=role<0.8;
		if(k<0.5) {
			VERTEX=p*(die ? 19.0+flash*3.0 : 0.0);shape=5.0;
			tint=vec4(0.96,0.81,0.33,die ? 1.0 : 0.0);
		} else if(k<1.5) {
			float count=reduced ? 3.0 : 6.0;
			vec2 center=arc_point(p.x,count,reach,seed,age);
			vec2 before=arc_point(max(0.0,p.x-1.0),count,reach,seed,age);
			vec2 after=arc_point(min(count,p.x+1.0),count,reach,seed,age);
			vec2 axis=normalize(after-before+vec2(0.00001,0.0));
			VERTEX=center+vec2(-axis.y,axis.x)*p.y*(4.0+pixel);
			local=vec2(p.y*(4.0+pixel),0.0);shape=6.0;tint.a=die ? 0.0 : 1.0;
		} else if(k<2.5) {VERTEX=vec2(i*reach,0.0)+p*(4.0+flash*8.0);shape=1.0;tint=vec4(1.0,0.95,0.64,die ? 0.0 : flash+fade*0.3);}
		else {VERTEX=vec2(reach*0.55,-10.0)+p*vec2(2.0,9.0);shape=3.0;tint=vec4(0.99,0.84,0.39,die ? 0.0 : 0.7);}
	}
	COLOR=vec4(1.0);
}
void fragment() {
	float mask=1.0;
	vec3 edge=dark ? vec3(0.92,0.97,0.82) : vec3(0.17,0.24,0.23);
	vec3 ink=tint.rgb;
	if(shape<1.5) {mask=1.0-smoothstep(0.6,1.0,length(local));}
	else if(shape<2.5) {
		mask=1.0-smoothstep(0.75,1.0,length(local));
		float stripe=step(0.5,fract((local.x+1.0)*2.3));
		ink=mix(vec3(0.98,0.78,0.19),vec3(0.22,0.27,0.13),stripe*0.85);
	} else if(shape<3.5) {
		float d=abs(local.x)+abs(local.y);
		mask=1.0-smoothstep(0.85,1.0,d);
		ink=mix(ink,edge,smoothstep(0.55,0.85,d)*0.8);
		ink=mix(ink,vec3(1.0),0.65*(1.0-smoothstep(0.03,0.16,abs(local.y))));
	} else if(shape<4.5) {
		mask=(1.0-smoothstep(0.75,1.0,abs(local.x)))*(1.0-smoothstep(0.45,1.0,abs(local.y)));
		ink=mix(edge,ink,1.0-smoothstep(0.2,0.8,abs(local.y)));
	} else if(shape<5.5) {
		float d=max(abs(local.x),abs(local.y));
		mask=1.0-smoothstep(0.88,1.0,d);
		ink=mix(ink,vec3(0.19,0.23,0.16),smoothstep(0.72,0.85,d));
		// The six pips communicate the actual six-target reward, never a reroll.
		vec2 q=vec2(abs(local.x)-0.42,local.y);
		float pip=min(length(q),min(length(q-vec2(0.0,0.46)),length(q+vec2(0.0,0.46))));
		ink=mix(ink,vec3(0.19,0.23,0.16),1.0-smoothstep(0.09,0.15,pip));
	} else {
		float d=abs(local.x);
		mask=1.0-smoothstep(3.0,4.0+pixel,d);
		ink=mix(vec3(0.95,0.7,0.2),edge,1.0-smoothstep(1.5,2.5,d));
		ink=mix(ink,vec3(1.0,0.97,0.79),1.0-smoothstep(0.3,1.3,d));
	}
	COLOR=vec4(ink,mask*tint.a*fade);
}
