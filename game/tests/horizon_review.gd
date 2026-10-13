extends "res://tests/render_review.gd"
func run():
	Engine.max_fps=10
	Journey.save_path="user://isolated-horizon-review.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	await chapter(0)
	await horizon_shots()
	await shot("render-01-coastal-reflections",Vector3(22,.8,16),Vector3(-14,8,-14))
	await shot("shore-02-tidal-water",Vector3(38,0,-17),Vector3(29,-1.0,-13))
	FileAccess.open(output.path_join("horizon-render-audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"failures":failures,"renderables":inventory},"\t"))
	print("HORIZON_RENDER: ",captures.size()," frames; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
