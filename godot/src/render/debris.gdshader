shader_type canvas_item;
render_mode unshaded;
uniform bool ice = false;
uniform bool dark = false;
uniform bool reduced = false;
uniform float pixel = 1.923077;

void vertex() {
	float t=INSTANCE_CUSTOM.x;
	float seed=INSTANCE_CUSTOM.y+INSTANCE_CUSTOM.w;
	float index=UV.x;
	float kind=UV.y;
	vec2 p=VERTEX;
	float coverage=COLOR.a;
	if(ice) {
		float angle=seed+index*2.39996;
		float travel=(7.0+mod(index,4.0)*3.0)*(1.0-exp(-t*9.0))*(reduced ? 0.25 : 1.0);
		vec2 center=vec2(cos(angle),sin(angle))*travel+vec2(0,18.0*t*t);
		float turn=angle+t*5.0;
		vec2 axis=vec2(cos(turn),sin(turn))*(2.0+mod(index,3.0));
		vec2 side=vec2(-axis.y,axis.x)*0.32;
		float fade=clamp(INSTANCE_CUSTOM.z,0.0,1.0)*min(1.0,t*18.0);
		vec3 outline=dark ? vec3(0.843137,0.960784,1.0) : vec3(0.141176,0.341176,0.4);
		if(kind<1.5) {
			float scale=kind<0.5 ? 1.28 : 1.0;
			VERTEX=center+(axis*p.x+side*p.y)*scale;
			COLOR=vec4(kind<0.5 ? outline : vec3(0.58,0.9,1),fade*(kind<0.5 ? 0.78 : 0.9));
		} else {
			float x=clamp(p.x,0.0,1.0);
			VERTEX=center+axis*(x*2.0-1.0)+normalize(axis)*(p.x-x)*pixel*2.0+normalize(side)*p.y*1.2;
			COLOR=vec4(0.94,1,1,fade*coverage);
		}
		if(reduced && index>=4.0) COLOR.a=0.0;
	} else {
		float radius=INSTANCE_CUSTOM.z;
		float angle=seed+index*2.39996;
		vec2 direction=vec2(cos(angle),sin(angle));
		float speed=radius*(1.2+0.8*sin(index*7.3+seed));
		vec2 center=direction*speed*(1.0-exp(-t*3.0))+vec2(0,100.0*t*t);
		float fade=clamp(1.0-t/1.2,0.0,1.0);
		if(kind<0.5) {
			float length=5.0+12.0*exp(-t*4.0);
			float x=clamp(p.x,0.0,1.0);
			VERTEX=center+direction*((x-1.0)*length+(p.x-x)*pixel*2.0)+vec2(-direction.y,direction.x)*p.y*2.0;
			COLOR=vec4(1,0.48,0.12,fade*0.75*coverage);
		} else {
			float r=length(p);
			VERTEX=center+p/max(r,0.0001)*(min(r,1.0)*(1.5+fade)+max(r-1.0,0.0)*pixel*2.0);
			COLOR=vec4(1,0.88,0.55,fade*coverage);
		}
		if(reduced && index>=6.0) COLOR.a=0.0;
	}
}
