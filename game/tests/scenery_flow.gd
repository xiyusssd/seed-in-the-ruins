extends Node
var checks=0
var failures=[]
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func check_texture_asset(folder: String,item: Dictionary):
	var path="res://assets/"+folder+"/"+item.file
	if OS.has_feature("editor"):
		check(FileAccess.get_sha256(path)==item.sha256,"Authored texture checksum matches "+item.file)
	else:
		# Export replaces source PNGs with imported texture resources.
		var texture=load(path)
		check(texture is Texture2D and texture.get_width()==int(item["size"][0]) and texture.get_height()==int(item["size"][1]) and not texture.get_image().is_empty(),"Exported texture loads at full resolution: "+item.file)
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://scenery-suite.json";Journey.fresh()
	var garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	var sky= garden.environment.sky.sky_material
	check(sky is ShaderMaterial and sky.get_shader_parameter("panorama").resource_path=="res://assets/scenery/coastal_daylight.hdr","The graded sky and its lighting cubemap use the original natural-light HDR panorama")
	check(garden.environment.ambient_light_source==Environment.AMBIENT_SOURCE_SKY,"Shadowed surfaces receive the sky's light instead of a fixed sepia fill")
	check(garden.lighting.fixtures.size()==2,"Pump station has two actual practical lights with visible fixtures")
	var pump_light=garden.lighting.fixtures.filter(func(f):return f.task=="pump")[0]
	check(pump_light.light.light_energy==0,"Pump work light is unpowered before restoration")
	Puzzles.data.solved.append("pump");garden.lighting.refresh()
	check(pump_light.light.light_energy>0 and pump_light.emission.emission_energy_multiplier>0,"Repairing the pump powers both the real light and its emissive bulb")
	Puzzles.data.solved.erase("pump");garden.lighting.refresh()
	var far=garden.geometry.find_child("DistantOceanRing",true,false)
	var ocean_vertices=far.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(Array(ocean_vertices).all(func(p):return maxf(absf(p.x),absf(p.z))>=69.99),"Far ocean has an open center so it cannot intersect the near waves")
	check(garden.water_mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and far.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and garden.get_node("CoastalSun").shadow_enabled,"Moving ocean receives building shadows without generating self-shadow interference")
	var probe=garden.geometry.find_child("CoastalReflectionCapture",true,false)
	check(probe and (probe.reflection_mask & garden.water_mesh.layers)!=0 and (probe.cull_mask & garden.water_mesh.layers)==0 and (probe.cull_mask & far.layers)==0,"The sea receives real scene reflections without being captured recursively")
	check(probe.size.x>140 and probe.size.z>140 and probe.enable_shadows and probe.update_mode==ReflectionProbe.UPDATE_ONCE,"Coastal reflection volume spans the near ocean and captures static architecture with shadows")
	check((garden.camera.cull_mask & garden.water_mesh.layers)!=0,"Excluding water from the reflection camera preserves visibility in the gameplay camera")
	var harbours=garden.geometry.find_children("DistantFactory*","Node3D",true,false)
	check(harbours.size()==5 and harbours.all(func(n):return n.find_children("*","CollisionObject3D",true,false).is_empty() and n.has_meta("open_window_bays")),"Harbour shells remain real decoration with open bays and cannot intercept the route")
	for harbour in harbours:
		var bank=harbour.find_child("SubmergedHarbourRock",true,false)
		check(bank and outward_faces(bank.mesh),"Harbour rock surface winding faces outward from its normals")
		check(bank and bank.to_global(bank.mesh.get_aabb().position).y<garden.water_mesh.position.y-1.0 and bank.to_global(bank.mesh.get_aabb().end).y>garden.water_mesh.position.y,"Every offshore building rests on a rock shelf extending beneath the sea")
	var breakwater=garden.geometry.find_children("ErodedBreakwater*","MeshInstance3D",true,false)
	check(breakwater.all(func(n):return outward_faces(n.mesh)),"Eroded breakwater surfaces face outward rather than disappearing from above")
	check(breakwater.size()==14 and breakwater.all(func(n):return n.mesh.get_aabb().end.y*n.scale.y+n.position.y<0 and n.mesh.get_aabb().position.y*n.scale.y+n.position.y<-2.3),"Eroded breakwater rocks emerge below the quay and continue beneath the sea")
	var concrete=garden.s.weathered_material(Color("8e8977"))
	check(concrete is StandardMaterial3D and concrete.albedo_texture and concrete.normal_texture and concrete.roughness_texture,"Marine concrete receives all three PBR maps")
	check(concrete.albedo_texture.get_width()>=1024,"Runtime generated concrete retains its full source resolution")
	check(concrete.albedo_texture.get_image().has_mipmaps() and concrete.normal_texture.get_image().has_mipmaps(),"Marine concrete maps keep their 3D mip chains")
	check("generated_materials/concrete_albedo" in concrete.albedo_texture.resource_path,"Generated concrete is assigned to the actual game material")
	var plaster=garden.s.generated_surface("plaster",Color.WHITE,.4)
	check(plaster.normal_enabled and plaster.uv1_world_triplanar and plaster.roughness_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_RED,"Generated plaster uses world-scale native PBR sampling and scalar roughness")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated_materials/SOURCES.json"))
	for item in manifest.assets:
		check_texture_asset("generated_materials",item)
	for asset in ["wood_planks_dirt","brown_mud_02","rusty_metal_sheet"]:
		var surface=garden.s.surface_pbr(asset,Color.WHITE,.6)
		check(surface.albedo_texture and surface.normal_texture and surface.roughness_texture,"Dedicated "+asset+" surface has all three maps")
	check(garden.companion.get_node("Body").material_override is ShaderMaterial,"Robot enamel receives continuous weathering rather than a flat shell")
	var tree=garden.geometry.find_child("CoastalTree",true,false)
	check(tree and tree.find_children("*","MeshInstance3D",true,false).size()>0,"Optimized scan imports as real renderable tree geometry")
	var leaf_nodes=tree.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.has_meta("wind_materials"))
	check(not leaf_nodes.is_empty(),"Scanned leaf materials are connected to the shared wind instead of remaining static")
	var scan_mesh=tree.find_children("*","MeshInstance3D",true,false)[0].mesh
	var branch_arrays=scan_mesh.surface_get_arrays(0)
	check(branch_arrays[Mesh.ARRAY_TEX_UV]==branch_arrays[Mesh.ARRAY_TEX_UV2],"Branch shading and tangent generation use the same non-degenerate UVs")
	var tangent=branch_arrays[Mesh.ARRAY_TANGENT];var valid_tangent=true
	for i in range(0,tangent.size(),4):
		var basis=Vector3(tangent[i],tangent[i+1],tangent[i+2])
		if not basis.is_finite() or basis.length_squared()<.5:valid_tangent=false;break
	check(valid_tangent,"Every branch tangent has a valid direction; resource checks alone previously missed black rendering artifacts")
	var rocks=garden.geometry.find_children("ScannedRockShore","Node3D",true,false)
	check(rocks.size()==4 and rocks[0].find_children("*","MeshInstance3D",true,false).size()>0,"All four shores include the optimized rock scan")
	for roof in garden.geometry.find_children("RoofTiles","MultiMeshInstance3D",true,false):
		check(roof.material_override is ShaderMaterial and "terracotta" in roof.material_override.shader.resource_path,"Clay roof tiles do not reflect like metal")
	check(garden.geometry.find_children("CoastalNeighbourhood","Node3D",true,false)[0].find_children("*","CollisionObject3D",true,false).all(func(n):return n.collision_layer==0),"Downloaded environment meshes cannot steal a puzzle ray")
	for house in garden.geometry.find_children("ShoreHouse*","Node3D",true,false):
		check(house.get_meta("saved_static_draws",0)>30,"Residential repetition is batched rather than adding separate static draws")
		check(house.find_children("SideWindowWall*","Node3D",true,false).size()==2,"Both side walls have actual window openings")
		var bank=house.find_child("TidalSoilShelf",true,false)
		var bank_arrays=bank.mesh.surface_get_arrays(0)
		var top_normals_valid=true;var submerged_vertices=0
		for i in bank_arrays[Mesh.ARRAY_VERTEX].size():
			var point:Vector3=bank_arrays[Mesh.ARRAY_VERTEX][i]
			var normal:Vector3=bank_arrays[Mesh.ARRAY_NORMAL][i]
			if point.y>0 and (normal.y<.9 or not normal.is_finite()):top_normals_valid=false
			if bank.to_global(point).y<garden.water_mesh.position.y-.4:submerged_vertices+=1
		check(top_normals_valid,"Soil shelf top normals face the sky rather than exposing inverted geometry")
		check(submerged_vertices>64,"Soil shelf continues below the waterline instead of terminating above the waves")
	check(garden.geometry.find_child("ConstructionFabric",true,false).find_children("*","CollisionObject3D",true,false).is_empty(),"Construction wear cannot obstruct walking or interactable rays")
	var sprig=garden.s.plant(Vector3(0,20,0),1,0,garden.geometry)
	var leaves=sprig.get_children().filter(func(n):return n is MeshInstance3D and n.material_override is ShaderMaterial)
	check(not leaves.is_empty() and leaves.all(func(n):return n.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]!=null),"Botanical leaves carry UVs for their veins and colour variation")
	check(leaves.filter(func(n):return not n.material_override.get_shader_parameter("petal")).all(func(n):return "generated_materials/leaf_albedo" in n.material_override.get_shader_parameter("leaf_surface").resource_path),"Generated veins are actually bound to curved foliage; petals keep their colour")
	garden.ui.pause_menu();await get_tree().process_frame
	check(garden.ui.layer>20 and garden.ui.menu_card.name=="SalvagedFrame","Wasteland menu retains its material colours above grayscale and has a salvaged frame")
	check(garden.ui.content.get_children().filter(func(n):return n is Button).all(func(n):return n.get_theme_font("font")==garden.ui.TITLE_FONT),"Menu controls consistently use the industrial display typeface")
	var city_manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated_city/SOURCES.json"))
	for item in city_manifest.assets:
		check_texture_asset("generated_city",item)
	var garden_manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated_garden/SOURCES.json"))
	for item in garden_manifest.assets:
		check_texture_asset("generated_garden",item)
	for chapter_id in 3:
		if chapter_id>0:Journey.chapter=chapter_id;garden.build_chapter();await get_tree().physics_frame
		var city=garden.geometry.find_child("CinematicRuins",true,false)
		check(city.find_children("*","CollisionObject3D",true,false).all(func(n):return n.collision_layer==0),"Reference scenery cannot intercept puzzle interactions")
		check(city.find_children("*","MeshInstance3D",true,false).size()<200,"Repeated thin frames and rails share meshes and batches rather than thousands of draws")
		if chapter_id<2:
			var pier=city.find_child("JointedStonePier",true,false)
			check(pier and outward_faces(pier.mesh) and Array(pier.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]).all(func(p):return p.is_finite()),"Jointed stone pier has finite geometry and outward-facing blocks")
		check(city.get_meta("reconstruction_version","")=="1.10.0","Opening reconstruction is present in every chapter")
		var tower=city.find_child("OldTownBellTower",true,false)
		check(tower.has_meta("open_arch_count") and tower.get_meta("open_arch_count")==4 and tower.find_child("SuspendedBronzeBell",true,false)!=null,"Bell tower has four real arch openings and a suspended bell")
		var canopy=city.find_child("BroadleafCanopy",true,false)
		check(canopy and canopy.multimesh.instance_count>1100 and canopy.material_override in garden.wind_field.leaf_materials,"Native broadleaf layers have real geometry and active wind")
		var broad=canopy.multimesh.mesh.surface_get_arrays(0)
		check(broad[Mesh.ARRAY_TEX_UV].size()==broad[Mesh.ARRAY_VERTEX].size() and broad[Mesh.ARRAY_TANGENT].size()>0,"Curved broad leaves retain vein UVs and shading tangents")
		var mountain=city.find_child("CoastalMountainRange",true,false)
		check(mountain.mesh.get_aabb().size.y>20 and mountain.mesh.get_aabb().size.x>70,"Distant mountains have full three-dimensional relief")
		check(outward_faces(mountain.mesh),"Mountain triangle winding faces outward from its smooth normals")
		var terrain=mountain.mesh.surface_get_arrays(0)
		check(terrain[Mesh.ARRAY_VERTEX].size()>3000 and Array(terrain[Mesh.ARRAY_NORMAL]).all(func(n):return n.is_finite() and n.length_squared()>.9),"Mountain lighting has finite smooth normals on a detailed ridge mesh")
		check(mountain.material_override is ShaderMaterial and mountain.material_override.get_shader_parameter("rock_surface") and mountain.material_override.get_shader_parameter("soil_surface"),"Mountain rock faces and soil shelves bind original full-resolution textures")
		if chapter_id==0:
			var palace=city.find_child("TidalPumpPalazzo",true,false)
			check(palace.get_meta("open_arch_count")==10 and palace.get_meta("altar_clearance")>garden.nodes.altar.y+1.6,"Pump palace has an open arcade above the altar approach")
		if chapter_id==1:
			var indoor_probe=garden.geometry.find_child("GreenhouseReflectionCapture",true,false)
			check(indoor_probe and indoor_probe.box_projection and (indoor_probe.cull_mask & garden.water_mesh.layers)==0,"Interior reflection probe remains bounded and excludes recursive water capture")
			var greenhouse=city.find_child("ReconstructedGlasshouse",true,false)
			check(greenhouse.get_meta("entry_open") and greenhouse.get_meta("glazing_grid")==Vector2(1.5,1.45),"Greenhouse pane grid retains an open western entrance")
		if chapter_id==2:
			check(garden.geometry.find_children("ReclaimedRockIsland*","MeshInstance3D",true,false).all(func(n):return outward_faces(n.mesh)),"Planted island surfaces retain outward-facing rock geometry")
			check(garden.geometry.find_children("ReclaimedRockIsland*","MeshInstance3D",true,false).size()==7,"Seven planted islands have sloped rock banks")
			check(city.find_child("TerracedOrangery",true,false).get_meta("underwater_foundation")<garden.water_mesh.position.y,"Orangery bearing arches continue under the water")
		var quay=city.find_child("ContinuousStoneQuay",true,false)
		var arrays=quay.mesh.surface_get_arrays(0);var valid=true;var underwater=false
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var point:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
			if not point.is_finite() or not normal.is_finite() or normal.length_squared()<.5:valid=false
			if point.y<-1.5:underwater=true
		check(valid and underwater,"Continuous quay has valid normals and foundations below the sea")
		var families={}
		for node in city.find_children("*","GeometryInstance3D",true,false):
			var mat=node.material_override
			if mat is StandardMaterial3D and mat.albedo_texture and "generated_city/" in mat.albedo_texture.resource_path:
				var family="city_plaster" if "city_plaster" in mat.albedo_texture.resource_path else "quay_stone"
				families[family]=mat
		check(families.size()==2,"New wall and paving materials are bound in every actual chapter")
		check(families.quay_stone.clearcoat_enabled and families.quay_stone.roughness>=.8 and families.quay_stone.clearcoat<.3 and families.quay_stone.clearcoat_roughness<.3,"Porous stone retains its PBR maps beneath a restrained rain coating")
		for mat in families.values():
			check(mat.normal_enabled and mat.normal_texture and mat.roughness_texture and mat.albedo_texture.get_image().has_mipmaps(),"City PBR material has native normals, roughness and mipmaps")
		var reclaimed=city.find_child("ReclaimedFoliage",true,false)
		check(reclaimed.material_override in garden.wind_field.leaf_materials,"New fern and ivy meshes share the active wind")
		var stems=city.find_child("ClimbingStems",true,false);var stems_valid=true
		for i in stems.multimesh.instance_count:
			var basis=stems.multimesh.get_instance_transform(i).basis
			if absf(basis.x.normalized().dot(basis.y.normalized()))>.0001 or absf(basis.z.normalized().dot(basis.y.normalized()))>.0001:stems_valid=false;break
		check(stems_valid,"Instanced curved stems preserve rotation under nonuniform local scaling")
		var puddles=city.find_children("RainPuddle","MeshInstance3D",true,false)
		check(puddles.size()>0 and puddles.all(func(n):return n.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"Transparent rain puddles cannot shadow the paving underneath")
		var fern=city.find_child("FernLeaflets",true,false)
		check(fern.material_override in garden.wind_field.leaf_materials,"Detailed fern leaflets receive the same active wind as ivy")
		var leaf_arrays=fern.multimesh.mesh.surface_get_arrays(0);var leaflet_valid=true
		for i in leaf_arrays[Mesh.ARRAY_VERTEX].size():
			if not leaf_arrays[Mesh.ARRAY_VERTEX][i].is_finite() or not leaf_arrays[Mesh.ARRAY_NORMAL][i].is_finite() or not leaf_arrays[Mesh.ARRAY_TEX_UV][i].is_finite():leaflet_valid=false
		check(leaflet_valid and leaf_arrays[Mesh.ARRAY_TANGENT].size()>0,"Serrated fern leaflets have finite geometry, normals, UVs and tangents")
		var hill=city.find_child("OldTownHillside",true,false);var hill_vertices=hill.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var coastline_valid=true;var boundary_count=0
		for point in hill_vertices:
			if point.x<-75.99 or point.x>-22.01 or point.z<-68.99 or point.z>25.99:
				boundary_count+=1
				if point.y>garden.water_mesh.position.y-.8:coastline_valid=false
		check(coastline_valid and boundary_count>100,"Old town terrain rolls below the sea at all outer edges")
		if chapter_id==1:
			var pots=city.find_children("WeatheredTerracottaPot","MeshInstance3D",true,false)
			var pot_material=pots[0].material_override
			check(pot_material is StandardMaterial3D and pot_material.normal_enabled and pot_material.roughness_texture and not pot_material.uv1_triplanar and pot_material.albedo_texture.get_image().has_mipmaps(),"Weathered pots bind full-resolution cylindrical PBR maps with mipmaps")
	print("SCENERY_TESTS: ",checks," checks; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func outward_faces(mesh: Mesh) -> bool:
	for surface in mesh.get_surface_count():
		var data=mesh.surface_get_arrays(surface)
		var vertices=data[Mesh.ARRAY_VERTEX];var normals=data[Mesh.ARRAY_NORMAL];var indices=data[Mesh.ARRAY_INDEX]
		for j in range(0,indices.size(),3):
			var a=indices[j];var b=indices[j+1];var d=indices[j+2]
			var cross=(vertices[b]-vertices[a]).cross(vertices[d]-vertices[a])
			if cross.dot(normals[a]+normals[b]+normals[d])>.00001:return false
	return true
