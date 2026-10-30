shader_type canvas_item;
render_mode unshaded;
uniform bool dark=false;
uniform float pixel=1.923077;

vec2 bolt(float s,vec2 finish,vec2 side,float phase) {
	vec2 point=finish*s;
	if(s>0.0)point+=side*sin(phase+s*28.5)*7.0;
	return point;
}

void vertex() {
	float progress=INSTANCE_CUSTOM.x,seed=INSTANCE_CUSTOM.y+INSTANCE_CUSTOM.w;
	float snap=1.0-smoothstep(0.0,0.42,progress);
	float reach=mix(34.0,176.0,smoothstep(0.0,0.14,progress));
	float arc=UV.x,kind=UV.y;
	float coverage=COLOR.a;
	vec3 primary=COLOR.rgb;
	vec3 outline=dark ? vec3(0.85098,0.968627,1) : vec3(0.25098,0.203922,0.039216);
	vec4 ink=vec4(1);
	if(kind>=7.0) {
		float layer=kind-7.0;
		float radius=layer<0.5 ? 10.0+23.0*snap : layer<1.5 ? 9.0+22.0*snap : layer<2.5 ? 6.0+15.0*snap : 3.0+8.0*snap;
		ink=layer<0.5 ? vec4(outline,0.42*snap) : layer<1.5 ? vec4(0.341176,0.788235,0.960784,0.38*snap) : layer<2.5 ? vec4(1,1,1,0.92*snap) : vec4(0.87451,0.984314,1,snap);
		float r=length(VERTEX);
		VERTEX=VERTEX/max(r,0.0001)*(min(r,1.0)*radius+max(r-1.0,0.0)*pixel*2.0);
	} else {
		vec2 p=VERTEX;
		float width=mod(arc,2.0)<0.5 ? 5.6 : 3.3;
		vec2 center,normal,tangent;
		float cap;
		float angle=seed+arc*6.283185307/8.0+sin(seed+arc*3.7)*0.14;
		vec2 direction=vec2(cos(angle),sin(angle));
		vec2 side=vec2(-direction.y,direction.x);
		vec2 finish=direction*reach*(0.62+0.3*mod(arc,4.0)/3.0);
		if(kind<4.0) {
			float s=clamp(p.x,0.0,5.0)/5.0;
			float phase=seed+progress*28.0;
			center=bolt(s,finish,side,phase);
			vec2 before=bolt(max(0.0,s-0.2),finish,side,phase);
			vec2 after=bolt(min(1.0,s+0.2),finish,side,phase);
			vec2 a=normalize(center-before+vec2(0.000001)),b=normalize(after-center+vec2(0.000001));
			tangent=s<=0.0 ? b : s>=1.0 ? a : normalize(a+b);
			normal=vec2(-tangent.y,tangent.x);
			if(s>0.0 && s<1.0)normal/=max(dot(normal,vec2(-b.y,b.x)),0.25);
			cap=p.x-clamp(p.x,0.0,5.0);
			if(kind<0.5){width*=3.2;ink=vec4(0.290196,0.721569,0.909804,0.3*snap);}
			else if(kind<1.5){width*=1.75;ink=vec4(outline,0.95*snap);}
			else if(kind<2.5){ink=vec4(primary,(1.0-progress)*0.96*snap);}
			else{width*=0.3;ink=vec4(1,1,1,0.94*snap);}
		} else {
			float fork_angle=angle+0.42*sin(seed+arc);
			tangent=vec2(cos(fork_angle),sin(fork_angle));normal=vec2(-tangent.y,tangent.x);
			center=finish*0.68+tangent*38.0*clamp(p.x,0.0,1.0);
			cap=p.x-clamp(p.x,0.0,1.0);
			if(kind<4.5){width=4.8;ink=vec4(outline,0.95*snap);}
			else if(kind<5.5){width=3.0;ink=vec4(0.458824,0.843137,1,0.9*snap);}
			else{width=0.9;ink=vec4(1,1,1,0.8*snap);}
		}
		float edge=sign(p.y)*(min(abs(p.y),0.5)*width+max(abs(p.y)-0.5,0.0)*pixel*2.0);
		VERTEX=center+normal*edge+tangent*cap*pixel;
	}
	COLOR=vec4(ink.rgb,ink.a*coverage);
}
