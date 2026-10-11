extends Control
## Boss title/callout cards follow the native director's announcement lifetime.
var visuals: RefCounted
var signature:=""

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;position=Vector2(0,238);size=Vector2(412,572);z_index=7

func present(frame: Dictionary) -> void:
	var items:Array=frame.get("notices",[])
	var next:=JSON.stringify([items,frame.theme])
	if signature==next:return
	signature=next
	for child in get_children():remove_child(child);child.queue_free()
	for item in items:
		var lines:Array=[item.get("kicker",""),item.get("title",""),item.get("note","")]
		if lines.is_empty():continue
		if item.kind=="rift-callout":
			var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",visuals.box(visuals.color("surface"),visuals.color("legend-prism"),20,6));add_child(card)
			if not frame.get("reduced",false):preload("res://src/ui/motion.gd").enter.call_deferred(card)
			var row:HBoxContainer=visuals.row(card,8);visuals.text(row,lines[0],14,"ink",true)
			if lines.size()>1:
				var sub:Label=visuals.text(row,lines[1],11,"text-2");sub.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;sub.custom_minimum_size.x=180
			card.size=card.get_combined_minimum_size();card.size.x=minf(388,card.size.x);card.position=Vector2((412-card.size.x)/2,float(str(item.get("top","34%")).trim_suffix("%"))/100*572-card.size.y/2)
		else:
			var intro:bool=item.kind=="rift-intro"
			if intro:
				for y in [0,498]:
					var bar:=ColorRect.new();bar.color=visuals.color("panel");bar.position.y=y;bar.size=Vector2(412,74);add_child(bar)
			var words:=VBoxContainer.new();words.add_theme_constant_override("separation",6);words.position=Vector2(0,229 if intro else 194);words.size.x=412;add_child(words)
			for i in range(lines.size()):
				var text:Label=visuals.text(words,lines[i],38 if intro and i==1 else 30 if i==1 else 11,"danger" if i==0 and (intro or item.tone=="rage") else "legend-prism" if i==0 else "ink" if i==1 else "text-2",i<2,true);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	visuals.pointer_through(self)
