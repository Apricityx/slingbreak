extends SceneTree
## Fixed 5-minute simulation workload; excludes rendering/audio/device scheduling.
const Session=preload("res://src/core/session.gd")

func _initialize() -> void:
	var session:=Session.new();session.start(9128)
	session.runtime.state.level=50;session.runtime.state.up.slots=3
	session.runtime.state.skills={"spectral":1,"lightning":1,"supernova":1,"timeslip":1};session.runtime.state.skillChosenLevel=50;session.runtime.generate()
	var timings:=PackedFloat64Array();var peak_jobs:=0;var peak_arrows:=0;var peak_particles:=0
	var initial_bytes:=OS.get_static_memory_usage()
	for i in range(18000):
		if i%75==0 and session.runtime.phase in ["ready","flying"]:session.command("shoot",{"dx":sin(i*.13)*75,"dy":100})
		if session.runtime.phase=="draft":session.command("choose",{"id":session.frame.draft.options[0]})
		var start:=Time.get_ticks_usec();session.update(1.0/60)
		timings.append((Time.get_ticks_usec()-start)/1000.0)
		peak_jobs=maxi(peak_jobs,session.runtime.skills.jobs.size());peak_arrows=maxi(peak_arrows,session.runtime.arrows.size());peak_particles=maxi(peak_particles,session.runtime.fx.particles.size())
	timings.sort()
	var report:={"seed":9128,"frames":timings.size(),"simulatedSeconds":300,"includes":"Native simulation, skill/Boss updates and semantic UI snapshots; excludes CanvasItem rendering, audio output and device scheduling","performanceMode":session.frame.performanceMode,"milliseconds":{"p50":timings[int(timings.size()*.5)],"p95":timings[int(timings.size()*.95)],"p99":timings[int(timings.size()*.99)],"max":timings[timings.size()-1]},"peakJobs":peak_jobs,"peakArrows":peak_arrows,"peakParticles":peak_particles,"initialStaticBytes":initial_bytes,"finalStaticBytes":OS.get_static_memory_usage()}
	DirAccess.make_dir_recursive_absolute("res://../agent-tmp/godot/native")
	var file:=FileAccess.open("res://../agent-tmp/godot/native/native-soak.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if peak_jobs<=512 and peak_arrows<=64 and peak_particles<=300 else 1)
