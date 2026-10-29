extends Control
## A clipped nine-cell native icon strip, with a small overshoot on locking.
signal locked
const Easing=preload("res://src/ui/easing.gd")
var visuals:RefCounted
var icons:Array=[]
var final_icon:=""
var ink:=Color.WHITE
var delay:=0.0
var duration:=.52
var age:=0.0
var tick:=Callable()
var tick_index:=0
var strip:Control
var base:Control
var reduced:=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base=get_parent().get_child(0)
	strip=Control.new();strip.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(strip)
	for i in range(9):
		var texture:=TextureRect.new();texture.texture=visuals.icon(final_icon if i==7 else icons[(i*13+int(duration*100))%icons.size()],ink)
		texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		strip.add_child(texture)
	_paint(0.0)
	base.visible=false

func _process(delta:float) -> void:
	age+=delta
	var p:=clampf((age-delay)/duration,0,1)
	var offset:float
	if p<.84:offset=7.28*Easing.bezier(p/.84,.3,.1,.3,1)
	else:offset=lerpf(7.28,7,Easing.bezier((p-.84)/.16,.3,0,.4,1))
	_paint(offset)
	while tick.is_valid() and tick_index<6 and age>delay+duration*.86*(1-pow(1-(tick_index+1)/6.0,.55)):
		tick.call();tick_index+=1
	if p>=1:
		# Keep the final rolling texture as the resting icon. Its tint and size
		# therefore remain identical on the frame where the reel locks.
		var final_cell:TextureRect=strip.get_child(7)
		var image:TextureRect=base.get_child(0)
		image.texture=final_cell.texture;base.visible=true
		visible=false
		locked.emit();queue_free()

func _paint(offset:float) -> void:
	strip.position.y=-offset*size.y
	var image:TextureRect=base.get_child(0)
	var icon_size:=image.size.max(image.get_combined_minimum_size())
	var inset:Vector2=(size-icon_size)/2
	for i in range(9):
		var cell:Control=strip.get_child(i);cell.position=inset+Vector2(0,i*size.y);cell.size=icon_size;cell.modulate.a=1 if i==7 else .55
