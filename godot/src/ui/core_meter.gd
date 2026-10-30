extends ProgressBar
## Segmented native version of achievements.css's core-unlock track.
var visuals:RefCounted
var state:="locked"
var reduced:=false
var age:=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	show_percentage=false
	value_changed.connect(func(_value):queue_redraw())

func present(next_state:String,still:bool) -> void:
	if state==next_state and reduced==still:return
	state=next_state;reduced=still
	set_process(state=="ready" and not reduced and visible)
	queue_redraw()

func _process(delta:float) -> void:
	age=fmod(age+delta,8.0);queue_redraw()

func _draw() -> void:
	if visuals==null:return
	if state=="ready":
		# Paint only inside the track; the three one-pixel cuts stay stationary.
		for x in range(int(size.x)):
			var phase:=float(x)/maxf(1,size.x)+(0.0 if reduced else age/2.0)
			var ink:Color=visuals.mix(visuals.color("accent-ink"),visuals.color("accent-bar"),.5-.5*cos(phase*TAU))
			draw_line(Vector2(x,1),Vector2(x,size.y-1),ink,1)
	for fraction in [.25,.5,.75]:
		draw_rect(Rect2(Vector2(floor(size.x*fraction)-1,0),Vector2(1,size.y)),visuals.color("bg"))
