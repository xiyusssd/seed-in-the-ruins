extends RefCounted
# Original, metre-scaled shore models. No decorative collision or puzzle targets.
var s: RefCounted
var root: Node3D
var bark: ShaderMaterial
var leaves: ShaderMaterial
var leaf_mesh: ArrayMesh
var grass_mesh: ArrayMesh
var grass_material: ShaderMaterial
var plaster_materials: Dictionary = {}
var scan_tree: PackedScene
var scan_rocks: PackedScene
var rng = RandomNumberGenerator.new()
var rod_meshes: Dictionary = {}
var roof_tile: ArrayMesh
var clay_material: ShaderMaterial
var pebble_mesh: ArrayMesh
const SHORE_RADIUS = 8.3
const SHORE_ASPECT = .72
const PLASTER = Color("b5aa90")
const TIMBER = Color("655e47")
const TILE = Color("855b45")
const IRON = Color("555e55")

func _init(shapes: RefCounted,parent: Node3D):
	s=shapes
	root=Node3D.new();root.name="CoastalNeighbourhood";parent.add_child(root)
	rng.seed=16009
	roof_tile=make_roof_tile()
	pebble_mesh=make_pebble()
	clay_material=ShaderMaterial.new();clay_material.shader=preload("res://shaders/terracotta.gdshader")
	bark=ShaderMaterial.new();bark.shader=preload("res://shaders/tree_bark.gdshader")
	leaves=ShaderMaterial.new();leaves.shader=preload("res://shaders/coastal_foliage.gdshader")
	leaves.set_shader_parameter("leaf_surface",preload("res://assets/generated_materials/leaf_albedo.png"))
	leaf_mesh=make_leaf()
	grass_mesh=make_grass()
	grass_material=leaves.duplicate();grass_material.set_shader_parameter("leaf_tint",Color("788660"))
	scan_tree=load("res://assets/scenery/tree_small_02/tree_small_02.gltf")
	scan_rocks=load("res://assets/scenery/coast_rocks_02/coast_rocks_02.gltf")

func box(p: Vector3,size: Vector3,color: Color,parent: Node3D) -> MeshInstance3D:
	var n=s.detail(p,size,color,parent)
	n.material_override=s.weathered_material(color,color==IRON)
	if color==TIMBER:n.material_override=s.surface_pbr("wood_planks_dirt",Color("b8ae99"),.7)
	if color==IRON:n.material_override=s.surface_pbr("rusty_metal_sheet",Color("b6b9a6"),.6,.12)
	if color.r>.55 and color.g>.5:
		if color not in plaster_materials:
			var mat=s.generated_surface("plaster",color.lightened(.2),.4)
			plaster_materials[color]=mat
		n.material_override=plaster_materials[color]
	n.set_meta("batchable_architecture",true)
	return n

func rod(a: Vector3,b: Vector3,radius: float,parent: Node3D,mat: Material,top=-1.0):
	var key=Vector3(radius,a.distance_to(b),radius if top<0 else top)
	if key not in rod_meshes:
		var cylinder=CylinderMesh.new();cylinder.bottom_radius=radius
		cylinder.top_radius=key.z;cylinder.height=key.y;cylinder.radial_segments=12
		rod_meshes[key]=cylinder
	var mesh=rod_meshes[key]
	var n=MeshInstance3D.new();n.mesh=mesh;n.material_override=mat;parent.add_child(n)
	n.position=(a+b)/2;n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	n.set_meta("batchable_architecture",true)
	return n

func build():
	# Leave the eastern horizon open: the sea has breathing room beyond the city.
	for i in 4:
		var p=[Vector3(-25,-.65,-6),Vector3(26,-.65,-13),Vector3(-28,-.65,17),Vector3(17,-.65,29)][i]
		var house=Node3D.new();house.name="ShoreHouse%d"%i;root.add_child(house)
		house.position=p;house.rotation.y=atan2(-p.x,-p.z)+PI
		house.set_meta("architecture","Open windows, tiled pitched roof, balconies and downpipes")
		island(house)
		residence(house,i)
		tree(Vector3(-5.6,.22,1.5),.72,house,i)
		meadow(Vector3(5.4,.10,-1.3),Vector2(2.0,4.0),house,240)
		meadow(Vector3(-5.4,.10,.9),Vector2(1.8,3.4),house,150)
		batch_architecture(house)

func shore_radius(angle: float) -> float:
	# The water shader uses this same continuous profile, including its phase.
	return SHORE_RADIUS+.38*sin(angle*3+.3)+.27*sin(angle*7-1.2)+.16*sin(angle*11+.8)

func shore_point(angle: float,fraction: float) -> Vector3:
	var radius=shore_radius(angle)*fraction
	var height=.09+.015*sin(angle*5)*smoothstep(.4,.82,fraction)
	if fraction>.82:height=lerpf(.09,-.72,(fraction-.82)/.18)
	if fraction>1:height=lerpf(-.72,-2.0,(fraction-1)/.16)
	return Vector3(cos(angle)*radius,height,sin(angle)*radius*SHORE_ASPECT)

func island(parent: Node3D):
	# A continuous soil shelf rolls into a submerged bank, instead of a vertical prism.
	var rocks=scan_rocks.instantiate();rocks.name="ScannedRockShore";parent.add_child(rocks)
	rocks.scale=Vector3(.32,.40,.24)
	rocks.position=Vector3(1.93,-.95,-2.17)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings=[0.0,.34,.66,.82,1.0,1.16]
	for ring_index in rings.size()-1:
		for i in 96:
			var a=i*TAU/96;var b=(i+1)*TAU/96
			var points=[shore_point(a,rings[ring_index]),shore_point(a,rings[ring_index+1]),shore_point(b,rings[ring_index+1]),shore_point(b,rings[ring_index])]
			for indices in [[0,1,2],[0,2,3]]:
				if (points[indices[1]]-points[indices[0]]).cross(points[indices[2]]-points[indices[0]]).length_squared()<.00000001:continue
				for index in indices:
					var point:Vector3=points[index]
					var wet=1-smoothstep(-.70,-.1,point.y)
					st.set_uv(Vector2(point.x,point.z)*.52)
					st.set_color(Color("d6c6a6").lerp(Color("737d68"),wet))
					st.add_vertex(point)
	st.index();st.generate_normals();st.generate_tangents()
	var n=MeshInstance3D.new();n.name="TidalSoilShelf";n.mesh=st.commit()
	n.material_override=s.surface_pbr("brown_mud_02",Color("e3dcc7"),.52)
	parent.add_child(n)
	shore_pebbles(parent)

func make_pebble() -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 5:
		for column in 10:
			var points=[]
			for pair in [Vector2(row,column),Vector2(row+1,column),Vector2(row+1,column+1),Vector2(row,column+1)]:
				var latitude=pair.x*PI/5;var longitude=pair.y*TAU/10
				var r=1+.08*sin(longitude*3+latitude*2)+.05*cos(longitude*5-latitude*3)
				points.append(Vector3(sin(latitude)*cos(longitude),cos(latitude)*.65,sin(latitude)*sin(longitude))*r)
			var normal=(points[0]+points[1]+points[2]+points[3]).normalized()
			s.add_face(st,points,normal)
	st.index();st.generate_normals()
	return st.commit()

func shore_pebbles(parent: Node3D):
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
	mm.mesh=pebble_mesh;mm.instance_count=130
	for i in mm.instance_count:
		var angle=rng.randf()*TAU;var fraction=rng.randf_range(.86,1.035)
		var point=shore_point(angle,fraction)
		var size_value=rng.randf_range(.12,.38)
		if i%9==0:size_value*=1.9
		point.y+=size_value*.22
		var basis=Basis.from_euler(Vector3(rng.randf_range(-.35,.35),rng.randf()*TAU,rng.randf_range(-.2,.2)))
		mm.set_instance_transform(i,Transform3D(basis.scaled(Vector3(size_value,size_value*.8,size_value*.85)),point))
		mm.set_instance_color(i,Color("b6b3a0").darkened(rng.randf_range(0,.25)))
	var n=MultiMeshInstance3D.new();n.name="TidalPebbles";n.multimesh=mm
	n.material_override=s.weathered_material(Color("9b9d8b"));parent.add_child(n)

func residence(parent: Node3D,variant: int):
	var plaster=[PLASTER,Color("9aa89c"),Color("c1b8a4"),Color("a8b2bb")][variant]
	# Rear and side walls enclose a shallow interior; front windows are real openings.
	box(Vector3(0,.22,0),Vector3(8.8,.34,6.6),plaster,parent)
	box(Vector3(0,2.97,0),Vector3(8.4,.18,6.2),plaster,parent)
	box(Vector3(0,3,3),Vector3(8.4,5.4,.24),plaster,parent)
	for side in [-1,1]:
		var wall=Node3D.new();wall.name="SideWindowWall%d"%side;parent.add_child(wall)
		wall.position.x=side*4.1;wall.rotation.y=-side*PI/2
		for level in 2:
			var base=.4+level*2.75
			box(Vector3(0,base+.33,0),Vector3(6.2,.66,.24),plaster,wall)
			box(Vector3(0,base+2.43,0),Vector3(6.2,.64,.24),plaster,wall)
			for pier in [-2.9,0,2.9]:box(Vector3(pier,base+1.38,0),Vector3(.55 if pier else 1.1,1.46,.24),plaster,wall)
			for bay in [-1,1]:window(Vector3(bay*1.5,base+1.38,-.12),wall,(level+variant+bay)%3==0)
	for level in 2:
		var base=.4+level*2.75
		box(Vector3(0,base+.33,-3),Vector3(8.4,.66,.28),plaster,parent)
		box(Vector3(0,base+2.43,-3),Vector3(8.4,.64,.28),plaster,parent)
		for pier in 4:
			box(Vector3(-4.05+pier*2.7,base+1.38,-3),Vector3(.5,1.46,.28),plaster,parent)
		for bay in 3:
			if level==0 and bay==1:
				for side in [-1,1]:box(Vector3(side*.84,base+1.38,-3),Vector3(.54,1.46,.28),plaster,parent)
				box(Vector3(0,2.42,-3),Vector3(1.2,.2,.28),plaster,parent)
			else:window(Vector3(-2.7+bay*2.7,base+1.38,-3.02),parent,(bay+level+variant)%4==0)
	# Separate doorway, steps, a shade canopy, and evidence of habitation.
	box(Vector3(0,1.35,-3.19),Vector3(1.12,1.95,.08),TIMBER,parent)
	for i in 5:box(Vector3(-.46+i*.23,1.35,-3.24),Vector3(.012,1.92,.02),IRON,parent)
	box(Vector3(.4,1.3,-3.3),Vector3(.035,.12,.04),Color("bda16c"),parent)
	for step in 3:box(Vector3(0,.15-step*.13,-3.6-step*.28),Vector3(1.6,.2,.5),plaster,parent)
	box(Vector3(0,2.56,-3.53),Vector3(1.8,.12,1),TILE,parent)
	# Cantilevered upper balcony and slender balusters.
	box(Vector3(0,3.13,-3.7),Vector3(5.4,.2,1.6),plaster,parent)
	var metal=s.surface_pbr("rusty_metal_sheet",Color("b6b9a6"),.6,.12)
	for i in 14:
		var x=-2.5+i*5.0/13
		rod(Vector3(x,3.25,-4.4),Vector3(x,4.15,-4.4),.025,parent,metal)
	rod(Vector3(-2.65,4.15,-4.4),Vector3(2.65,4.15,-4.4),.035,parent,metal)
	for side in [-1,1]:
		rod(Vector3(side*2.65,4.15,-4.4),Vector3(side*2.65,4.15,-3),.035,parent,metal)
		rod(Vector3(side*4.3,.3,-2.8),Vector3(side*4.3,5.8,-2.8),.065,parent,metal)
		rod(Vector3(side*4.3,.3,-2.8),Vector3(side*4.3,.3,-3.3),.065,parent,metal)
		box(Vector3(side*2.55,3.33,-3.8),Vector3(.48,.25,.6),TILE,parent)
		for j in 2:s.plant(Vector3(side*2.55,3.47,-3.94+j*.28),.32,1,parent)
	# Pitched roof, fascia and tile rows: instanced curved tiles avoid hundreds of nodes.
	for side in [-1,1]:
		var slope=box(Vector3(0,6.18,side*1.65),Vector3(9.1,.14,3.65),TILE,parent)
		slope.rotation.x=side*.31
		box(Vector3(0,5.67,side*3.42),Vector3(9.18,.18,.15),TIMBER,parent)
		rod(Vector3(-4.5,5.63,side*3.44),Vector3(4.5,5.63,side*3.44),.075,parent,metal)
	var tiles=MultiMesh.new();tiles.transform_format=MultiMesh.TRANSFORM_3D;tiles.use_colors=true
	tiles.mesh=roof_tile;tiles.instance_count=2*20*7
	for index in tiles.instance_count:
		var side=-1 if index<140 else 1
		var col=index%20;var row=(index%140)/20
		var z=side*(.2+row*.48)
		var p=Vector3(-4.27+col*.45,6.75-absf(z)*.32,z)
		var basis=Basis(Vector3.RIGHT,side*.31)
		tiles.set_instance_transform(index,Transform3D(basis,p))
		tiles.set_instance_color(index,Color.WHITE.darkened(rng.randf_range(0,.16)))
	var roof=MultiMeshInstance3D.new();roof.name="RoofTiles";roof.multimesh=tiles
	roof.material_override=clay_material;parent.add_child(roof)
	var ridge=MultiMesh.new();ridge.transform_format=MultiMesh.TRANSFORM_3D;ridge.mesh=roof_tile;ridge.instance_count=18
	for i in 18:ridge.set_instance_transform(i,Transform3D(Basis(Vector3.UP,PI/2),Vector3(-4.25+i*.5,6.86,0)))
	var ridge_node=MultiMeshInstance3D.new();ridge_node.name="RidgeCaps";ridge_node.multimesh=ridge;ridge_node.material_override=clay_material;parent.add_child(ridge_node)
	box(Vector3(2.6,6.7,1.1),Vector3(.6,1.3,.65),plaster,parent)
	box(Vector3(2.6,7.39,1.1),Vector3(.75,.16,.8),TIMBER,parent)
	# End gables fill the triangular space below the ridge.
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		s.add_face(st,[Vector3(side*4.1,5.6,-3.1),Vector3(side*4.1,6.62,0),Vector3(side*4.1,5.6,3.1)],Vector3(side,0,0))
	var gable=MeshInstance3D.new();gable.mesh=st.commit();gable.material_override=s.weathered_material(plaster);parent.add_child(gable)
	gable.set_meta("batchable_architecture",true)

func window(p: Vector3,parent: Node3D,shut: bool):
	var width=1.82;var height=1.43
	for side in [-1,1]:
		box(p+Vector3(side*(width/2+.09),0,.05),Vector3(.18,height+.1,.22),PLASTER,parent)
		box(p+Vector3(side*width/2,0,-.06),Vector3(.08,height+.1,.12),TIMBER,parent)
		box(p+Vector3(0,side*height/2,-.06),Vector3(width,.08,.12),TIMBER,parent)
	box(p+Vector3(0,0,-.06),Vector3(.05,height,.1),TIMBER,parent)
	box(p+Vector3(0,-.78,-.14),Vector3(2.05,.13,.36),PLASTER,parent)
	# Interior darkness is recessed, preserving parallax through the actual opening.
	box(p+Vector3(0,0,.6),Vector3(width,height,.04),Color("303b37"),parent)
	if shut:
		for i in 6:box(p+Vector3(-.76+i*.3,0,-.13),Vector3(.28,height,.05),IRON,parent)
	else:
		var glass=MeshInstance3D.new();var pane=BoxMesh.new();pane.size=Vector3(width*.42,height*.88,.015)
		glass.mesh=pane;glass.material_override=ShaderMaterial.new()
		glass.material_override.shader=preload("res://shaders/ruins_glass.gdshader")
		parent.add_child(glass);glass.position=p+Vector3(-.46,0,0)
		glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func make_leaf() -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var t0=float(i)/5;var t1=float(i+1)/5
		for side in [-1,1]:
			var points=[];var uvs=[]
			for t in [t0,t1]:
				points.append(Vector3(side*sin(PI*t)*.12,sin(PI*t)*.025,t*.42))
				points.append(Vector3(0,sin(PI*t)*.055,t*.42))
				uvs.append(Vector2(.5+side*.5,t));uvs.append(Vector2(.5,t))
			for index in [0,2,3,0,3,1]:
				st.set_normal(Vector3.UP);st.set_uv(uvs[index]);st.add_vertex(points[index])
	return st.commit()

func tree(p: Vector3,scale_value: float,parent: Node3D,variant=0):
	if scan_tree:
		var scanned=scan_tree.instantiate();scanned.name="CoastalTree";parent.add_child(scanned)
		scanned.position=p;scanned.scale=Vector3.ONE*scale_value
		scanned.rotation.y=variant*1.73
		for node in scanned.find_children("*","MeshInstance3D",true,false):
			var wind_materials: Array[ShaderMaterial]=[]
			for surface in node.mesh.get_surface_count():
				var original=node.mesh.surface_get_material(surface)
				if original is StandardMaterial3D:original.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				if original is StandardMaterial3D and "leaves" in original.resource_name:
					var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/scanned_leaves.gdshader")
					mat.set_shader_parameter("albedo_texture",original.albedo_texture)
					mat.set_shader_parameter("normal_texture",original.normal_texture)
					mat.set_shader_parameter("root_height",p.y)
					node.set_surface_override_material(surface,mat);wind_materials.append(mat)
			if not wind_materials.is_empty():node.set_meta("wind_materials",wind_materials)
		return scanned
	var group=Node3D.new();group.name="CoastalTree";parent.add_child(group);group.position=p
	group.scale=Vector3.ONE*scale_value
	rod(Vector3.ZERO,Vector3(.13,2.9,.08),.21,group,bark,.12)
	rod(Vector3(.13,2.8,.08),Vector3(-.28,5.0,.13),.12,group,bark,.035)
	var transforms: Array[Transform3D]=[]
	for branch in 9:
		var angle=branch*2.4+variant*.7
		var h=1.85+(branch%4)*.66
		var start=Vector3(.1,h,.05)
		var end=start+Vector3(cos(angle)*(1.45+(branch%2)*.45),.8,sin(angle)*(1.45+(branch%2)*.45))
		rod(start,end,.065,group,bark,.02)
		for twig in 3:
			var tip=end+Vector3(cos(angle+twig-1)*.58,.38+(twig%2)*.35,sin(angle+twig-1)*.58)
			rod(start.lerp(end,.72),tip,.025,group,bark,.007)
			for j in 15:
				var offset=Vector3(rng.randf_range(-.55,.55),rng.randf_range(-.18,.45),rng.randf_range(-.55,.55))
				var basis=Basis.from_euler(Vector3(rng.randf_range(-.6,.6),rng.randf()*TAU,rng.randf_range(-.45,.45)))
				transforms.append(Transform3D(basis.scaled(Vector3.ONE*rng.randf_range(.85,1.45)),tip+offset))
	foliage(transforms,group,"TreeLeaves")
	return group

func make_grass() -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 5:
		var height=[.34,.64,.41,.55,.46][blade]
		var basis=Basis(Vector3.UP,blade*1.71)
		for segment in 5:
			var points=[];var uvs=[]
			for step in [segment,segment+1]:
				var t=float(step)/5
				var width=(.012+sin(PI*t)*.02)*(1.0-t)
				for side in [-1,1]:
					points.append(basis*Vector3(side*width,height*t,.16*t*t)+Vector3((blade-2)*.026,0,0))
					uvs.append(Vector2(.5+side*.5,t))
			var normal=basis*Vector3(0,-.19*(segment+.5)/5/height,1).normalized()
			s.add_face(st,[points[0],points[1],points[3],points[2]],normal,[uvs[0],uvs[1],uvs[3],uvs[2]])
	return st.commit()

func foliage(transforms: Array[Transform3D],parent: Node3D,name_value: String,mesh_override: Mesh=null):
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
	mm.mesh=mesh_override if mesh_override else leaf_mesh;mm.instance_count=transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i,transforms[i])
		var tint=Color.WHITE.lerp(Color("bacfa0"),rng.randf()*.55)
		if mesh_override:tint=tint.lerp(Color("ddbd82"),pow(rng.randf(),2)*.8)
		mm.set_instance_color(i,tint.darkened(rng.randf()*.16))
	var n=MultiMeshInstance3D.new();n.name=name_value;n.multimesh=mm;n.material_override=leaves
	n.set_meta("wind_leaf_material",true);n.extra_cull_margin=.15;parent.add_child(n)
	return n

func meadow(p: Vector3,size_value: Vector2,parent: Node3D,count=80):
	var transforms: Array[Transform3D]=[]
	for i in count:
		# Elliptical patches with clustered density avoid a rectangular planting grid.
		var angle=rng.randf()*TAU;var radius=sqrt(rng.randf())
		var offset=Vector3(cos(angle)*radius*size_value.x/2,0,sin(angle)*radius*size_value.y/2)
		if i%3==0:offset*=.5
		var basis=Basis.from_euler(Vector3(rng.randf_range(-.12,.12),rng.randf()*TAU,rng.randf_range(-.12,.12)))
		transforms.append(Transform3D(basis.scaled(Vector3.ONE*rng.randf_range(.55,1.4)),p+offset))
	var grass=foliage(transforms,parent,"ShoreGrass",grass_mesh);grass.material_override=grass_material
	grass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 5:s.plant(p+Vector3(rng.randf_range(-size_value.x/2,size_value.x/2),0,rng.randf_range(-size_value.y/2,size_value.y/2)),rng.randf_range(.24,.42),i%2,parent)

func make_roof_tile() -> ArrayMesh:
	# Curved overlapping clay pans, rather than closed cylinders laid on the roof.
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var points=[];var uvs=[]
		for x in [-.215+i*.043,-.215+(i+1)*.043]:
			for z in [-.285,.285]:
				points.append(Vector3(x,.072*(1.-pow(x/.215,2))+(.012 if z<0 else 0),z))
				uvs.append(Vector2((x+.215)/.43,(z+.285)/.57))
		var x=-.215+(i+.5)*.043
		s.add_face(st,[points[0],points[1],points[3],points[2]],Vector3(.144*x/(.215*.215),1,0).normalized(),[uvs[0],uvs[1],uvs[3],uvs[2]])
	return st.commit()

func batch_architecture(house: Node3D):
	var groups={};var count=0
	for node in house.find_children("*","MeshInstance3D",true,false):
		if not node.has_meta("batchable_architecture"):continue
		var key=str(node.mesh.get_rid())+str(node.material_override.get_rid())
		if key not in groups:groups[key]=[]
		groups[key].append(node)
	for entries in groups.values():
		if entries.size()<2:continue
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=entries[0].mesh;mm.instance_count=entries.size()
		var inverse=house.global_transform.affine_inverse()
		for index in entries.size():mm.set_instance_transform(index,inverse*entries[index].global_transform)
		var batch=MultiMeshInstance3D.new();batch.name="ArchitectureBatch";batch.multimesh=mm;batch.material_override=entries[0].material_override;house.add_child(batch)
		for node in entries:node.get_parent().remove_child(node);node.queue_free()
		count+=entries.size()-1
	house.set_meta("saved_static_draws",count)
