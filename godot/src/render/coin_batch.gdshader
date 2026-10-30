shader_type canvas_item;
render_mode unshaded;
uniform bool dark=false;
uniform float pixel=1.923077;

vec2 diamond(float s,float size) {
	float index=min(floor(s),3.0),f=s-index;
	vec2 a= index<0.5 ? vec2(0,-1) : index<1.5 ? vec2(0.7,0) : index<2.5 ? vec2(0,1) : vec2(-0.7,0);
	vec2 b= index<0.5 ? vec2(0.7,0) : index<1.5 ? vec2(0,1) : index<2.5 ? vec2(-0.7,0) : vec2(0,-1);
	return mix(a,b,f)*size;
}
void vertex() {
	float progress=INSTANCE_CUSTOM.x,seed=INSTANCE_CUSTOM.y+INSTANCE_CUSTOM.w;
	float fade=1.0-smoothstep(0.2,0.58,progress);
	float radius=15.0*(1.0+0.42*sin(min(1.0,progress*4.5)*3.141592654));
	float index=UV.x,kind=UV.y,coverage=COLOR.a;
	vec2 p=VERTEX;
	vec4 ink;
	if(kind<2.0) {
		float r=length(p),extent=radius+(kind<0.5 ? 3.0 : 0.0);
		VERTEX=p/max(r,0.0001)*(min(r,1.0)*extent+max(r-1.0,0.0)*pixel*2.0);
		ink=kind<0.5 ? vec4(0.54902,0.392157,0.109804,0.82*fade) : vec4(0.956863,0.768627,0.247059,0.98*fade);
	} else {
		vec2 center,normal,tangent;
		float width=1.2,steps=1.0;
		if(kind<4.0) {
			steps=kind<2.5 ? 28.0 : 20.0;
			float angle=kind<2.5 ? clamp(p.x,0.0,steps)/steps*6.283185307 : -3.141592654*0.78+clamp(p.x,0.0,steps)/steps*3.141592654;
			normal=vec2(cos(angle),sin(angle));tangent=vec2(-normal.y,normal.x);
			center=normal*radius*(kind<2.5 ? 1.0 : 0.7);
			width=kind<2.5 ? 2.2 : 1.5;
			ink=kind<2.5 ? vec4(1,0.972549,0.784314,fade) : vec4(0.607843,0.407843,0.090196,fade);
		} else if(kind<4.5) {
			float angle=index*3.141592654/2.0+3.141592654/4.0;
			tangent=vec2(cos(angle),sin(angle));normal=vec2(-tangent.y,tangent.x);
			center=tangent*(radius+8.0-7.0+14.0*clamp(p.x,0.0,1.0));
			width=2.2;ink=vec4(1,0.984314,0.862745,fade);
		} else {
			float angle=seed+index*6.283185307/10.0;
			vec2 shard=vec2(cos(angle),sin(angle))*mix(10.0,48.0,smoothstep(0.0,0.24,progress))+vec2(0,30.0*progress*progress);
			float size=(3.0+mod(index,3.0))*fade;
			if(kind<5.5) {
				steps=4.0;
				float s=clamp(p.x,0.0,4.0);
				vec2 prev=diamond(max(s-0.001,0.0),size),next=diamond(min(s+0.001,4.0),size);
				tangent=normalize(next-prev+vec2(0.000001));normal=vec2(-tangent.y,tangent.x);
				center=shard+diamond(s,size);
				ink=mod(index,2.0)<0.5 ? vec4(1,0.945098,0.631373,fade) : vec4(0.905882,0.662745,0.180392,fade);
			} else {
				tangent=vec2(0,1);normal=vec2(-1,0);center=shard+vec2(0,(2.0-4.0*clamp(p.x,0.0,1.0))*size);
				ink=vec4(1,0.984314,0.862745,fade*0.8);
			}
		}
		float edge=sign(p.y)*(min(abs(p.y),0.5)*width+max(abs(p.y)-0.5,0.0)*pixel*2.0);
		VERTEX=center+normal*edge+tangent*(p.x-clamp(p.x,0.0,steps))*pixel;
	}
	COLOR=vec4(ink.rgb,ink.a*coverage);
}
