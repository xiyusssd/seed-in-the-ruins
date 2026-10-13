extends "res://tests/render_review.gd"
func run():
	Engine.max_fps=10
	Journey.save_path="user://isolated-reference-review.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	await chapter(0);await reference_tide()
	await shot("01-pump-overview",Vector3(14,14,21),Vector3(-2,3,-4))
	await chapter(1);await reference_spring()
	await shot("20-greenhouse-overview",Vector3(21,15,18),Vector3(0,6,1))
	await chapter(2);await reference_garden()
	await shot("30-regrowth-overview",Vector3(17,17,22),Vector3(0,5,-3))
	FileAccess.open(output.path_join("reference-render-audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"failures":failures,"renderables":inventory},"\t"))
	print("REFERENCE_RENDER: ",captures.size()," frames; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
