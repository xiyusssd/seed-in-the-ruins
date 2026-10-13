extends SceneTree
func _initialize():run.call_deferred()
func run():
	var args=OS.get_cmdline_user_args()
	if args.size()!=1:push_error("Expected models directory");quit(1);return
	var failures=[];var report={"models":[],"failures":failures}
	for chapter in 3:
		var path=args[0].path_join("chapter-%d.tscn"%chapter)
		var packed=load(path)
		if not packed is PackedScene:failures.append("Cannot load "+path);continue
		var scene=packed.instantiate();root.add_child(scene)
		var geometry=scene.find_children("*","GeometryInstance3D",true,false)
		if scene.get_meta("reconstruction_version","")!="1.10.0" or geometry.size()<100:failures.append("Incomplete reconstructed model")
		var invalid=0;var meshes={};var instances=0
		for node in geometry:
			var mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D else null
			if not mesh:invalid+=1;continue
			instances+=node.multimesh.instance_count if node is MultiMeshInstance3D else 1
			if mesh.get_instance_id() in meshes:continue
			meshes[mesh.get_instance_id()]=true
			for surface in mesh.get_surface_count():
				var material=node.material_override
				if not material and node is MeshInstance3D:material=node.get_surface_override_material(surface)
				if not material:material=mesh.surface_get_material(surface)
				if not material:invalid+=1
				var arrays=mesh.surface_get_arrays(surface)
				if arrays[Mesh.ARRAY_NORMAL]==null:invalid+=1
				for p in arrays[Mesh.ARRAY_VERTEX]:
					if not p.is_finite():invalid+=1
		if invalid>0:failures.append("Invalid model geometry")
		report.models.append({"chapter":chapter,"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size(),"geometry_nodes":geometry.size(),"unique_meshes":meshes.size(),"instances":instances,"finite_geometry":invalid==0})
		scene.free();geometry.clear();packed=null
		await process_frame
	await process_frame
	await process_frame
	FileAccess.open(args[0].path_join("model-verification.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MODEL_SCENE_LOAD: 3 scenes; failures=",failures)
	quit(0 if failures.is_empty() else 1)
