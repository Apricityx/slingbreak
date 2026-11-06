extends Control
## Each announcement owns its entrance and retirement, so replacing a callout
## does not restart the other cards or remove their unfinished exit animations.
const Motion=preload("res://src/ui/motion.gd")
var visuals: RefCounted
var cards:Dictionary={}
var current_theme:=""

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;position=Vector2(0,238);size=Vector2(412,572);z_index=7

func present(frame: Dictionary) -> void:
	var wanted:Dictionary={}
	if current_theme!=frame.theme:
		for card in cards.values():card.queue_free()
		cards.clear();current_theme=frame.theme
	for item in frame.get("notices",[]):
		# Boss status changes are communicated visually, without footer callouts.
		if item.kind=="rift-callout":continue
		var key:=str(item.get("key",JSON.stringify(item)))
		wanted[key]=true
		if cards.has(key):continue
		var holder:=Control.new();holder.size=size;holder.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(holder)
		cards[key]=holder
		_build(holder,item,frame.get("reduced",false))
	for key in cards.keys():
		if wanted.has(key):continue
		var card:Control=cards[key];cards.erase(key)
		if frame.get("reduced",false):card.queue_free()
		else:Motion.leave(card,.24)
	visuals.pointer_through(self)

func _build(holder:Control,item:Dictionary,reduced:bool) -> void:
	var lines:Array=[item.get("kicker",""),item.get("title",""),item.get("note","")]
	if item.kind=="rift-callout":
		_build_boss_status(holder,item,reduced)
	else:
		var intro:bool=item.kind=="rift-intro"
		if intro:
			for y in [0,498]:
				var bar:=ColorRect.new();bar.color=visuals.color("panel");bar.position.y=y;bar.size=Vector2(412,74);holder.add_child(bar)
		var words:=VBoxContainer.new();words.add_theme_constant_override("separation",6);words.position=Vector2(0,229 if intro else 194);words.size.x=412;holder.add_child(words)
		for i in range(lines.size()):
			var text:Label=visuals.text(words,lines[i],38 if intro and i==1 else 30 if i==1 else 11,"danger" if i==0 and (intro or item.get("tone","")=="rage") else "legend-prism" if i==0 else "ink" if i==1 else "text-2",i<2,true);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if not reduced:Motion.enter(holder)

func _build_boss_status(holder:Control,item:Dictionary,reduced:bool) -> void:
	# The right half of the earnings footer is reserved for transient boss
	# messages. Never cover the board, boss health, queue or aiming controls.
	holder.position=Vector2(218,590);holder.size=Vector2(178,74)
	var tone:String=item.get("tone","minor")
	var accent:Color=visuals.color("accent" if tone=="weak" else "on-panel")
	var rule:=ColorRect.new();rule.position=Vector2(0,4);rule.size=Vector2(2,62)
	rule.color=Color(accent,0.65);holder.add_child(rule)
	var words:=VBoxContainer.new();words.position=Vector2(12,0);words.size=Vector2(166,74)
	words.add_theme_constant_override("separation",3);holder.add_child(words)
	var caption:Label=visuals.text(words,{"weak":"弱点暴露","rage":"狂暴预警","shift":"阶段变化","seal":"战斗结束"}.get(tone,"首领动态"),9,"on-panel",true)
	caption.modulate.a=0.6
	var title:Label=visuals.text(words,item.get("title",""),18,"on-panel",true)
	title.add_theme_color_override("font_color",accent)
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var note:Label=visuals.text(words,item.get("note",""),10,"on-panel",false,true)
	note.modulate.a=0.8;note.visible=not note.text.is_empty()
	if not reduced:
		holder.modulate.a=0.0;Motion.fade(holder,1.0,.2)
