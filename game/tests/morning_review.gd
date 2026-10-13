extends "res://tests/render_review.gd"
func run():
	Engine.max_fps=10
	Journey.save_path="user://isolated-morning-review.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	await chapter(0)
	await shot("reference-01-tidal-palazzo",Vector3(8,3.8,12),Vector3(-10,7,-12))
	await shot("render-01-coastal-reflections",Vector3(22,.8,16),Vector3(-14,8,-14))
	await horizon_shots()
	await shot("cg-04-wet-paving",Vector3(9,2.35,5.3),Vector3(9,1.38,3))
	var h=garden.geometry.find_child("ShoreHouse0",true,false)
	await shot("shore-02-tidal-water",h.to_global(Vector3(10,1.7,-2)),h.to_global(Vector3(7.9,-.65,0)))
	await chapter(1)
	await shot("render-02-greenhouse-morning",Vector3(-9.2,3.3,.5),Vector3(0,7,-1))
	await shot("detail-03-potting-bench",Vector3(-5,3.2,-.7),Vector3(-7,2.6,-2.7))
	await shot("20-greenhouse-overview",Vector3(21,15,18),Vector3(0,6,1))
	await chapter(2)
	await shot("30-regrowth-overview",Vector3(17,17,22),Vector3(0,5,-3))
	FileAccess.open(output.path_join("morning-render-audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"failures":failures,"renderables":inventory},"\t"))
	print("MORNING_RENDER: ",captures.size()," frames; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
