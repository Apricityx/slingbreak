shader_type canvas_item;
render_mode unshaded;

uniform float age = 0.0;
uniform float seed = 0.0;
uniform float strength = 1.0;
uniform bool reduced = false;
varying vec2 local_point;

void vertex() {
	local_point = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
	vec2 flow = p*6.0 + vec2(seed, t*1.8);
	float n = noise(flow)*0.65 + noise(flow*2.1-t*2.0)*0.35;
	float expand = 1.0-exp(-t*9.0);
	float envelope = 1.0-smoothstep(0.22,1.05,t);
	float body = 1.0-smoothstep(0.18,0.48, radius/max(expand,0.05)+(n-0.5)*0.25);
	float hot = body*envelope;
	float core = exp(-radius*radius/(0.002+t*0.035))*exp(-t*15.0);
	float front = 0.08+0.73*(1.0-exp(-t*5.0));
	float shock = exp(-pow((radius-front)/0.014,2.0))*exp(-t*4.5);
	float smoke = (1.0-smoothstep(0.28,0.61,radius/max(expand,0.05)+(n-0.5)*0.2));
	smoke *= smoothstep(0.12,0.45,t)*(1.0-smoothstep(0.55,1.4,t))*(0.35+n*0.25);
	vec3 flame = mix(vec3(0.72,0.13,0.025),vec3(1.0,0.68,0.17),smoothstep(0.1,0.8,hot));
	flame = mix(flame,vec3(1.0,0.96,0.73),clamp(core*2.0,0.0,1.0));
	float glow = exp(-radius*radius*7.0)*exp(-t*6.0)*0.22;
	float alpha = clamp(hot*0.92+core+shock*0.7+smoke+glow,0.0,0.94);
	vec3 col = mix(vec3(0.18,0.14,0.13),flame,clamp((hot+core+glow)/max(alpha,0.001),0.0,1.0));
	col = mix(col,vec3(1.0,0.79,0.45),shock);
	COLOR = vec4(col,alpha*strength*(reduced ? 0.65 : 1.0));
}
