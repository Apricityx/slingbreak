extends RefCounted
## Authored, sampleable animation. No renderer-local timers, RNG or gameplay writes.
const INTRO_SECONDS:=3.2
const SHIFT_SECONDS:=3.4
const REVEAL_AT:=1.58
const CENTER:=Vector2(390,92)
const WARD_RADIUS:=57.0
const PUPIL_RADIUS:=43.0

static func pose(g:RefCounted) -> Dictionary:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	var t:float=g.presentation_time
	var intro:float=maxf(0,t-d.intro_at)
	var shift:float=t-m.phase_at
	var dying:float=t-d.dying_at if d.dying_at>=0 else -1.0
	var opened:float=smoothstep(0.95,2.35,intro)
	var presence:float=smoothstep(0.0,1.25,intro)
	var spread:float=1.0-smoothstep(0.25,1.65,intro)
	var flash:=0.0
	var lift:=0.0
	var size:=1.0
	var morph:=0.0
	var stage:float=d.fight.phase
	var origin:Vector2=m.center
	var shifting:bool=shift>=0 and shift<SHIFT_SECONDS
	var ritual:=0.0
	var upper:=1.0;var lower:=1.0;var focus:=0.0;var fracture:=0.0;var recoil:=0.0
	var pose_name:="observe"
	var rift_open:float=smoothstep(0.12,1.3,intro)
	var emergence:float=smoothstep(0.9,2.35,intro)
	if intro>=1.55 and intro<2.6:emergence+=sin(clampf((intro-1.55)/1.05,0,1)*PI)*0.12
	var heat:=0.0;var laser_pulse:=0.0;var dilate:=0.0
	if not m.move.is_empty() and not shifting:
		var anticipation:float=clampf((t-m.move.start)/(m.move.live-m.move.start),0,1)
		var cast_age:float=t-m.move.live
		ritual=anticipation*(1.0 if cast_age<0 else exp(-cast_age*4.0))
		if m.move.id=="doom":ritual=maxf(ritual,m.charge());heat=0.55*m.charge()
		# Lid tension is an internal pose, never a scale/position animation.
		if cast_age<0:opened*=1-0.28*anticipation
		elif cast_age<0.25:opened*=0.72+0.28*smoothstep(0,0.25,cast_age)
		if m.move.id=="gaze":
			# Lock (lids narrow, slit) → charge (pupil dilates: the counter window)
			# → snap open into the sweep → cool down through recovery.
			var cool:float=1-smoothstep(m.move.active_end,m.move.end,t)
			focus=smoothstep(0,0.35,t-m.move.start)*cool
			opened=1
			if cast_age<0:
				pose_name="lock" if anticipation<0.4 else "charge"
				upper=lerpf(1,0.55,smoothstep(0,0.3,anticipation))+0.4*smoothstep(0.35,0.95,anticipation)
				lower=lerpf(1,0.7,smoothstep(0,0.3,anticipation))+0.25*smoothstep(0.35,0.95,anticipation)
				dilate=smoothstep(0.08,0.4,anticipation)*0.85
				heat=smoothstep(0.2,1.0,anticipation)
			else:
				pose_name="sweep" if t<m.move.active_end else "recover"
				upper=1.08;lower=0.98
				recoil=exp(-cast_age*8)*smoothstep(0,0.025,cast_age)
				laser_pulse=exp(-cast_age*10)+0.25*(0.5+0.5*sin(t*31))*float(t<m.move.active_end)
				heat=cool;dilate=0.35*cool
	if shifting:
		# Hold the outgoing silhouette, blink shut, part the shell, then reveal.
		opened=1-smoothstep(0.18,0.72,shift)+smoothstep(1.6,2.65,shift)
		spread=smoothstep(0.5,1.45,shift)*(1-smoothstep(2.0,3.3,shift))
		morph=smoothstep(0.72,1.5,shift)*(1-smoothstep(1.68,2.8,shift))
		flash=exp(-maxf(0,shift-REVEAL_AT)*8.0) if shift>=REVEAL_AT else 0.0
		stage=float(d.fight.phase-1)+smoothstep(1.25,2.2,shift)
		origin=m.phase_origin.lerp(CENTER,smoothstep(0,0.72,shift))
		ritual=morph
		rift_open=1-smoothstep(0.1,0.8,shift)+smoothstep(0.85,1.8,shift)
		emergence=1-smoothstep(0.1,0.65,shift)+smoothstep(1.58,2.65,shift)
	if m.exposed():
		var broken:float=maxf(0,t-m.broken_at)
		pose_name="broken" if broken<0.48 else "exposed"
		fracture=smoothstep(0,0.16,broken)
		recoil=exp(-broken*7)
		upper=0.65+0.45*smoothstep(0.08,0.55,broken);lower=1.0
		opened=1;focus=0;heat=0;spread=maxf(spread,0.25*fracture)
		dilate=smoothstep(0.0,0.35,broken)*(1-smoothstep(m.stunned_until-0.6,m.stunned_until,t))
		flash=maxf(flash,exp(-broken*12)*0.65)
	elif t<m.refill_until:
		fracture=1-smoothstep(m.stunned_until,m.refill_until,t)
	if dying>=0:
		opened=1-smoothstep(0.15,1.12,dying)
		spread=smoothstep(0.0,0.95,dying)
		presence=1-smoothstep(0.8,1.3,dying)
		morph=smoothstep(0.15,0.85,dying)
		emergence=1-smoothstep(0.1,1.1,dying);rift_open=1-smoothstep(0.65,1.3,dying)
	if not g.reduced and not shifting and dying<0 and m.move.is_empty() and not m.exposed():
		# Slow lid tension, with a small, infrequent blink; pupil never pulses.
		var blink:float=fposmod(t+1.7,8.7)
		opened*=1-0.32*exp(-pow((blink-7.7)/0.12,2))
	if dying>=0:dilate=1-smoothstep(0.2,0.9,dying);heat=0
	var impact:float=m.visuals.impulse(t)
	# Ward crystals follow the real meter; each seal contact flashes the ring.
	var ward:float=clampf(float(d.fight.data.get("ward",100))/100.0,0,1)
	var ward_show:float=0.0 if m.exposed() or dying>=0 else smoothstep(1.4,2.6,intro)*(1-smoothstep(0.05,0.6,shift)+smoothstep(2.6,3.3,shift) if shifting else 1.0)
	var ward_flash:=0.0
	for event in m.visuals.events:
		if event.kind=="ward" and t>=event.born:ward_flash=maxf(ward_flash,exp(-(t-event.born)*9))
	var damage:float=1-clampf(float(d.fight.hp)/maxf(1,float(d.fight.max)),0,1)
	opened*=1-impact*0.12
	flash=maxf(flash,impact*0.6)
	if g.reduced:lift=0;size=1;flash*=0.35
	return {"opening":clampf(opened,0,1),"presence":presence,"spread":spread,
		"flash":flash,"lift":lift,"size":size,"morph":morph,"stage":stage,"shifting":shifting,"origin":origin,"ritual":ritual,
		"upper_lid":upper,"lower_lid":lower,"focus":focus,"fracture":fracture,"recoil":recoil*(0.3 if g.reduced else 1.0),"pose":pose_name,
		"rift_open":rift_open,"emergence":emergence,"heat":clampf(heat,0,1),"laser_pulse":laser_pulse,
		"dilate":clampf(dilate,0,1),"ward":ward,"ward_show":clampf(ward_show,0,1),"ward_flash":ward_flash*(0.5 if g.reduced else 1.0),"damage":damage}
