extends RefCounted
# Real, original 3D scenery guided by the generated tide / greenhouse images.
# Geometry here is decoration: the existing collision and puzzle routes stay authoritative.
var garden: Node3D
var s: RefCounted
var root: Node3D
var botany: RefCounted
var rng=RandomNumberGenerator.new()
var wall_material: Material
var paving_material: Material
var wood_material: Material
var metal_material: Material
var soil_material: Material
var dark_material: Material
var house_tints: Array[Material]=[]
var reconstruction: RefCounted
var pot_material: StandardMaterial3D
var stem_material: Material
var fern_mesh: ArrayMesh
var fern_material: ShaderMaterial
var fern_transforms: Array[Transform3D]=[]
var timber_transforms: Array[Transform3D]=[]
var pot_mesh: ArrayMesh
var box_meshes: Dictionary={}
var ivy_material: ShaderMaterial
var puddle_material: ShaderMaterial
var foliage_transforms: Array[Transform3D]=[]
var stem_transforms: Array[Transform3D]=[]
var rubble_transforms: Array[Transform3D]=[]
var roof_transforms: Array[Transform3D]=[]

func _init(world: Node3D):
	garden=world;s=garden.s
	root=Node3D.new();root.name="CinematicRuins";garden.geometry.add_child(root)
	root.set_meta("render_profile","1.13.0")
	rng.seed=190105+Journey.chapter
	botany=load("res://scripts/coastal_scenery.gd").new(s,root)
	wall_material=city_material("city_plaster",.4,.4)
	paving_material=city_material("quay_stone",.333,.48)
	wood_material=s.surface_pbr("wood_planks_dirt",Color("9a8c70"),.65)
	metal_material=s.surface_pbr("rusty_metal_sheet",Color("af9d82"),.5,.15)
	soil_material=s.surface_pbr("brown_mud_02",Color("a6ad88"),.65)
	dark_material=s.material(Color("222d29"))
	for tint in [Color("e2dfd1"),Color("d4d8cf"),Color("dfcbb8"),Color("c3c9ba")]:
		var mat=wall_material.duplicate();mat.albedo_color=tint;house_tints.append(mat)
	pot_mesh=make_pot()
	pot_material=StandardMaterial3D.new()
	pot_material.albedo_texture=load("res://assets/generated_garden/terracotta_albedo.png")
	pot_material.normal_enabled=true
	pot_material.normal_texture=load("res://assets/generated_garden/terracotta_normal.png")
	pot_material.normal_scale=.3
	pot_material.roughness=1.4
	pot_material.roughness_texture=load("res://assets/generated_garden/terracotta_roughness.png")
	pot_material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	pot_material.uv1_scale=Vector3(2,1,1)
	pot_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	stem_material=s.material(Color("39412b"))
	fern_mesh=make_fern_leaflet()
	fern_material=botany.leaves.duplicate()
	fern_material.set_shader_parameter("leaf_tint",Color("607a3c"))
	ivy_material=botany.leaves.duplicate()
	ivy_material.set_shader_parameter("leaf_tint",Color("526844"))
	puddle_material=ShaderMaterial.new();puddle_material.shader=preload("res://shaders/quay_puddle.gdshader")

func city_material(family: String,scale_value: float,normal_strength: float) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new()
	mat.albedo_texture=load("res://assets/generated_city/"+family+"_albedo.png")
	mat.normal_enabled=true;mat.normal_texture=load("res://assets/generated_city/"+family+"_normal.png")
	mat.normal_scale=normal_strength
	mat.roughness_texture=load("res://assets/generated_city/"+family+"_roughness.png")
	mat.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness=1.0;mat.vertex_color_use_as_albedo=true
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar=true;mat.uv1_world_triplanar=true;mat.uv1_scale=Vector3.ONE*scale_value
	if family=="quay_stone":
		mat.albedo_color=Color("a1afb4")
		mat.roughness=.88
		mat.clearcoat_enabled=true
		mat.clearcoat=.18
		mat.clearcoat_roughness=.24
	return mat

func box(p: Vector3,size_value: Vector3,mat: Material,parent: Node3D=null):
	if size_value not in box_meshes:box_meshes[size_value]=s.bevel_box(size_value)
	var n=MeshInstance3D.new();n.mesh=box_meshes[size_value];n.material_override=mat
	n.position=p;(parent if parent else root).add_child(n);n.set_meta("cg_batch",true)
	return n

func rod(a: Vector3,b: Vector3,radius: float):
	var direction=b-a
	if direction.length_squared()<.000001:return
	stem_transforms.append(Transform3D(Basis(Quaternion(Vector3.UP,direction.normalized())).scaled_local(Vector3(radius,direction.length(),radius)),(a+b)/2))

func batch(label: String,mesh: Mesh,mat: Material,transforms: Array[Transform3D],shadow=true):
	if transforms.is_empty():return
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=transforms.size()
	for i in transforms.size():mm.set_instance_transform(i,transforms[i])
	var n=MultiMeshInstance3D.new();n.name=label;n.multimesh=mm;n.material_override=mat;root.add_child(n)
	if not shadow:n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

func build():
	reconstruction=load("res://scripts/reference_reconstruction.gd").new(self)
	quay()
	deck_surfaces()
	waterfront()
	town()
	town_ground_details()
	chapter_details()
	reconstruction.build()
	load("res://scripts/structural_refinement.gd").new(self).build()
	load("res://scripts/realism_details.gd").new(self).build()
	var ivy=batch("ReclaimedFoliage",botany.leaf_mesh,ivy_material,foliage_transforms)
	if ivy:ivy.set_meta("wind_leaf_material",true);ivy.extra_cull_margin=.2
	var stem=CylinderMesh.new();stem.height=1;stem.bottom_radius=1;stem.top_radius=.72;stem.radial_segments=7
	batch("ClimbingStems",stem,stem_material,stem_transforms,false)
	batch("QuayTimber",stem,wood_material,timber_transforms)
	var fern_batch=batch("FernLeaflets",fern_mesh,fern_material,fern_transforms)
	fern_batch.set_meta("wind_leaf_material",true);fern_batch.extra_cull_margin=.2
	batch("BrokenMasonry",botany.pebble_mesh,paving_material,rubble_transforms)
	batch("TownRoofTiles",botany.roof_tile,botany.clay_material,roof_transforms)
	batch_static()
	root.set_meta("scene_reference","cinematics/tide.png; cinematics/spring.png; cinematics/yaya.png")
	root.set_meta("town_buildings",19)
	reconstruction=null # Release builder references after meshes and batches are committed.

func quay_height(x: float,z: float) -> float:
	if Journey.chapter==2:return 1.55 if z>6 else 3.9
	if Journey.chapter==0 and x>-1 and z<5:return .42
	return 1.35

func quay():
	var slabs=0
	var cells={}
	var paving=SurfaceTool.new();paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in range(-5,6):
		for iz in range(-4,6):
			var x=ix*2.5;var z=iz*2.5-1
			# Open service channels remain visibly below the rotary bridges.
			if Journey.chapter==0 and x>-5 and x<0 and z<7:continue
			if Journey.chapter==2 and absf(x)<2 and z<7:continue
			if Journey.chapter==1 and x>-4 and x<0 and absf(z)<2:continue
			var top=quay_height(x,z)
			cells[Vector2i(ix,iz)]=top
			var points=[Vector3(x-1.25,top,z-1.25),Vector3(x+1.25,top,z-1.25),Vector3(x+1.25,top,z+1.25),Vector3(x-1.25,top,z+1.25)]
			s.add_face(paving,points,Vector3.UP,[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
			slabs+=1
			if abs(ix)==5 or iz in [-4,5]:
				for j in 2:
					var p=Vector3(x+rng.randf_range(-1,1),top+.04,z+rng.randf_range(-1,1))
					fern(p,rng.randf_range(.85,1.35),rng.randf()*TAU)
					for k in 4:rubble(p+Vector3(rng.randf_range(-.8,.8),-.06,rng.randf_range(-.8,.8)),rng.randf_range(.08,.32))
	for cell in cells:
		var top:float=cells[cell];var x=cell.x*2.5;var z=cell.y*2.5-1
		for side in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
			var bottom:float=cells.get(cell+side,-1.8)
			if bottom>=top-.01:continue
			var normal=Vector3(side.x,0,side.y)
			var along=normal.cross(Vector3.UP)*1.25
			var center=Vector3(x,0,z)+normal*1.25
			var points=[center+along+Vector3(0,bottom,0),center-along+Vector3(0,bottom,0),center-along+Vector3(0,top,0),center+along+Vector3(0,top,0)]
			s.add_face(paving,points,normal,[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	paving.index();paving.generate_tangents()
	var quay_mesh=MeshInstance3D.new();quay_mesh.name="ContinuousStoneQuay";quay_mesh.mesh=paving.commit()
	quay_mesh.material_override=paving_material;root.add_child(quay_mesh)
	for p in [Vector2(9,3),Vector2(-9,8),Vector2(10,-8),Vector2(7,7),Vector2(10,0),Vector2(-11,1),Vector2(-8,-6),Vector2(4,-10),Vector2(12,9),Vector2(-6,10),Vector2(7,-5)]:
		puddle(Vector3(p.x,quay_height(p.x,p.y)+.015,p.y),Vector2(1.2,2.3),p.x*.31)
	root.set_meta("quay_slabs",slabs)
	# Low waterfront coping and mooring iron establish a real, inhabited quay.
	for x in [-13.9,13.9]:
		for i in 6:
			var z=-10+i*4.2;var top=quay_height(x,z)
			box(Vector3(x,top+.17,z),Vector3(.48,.34,3.9),wall_material)
			var bollard=box(Vector3(x-.4*signf(x),top+.31,z),Vector3(.22,.55,.22),metal_material)
			bollard.rotation.y=.25
			box(Vector3(x-.4*signf(x),top+.53,z),Vector3(.43,.11,.23),metal_material)

func deck_surfaces():
	for id in ["arrival","landing","altar","sun","west","east","north","summit"]:
		if id not in garden.nodes:continue
		var p:Vector3=garden.nodes[id]
		var size_value=Vector2(3.15,3.15)
		if id=="landing":size_value=Vector2(2.6,2.0 if Journey.chapter==2 else 2.6)
		if id=="altar":size_value=Vector2(3.95,3.95)
		if id=="sun" or id=="summit":size_value=Vector2(3.75,3.75)
		var surface=PlaneMesh.new();surface.size=size_value
		var n=MeshInstance3D.new();n.name="QuayPaving_"+id;n.mesh=surface;n.material_override=paving_material
		n.position=p+Vector3(0,.022,0);n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(n)
		puddle(p+Vector3(-size_value.x*.23,.030,size_value.y*.2),Vector2(.65,1.0),float(id.length()))

func puddle(p: Vector3,size_value: Vector2,phase: float):
	var surface=PlaneMesh.new();surface.size=size_value
	var n=MeshInstance3D.new();n.name="RainPuddle";n.mesh=surface
	n.material_override=puddle_material;n.position=p;n.rotation.y=phase;n.layers=2;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(n)

func rubble(p: Vector3,size_value: float):
	var basis=Basis.from_euler(Vector3(rng.randf_range(-.5,.5),rng.randf()*TAU,rng.randf_range(-.4,.4)))
	rubble_transforms.append(Transform3D(basis.scaled_local(Vector3(size_value,size_value*.7,size_value*.85)),p))

func make_fern_leaflet() -> ArrayMesh:
	# Serrated narrow leaflet with a raised midrib; UVs drive both veins and wind.
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 10:
		var a=j/10.0;var b=(j+1)/10.0
		var wa=maxf(.003,sin(a*PI)*(.083 if j%2==0 else .060))
		var wb=maxf(.003,sin(b*PI)*(.083 if j%2==1 else .060))
		for side in [-1,1]:
			var points=[Vector3(0,sin(a*PI)*.035,a),Vector3(side*wa,0,a),Vector3(side*wb,0,b),Vector3(0,sin(b*PI)*.035,b)]
			s.add_face(st,points,Vector3.UP,[Vector2(.5,a),Vector2(0 if side<0 else 1,a),Vector2(0 if side<0 else 1,b),Vector2(.5,b)])
	st.index();st.generate_normals();st.generate_tangents()
	return st.commit()

func fern(p: Vector3,scale_value: float,phase: float):
	for frond in 9:
		var angle=phase+frond*TAU/9
		var out=Vector3(cos(angle),0,sin(angle))
		var side=Vector3(-sin(angle),0,cos(angle))
		var length_value=scale_value*(.75+.17*sin(frond*2.7))
		var previous=p
		for j in 12:
			var t=(j+1)/12.0
			var center=p+out*length_value*t+Vector3(0,length_value*(sin(t*PI*.85)*.80+.14*t),0)
			rod(previous,center,.004*scale_value);previous=center
			for sign_value in [-1,1]:
				var direction=(side*sign_value+out*.50+Vector3(0,.06,0)).normalized()
				var basis=Basis(Quaternion(Vector3.BACK,direction))
				var leaf_scale=scale_value*(.29*(1-t)+.06)
				fern_transforms.append(Transform3D(basis.scaled_local(Vector3(leaf_scale,leaf_scale,leaf_scale)),center))

func vine(p: Vector3,height: float,wall_normal: Vector3):
	var along=wall_normal.cross(Vector3.UP).normalized()
	var previous=p
	for i in int(height/.22):
		var h=i*.22
		var point=p+Vector3(0,h,0)+along*(sin(h*2.1)*.12+sin(h*.8)*.18)
		rod(previous,point+Vector3(0,.02,0),.012);previous=point
		for side in [-1,1]:
			var branch_length=rng.randf_range(.24,.55) if i%3==0 else .18
			var branch_previous=point
			for j in (4 if i%3==0 else 1):
				var tip=point+along*side*branch_length*(j+1)/4.0+wall_normal*.07+Vector3(0,.10+sin(j)*.12,0)
				rod(branch_previous,tip,.004);branch_previous=tip
				var direction=(along*side*.6+Vector3(0,.8,.04)).normalized()
				var basis=Basis(Quaternion(Vector3.BACK,direction))
				foliage_transforms.append(Transform3D(basis.scaled_local(Vector3(.65,.65,.65)),tip))

func town_height(x: float,z: float) -> float:
	var height_value=maxf(-1.55,(absf(x+28)*.36+maxf(0,-z-6)*.10)-2.2)
	var col=clampi(roundi((-x-36)/11),0,2);var row=clampi(roundi((z+53)/12),0,5)
	var center=Vector2(-36-col*11,-53+row*12)
	var pad_height=maxf(-1.55,(absf(center.x+28)*.36+maxf(0,-center.y-6)*.10)-2.2)
	var edge=maxf(absf(x-center.x)/4.4,absf(z-center.y)/3.9)
	var land=lerpf(pad_height,height_value,smoothstep(1,1.4,edge))
	var coast_distance=minf(-25+sin(z*.17)*2-x,minf(x+76,minf(z+69,23+sin(x*.12)*3-z)))
	return lerpf(-3.4,land,smoothstep(0,6,coast_distance))

func town():
	# A stepped hillside town occupies the western shore; the eastern sea remains open.
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in 27:
		for iz in 38:
			var points=[]
			for pair in [Vector2(ix,iz),Vector2(ix+1,iz),Vector2(ix+1,iz+1),Vector2(ix,iz+1)]:
				var x=-76+pair.x*2;var z=-69+pair.y*2.5
				points.append(Vector3(x,town_height(x,z),z))
			var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
			s.add_face(st,points,normal,[Vector2(points[0].x,points[0].z),Vector2(points[1].x,points[1].z),Vector2(points[2].x,points[2].z),Vector2(points[3].x,points[3].z)])
	st.index();st.generate_normals();st.generate_tangents()
	var hill=MeshInstance3D.new();hill.name="OldTownHillside";hill.mesh=st.commit();hill.material_override=soil_material;root.add_child(hill)
	for row in 6:
		for col in 3:
			var x=-36-col*11;var z=-53+row*12
			var p=Vector3(x,town_height(x,z),z)
			var house=Node3D.new();house.name="HillsideHouse_%d_%d"%[row,col];root.add_child(house)
			house.position=p;house.rotation.y=-PI/2+.07*sin(row*1.8+col)
			house_model(house,2+(row+col)%2,row+col)
			for j in 6:
				var step_p=p+Vector3(4.0+j*.38,-.08-j*.15,2.5)
				box(step_p,Vector3(.44,.24,2.15),paving_material)
			if (row+col)%2==0:fern(p+Vector3(4.4,0,-2.8),1.1,float(row))
			if (row+col)%3==0:botany.tree(p+Vector3(-4,0,2),.8,root,row)
	var tower=Node3D.new();tower.name="OldTownBellTower";root.add_child(tower)
	tower.position=Vector3(-56,town_height(-56,-22),-22)
	tower.rotation.y=-PI/2
	for i in 75:
		var z=rng.randf_range(-63,20);var x=-27+sin(z*.17)*2-rng.randf_range(1.5,5.8)
		var y=town_height(x,z)
		if y>-1.7:rubble(Vector3(x,y+.06,z),rng.randf_range(.3,.85))
	for row in 6:
		var z=-59+row*12
		for col in 3:
			var x=-36-col*11;var y=town_height(x,z)
			box(Vector3(x,y-.26,z),Vector3(9.2,.52,.48),paving_material)
			for post in 4:box(Vector3(x-4+post*2.65,y+.45,z),Vector3(.17,.9,.17),wall_material)

func house_model(parent: Node3D,floors: int,variant: int):
	var width=6.2+(variant%3)*.7;var depth=5.2+(variant%2)*.75;var height=floors*2.65
	parent.set_meta("house_dimensions",Vector2(width,depth))
	box(Vector3(0,-.30,0),Vector3(width+.6,.6,depth+.5),paving_material,parent)
	for floor_id in floors:
		box(Vector3(0,floor_id*2.65+.16,0),Vector3(width,.22,depth),paving_material,parent)
	facade(parent,Vector3(0,0,-depth/2),0,width,3,floors,variant,true)
	facade(parent,Vector3(0,0,depth/2),PI,width,3,floors,variant+1,false)
	facade(parent,Vector3(-width/2,0,0),PI/2,depth,2,floors,variant+2,false)
	facade(parent,Vector3(width/2,0,0),-PI/2,depth,2,floors,variant+3,false)
	var columns=ceili((width+.7)/.45);var rows=ceili((depth/2+.45)/.48)
	var holes=0
	for side in [-1,1]:
		for row in rows:
			for col in columns:
				var z=side*(.15+row*.48)
				var p=Vector3(-(columns-1)*.225+col*.45,height+1.07-absf(z)*.33,z)
				# The damaged patch omits BOTH ceramic and its wooden deck.
				if variant%3==0 and side==1 and row in [2,3] and col in [3,4,5]:holes+=1;continue
				var roof=box(p+Vector3(0,-.10,0),Vector3(.45,.09,.51),wood_material,parent)
				roof.rotation.x=side*.32
				roof_transforms.append(root.global_transform.affine_inverse()*parent.global_transform*Transform3D(Basis(Vector3.RIGHT,side*.32),p))
		for rafter in 5:
			var n=box(Vector3(-width/2+rafter*width/4,height+.45,side*depth/4),Vector3(.12,.15,depth/2+.75),wood_material,parent)
			n.rotation.x=side*.32
	parent.set_meta("missing_roof_cells",holes)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		s.add_face(st,[Vector3(side*width/2,height,-depth/2),Vector3(side*width/2,height+1.08,0),Vector3(side*width/2,height,depth/2)],Vector3(side,0,0))
	var gable=MeshInstance3D.new();gable.mesh=st.commit();gable.material_override=wall_material;parent.add_child(gable)
	box(Vector3(width*.30,height+1.2,.75),Vector3(.5,1.2,.55),wall_material,parent)
	box(Vector3(width*.30,height+1.82,.75),Vector3(.65,.14,.7),metal_material,parent)
	box(Vector3(width/2+.15,height/2,-depth/2),Vector3(.09,height,.09),metal_material,parent)

func facade(parent: Node3D,position_value: Vector3,yaw: float,width: float,bays: int,floors: int,variant: int,balconies: bool):
	var face=Node3D.new();face.name="OpenWindowFacade";parent.add_child(face)
	face.position=position_value;face.rotation.y=yaw
	var material_value=house_tints[variant%house_tints.size()]
	var spacing=(width-.3)/bays
	var opening=minf(1.28,spacing-.65)
	for floor_id in floors:
		var base=floor_id*2.65
		box(Vector3(0,base+.35,0),Vector3(width,.70,.34),material_value,face)
		box(Vector3(0,base+2.40,0),Vector3(width,.48,.34),material_value,face)
		for pier in bays+1:box(Vector3(-width/2+.15+pier*spacing,base+1.46,0),Vector3(spacing-opening,1.55,.34),material_value,face)
		for bay in bays:
			var x=-width/2+.15+(bay+.5)*spacing
			reconstruction.arch(face,Vector3(x,base+.70,-.08),opening,1.55,.20,.085,material_value)
			box(Vector3(x,base+1.43,.43),Vector3(opening,1.40,.035),dark_material,face)
			for side in [-1,1]:
				box(Vector3(x+side*opening/2,base+1.43,-.04),Vector3(.085,1.46,.12),wood_material,face)
				box(Vector3(x,base+1.43+side*.69,-.04),Vector3(opening,.085,.12),wood_material,face)
			box(Vector3(x,base+1.43,-.04),Vector3(.065,1.4,.10),wood_material,face)
			box(Vector3(x,base+.68,-.14),Vector3(opening+.22,.13,.35),material_value,face)
			if (bay+floor_id+variant)%5==0:
				for slat in 6:box(Vector3(x-opening*.42+slat*opening*.168,base+1.43,-.14),Vector3(opening*.16,1.35,.055),wood_material,face)
			if (bay+floor_id+variant)%4==1:
				for side in [-1,1]:
					var shutter=Node3D.new();face.add_child(shutter)
					shutter.position=Vector3(x+side*opening/2,base+1.43,-.16)
					shutter.rotation.y=side*(.55+variant*.07)
					box(Vector3(side*opening*.23,0,0),Vector3(opening*.46,1.35,.065),wood_material,shutter)
			if balconies and floor_id>0 and bay==1:
				box(Vector3(x,base+.2,-.55),Vector3(opening+.5,.16,1.05),material_value,face)
				for post in 7:box(Vector3(x-opening*.55+post*opening*.183,base+.72,-1.02),Vector3(.034,.95,.034),metal_material,face)
				box(Vector3(x,base+1.2,-1.02),Vector3(opening+.5,.042,.042),metal_material,face)

func make_pot() -> ArrayMesh:
	# Revolved hollow ceramic profile, including a real thick rim and inner wall.
	var profile=[Vector2(.24,0),Vector2(.25,.07),Vector2(.32,.46),Vector2(.36,.49),Vector2(.36,.56),Vector2(.30,.56),Vector2(.29,.48),Vector2(.22,.08)]
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in profile.size()-1:
		for i in 32:
			var points=[];var uvs=[]
			for pair in [Vector2(i,band),Vector2(i+1,band),Vector2(i+1,band+1),Vector2(i,band+1)]:
				var a=pair.x*TAU/32;var section=profile[int(pair.y)]
				points.append(Vector3(cos(a)*section.x,section.y,sin(a)*section.x))
				uvs.append(Vector2(pair.x/32,section.y/.56))
			var outward=Vector3(cos((i+.5)*TAU/32),0,sin((i+.5)*TAU/32))
			if band>=5:outward=-outward
			if band==4:outward=Vector3.UP
			s.add_face(st,points,outward,uvs)
	st.index();st.generate_normals();st.generate_tangents()
	return st.commit()

func pot(p: Vector3,size_value: float):
	var n=MeshInstance3D.new();n.name="WeatheredTerracottaPot";n.mesh=pot_mesh;n.material_override=pot_material
	n.position=p;n.scale=Vector3.ONE*size_value;root.add_child(n)
	var soil=CylinderMesh.new();soil.height=.07;soil.top_radius=.27;soil.bottom_radius=.26;soil.radial_segments=24
	var fill=MeshInstance3D.new();fill.mesh=soil;fill.material_override=soil_material;fill.position=p+Vector3(0,.43*size_value,0)
	fill.scale=Vector3.ONE*size_value;root.add_child(fill)
	fern(p+Vector3(0,.48*size_value,0),size_value*.62,rng.randf()*TAU)

func chapter_details():
	match Journey.chapter:
		0:
			for x in [-6.5,.5]:vine(Vector3(x,2,-10.34),6.5,Vector3.FORWARD)
			for p in [Vector3(-10,1.35,-6),Vector3(-11,1.35,6),Vector3(11,.42,-5)]:crate(p)
		1:
			for x in [-9.9,-6.9,8.1,10.9]:
				for z in [-3.78,7.38]:vine(Vector3(x,2,z),9.0,Vector3.FORWARD if z<0 else Vector3.BACK)
			for i in 90:
				var x=rng.randf_range(-10.3,10.8);var z=rng.randf_range(-9.5,10.1)
				if z>-1 and z<7 and x>-4.3 and x<3.3:continue
				if z<-4.8 and z>-7.5:continue
				fern(Vector3(x,1.35,z),rng.randf_range(1.0,1.7),rng.randf()*TAU)
			for x in [-9.9,-6.9,8.1,10.9]:
				for offset in [-.25,.26]:vine(Vector3(x+offset,2,7.40),rng.randf_range(5,9),Vector3.BACK)
			for x in [-8,-4,0,4,8]:
				fern(Vector3(x,1.68,-6),.95,rng.randf()*TAU)
			workbench(Vector3(-7,1.35,-2.7))
			workbench(Vector3(8,1.35,6.5))
			for i in 5:pot(Vector3(-2.7+i*2.4,1.35,-2.7),.8+(i%3)*.13)
			for i in 5:pot(Vector3(-8+i*2.8,1.35,6.5),1.1)
			for p in [Vector3(-11,1.35,5),Vector3(10,1.35,6)]:crate(p)
		2:
			for p in [Vector3(-10,3.9,1),Vector3(10,3.9,1),Vector3(-8,3.9,-9),Vector3(9,3.9,-9)]:
				for i in 4:fern(p+Vector3(rng.randf_range(-1.5,1.5),0,rng.randf_range(-1.5,1.5)),1.3,rng.randf()*TAU)
			for x in [-1.55,1.55]:vine(Vector3(x,3.9,-10.3),5,Vector3.FORWARD)
			for p in [Vector3(-10,3.9,6),Vector3(10,3.9,-7)]:crate(p)

func crate(p: Vector3):
	for side in [-1,1]:
		for j in 5:
			box(p+Vector3(side*.57,.08+j*.14,0),Vector3(.09,.12,1.10),wood_material)
			box(p+Vector3(0,.08+j*.14,side*.55),Vector3(1.1,.12,.09),wood_material)
	box(p+Vector3(0,.01,0),Vector3(1.1,.10,1.1),wood_material)
	for x in [-.53,.53]:
		for z in [-.53,.53]:box(p+Vector3(x,.38,z),Vector3(.10,.8,.10),metal_material)
	for i in 12:rubble(p+Vector3(rng.randf_range(-1.4,1.4),.06,rng.randf_range(-1.4,1.4)),rng.randf_range(.08,.20))

func greenhouse_glazing():
	var glazing=ShaderMaterial.new();glazing.shader=preload("res://shaders/ruins_glass.gdshader")
	for x in [-8.5,-5.5,-2.5,.5,3.5,6.5,9.5]:
		for z in [-3.82,7.42]:
			if int(x*2)%3==0:continue
			for y in [4.9,9.3]:
				var pane=box(Vector3(x,y,z),Vector3(2.75,3.85,.025),glazing)
				pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1,1]:
		for x in [-8.5,-5.5,-2.5,.5,3.5,6.5,9.5]:
			if int(x*2)%4==0:continue
			# Broken portions leave real gaps above the mechanism, with no glass overlay across it.
			var pane=box(Vector3(x,12.23,1.8+side*3.1),Vector3(2.8,.025,4.4),glazing)
			pane.rotation.x=side*.31;pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func batch_static():
	var groups={}
	for n in root.find_children("*","MeshInstance3D",true,false):
		if not n.has_meta("cg_batch"):continue
		var key=str(n.mesh.get_rid())+str(n.material_override.get_rid())+str(n.cast_shadow)
		if key not in groups:groups[key]=[]
		groups[key].append(n)
	var saved=0
	for entries in groups.values():
		if entries.size()<2:continue
		var transforms: Array[Transform3D]=[]
		for n in entries:transforms.append(root.global_transform.affine_inverse()*n.global_transform)
		var n=batch("RuinedArchitecture",entries[0].mesh,entries[0].material_override,transforms,entries[0].cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		saved+=entries.size()-1
		for old in entries:old.get_parent().remove_child(old);old.queue_free()
	root.set_meta("batched_architectural_instances",saved)

func timber_rod(a: Vector3,b: Vector3,radius: float):
	var d=b-a
	timber_transforms.append(Transform3D(Basis(Quaternion(Vector3.UP,d.normalized())).scaled_local(Vector3(radius,d.length(),radius)),(a+b)/2))

func waterfront():
	# Joined weathered boards rest on piles that extend below the water.
	for sign_value in [-1,1]:
		var top=quay_height(sign_value*13,8)
		for row in 9:
			var plank=box(Vector3(sign_value*16.15,top-.03,5.9+row*.28),Vector3(5.0,.17,.25),wood_material)
			plank.rotation.z=.005*sin(row*2)
		for x in [sign_value*14.2,sign_value*17.9]:
			for z in [6.1,8.0]:
				timber_rod(Vector3(x,-2.3,z),Vector3(x,top+.25,z),.14)
				box(Vector3(x,top-.32,7.0),Vector3(.16,.22,2.55),wood_material)
		# A metal access ladder follows the water face, with nine individual rungs.
		for x in [sign_value*18.7,sign_value*18.05]:
			box(Vector3(x,top-1.0,6.2),Vector3(.065,3.0,.065),metal_material)
		for i in 9:box(Vector3(sign_value*18.37,top-.14-i*.32,6.2),Vector3(.7,.055,.075),metal_material)
		crate(Vector3(sign_value*15.8,top+.05,7.8))
		# Bent remnants of an older pier have a visible submerged foundation.
		for i in 5:
			var a=Vector3(sign_value*(15.4+i*.72),-2.4,-8+i*.42)
			var b=a+Vector3(.16*sin(i),2.55+(i%3)*.22,.10*cos(i))
			timber_rod(a,b,.13)
		box(Vector3(sign_value*16.8,-.10,-7.2),Vector3(3.9,.18,.20),wood_material)
	root.set_meta("waterfront_piles",18)
	# Irregular damp moss patches grow along the coping and greenhouse margins.
	for i in 14:
		var x=(-1 if i%2==0 else 1)*rng.randf_range(10.8,12.3);var z=rng.randf_range(-9,10)
		moss_patch(Vector3(x,quay_height(x,z)+.009,z),Vector2(.7,1.2),i*.4)

func moss_patch(p: Vector3,size_value: Vector2,phase: float):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var points=[Vector3.ZERO];var uvs=[Vector2(.5,.5)]
		for a in [i*TAU/24,(i+1)*TAU/24]:
			var r=.75+.12*sin(a*5+phase)+.1*sin(a*9-phase)
			points.append(Vector3(cos(a)*r*size_value.x,0,sin(a)*r*size_value.y))
			uvs.append(Vector2(cos(a)*r*.5+.5,sin(a)*r*.5+.5))
		s.add_face(st,points,Vector3.UP,uvs)
	st.index();st.generate_tangents()
	var n=MeshInstance3D.new();n.name="DampMossPatch";n.mesh=st.commit()
	n.position=p;n.material_override=s.surface_pbr("brown_mud_02",Color("424f29"),.85)
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(n)

func workbench(p: Vector3):
	# The table top is a real support at 1.05 m; pots sit exactly on its top face.
	for i in 7:box(p+Vector3(0,1.0,-.57+i*.19),Vector3(3.5,.10,.17),wood_material)
	for x in [-1.42,1.42]:
		for z in [-.47,.47]:box(p+Vector3(x,.47,z),Vector3(.13,.94,.13),wood_material)
		box(p+Vector3(x,.28,0),Vector3(.10,.12,1.25),wood_material)
	box(p+Vector3(0,.38,0),Vector3(3.0,.14,.14),wood_material)
	for i in 4:
		var pot_position=p+Vector3(-1.23+i*.78,1.05,-.12 if i%2==0 else .15)
		pot(pot_position,.78+(i%2)*.15)
	# Shallow soil tray and a discarded metal trowel create readable near props.
	box(p+Vector3(0,1.11,.43),Vector3(.85,.06,.27),soil_material)
	for x in [-.45,.45]:box(p+Vector3(x,1.15,.43),Vector3(.065,.13,.33),wood_material)
	var blade=box(p+Vector3(.74,1.12,.48),Vector3(.18,.045,.32),metal_material);blade.rotation.y=.7
	var handle=box(p+Vector3(.94,1.13,.69),Vector3(.07,.07,.31),wood_material);handle.rotation.y=.7
	moss_patch(p+Vector3(.5,.008,.86),Vector2(1.8,.62),p.x)
	root.set_meta("potting_benches",root.get_meta("potting_benches",0)+1)

func town_ground_details():
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 6:
		for j in 34:
			var x=-66+j;var z=-59+row*12
			var points=[];var uv=[]
			for pair in [Vector2(x,z-.6),Vector2(x+1,z-.6),Vector2(x+1,z+.6),Vector2(x,z+.6)]:
				points.append(Vector3(pair.x,town_height(pair.x,pair.y)+.03,pair.y));uv.append(pair)
			var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
			s.add_face(st,points,normal,uv)
	st.index();st.generate_normals();st.generate_tangents()
	var paths=MeshInstance3D.new();paths.name="OldTownPavedLanes";paths.mesh=st.commit();paths.material_override=paving_material
	root.add_child(paths)
	var grass_transforms: Array[Transform3D]=[]
	for i in 4200:
		var x=rng.randf_range(-69,-30);var z=rng.randf_range(-64,18)
		var col=clampi(roundi((-x-36)/11),0,2);var row=clampi(roundi((z+53)/12),0,5)
		if absf(x-(-36-col*11))<4.6 and absf(z-(-53+row*12))<4.1:continue
		if absf(z-(-59+roundf((z+59)/12)*12))<.7:continue
		var y=town_height(x,z)
		if y<-1:continue
		var scale_value=rng.randf_range(.7,1.6)
		grass_transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled_local(Vector3(.9,scale_value,.9)),Vector3(x,y+.012,z)))
	var grass=batch("HillsideWildGrass",botany.grass_mesh,botany.grass_material,grass_transforms)
	grass.set_meta("wind_leaf_material",true);grass.extra_cull_margin=.2
