extends "res://tests/render_review.gd"
func run():
	Engine.max_fps=10;Journey.save_path="user://isolated-repair-review.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	await chapter(1)
	await shot("render-02-greenhouse-morning",Vector3(-9.2,3.3,.5),Vector3(0,7,-1))
	await shot("detail-03-potting-bench",Vector3(-5,3.2,-.7),Vector3(-7,2.6,-2.7))
	await shot("render-05-nursery-canopy",Vector3(6.9,2.8,5.5),Vector3(9.2,3.0,2.0))
	await repair_result_shots()
	FileAccess.open(output.path_join("repair-render-audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"failures":failures,"renderables":inventory},"\t"))
	print("REPAIR_RENDER: ",captures.size()," frames; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
