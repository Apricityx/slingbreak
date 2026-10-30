shader_type canvas_item;
render_mode unshaded;

uniform bool reduced = false;
varying float age;
varying float seed;
varying float strength;
varying vec2 local_point;
varying vec4 envelope;
varying vec4 timing;

void vertex() {
	age=INSTANCE_CUSTOM.x;seed=INSTANCE_CUSTOM.y+INSTANCE_CUSTOM.w;strength=INSTANCE_CUSTOM.z;
	float t=max(age,0.001);
	envelope=vec4(1.0-exp(-t*9.0),1.0-smoothstep(0.22,1.05,t),exp(-t*15.0),1.0/(0.002+t*0.035));
	timing=vec4(0.08+0.73*(1.0-exp(-t*5.0)),exp(-t*4.5),exp(-t*6.0)*0.22,smoothstep(0.12,0.45,t)*(1.0-smoothstep(0.55,1.4,t)));
	// Tight, age-dependent support. The turbulent smoke cannot exceed
	// 0.71*expand; retain shock/glow down to ~1/1024 alpha rather than shade
	// the old full-sized empty carrier on every tail frame.
	float glow_extent=sqrt(max(0.0,log(max(timing.z*1024.0,1.0)))/7.0);
	float extent=max(max(0.72*envelope.x,timing.x+0.04),glow_extent);
	VERTEX*=extent/cos(3.141592654/12.0);
	local_point=VERTEX;
}

float hash(vec2 p) {
	// Polynomial hash: no four transcendental sin calls per noise sample.
	vec3 q=fract(vec3(p.xyx)*0.1031);
	q+=dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment() {
	vec2 p = local_point;
	float t = max(age, 0.001);
	float radius = length(p);
	// Most carrier pixels contain only the cheap glow/shock. Do not evaluate
	// turbulent noise there; include the full furthest possible smoke front.
	float expand = envelope.x;
	float n=0.5;
	if(radius<0.72*expand) {
		vec2 flow = p*6.0 + vec2(seed, t*1.8);
		n = noise(flow)*0.65 + noise(flow*2.1-t*2.0)*0.35;
	}
	float body = 1.0-smoothstep(0.18,0.48, radius/max(expand,0.05)+(n-0.5)*0.25);
	float hot = body*envelope.y;
	float core = exp(-radius*radius*envelope.w)*envelope.z;
	float shock_distance=(radius-timing.x)/0.014;
	float shock = exp(-shock_distance*shock_distance)*timing.y;
	float smoke = (1.0-smoothstep(0.28,0.61,radius/max(expand,0.05)+(n-0.5)*0.2));
	smoke *= timing.w*(0.35+n*0.25);
	vec3 flame = mix(vec3(0.72,0.13,0.025),vec3(1.0,0.68,0.17),smoothstep(0.1,0.8,hot));
	flame = mix(flame,vec3(1.0,0.96,0.73),clamp(core*2.0,0.0,1.0));
	float glow = exp(-radius*radius*7.0)*timing.z;
	float alpha = clamp(hot*0.92+core+shock*0.7+smoke+glow,0.0,0.94);
	vec3 col = mix(vec3(0.18,0.14,0.13),flame,clamp((hot+core+glow)/max(alpha,0.001),0.0,1.0));
	col = mix(col,vec3(1.0,0.79,0.45),shock);
	COLOR = vec4(col,alpha*strength*(reduced ? 0.65 : 1.0));
}
