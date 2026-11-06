extends "res://src/core/variants/rule.gd"
## 封印核心: the core shows up early (threshold ×0.6) but stays sealed until
## SEALS marked bricks are broken; coins from the skipped bricks are the cost
## of rushing it, so the core bonus is only ×1.3.
const Progress=preload("res://src/core/progress.gd")
const SEALS:=3
const TINT:="#b06ad0"

func title() -> String:return "封印核心"
func color() -> String:return TINT
func note() -> String:return "核心提前显现 · 击碎 %d 块封印砖解封" % int(data.get("total",SEALS))

func shape() -> void:
	# Seal bricks sit in the lower half so the unlock is not a free top-row hit.
	var pool:Array=g.shuffle(g.bricks.filter(func(b):return b.type=="normal" and b.y>=350))
	if pool.size()<SEALS:pool=g.shuffle(g.bricks.filter(func(b):return b.type=="normal"))
	var chosen:Array=pool.slice(0,SEALS)
	for brick in chosen:brick.flags.seal=true
	data={"total":chosen.size(),"denied":0}

func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("total"),0,SEALS,true) and Progress.finite_number(saved.get("denied"),0,100000,true)

func seals() -> Array:return g.bricks.filter(func(b):return b.flags.get("seal",false))
func threshold_scale() -> float:return 0.6

func destroyed(brick:RefCounted) -> void:
	if not brick.flags.get("seal",false):return
	var left:int=seals().size()
	g.fx.ring(brick.position,Color(TINT),70)
	if left==0:
		var point:=Vector2(g.core.x,g.core.y) if g.core!=null else Vector2(390,80)
		g.fx.ring(point,Color(TINT),160);g.fx.burst(point,Color(TINT),24,1.4);g.cue("core")
		g.events.append({"type":"toast","text":"封印解除 · 核心可被击破"})
	else:g.fx.floating(brick.position,"封印 %d/%d" % [int(data.total)-left,int(data.total)],Color(TINT),15)

func core_hit(arrow:RefCounted) -> bool:
	if seals().is_empty():return true
	data.denied=int(data.denied)+1
	var point:=Vector2(g.core.x,g.core.y)
	g.fx.ring(point,Color(TINT),60);g.cue("clang",1,point.x)
	if not arrow.flags.get("sealHinted",false):
		arrow.flags.sealHinted=true;g.fx.floating(point+Vector2(0,48),"封印 剩 %d" % seals().size(),Color(TINT),15)
	return false

func bonus_scale() -> float:return 1.3
func status() -> String:
	var left:int=seals().size()
	return "封印 剩 %d" % left if left>0 else "已解封"
func summary() -> Array:return ["%d 道封印" % int(data.total)]

## Seal bricks wear a halo; while sealed the core is ringed and tethered to them.
func draw(canvas:CanvasItem) -> void:
	var tint:=Color(TINT)
	var left:=seals()
	for brick in left:
		tint.a=0.7;canvas.draw_rect(brick.bounds.grow(4),tint,false,2)
	if g.core==null or left.is_empty():return
	var point:Vector2=g.core_display_position()
	tint.a=0.6;canvas.draw_arc(point,46,0,TAU,48,tint,2.5,true)
	tint.a=0.16
	for brick in left:canvas.draw_line(point,brick.position,tint,1,true)
