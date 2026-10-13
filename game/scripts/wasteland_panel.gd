extends PanelContainer
# Salvaged sheet-metal frame. All wear stays outside the reading area.
var paper = false
func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw():
	var edge=Color("78654a") if paper else Color("4d594e")
	var rust=Color("8b5037")
	var dark=Color("655b47") if paper else Color("121a17")
	draw_rect(Rect2(2,2,size.x-4,7),edge)
	draw_rect(Rect2(2,size.y-8,size.x-4,6),dark)
	for x in [12.0,size.x-12.0]:
		for y in [15.0,size.y-15.0]:
			draw_circle(Vector2(x,y),3.6,dark)
			draw_arc(Vector2(x,y),3.5,PI,TAU,12,edge,1.0,true)
			draw_line(Vector2(x-1.5,y+1.5),Vector2(x+1.5,y-1.5),edge,1.0,true)
	# Sparse scratches, oxidation and a folded archive corner are authored marks.
	for i in 18:
		var x=24+fmod(i*137.7,maxf(1,size.x-48))
		var y=4.0 if i%2==0 else size.y-5.0
		draw_line(Vector2(x,y),Vector2(x+3+(i%4)*2,y+1),rust if i%3==0 else edge,1.0)
	for i in 7:
		var y=36+fmod(i*83.3,maxf(1,size.y-72))
		draw_rect(Rect2(2,y,2,4+i%3),rust)
	if paper:
		draw_colored_polygon(PackedVector2Array([Vector2(size.x-22,9),Vector2(size.x-9,9),Vector2(size.x-9,22)]),Color("a99a78"))
