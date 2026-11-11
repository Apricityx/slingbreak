extends "res://src/core/variants/rule.gd"
## 限箭挑战: a board/loadout estimate sets a visible target. Missing the target
## tapers the extra reward, never confiscates the normal core bonus.
const Progress=preload("res://src/core/progress.gd")

func title() -> String:return "限箭挑战"
func color() -> String:return "#8d78b9"
func note() -> String:return "目标 %d 箭内击破核心：奖金 ×2，每省一箭 +0.1（最多 ×3）；每超一箭 -0.15，最低保留 ×1。首箭前按砖阵与装备更新目标。" % int(data.get("par",8))

func shape() -> void:
	data={"par":estimate()}

func estimate() -> int:
	var contacts:Array=[]
	for brick in g.bricks:contacts.append(ceil(brick.hp/maxf(0.1,g.damage())))
	contacts.sort()
	var work:=0.0
	for hits in contacts.slice(0,maxi(0,g.threshold-g.killed)):work+=float(hits)
	# Modest routing allowance plus two arrows for the core. Raw historical
	# shot counts include unrelated variants and must not set this board's par.
	return clampi(ceili(work/maxf(1.0,g.penetration()*0.8))+2,6,240)

func update(_delta:float) -> void:
	if used()==0:data.par=estimate()

func launched(arrow:RefCounted) -> void:
	if arrow.flags.get("main",false) and used()==1:data.par=estimate()

func valid(saved:Dictionary) -> bool:return Progress.finite_number(saved.get("par"),3,240,true)

func used() -> int:
	return int(g.state.skillRuntime.get("shots",0)) if g.state.skillRuntime is Dictionary else 0

func bonus_scale() -> float:
	var spare:int=int(data.par)-used()
	return minf(3.0,2.0+0.1*spare) if spare>=0 else maxf(1.0,2.0+0.15*spare)

func status() -> String:
	return "%d/%d 箭 · 奖金 ×%s" % [used(),int(data.par),String.num(bonus_scale(),2)]

func summary() -> Array:return ["%d / %d 箭" % [used(),int(data.par)]]
