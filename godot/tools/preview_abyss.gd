extends RefCounted
static func setup(g:RefCounted,id:String) -> void:
	g.state.level=100;g.state.skillChosenLevel=100;g.state.bossOverride={"level":100,"boss":"eye"};g.generate()
	g.phase="ready";g.board_entrance=null;g.bosses.fight.intro=true
	if id not in ["eye_intro","eye_nebula","eye_model","eye_phase","eye_phase_close"]:
		g.bosses.fight.phase=3 if id=="eye_doom" else 2;g.bosses.model.setup(false)
	g.time=0;g.presentation_time=0;g.fx.reset();g.pointer=Vector2(440,720)
	g.bosses.intro_at=0 if id in ["eye_intro","eye_nebula"] else -4
	g.bosses.model.next_at=100
	g.bosses.model.phase_at=-100;g.bosses.model.phase_revealed=true
	g.bosses.model.visuals.reset()
	if id in ["eye_gaze","eye_gaze_counter","eye_gaze_failure","eye_ward"]:
		g.state.up.power=30;g.state.up.arrow=24;g.state.skills={"railgun":1}
		g.bosses.fight.max=ceil(g.damage()*(24+6*g.bosses.fight.phase));g.bosses.fight.hp=g.bosses.fight.max
	if id in ["eye_intro","eye_nebula"]:g.bosses.model.intro()
	if id=="eye_ward":
		# Mid-fight seal (four crystals left) so the loop reaches the break.
		g.bosses.fight.data.ward=g.bosses.model.Pattern.CHIP*4
		# Open a central lane so the ward itself is the visible target.
		for brick in g.bricks.duplicate():
			if absf(brick.x-390)<70:g.bricks.erase(brick)
	if id=="eye_summon":
		# A clear, reachable ritual site within a dense production board.
		for brick in g.bricks.duplicate():
			if brick.position.distance_to(Vector2(390,650))<72:g.bricks.erase(brick)

static func contact(g:RefCounted,point:Vector2) -> void:
	var m:RefCounted=g.bosses.model
	var before:int=m.visuals.serial
	var arrow:RefCounted=g.launch(point,Vector2(0,-24))
	g.bosses.contact(arrow,true);g.arrows.clear()
	assert(m.visuals.serial>before,"Boss contacts must emit real presentation events")
static func step(entry:Dictionary,time:float) -> void:
	var g:RefCounted=entry.g;var m:RefCounted=g.bosses.model
	if entry.id=="eye_nebula":
		while float(entry.get("elapsed",0))+1.0/60<=time+0.00001:
			m.next_at=100;g.update(1.0/60);entry.elapsed=float(entry.get("elapsed",0))+1.0/60
		return
	if entry.id in ["eye_gaze_counter","eye_gaze_failure","eye_ward"]:
		step_gaze(entry,maxf(0,time));return
	var previous:float=g.time
	if entry.id in ["eye_phase","eye_phase_close","eye_final_phase","eye_death"]:
		# Trigger the real phase controller and run its board entrance/input lock.
		if time>=0.3 and entry.id=="eye_death" and not entry.get("shifted",false):
			g.bosses.fight.phase=3;g.bosses.fight.hp=0;entry.shifted=true
		elif time>=1.0 and not entry.get("shifted",false):
			g.bosses.fight.hp=0;entry.shifted=true
		g.clock=maxf(0,time)
		if time>previous:g.tick(time-previous)
		g.presentation_time=g.time
		return
	g.time=maxf(0,time);g.clock=g.time;g.presentation_time=g.time
	g.pointer=Vector2(390+sin(time)*240,650)
	if time>=0 and not entry.fired:
		if entry.id=="eye_gaze":m.begin("gaze")
		elif entry.id=="eye_doom":m.begin("doom")
		elif entry.id=="eye_mirage":m.begin("mirage")
		elif entry.id in ["eye_summon","eye_tear","eye_orbit"]:m.begin(entry.id.trim_prefix("eye_"))
		entry.fired=true
	if entry.id=="eye_doom" and not m.move.is_empty():
		var contacts:int=entry.get("contacts",0)
		if contacts<3 and time>=2.0+contacts*0.85:
			contact(g,m.center+Vector2(0,m.Rig.PUPIL_RADIUS+12));entry.contacts=contacts+1
	if entry.id=="eye_impact":
		var contacts:int=entry.get("contacts",0)
		if contacts==0 and time>=0.5:contact(g,m.center+Vector2(0,m.Rig.WARD_RADIUS+12));entry.contacts=1
		elif contacts==1 and time>=1.2:m.begin("doom");entry.contacts=2
		elif contacts>=2 and contacts<5 and time>=2.1+(contacts-2)*0.4:
			contact(g,m.center+Vector2(0,m.Rig.PUPIL_RADIUS+12));entry.contacts=contacts+1
	if entry.id=="eye_intro" and time>=m.Rig.INTRO_SECONDS and not entry.get("orbit_started",false):
		m.begin("orbit");entry.orbit_started=true
	m.update(maxf(0,g.time-previous))
	g.fx.update(maxf(0,g.time-previous))

static func step_gaze(entry:Dictionary,time:float) -> void:
	var g:RefCounted=entry.g;var m:RefCounted=g.bosses.model
	# Fixed 60 Hz production ticks even when capture frames are only 25 Hz.
	while float(entry.get("elapsed",0))+1.0/60<=time+0.00001:
		if entry.id=="eye_ward":
			# Real shots into the seal: each contact chips crystals until it breaks.
			var pull:Vector2=(g.origin-m.center).normalized()*100
			if not m.exposed() and g.time>=0.3 and g.shoot(pull.x,pull.y):entry.shots=int(entry.get("shots",0))+1
		elif not entry.fired and g.time>=0.4:
			m.begin("gaze");entry.fired=true
			assert(m.move.get("id")=="gaze","Fixture must use the production gaze cast")
			entry.pull=(g.origin-m.center).normalized()*100
		if entry.id=="eye_gaze_counter" and entry.fired:
			# Answer the open pupil mid-charge through the real launcher.
			var shots:int=entry.get("shots",0)
			if shots<1 and g.time>=1.75:
				var pull:Vector2=entry.pull
				if g.shoot(pull.x,pull.y):entry.shots=shots+1;g.drag=null
			elif shots==0 and g.time>=1.1:g.drag={"dx":entry.pull.x,"dy":entry.pull.y}
		m.next_at=100
		g.update(1.0/60);entry.elapsed=float(entry.get("elapsed",0))+1.0/60
		if m.exposed() and not entry.has("broken_at"):entry.broken_at=g.time
		if g.time>4 and entry.id=="eye_gaze_counter":assert(entry.has("broken_at"),"Real launcher must interrupt")
