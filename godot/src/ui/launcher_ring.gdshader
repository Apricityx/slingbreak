shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0,1.0)=0.0;
uniform float ready_mix : hint_range(0.0,1.0)=0.0;
uniform float clock=0.0;
uniform float ready_age=0.0;
uniform float interaction=0.0;
uniform bool reduced_motion=false;
uniform bool failed=false;
uniform bool busy=false;
uniform bool focused=false;
uniform vec4 plate_color : source_color=vec4(.97,.98,.95,1.0);
uniform vec4 track_color : source_color=vec4(.84,.88,.81,1.0);
uniform vec4 accent_color : source_color=vec4(.52,.75,.27,1.0);
void fragment(){
	vec2 p=UV-vec2(.5);float r=length(p);float aa=max(fwidth(r),.001);
	float angle=mod(atan(p.x,-p.y)+TAU,TAU)/TAU;
	vec3 accent=failed?vec3(.92,.49,.20):accent_color.rgb;
	vec3 fresh=mix(accent,vec3(.78,.96,.50),.55);
	float breath=reduced_motion?0.0:(.5+.5*sin(clock*2.1));
	float shadow=exp(-pow(length(p-vec2(0.0,.022))/.32,5.0))*.16;
	float halo=exp(-pow((r-.33)/.045,2.0))*(.035+ready_mix*.05)*(1.0+breath*.2);
	vec3 rgb=mix(vec3(.04,.07,.025),accent,halo/max(.001,halo+shadow));float alpha=clamp(shadow+halo,0.0,1.0);
	float plate=1.0-smoothstep(.338235-aa,.338235+aa,r);
	vec3 surface=plate_color.rgb+vec3((.5-UV.y)*.012);
	surface+=interaction*.025;rgb=mix(rgb,surface,plate);alpha=mix(alpha,1.0,plate);
	float rail=1.0-smoothstep(.014-aa,.014+aa,abs(r-.314));
	rgb=mix(rgb,track_color.rgb,rail*.72);alpha=max(alpha,rail*.88);
	float arc=rail*(1.0-smoothstep(progress-.0015,progress+.0015,angle))*step(.0001,progress);
	if(progress>=.999)arc=rail;
	float sheen=reduced_motion?0.0:pow(max(0.0,cos((angle-clock*.19)*TAU)),18.0);
	vec3 ring_ink=mix(accent,fresh,clamp(.25+.5*angle+sheen*.45,0.0,1.0));
	rgb=mix(rgb,ring_ink,arc);alpha=max(alpha,arc);
	vec2 tip=vec2(sin(progress*TAU),-cos(progress*TAU))*.314;
	float cap=(1.0-smoothstep(.014-aa,.014+aa,length(p-tip)))*step(.0001,progress)*(1.0-ready_mix);
	rgb=mix(rgb,fresh,cap);alpha=max(alpha,cap);
	float spark=exp(-pow(length(p-tip)/.034,2.0))*.25*(1.0-ready_mix)*step(.0001,progress);
	rgb+=fresh*spark;alpha=max(alpha,spark);
	float pulse=0.0;
	if(!reduced_motion && ready_age<1.6 && ready_mix>0.0){
		float age=clamp((ready_age-.35)/1.2,0.0,1.0);
		pulse=(1.0-smoothstep(.007,.007+aa,abs(r-mix(.34,.46,age))))*pow(1.0-age,2.0)*ready_mix*.35;
	}
	if(busy){float spin=reduced_motion?.35:pow(max(0.0,cos((angle-clock*.7)*TAU)),6.0);pulse=max(pulse,rail*spin*.8);}
	if(focused)pulse=max(pulse,(1.0-smoothstep(.008,.008+aa,abs(r-.40)))*.9);
	rgb=mix(rgb,fresh,pulse);alpha=max(alpha,pulse);
	COLOR=vec4(rgb,alpha);
}
