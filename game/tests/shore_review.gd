extends "res://tests/render_review.gd"
func run():
	Engine.max_fps=10
	Journey.save_path="user://isolated-shore-review.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await chapter(0);colour(1)
	var h=garden.geometry.find_child("ShoreHouse0",true,false)
	await shot("house",h.to_global(Vector3(11,6,-16)),h.to_global(Vector3(0,3.4,0)))
	await shot("bank",h.to_global(Vector3(10,3.1,-7)),h.to_global(Vector3(5.9,-.1,-2.8)))
	await shot("tidal-water",h.to_global(Vector3(10,1.7,-2)),h.to_global(Vector3(7.9,-.65,0)))
	await shot("meadow",h.to_global(Vector3(6.9,1.25,-3.8)),h.to_global(Vector3(5.4,.4,-1.3)))
	await shot("sea",Vector3(-9,2.6,14),Vector3(-6,-1,50))
	await shot("ripples",Vector3(-9,.6,14),Vector3(-7,-1.3,23))
	get_tree().quit(0 if failures.is_empty() else 1)
