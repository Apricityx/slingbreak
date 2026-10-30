shader_type canvas_item;
render_mode unshaded;
uniform int effect=0;
uniform bool dark=false;
uniform bool reduced=false;
uniform vec4 accent:source_color=vec4(1.0);
uniform float pixel=1.923077;
varying vec2 sample_point;
varying vec4 primary;
varying float element;
varying float index;
varying float fade;
varying float flash;
varying float progress;
varying float size;
varying float opacity;

vec4 segment(vec2 p,vec2 start,vec2 finish,float extent) {
	vec2 delta=finish-start;
	float len=max(length(delta),0.00001);
	vec2 axis=delta/len;
	return vec4(mix(start,finish,p.x)+vec2(-axis.y,axis.x)*p.y*extent,vec2(p.x*len,p.y*extent));
}
vec2 storm_point(float at,float segments,float reach,float seed,float age,float motion) {
	float wave=(at>0.0 && at<segments) ? sin(seed+at*4.7+age*32.0*motion)*7.0*motion : 0.0;
	return vec2(reach*at/segments,wave);
}
void vertex() {
	vec2 p=VERTEX;
	vec4 stroke;
	progress=INSTANCE_CUSTOM.x;
	float seed=INSTANCE_CUSTOM.y,reach=INSTANCE_CUSTOM.z,age=progress*INSTANCE_CUSTOM.w;
	primary=COLOR;element=UV.y;index=UV.x;opacity=1.0;size=0.0;
	fade=1.0-pow(progress,0.72);flash=1.0-smoothstep(0.0,0.2,progress);
	if(effect==0) {
		float count=reduced ? 2.0 : 3.0;
		float retreat=mix(8.0,34.0,smoothstep(0.0,0.18,progress));
		vec2 anchor=vec2(-retreat-index*7.0,(index-(count-1.0)*0.5)*14.0);
		opacity=1.0-index*0.2;
		if(element<0.5) {stroke=segment(p,anchor+vec2(-22.0,0.0),anchor+vec2(18.0,0.0),1.7+pixel);VERTEX=stroke.xy;sample_point=stroke.zw;}
		else if(element<1.5)VERTEX=anchor+vec2(23.0-11.0*p.x,p.y*4.0);
		else {
			float radius=22.0+index*10.0+progress*10.0;
			float angle=-mix(-0.72,0.72,p.x/12.0)+seed-index*0.24;
			vec2 axis=vec2(cos(angle),sin(angle));
			sample_point=vec2(p.y*(0.7+pixel),0.0);
			VERTEX=axis*(radius+sample_point.x);
			opacity=0.4-index*0.08;
		}
	} else if(effect==1) {
		float finish=56.0+progress*20.0;
		if(element<0.5) {stroke=segment(p,vec2(-42.0,0.0),vec2(finish,0.0),4.0+pixel);VERTEX=stroke.xy;sample_point=stroke.zw;}
		else if(element<1.5)VERTEX=vec2(finish+10.0-25.0*p.x,p.y*5.0);
		else {stroke=segment(p,vec2(8.0+index*5.0,(index-1.5)*5.0-3.0),vec2(8.0+index*5.0,(index-1.5)*5.0+3.0),0.5+pixel);VERTEX=stroke.xy;sample_point=stroke.zw;}
	} else if(effect==2) {
		reach=min(reach,128.0);size=mix(16.0,9.0,smoothstep(0.0,1.0,progress));
		float bracket=size*0.65;
		if(element<0.5) {stroke=segment(p,vec2(18.0,0.0),vec2(reach-size,0.0),0.55+pixel);VERTEX=stroke.xy;sample_point=stroke.zw;}
		else if(element<1.5) {
			float sign_value=index<2.0 ? -1.0 : 1.0;
			float offset=mod(index,2.0)<0.5 ? -bracket : bracket;
			stroke=segment(p,vec2(reach+offset,sign_value*size),vec2(reach+offset,sign_value*(size+bracket)),0.9+pixel);VERTEX=stroke.xy;sample_point=stroke.zw;
		} else {sample_point=p*(2.5+pixel);VERTEX=vec2(reach,0.0)+sample_point;}
	} else if(effect==3) {
		flash=1.0-smoothstep(0.0,0.22,progress);
		if(element<0.5) {
			float angle=-0.55+index*0.55;
			vec2 axis=vec2(cos(angle),-sin(angle));
			float travel=mix(6.0,28.0,smoothstep(0.0,0.28,progress))*(1.0+index*0.12);
			stroke=segment(p,axis*4.0,axis*travel,2.5+pixel);VERTEX=stroke.xy;sample_point=stroke.zw;
		} else {size=5.0+flash*8.0;sample_point=p*(size+pixel);VERTEX=sample_point;}
	} else {
		fade=1.0-smoothstep(0.18,1.0,progress);flash=exp(-age*38.0);
		reach*=smoothstep(0.0,0.18,progress);
		if(element<0.5) {
			float segments=reduced ? 3.0 : 5.0;
			float motion=reduced ? 0.3 : 1.0;
			vec2 center=storm_point(p.x,segments,reach,seed,age,motion);
			vec2 before=storm_point(max(0.0,p.x-1.0),segments,reach,seed,age,motion);
			vec2 after=storm_point(min(segments,p.x+1.0),segments,reach,seed,age,motion);
			vec2 a=normalize(center-before+vec2(0.00001,0.0)),b=normalize(after-center+vec2(0.00001,0.0));
			vec2 tangent=p.x<=0.0 ? b : p.x>=segments ? a : normalize(a+b);
			vec2 normal=vec2(-tangent.y,tangent.x);
			if(p.x>0.0 && p.x<segments)normal/=max(dot(normal,vec2(-b.y,b.x)),0.25);
			sample_point=vec2(p.y*(4.0+pixel),0.0);VERTEX=center+normal*sample_point.x;
		} else if(element<2.5) {
			size=element<1.5 ? 5.0+flash*9.0 : 2.5;
			sample_point=p*(size+pixel);VERTEX=sample_point+vec2(element<1.5 ? 0.0 : reach,0.0);
		} else {stroke=segment(p,vec2(reach*0.55,0.0),vec2(reach*0.55,0.0)+vec2(cos(0.8),-sin(0.8))*18.0,0.65+pixel);VERTEX=stroke.xy;sample_point=stroke.zw;}
	}
	COLOR=vec4(1.0);
}
vec4 over(vec4 a,vec4 b) { return vec4(b.rgb*b.a+a.rgb*(1.0-b.a),b.a+a.a*(1.0-b.a)); }
float edge(float d,float radius) { return 1.0-smoothstep(radius-pixel*0.5,radius+pixel*0.5,d); }
void fragment() {
	vec4 ink=vec4(0.0);
	if(effect==0) {
		if(element<0.5) {
			ink=over(ink,vec4(primary.rgb,fade*fade*primary.a*opacity*0.55*edge(abs(sample_point.y),1.7)));
			float inner=step(4.0,sample_point.x)*step(sample_point.x,37.0);
			ink=over(ink,vec4(accent.rgb,fade*fade*primary.a*opacity*0.9*inner*edge(abs(sample_point.y),0.6)));
		} else if(element<1.5)ink=over(ink,vec4(accent.rgb,fade*fade*primary.a*opacity));
		else ink=over(ink,vec4(primary.rgb,fade*fade*primary.a*opacity*edge(abs(sample_point.x),0.7)));
	} else if(effect==1) {
		if(element<0.5) {
			ink=over(ink,vec4(primary.rgb,0.25*fade*fade*primary.a*edge(abs(sample_point.y),4.0)));
			ink=over(ink,vec4(accent.rgb,0.9*fade*fade*primary.a*edge(abs(sample_point.y),1.1)));
			float core=step(24.0,sample_point.x)*step(sample_point.x,82.0);
			ink=over(ink,vec4(1.0,1.0,1.0,flash*0.95*core*edge(abs(sample_point.y),0.6)));
		} else if(element<1.5)ink=over(ink,vec4(accent.rgb,fade*fade*primary.a));
		else ink=over(ink,vec4(primary.rgb,fade*fade*primary.a*0.7*edge(abs(sample_point.y),0.5)));
	} else if(effect==2) {
		if(element<0.5)ink=over(ink,vec4(primary.rgb,fade*fade*primary.a*0.4*edge(abs(sample_point.y),0.55)));
		else if(element<1.5)ink=over(ink,vec4(accent.rgb,fade*fade*primary.a*0.92*edge(abs(sample_point.y),0.9)));
		else ink=over(ink,vec4(1.0,1.0,1.0,fade*0.9*edge(length(sample_point),2.5)));
	} else if(effect==3) {
		if(element<0.5) {
			ink=over(ink,vec4(primary.rgb,fade*primary.a*flash*0.42*edge(abs(sample_point.y),2.5)));
			ink=over(ink,vec4(accent.rgb,fade*fade*primary.a*0.95*edge(abs(sample_point.y),0.75)));
		} else ink=over(ink,vec4(1.0,1.0,1.0,flash*0.8*edge(length(sample_point),size)));
	} else {
		if(element<0.5) {
			float d=abs(sample_point.x);
			ink=over(ink,vec4(0.3,0.75,1.0,fade*(reduced ? 0.15 : 0.3)*edge(d,4.0)));
			ink=over(ink,vec4(dark ? vec3(0.894118,0.956863,1.0) : vec3(0.14902,0.207843,0.27451),fade*0.85*edge(d,2.0)));
			ink=over(ink,vec4(accent.rgb,fade*edge(d,1.0)));
			ink=over(ink,vec4(1.0,1.0,1.0,fade*edge(d,0.35)));
		} else if(element<1.5)ink=over(ink,vec4(0.8,0.98,1.0,flash*0.8*edge(length(sample_point),size)));
		else if(element<2.5)ink=over(ink,vec4(accent.rgb,fade*edge(length(sample_point),2.5)));
		else ink=over(ink,vec4(accent.rgb,fade*edge(abs(sample_point.y),0.65)));
	}
	COLOR=vec4(ink.rgb/max(ink.a,0.00001),ink.a);
}
