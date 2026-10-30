shader_type canvas_item;
render_mode unshaded;
uniform bool ice=false;
uniform bool dark=false;
uniform bool reduced=false;
uniform float pixel=1.923077;
varying vec2 sample_point;
varying float extent;
varying float tail;
varying float fade;

vec4 over(vec4 a,vec4 b) { return vec4(b.rgb*b.a+a.rgb*(1.0-b.a),b.a+a.a*(1.0-b.a)); }
float edge(float d,float r) { return 1.0-smoothstep(r-pixel*0.5,r+pixel*0.5,d); }
void vertex() {
	float t=INSTANCE_CUSTOM.x,seed=INSTANCE_CUSTOM.y+INSTANCE_CUSTOM.w,index=UV.x;
	float angle=seed+index*2.39996;
	vec2 direction=vec2(cos(angle),sin(angle)),p=VERTEX,center;
	if(ice) {
		float travel=(7.0+mod(index,4.0)*3.0)*(1.0-exp(-t*9.0))*(reduced ? 0.25 : 1.0);
		center=direction*travel+vec2(0.0,18.0*t*t);
		direction=vec2(cos(angle+t*5.0),sin(angle+t*5.0));
		extent=2.0+mod(index,3.0);tail=0.0;
		fade=clamp(INSTANCE_CUSTOM.z,0.0,1.0)*min(1.0,t*18.0);
		sample_point=p*(vec2(extent,extent*0.32)*1.28+vec2(pixel));
		if(reduced && index>=4.0)fade=0.0;
	} else {
		float speed=INSTANCE_CUSTOM.z*(1.2+0.8*sin(index*7.3+seed));
		center=direction*speed*(1.0-exp(-t*3.0))+vec2(0.0,100.0*t*t);
		fade=clamp(1.0-t/1.2,0.0,1.0);extent=1.5+fade;
		tail=5.0+12.0*exp(-t*4.0);
		float left=-tail-pixel,right=extent+pixel;
		sample_point=vec2(mix(left,right,(p.x+1.0)*0.5),p.y*(extent+pixel));
		if(reduced && index>=6.0)fade=0.0;
	}
	VERTEX=center+direction*sample_point.x+vec2(-direction.y,direction.x)*sample_point.y;
	COLOR=vec4(1.0);
}
void fragment() {
	vec4 ink=vec4(0.0);
	if(ice) {
		float d=(abs(sample_point.x)+abs(sample_point.y)/0.32)*0.304776;
		vec3 outline=dark ? vec3(0.843137,0.960784,1.0) : vec3(0.141176,0.341176,0.4);
		ink=over(ink,vec4(outline,fade*0.78*edge(d,extent*1.28*0.304776)));
		ink=over(ink,vec4(0.58,0.9,1.0,fade*0.9*edge(d,extent*0.304776)));
		vec2 delta=sample_point-vec2(clamp(sample_point.x,-extent,extent),0.0);
		ink=over(ink,vec4(0.94,1.0,1.0,fade*edge(length(delta),0.6)));
	} else {
		vec2 delta=sample_point-vec2(clamp(sample_point.x,-tail,0.0),0.0);
		ink=over(ink,vec4(1.0,0.48,0.12,fade*0.75*edge(length(delta),1.0)));
		ink=over(ink,vec4(1.0,0.88,0.55,fade*edge(length(sample_point),extent)));
	}
	COLOR=vec4(ink.rgb/max(ink.a,0.00001),ink.a);
}
