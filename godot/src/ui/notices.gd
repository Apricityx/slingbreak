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
		var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",visuals.box(visuals.color("surface"),visuals.color("legend-prism"),20,6));holder.add_child(card)
		var row:HBoxContainer=visuals.row(card,8);visuals.text(row,lines[0],14,"ink",true)
		var sub:Label=visuals.text(row,lines[1],11,"text-2");sub.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;sub.custom_minimum_size.x=180
		card.size=card.get_combined_minimum_size();card.size.x=minf(388,card.size.x);card.position=Vector2((412-card.size.x)/2,float(str(item.get("top","34%")).trim_suffix("%"))/100*572-card.size.y/2)
		if not reduced:Motion.enter(card)
	else:
		var intro:bool=item.kind=="rift-intro"
		if intro:
			for y in [0,498]:
				var bar:=ColorRect.new();bar.color=visuals.color("panel");bar.position.y=y;bar.size=Vector2(412,74);holder.add_child(bar)
		var words:=VBoxContainer.new();words.add_theme_constant_override("separation",6);words.position=Vector2(0,229 if intro else 194);words.size.x=412;holder.add_child(words)
		for i in range(lines.size()):
			var text:Label=visuals.text(words,lines[i],38 if intro and i==1 else 30 if i==1 else 11,"danger" if i==0 and (intro or item.get("tone","")=="rage") else "legend-prism" if i==0 else "ink" if i==1 else "text-2",i<2,true);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if not reduced:Motion.enter(holder)
