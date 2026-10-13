extends "res://tests/render_review.gd"
# Short actual-raster review before freezing the complete release.
func run():
	Engine.max_fps=10;Journey.save_path="user://refinement-preview.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	await chapter(0)
	await shot("reference-01-tidal-palazzo",Vector3(8,3.8,12),Vector3(-10,7,-12))
	await shot("03-pipe-controls",Vector3(-3,4.6,4.35),Vector3(-3,3.9,6))
	await chapter(1)
	await shot("21-greenhouse-glass",Vector3(-5,10,-9),Vector3(1,9,0))
	await shot("model-01-roof-truss",Vector3(6.8,10.2,5.3),Vector3(2,12.4,1.8))
	await shot("render-05-nursery-canopy",Vector3(6.9,2.8,5.5),Vector3(9.2,3,2))
	await shot("reference-04-greenhouse-interior",Vector3(6.3,3.25,7),Vector3(0,5,-.3))
	await chapter(2)
	await shot("model-02-orangery-bracing",Vector3(10,10.8,7),Vector3(6,12,-2))
	await shot("31-planter-flora",Vector3(-3.5,8,3.5),Vector3(-5,6.8,0))
	await shot("reference-06-orangery",Vector3(11,7.2,7),Vector3(0,7.4,-5))
	FileAccess.open(output.path_join("refinement-preview.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"failures":failures},"\t"))
	print("REFINEMENT_PREVIEW: ",captures.size()," frames; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
