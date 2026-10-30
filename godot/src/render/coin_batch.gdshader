shader_type canvas_item;
render_mode unshaded;
uniform float pixel=1.923077;
varying vec2 sample_point;
varying float kind;
varying float fade;
varying float radius;
varying float shard_index;
varying float shard_size;

vec4 over(vec4 a,vec4 b) { return vec4(b.rgb*b.a+a.rgb*(1.0-b.a),b.a+a.a*(1.0-b.a)); }
float edge(float d,float r) { return 1.0-smoothstep(r-pixel*0.5,r+pixel*0.5,d); }
void vertex() {
	float progress=INSTANCE_CUSTOM.x,seed=INSTANCE_CUSTOM.y+INSTANCE_CUSTOM.w;
	fade=1.0-smoothstep(0.2,0.58,progress);
	radius=15.0*(1.0+0.42*sin(min(1.0,progress*4.5)*3.141592654));
	shard_index=UV.x;kind=UV.y;vec2 p=VERTEX;
	if(kind<0.5) {
		VERTEX=p*(radius+3.0+pixel)/cos(3.141592654/24.0);sample_point=VERTEX;
	} else if(kind<1.5) {
		float angle=shard_index*1.570796327+0.785398163;
		vec2 tangent=vec2(cos(angle),sin(angle)),normal=vec2(-tangent.y,tangent.x);
		VERTEX=tangent*(radius+1.0+14.0*p.x)+normal*p.y*(1.1+pixel);
		sample_point=vec2(p.y*(1.1+pixel),0.0);
	} else {
		float angle=seed+shard_index*0.628318531;
		vec2 shard=vec2(cos(angle),sin(angle))*mix(10.0,48.0,smoothstep(0.0,0.24,progress))+vec2(0.0,30.0*progress*progress);
		shard_size=(3.0+mod(shard_index,3.0))*fade;
		if(kind<2.5) {
			vec2 extent=vec2(shard_size*0.7,shard_size)+vec2(pixel*1.5);
			VERTEX=shard+p*extent;sample_point=p*extent;
		} else {
			VERTEX=shard+vec2(p.y*(0.6+pixel),(p.x*4.0-2.0)*shard_size);
			sample_point=vec2(p.y*(0.6+pixel),0.0);
		}
	}
	COLOR=vec4(1.0);
}
void fragment() {
	vec4 ink=vec4(0.0);
	if(kind<0.5) {
		float d=length(sample_point);
		ink=over(ink,vec4(0.54902,0.392157,0.109804,0.82*fade*edge(d,radius+3.0)));
		ink=over(ink,vec4(0.956863,0.768627,0.247059,0.98*fade*edge(d,radius)));
		ink=over(ink,vec4(1.0,0.972549,0.784314,fade*edge(abs(d-radius),1.1)));
		// Half-ring stamp; the two direction tests avoid atan per pixel.
		float stamp=step(-0.637424*sample_point.x+0.770513*sample_point.y,0.0);
		ink=over(ink,vec4(0.607843,0.407843,0.090196,fade*stamp*edge(abs(d-radius*0.7),0.75)));
	} else if(kind<1.5 || kind>2.5) {
		float alpha=edge(abs(sample_point.x),kind<1.5 ? 1.1 : 0.6);
		ink=over(ink,vec4(1.0,0.984314,0.862745,fade*alpha*(kind>2.5 ? 0.8 : 1.0)));
	} else {
		float d=abs(sample_point.x)/0.7+abs(sample_point.y)-shard_size;
		float alpha=edge(abs(d)*0.573462,0.6);
		vec3 col=mod(shard_index,2.0)<0.5 ? vec3(1.0,0.945098,0.631373) : vec3(0.905882,0.662745,0.180392);
		ink=over(ink,vec4(col,fade*alpha));
	}
	COLOR=vec4(ink.rgb/max(ink.a,0.00001),ink.a);
}
