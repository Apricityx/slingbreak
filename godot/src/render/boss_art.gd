extends RefCounted
## Boss art reads the real targets, deadlines, hands, segments and portals. Every
## interactive shape is painted from the collider's state in world coordinates.
var c:Node2D
var canvas:CanvasItem
var g:RefCounted
var d:RefCounted
var m:RefCounted
var p:Dictionary
var t:float
var abyss:=preload("res://src/render/abyss_art.gd").new()
var clock_art:=preload("res://src/render/clock_art.gd").new()
var serpent_art:=preload("res://src/render/serpent_art.gd").new()
var forge_art:=preload("res://src/render/forge_art.gd").new()

func paint(board:Node2D,front:bool) -> void:
	var director:RefCounted=board.simulation.bosses
	if director.model==null or director.exploded:return
	c=board;canvas=board.draw_on;g=c.simulation;d=director;m=d.model;p=d.palette();t=g.presentation_time
	match d.boss_id:
		"eye":abyss.paint(self,front)
		"clock":clock(front)
		"serpent":serpent(front)
		"forge":forge(front)
	canvas.draw_set_transform(Vector2.ZERO)

func color(key:String,opacity:float=1) -> Color:return c.alpha(Color(p[key]),opacity)
func line(a:Vector2,b:Vector2,key:String,width:float=2,opacity:float=1) -> void:canvas.draw_line(a,b,color(key,opacity),width,true)
func ring(at:Vector2,r:float,key:String,width:float=2,opacity:float=1) -> void:
	if r>0:canvas.draw_arc(at,r,0,TAU,64,color(key,opacity),width,true)
func circle(at:Vector2,r:float,key:String,opacity:float=1) -> void:canvas.draw_circle(at,maxf(0.01,r),color(key,opacity))
func ellipse(at:Vector2,r:Vector2,key:String,fill:bool=false,width:float=2,opacity:float=1) -> void:
	var points:=PackedVector2Array()
	for index in range(65):points.append(at+Vector2(cos(index*TAU/64),sin(index*TAU/64))*r)
	if fill:canvas.draw_colored_polygon(points,color(key,opacity))
	else:canvas.draw_polyline(points,color(key,opacity),width,true)
func polygon(points:PackedVector2Array,key:String,edge:String="",width:float=2,opacity:float=1) -> void:
	canvas.draw_colored_polygon(points,color(key,opacity))
	if edge!="":points.append(points[0]);canvas.draw_polyline(points,color(edge,opacity),width,true)
func glow(at:Vector2,r:float,key:String,opacity:float=0.25) -> void:
	for index in range(16,0,-1):circle(at,r*index/16,key,opacity*(1-index/17.0)/6)
func countdown(at:Vector2,r:float,key:String,start:float,end:float) -> void:
	var remaining:=clampf((end-t)/maxf(0.001,end-start),0,1)
	if remaining>0:canvas.draw_arc(at,r,-PI/2,-PI/2+TAU*remaining,64,color(key),3,true)
func text(value:String,at:Vector2,size:int,key:String) -> void:c._text(value,at,size,color(key))
func bezier(a:Vector2,b:Vector2,end:Vector2) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for index in range(25):
		var k:float=index/24.0
		points.append(a*pow(1-k,2)+2*b*(1-k)*k+end*k*k)
	return points
func cog(at:Vector2,r:float,teeth:int,angle:float,fill:bool=false) -> void:
	var points:=PackedVector2Array()
	for index in range(teeth*2):points.append(at+Vector2.from_angle(angle+index*PI/teeth)*r*(0.82 if index%2 else 1))
	if fill:polygon(points,"brass","rim")
	else:points.append(points[0]);canvas.draw_polyline(points,color("brassDeep"),2,true);ring(at,r*0.3,"brassDeep")

func clock(front:bool) -> void:clock_art.paint(self,front)

func serpent(front:bool) -> void:serpent_art.paint(self,front)

func forge(front:bool) -> void:forge_art.paint(self,front)
