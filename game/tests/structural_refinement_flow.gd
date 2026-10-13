extends Node
var checks=0
var failures=[]
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://structural-refinement-tests.json";Journey.fresh()
	var garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	for chapter in 3:
		if chapter>0:Journey.chapter=chapter;garden.build_chapter();await get_tree().physics_frame
		var city=garden.geometry.find_child("CinematicRuins",true,false)
		var label=["PumpServiceMembers","RoofTrussMembers","OrangeryRoofMembers"][chapter]
		var frame=city.find_child(label,true,false)
		check(frame is MultiMeshInstance3D,"Structural members are actual batched geometry in chapter %d"%chapter)
		if not frame:continue
		check(frame.multimesh.instance_count>=[1,80,40][chapter],"Complete structural frame in chapter %d"%chapter)
		var arrays=frame.multimesh.mesh.surface_get_arrays(0)
		var vertex=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
		check(vertex.size()>50 and Array(vertex).all(func(p):return p.is_finite()),"Detailed finite structural section")
		check(Array(normals).all(func(n):return n.is_finite() and n.length_squared()>.99),"Section normals are finite unit vectors")
		check(arrays[Mesh.ARRAY_TEX_UV].size()==vertex.size() and arrays[Mesh.ARRAY_TANGENT].size()==vertex.size()*4,"All frame surfaces have PBR UVs and tangents")
		var cap_down=0;var cap_up=0;var recessed=false
		for i in vertex.size():
			if normals[i].y<-.99:cap_down+=1
			if normals[i].y>.99:cap_up+=1
			if absf(vertex[i].x)<.02 and absf(vertex[i].z)>.04:recessed=true
		check(cap_down>0 and cap_up>0 and recessed,"I-section has recessed web and both end caps")
		check(outward_faces(frame.multimesh.mesh),"Frame faces wind outward from their normals")
		for label_value in ["SteelConnectionPlates","SteelFixingBolts","DressedCopingStones"]:
			var batch=city.find_child(label_value,true,false)
			check(batch is MultiMeshInstance3D and batch.multimesh.instance_count>0,"Actual repeated "+label_value)
		check(city.find_children("*","CollisionObject3D",true,false).is_empty(),"Detailed frames cannot steal puzzle rays or block walking")
		check(city.find_children("*","MeshInstance3D",true,false).size()<200,"Additional detail retains the existing static draw budget")
		if chapter==1:
			var drain=city.find_child("GreenhouseDownpipes",true,false)
			check(drain and drain.multimesh.instance_count==2,"Both side gutters drain down to the masonry")
			var entry=garden.geometry.find_child("ReconstructedGlasshouse",true,false)
			check(entry.get_meta("entry_open"),"Western greenhouse entrance remains open")
		if chapter==2:
			check(city.find_child("DressedCopingStones",true,false).multimesh.instance_count>48,"All three flower beds receive jointed rims and end closures")
	garden.queue_free();await get_tree().process_frame
	print("STRUCTURAL_REFINEMENT_FLOW: ",checks," checks; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func outward_faces(mesh: Mesh) -> bool:
	var arrays=mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX]
	for j in range(0,indices.size(),3):
		var a=indices[j];var b=indices[j+1];var d=indices[j+2]
		if (vertices[b]-vertices[a]).cross(vertices[d]-vertices[a]).dot(normals[a])>.000001:return false
	return true
