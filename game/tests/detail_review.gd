extends "res://tests/render_review.gd"
func run():
	Engine.max_fps=10
	Journey.save_path="user://isolated-detail-review.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await chapter(0);colour(1)
	await shot("detail-roof",Vector3(-40,16,-59),Vector3(-37.3,11.5,-55.4))
	await shot("detail-town",Vector3(-12,12,26),Vector3(-43,12,-26))
	await chapter(1);colour(1)
	await shot("detail-bench",Vector3(-5.0,3.2,-.7),Vector3(-7,2.6,-2.7))
	print("DETAIL_AUDIT: failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
