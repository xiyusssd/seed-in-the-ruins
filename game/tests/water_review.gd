extends "res://tests/render_review.gd"
func run():
 Engine.max_fps=10
 Journey.save_path="user://isolated-water-review.json";Journey.fresh()
 garden=load("res://garden.tscn").instantiate();add_child(garden)
 await chapter(0);colour(1)
 await shot("sea-check",Vector3(-9,2.6,14),Vector3(-6,-1,50))
 await shot("water-check",Vector3(-5,4.2,1),Vector3(-3,2.8,-1))
 get_tree().quit()
