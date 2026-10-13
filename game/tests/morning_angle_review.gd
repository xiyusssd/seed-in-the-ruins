extends "res://tests/render_review.gd"
func run():
	Engine.max_fps=10
	Journey.save_path="user://isolated-morning-angle-review.json";Journey.fresh();Journey.chapter=1
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await chapter(1)
	await shot("greenhouse-a",Vector3(-9.2,3.3,.5),Vector3(0,7,-1))
	await shot("greenhouse-b",Vector3(-8.5,2.8,-.4),Vector3(3,7.2,2.5))
	print("MORNING_ANGLE_RENDER: ",captures.size()," frames; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
