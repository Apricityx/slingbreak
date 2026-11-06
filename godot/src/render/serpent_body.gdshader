shader_type canvas_item;
render_mode unshaded;
// 星渊巨蟒 body: one ribbon mesh per serpent. UV.x = arc length (px), UV.y =
// -1..1 across the body. COLOR.r = fraction head->tail, COLOR.g = hit flash,
// COLOR.b = kind (0 main, 0.5 twin, 1 shadow), COLOR.a = opacity.
uniform float clock=0.0;
uniform float stun=0.0;
uniform float armour_front=2.0;
uniform float dark=0.0;
uniform float dissolve=0.0;
uniform float heat=0.0;
uniform bool light_theme=false;
uniform vec4 body : source_color=vec4(0.12,0.44,0.48,1.0);
uniform vec4 body_light : source_color=vec4(0.37,0.82,0.86,1.0);
uniform vec4 belly : source_color=vec4(0.75,0.96,0.97,1.0);
uniform vec4 deep : source_color=vec4(0.0,0.04,0.06,1.0);
uniform vec4 glow : source_color=vec4(0.31,0.88,0.93,1.0);
uniform vec4 star : source_color=vec4(0.96,0.81,0.38,1.0);
uniform vec4 twin : source_color=vec4(0.91,0.71,0.29,1.0);
uniform vec4 weak : source_color=vec4(1.0,0.42,0.35,1.0);
varying vec4 tint;
void vertex(){tint=COLOR;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	float along=tint.r;float flash=tint.g;float kind=tint.b;
	float v=UV.y;float av=abs(v);
	float edge=1.0-smoothstep(1.0-fwidth(v)*1.5,1.0,av);
	if(kind>0.75){COLOR=vec4(deep.rgb,0.28*edge*tint.a*(1.0-dissolve));}
	else{
		// Cylindrical light from the upper left; v is the screen-space side.
		float n=sqrt(max(0.0,1.0-v*v));
		float light=clamp(0.25+0.75*n-0.35*v,0.0,1.2);
		vec3 skin=mix(body.rgb,body_light.rgb,smoothstep(0.15,1.0,light));
		if(kind>0.25)skin=mix(skin,twin.rgb,0.45);
		// Staggered plates whose size follows the body width.
		vec2 cell=vec2(UV.x/15.0,v*2.2);
		float row=floor(cell.y);
		cell.x+=mod(row,2.0)*0.5;
		vec2 f=fract(cell)-0.5;
		float plate=abs(f.x)*1.15+abs(f.y)*0.9;
		float seam=smoothstep(0.38,0.5,plate);
		float shine=smoothstep(0.3,0.0,length(f-vec2(0.12,-0.15)));
		vec3 color=skin*(1.0-0.38*seam)+body_light.rgb*shine*0.22*n;
		// Pale belly line along the lower flank.
		color=mix(color,belly.rgb,smoothstep(0.55,0.95,v)*0.35);
		// Stars caught in some plates, twinkling.
		vec2 id=floor(cell);
		float pick=hash(id);
		float twinkle=0.5+0.5*sin(clock*3.0+pick*40.0);
		color+=star.rgb*step(0.86,pick)*smoothstep(0.22,0.0,length(f))*twinkle*0.9*n;
		// Dorsal light stripe with a pulse running head to tail.
		float pulse=0.55+0.45*sin(UV.x*0.045-clock*6.0);
		float stripe=smoothstep(0.24,0.0,abs(v+0.05));
		vec3 stripe_ink=mix(glow.rgb,weak.rgb,heat);
		color=mix(color,stripe_ink,stripe*(0.45+0.4*pulse)*(1.0-stun*0.7));
		// Dark rim so the silhouette reads on both themes.
		color=mix(color,deep.rgb,smoothstep(0.72,1.0,av)*(light_theme?0.55:0.75));
		// Broken: plates go dull; refill re-arms them from head to tail.
		float bare=max(stun,smoothstep(armour_front-0.02,armour_front+0.02,along));
		vec3 grey=vec3(dot(color,vec3(0.3,0.59,0.11)));
		color=mix(color,grey*0.85,bare*0.6);
		float wave=smoothstep(0.06,0.0,abs(along-armour_front));
		color+=glow.rgb*wave*0.8;
		color=mix(color,vec3(1.0),flash*0.55);
		// Star-eclipse: the body sinks into the dark, the stripe keeps burning.
		color*=1.0-dark*0.55*(1.0-stripe);
		float alpha=edge*tint.a;
		// Collapse: dissolves tail first with a hot edge.
		if(dissolve>0.0){
			float cut=1.0-dissolve*1.15+hash(floor(vec2(UV.x/9.0,v*3.0)))*0.12;
			alpha*=step(along,cut);
			color=mix(color,star.rgb,smoothstep(cut-0.06,cut,along));
		}
		COLOR=vec4(color,alpha);
	}
}
