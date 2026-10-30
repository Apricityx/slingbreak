shader_type canvas_item;
render_mode unshaded;
uniform float age = 0.0;
uniform float clock = 0.0;
uniform float seed = 0.0;
uniform bool shell = false;
uniform bool dark = false;
uniform vec2 size = vec2(84.0,44.0);
uniform vec2 direction = vec2(1.0,0.0);
varying vec2 point;
varying vec2 sweep_axis;
varying vec4 beat;
void vertex() {
	point=VERTEX;
	sweep_axis=vec2(cos(clock*0.35+seed),sin(clock*0.35+seed));
	beat=vec4(exp(-age*30.0),exp(-age*9.0),1.0/max(0.008+age*0.05,0.0001),clamp(age*2.8,0.0,1.0));
}
float hash(vec2 p) {
	vec3 q=fract(vec3(p.xyx)*0.1031);q+=dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float fbm(vec2 p) {
	float value=0.0;
	value+=noise(p)*0.55;p=p*2.03+7.1;
	value+=noise(p)*0.28;p=p*2.07-3.4;
	value+=noise(p)*0.12;
	return value;
}
void fragment() {
	// The circular carrier uses a radius of 2.5 world units; normalize it
	// back to the shader's -1..1 space before evaluating the film or wave.
	vec2 p=point/2.5;
	vec3 blue=dark ? vec3(0.38,0.84,0.97) : vec3(0.12,0.53,0.69);
	vec3 edge_blue=dark ? vec3(0.08,0.28,0.36) : vec3(0.05,0.24,0.30);
	float a=0.0;
	vec3 col=blue;
	if(shell) {
		float n=fbm(p*3.4+seed);
		// `point` is the normalized Polygon2D vertex. Keep the film in this
		// space so it covers the whole brick instead of collapsing to a rim.
		vec2 bounds=vec2(0.94,0.86);
		vec2 q=abs(p)-bounds;
		float outside=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0);
		float inside=1.0-smoothstep(-0.04,0.02,outside);
		float edge=1.0-smoothstep(0.02,0.16,abs(outside));
		float arrival=beat.w;
		float travel=dot(p,direction)*0.34+0.5;
		float growth=smoothstep(travel-0.22,travel+0.14,arrival+n*0.16)*step(0.0,age);
		vec2 drift=vec2(clock*0.11,-clock*0.07);
		float crystal=fbm(p*7.0+drift+seed*1.7);
		float facets=pow(abs(sin(p.x*9.0+p.y*13.0+crystal*3.0)),15.0);
		float facet2=pow(abs(sin(p.y*17.0-p.x*7.0+seed)),22.0);
		float sweep=pow(max(0.0,1.0-abs(dot(p,sweep_axis))*3.2),7.0);
		// Reuse the evolving crystal field for veins rather than evaluating
		// a third three-octave noise field on every frozen pixel.
		float veins=smoothstep(0.62,0.78,crystal);
		float coating=0.10+crystal*0.16+facets*0.28+facet2*0.2+sweep*0.16;
		a=(inside*coating+edge*0.68+veins*0.16)*growth;
		col=mix(edge_blue,blue,clamp(inside*0.78+facets*0.35+facet2*0.2+sweep*0.45,0.0,1.0));
		col=mix(col,vec3(0.86,0.99,1.0),clamp(edge*0.8+facets*0.35+facet2*0.2+sweep*0.45,0.0,1.0));
	} else {
		// A compact hit spark only. The readable crystal fragments are drawn by
		// frost.gd with bounded world-space travel, so this carrier never throws
		// razor lines across the board.
		float r=length(p);
		float flash=beat.x;
		float fade=beat.y;
		float core=exp(-r*r*beat.z)*fade;
		float flecks=pow(max(0.0,sin(atan(p.y,p.x)*10.0+seed+r*20.0)),18.0)*exp(-r*3.0)*fade;
		a=core*0.8+flecks*0.35+flash*0.28;
		col=mix(blue,vec3(0.94,1.0,1.0),clamp(core+flash,0.0,1.0));
	}
	COLOR=vec4(col,clamp(a,0.0,0.85));
}
