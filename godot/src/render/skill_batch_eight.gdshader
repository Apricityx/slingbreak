shader_type canvas_item;
render_mode unshaded;
uniform int effect=0;
uniform bool dark=false;
uniform bool reduced=false;
uniform vec4 accent:source_color=vec4(1.0);
varying vec2 local;
varying vec4 primary;
varying float element;
varying float index;
varying float age;
varying float fade;
varying float flash;
varying float outcome;
varying float enabled;

vec2 turn(vec2 p,float angle) {return mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*p;}
void vertex() {
	local=VERTEX;primary=COLOR;element=UV.y;index=UV.x;
	float t=INSTANCE_CUSTOM.x,seed=INSTANCE_CUSTOM.y;
	outcome=INSTANCE_CUSTOM.z;age=t*INSTANCE_CUSTOM.w;
	float grow=1.0-exp(-age*28.0),motion=reduced ? 0.3 : 1.0;
	fade=1.0-smoothstep(0.18,1.0,t);flash=exp(-age*38.0);enabled=1.0;
	if(outcome<0.0) {
		if(element>2.5) {
			float angle=index*1.5707963;
			VERTEX=turn(vec2(0.0,17.0+grow*4.0)+local*vec2(10.0,2.0),angle)*vec2(1.55,0.9);
			fade*=exp(-age*4.0);
		} else {enabled=0.0;VERTEX=vec2(0.0);}
	} else if(element<0.5) {
		float radius=effect==3 ? 28.0+grow*20.0 : 8.0+flash*14.0;
		VERTEX=local*radius;
	} else if(element<1.5) {
		if(effect==0) {
			float angle=-1.5707963+(index-1.0)*0.8;
			float travel=17.0+grow*30.0+age*45.0*motion;
			VERTEX=turn(vec2(travel,0.0)+local*vec2(23.0*(1.0-t*0.5),7.0),angle);
			enabled=index<outcome ? 1.0 : 0.0;
		} else if(effect==1) {
			VERTEX=turn(vec2(9.0+grow*43.0,0.0)+local*vec2(46.0*(1.0-t*0.6),8.5),index*1.5707963);
			fade*=exp(-age*4.0);
		} else if(effect==2) {
			float size=outcome>2.0 ? 24.0 : 17.0;
			VERTEX=local*size*(0.78+grow*0.22)+vec2(0.0,-age*22.0*motion);
		} else {
			float angle=index*0.7853982+0.18;
			VERTEX=turn(vec2(25.0+grow*60.0,0.0)+local*vec2(25.0*(1.0-t*0.6),9.0),angle);
		}
	} else if(element<2.5) {
		float count=reduced ? 4.0 : 10.0;
		float angle=effect==2 ? -2.85+index*2.55/max(1.0,count-1.0) : seed+index*2.39996;
		vec2 axis=vec2(cos(angle),sin(angle));
		float distance=12.0+grow*(20.0+mod(index,3.0)*9.0)*motion;
		vec2 center=axis*distance+vec2(0.0,age*age*65.0*motion);
		if(effect==2) {
			distance*=outcome>2.0 ? 1.45 : 0.8;
			center=axis*distance+vec2(0.0,age*age*70.0*motion);
			float flip=reduced ? 0.85 : 0.35+abs(cos(seed+index+age*10.0))*0.65;
			VERTEX=center+local*vec2(5.0*flip,6.5)*(1.0-t*0.5);
			if(outcome<2.0 && index>=3.0)enabled=0.0;
		} else {
			if(effect==3)center*=1.8;
			VERTEX=center+turn(local*vec2(3.0,6.0)*(1.0-t*0.5),angle+age*motion);
		}
	} else {enabled=0.0;VERTEX=vec2(0.0);}
	COLOR=vec4(1.0);
}

float segment(vec2 p,vec2 a,vec2 b) {
	vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0));
}
void fragment() {
	vec3 edge=dark ? vec3(0.96,0.91,0.68) : vec3(0.26,0.19,0.09);
	vec3 ink=primary.rgb;
	float alpha=fade*enabled;
	float d=length(local);
	if(outcome<0.0) {
		ink=mix(edge,accent.rgb,0.5+local.y*0.5);
		alpha*=1.0-smoothstep(0.75,1.0,abs(local.x));
	} else if(element<0.5) {
		float shape=d;
		if(effect==3)shape+=sin(atan(local.y,local.x)*7.0+age*12.0)*0.12;
		alpha=(1.0-smoothstep(0.15,1.0,shape))*flash*enabled;
		ink=vec3(1.0,0.98,0.86);
	} else if(effect==2 && element<2.5) {
		float rim=smoothstep(0.65,0.77,d);
		ink=mix(mix(primary.rgb,vec3(1.0,0.86,0.39),0.65),edge,rim);
		ink=mix(ink,accent.rgb,(1.0-smoothstep(0.035,0.095,abs(d-0.57)))*0.8);
		if(element<1.5) {
			float yen=min(segment(local,vec2(-0.24,-0.32),vec2(0.0,-0.02)),segment(local,vec2(0.24,-0.32),vec2(0.0,-0.02)));
			yen=min(yen,segment(local,vec2(0.0,-0.02),vec2(0.0,0.36)));
			yen=min(yen,segment(local,vec2(-0.22,0.05),vec2(0.22,0.05)));
			yen=min(yen,segment(local,vec2(-0.22,0.21),vec2(0.22,0.21)));
			ink=mix(ink,edge,1.0-smoothstep(0.035,0.065,yen));
		} else ink=mix(ink,accent.rgb,(1.0-smoothstep(0.04,0.12,abs(local.x+local.y*0.4)))*0.65);
		alpha*=1.0-smoothstep(0.85,0.99,d);
	} else {
		float diamond=abs(local.x)+abs(local.y);
		float border=smoothstep(0.64,0.85,diamond);
		ink=mix(primary.rgb,edge,border);
		ink=mix(ink,accent.rgb,(1.0-smoothstep(0.03,0.18,abs(local.y)))*0.95);
		ink=mix(ink,vec3(1.0),flash*0.5);
		alpha*=1.0-smoothstep(0.87,1.0,diamond);
	}
	COLOR=vec4(ink,alpha);
}
