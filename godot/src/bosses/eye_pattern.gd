extends RefCounted
## Eye-only authored sequencing and the V5 gaze / tear contracts. Pure helpers:
## no board writes, presentation or gameplay RNG.
const VERSION:=5
## Gaze: lock + charge (pupil open to counter), one sweep, short recovery.
const ANTICIPATION:=2.2
const SWEEP:=1.6
const RECOVERY:=0.6
const ARC:=0.92
const PETRIFY_LIMIT:=6
const BEAM_FLOOR:=760.0
## Ward: twelve crystals, each direct seal contact chips one.
const CHIP:=100.0/12
const CHIP_LIMIT:=4
## Any ward damage pauses anchor regeneration, so steady pressure wins.
const REGEN_DELAY:=1.8
const TEARS:=3
const TEAR_FALL:=2.3
const TEAR_GAP:=0.55
const TEAR_DRAIN:=34.0
const SEQUENCES:=[ ["orbit","tear"], ["gaze","mirage","summon"], ["gaze","doom","orbit","doom"] ]

static func choose(fight:Dictionary) -> String:
	var key:String=str(int(fight.phase))
	var cursor:int=int(fight.data.sequence.get(key,0))
	var sequence:Array=SEQUENCES[fight.phase-1]
	return sequence[cursor%sequence.size()]

static func accepted(fight:Dictionary,id:String) -> void:
	if id!=choose(fight):return
	var key:String=str(int(fight.phase))
	fight.data.sequence[key]=(int(fight.data.sequence.get(key,0))+1)%SEQUENCES[fight.phase-1].size()

## Older eye saves (unversioned / V3 / V4) resume on the V5 contract, keeping
## phase, HP, ward and the authored cursor; no transient cast is persisted.
static func migrate(fight:Dictionary) -> void:
	if int(fight.data.get("encounterVersion",0))==VERSION:return
	fight.abilities=[["orbit","tear"],["gaze","mirage","summon"],["gaze","orbit","doom"]]
	fight.data.encounterVersion=VERSION
	var sequence:Variant=fight.data.get("sequence")
	fight.data.sequence=sequence if sequence is Dictionary else {}

## Sweep angle at time t; dir chooses left→right or right→left.
static func sweep_angle(move:Dictionary,t:float) -> float:
	var k:float=smoothstep(0.0,1.0,clampf((t-move.live)/SWEEP,0,1))
	return PI/2-move.dir*ARC*(1-2*k)

## The beam stops at the side walls or above the launcher lane, never past it.
static func beam_end(center:Vector2,angle:float) -> Vector2:
	var dir:=Vector2.from_angle(angle)
	var reach:float=(BEAM_FLOOR-center.y)/maxf(0.001,dir.y)
	if dir.x>0.001:reach=minf(reach,(760-center.x)/dir.x)
	elif dir.x<-0.001:reach=minf(reach,(20-center.x)/dir.x)
	return center+dir*reach

## Tear i launches from the lower lid toward its lane and falls in TEAR_FALL s.
static func tear_position(tear:Dictionary,t:float,center:Vector2) -> Vector2:
	var k:float=clampf((t-tear.at)/TEAR_FALL,0,1)
	var start:=center+Vector2(float(tear.side)*34,40)
	var x:float=lerpf(start.x,tear.x,smoothstep(0,0.45,k))+sin(k*9.0+tear.x)*10*k
	return Vector2(x,lerpf(start.y,860,k*k*0.55+k*0.45))
