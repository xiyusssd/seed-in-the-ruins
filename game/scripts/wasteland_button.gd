extends Button
var primary = false
func _draw():
	var ink=Color("56432a") if primary else Color("8c8265")
	var x=13.0
	for y in [-4,0,4]:draw_line(Vector2(x,size.y/2+y),Vector2(x+5,size.y/2+y),ink,1.0)
	var screw=Vector2(size.x-12,size.y/2)
	draw_circle(screw,2,ink)
	draw_line(screw+Vector2(-1,-1),screw+Vector2(1,1),Color("262d26"),1.0)
	if has_focus():draw_line(Vector2(3,4),Vector2(3,size.y-4),Color("ddbb75"),2.0)
