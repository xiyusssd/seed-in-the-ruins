extends "res://tests/render_review.gd"
# Reframe the foliage detail captures without repeating the whole scene suite.
# Geometry, materials and completed-state inventory remain the same.
func run():
	if DisplayServer.get_name()=="headless":get_tree().quit(1);return
	Engine.max_fps=10
	Journey.save_path="user://isolated-plant-details.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await chapter(0)
	await plant_details(garden.geometry.find_child("ShoreHouse0",true,false))
	var path=output.path_join("model-render-audit.json")
	var report=JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(report.renderer==RenderingServer.get_current_rendering_method())
	for capture in captures:
		var found=false
		for i in report.captures.size():
			if report.captures[i].name==capture.name:
				report.captures[i]=capture;found=true;break
		if not found:report.captures.append(capture)
	report.failures.append_array(failures)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PLANT_DETAIL_REVIEW: ",captures.size()," frames; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
