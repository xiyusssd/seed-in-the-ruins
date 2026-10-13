extends RefCounted
# Opening-image reconstruction: actual open arches, glazing, terrain and plants.
# All dimensions are metres. The puzzle route remains the walkable surface.
var c: RefCounted
var s: RefCounted
var root: Node3D
var unit_box: ArrayMesh
var arch_cache: Dictionary={}
var broad_leaves: Array[Transform3D]=[]
var petals: Array[Transform3D]=[]
var iron: Array[Transform3D]=[]
var rng=RandomNumberGenerator.new()
var leaf_mesh: ArrayMesh
var leaf_mat: ShaderMaterial
var terrain_noise=FastNoiseLite.new()
var glass_mat: ShaderMaterial
var masonry: Material

func _init(city: RefCounted):
	c=city;s=c.s;root=c.root;rng.seed=110012+Journey.chapter
	unit_box=s.bevel_box(Vector3.ONE)
	masonry=c.wall_material.duplicate();masonry.albedo_color=Color("c5c4b4")
	leaf_mesh=make_broad_leaf()
	leaf_mat=c.botany.leaves.duplicate();leaf_mat.set_shader_parameter("leaf_tint",Color("63824b"))
	glass_mat=ShaderMaterial.new();glass_mat.shader=preload("res://shaders/ruins_glass.gdshader")

func block(p: Vector3,size_value: Vector3,mat: Material,parent: Node3D=null,yaw=0.0):
	var n=MeshInstance3D.new();n.mesh=unit_box;n.material_override=mat
	n.position=p;n.rotation.y=yaw;n.scale=size_value
	(parent if parent else root).add_child(n);n.set_meta("cg_batch",true)
	return n

func beam(a: Vector3,b: Vector3,radius=.045):
	var d=b-a
	iron.append(Transform3D(Basis(Quaternion(Vector3.UP,d.normalized())).scaled_local(Vector3(radius,d.length(),radius)),(a+b)/2))

func model(label: String,p: Vector3,yaw=0.0) -> Node3D:
	var n=Node3D.new();n.name=label;root.add_child(n);n.position=p;n.rotation.y=yaw
	return n

func arch_mesh(width: float,height: float,depth: float,thickness: float) -> ArrayMesh:
	var key=Vector4(width,height,depth,thickness)
	if key in arch_cache:return arch_cache[key]
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius=width/2;var spring=height-radius
	# Two jambs plus the curved extrados form a genuinely empty opening.
	var inner=[Vector2(-radius,0),Vector2(-radius,spring)]
	var outer=[Vector2(-radius-thickness,0),Vector2(-radius-thickness,spring)]
	for i in range(1,25):
		var a=PI-i*PI/24
		inner.append(Vector2(cos(a)*radius,spring+sin(a)*radius))
		outer.append(Vector2(cos(a)*(radius+thickness),spring+sin(a)*(radius+thickness)))
	inner.append(Vector2(radius,0));outer.append(Vector2(radius+thickness,0))
	for j in inner.size()-1:
		for side in [-1,1]:
			var pts=[Vector3(inner[j].x,inner[j].y,side*depth/2),Vector3(outer[j].x,outer[j].y,side*depth/2),Vector3(outer[j+1].x,outer[j+1].y,side*depth/2),Vector3(inner[j+1].x,inner[j+1].y,side*depth/2)]
			if side<0:pts.reverse()
			s.add_face(st,pts,Vector3(0,0,side),[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
		for strip in [inner,outer]:
			var a:Vector2=strip[j];var b:Vector2=strip[j+1]
			var norm=Vector3(b.y-a.y,a.x-b.x,0).normalized()*(1 if strip==inner else -1)
			s.add_face(st,[Vector3(a.x,a.y,-depth/2),Vector3(a.x,a.y,depth/2),Vector3(b.x,b.y,depth/2),Vector3(b.x,b.y,-depth/2)],norm,[Vector2(0,0),Vector2(depth,0),Vector2(depth,a.distance_to(b)),Vector2(0,a.distance_to(b))])
	# Masonry above the extrados fills the spandrel; the intrados remains open.
	for j in range(1,25):
		for side in [-1,1]:
			var a:Vector2=outer[j];var b:Vector2=outer[j+1]
			s.add_face(st,[Vector3(a.x,a.y,side*depth/2),Vector3(b.x,b.y,side*depth/2),Vector3(b.x,height+thickness,side*depth/2),Vector3(a.x,height+thickness,side*depth/2)],Vector3(0,0,side),[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	st.index();st.generate_normals();st.generate_tangents()
	var mesh=st.commit();arch_cache[key]=mesh;return mesh

func arch(parent: Node3D,p: Vector3,width: float,height: float,depth: float,thickness: float,mat: Material,yaw=0.0):
	var n=MeshInstance3D.new();n.mesh=arch_mesh(width,height,depth,thickness);n.material_override=mat
	n.position=p;n.rotation.y=yaw;parent.add_child(n);n.set_meta("cg_batch",true)
	parent.set_meta("open_arch_count",parent.get_meta("open_arch_count",0)+1)
	return n

func build():
	load("res://scripts/harbor_horizon.gd").new(s,root).build()
	mountain_shore()
	bell_tower()
	match Journey.chapter:
		0:pump_palazzo()
		1:glasshouse()
		2:orangery()
	seed_crate()
	var leaves=c.batch("BroadleafCanopy",leaf_mesh,leaf_mat,broad_leaves)
	if leaves:leaves.set_meta("wind_leaf_material",true);leaves.extra_cull_margin=.25
	var flower_mat=s.material(Color("ebe5ce"));flower_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	c.batch("SmallWhiteFlowers",leaf_mesh,flower_mat,petals)
	var steel=CylinderMesh.new();steel.height=1;steel.bottom_radius=1;steel.top_radius=1;steel.radial_segments=8
	c.batch("ReconstructedIronwork",steel,c.metal_material,iron)
	root.set_meta("reconstruction_version","1.10.0")
	root.set_meta("broadleaf_instances",broad_leaves.size())
	root.set_meta("opening_arch_meshes",arch_cache.keys().filter(func(key):return key is Vector4).size())

func pump_palazzo():
	var palace=model("TidalPumpPalazzo",Vector3(-3,0,-8))
	# The middle opening clears the raised altar and its approach stair.
	for x in [-4.6,0,4.6]:
		arch(palace,Vector3(x,1.35,2.6),3.55,6.7,.72,.48,masonry)
		block(Vector3(x,8.9,2.6),Vector3(4.6,1.65,.72),masonry,palace)
		arch(palace,Vector3(x,9.65,2.6),1.32,2.3,.40,.19,c.wall_material)
		block(Vector3(x,10.5,2.9),Vector3(1.15,1.65,.035),c.dark_material,palace)
		for dx in [-.40,0,.40]:block(Vector3(x+dx,10.55,3.03),Vector3(.045,1.6,.06),c.metal_material,palace)
		for y in [10.05,10.7,11.25]:block(Vector3(x,y,3.03),Vector3(1.22,.045,.06),c.metal_material,palace)
		for dx in [-1.5,1.5]:
			block(Vector3(x+dx,10.6,2.5),Vector3(1.7,2.05,.72),masonry,palace)
		block(Vector3(x,12.0,2.6),Vector3(4.6,.47,.72),masonry,palace)
	for side in [-1,1]:
		for z in [-1.8,1.4]:arch(palace,Vector3(side*6.9,1.35,z),2.5,6.7,.62,.44,masonry,PI/2)
		block(Vector3(side*6.9,9.9,-.2),Vector3(.62,4.1,6.4),masonry,palace)
		block(Vector3(side*6.9,3.9,2.75),Vector3(.66,5.1,.82),c.paving_material,palace)
	block(Vector3(0,7.9,-.2),Vector3(14.6,.30,6.1),c.paving_material,palace)
	block(Vector3(0,12.34,-.2),Vector3(14.7,.23,6.7),masonry,palace)
	for z in [-3.55,3.15]:
		block(Vector3(0,12.55,z),Vector3(15,.30,.44),c.wall_material,palace)
		for x in range(-7,8):block(Vector3(x,13.0,z),Vector3(.048,.65,.048),c.metal_material,palace)
		block(Vector3(0,13.32,z),Vector3(14.8,.055,.055),c.metal_material,palace)
	for x in [-9.7,3.7]:
		c.vine(Vector3(x,1.4,-5.0),10.8,Vector3.BACK)
		curtain(Vector3(x,11.9,-5.04),4.9,2.2)
	# A waterside loggia ties the building to the town rather than loose pillars.
	var loggia=model("TidalArcadedLoggia",Vector3(-17,0,-7))
	for j in 4:arch(loggia,Vector3(0,1.35,-5.2+j*3.8),2.9,4.1,.55,.35,masonry,PI/2)
	block(Vector3(0,5.82,.5),Vector3(4.0,.30,16),c.paving_material,loggia)
	block(Vector3(-1.75,6.35,.5),Vector3(.45,.90,16),masonry,loggia)
	for j in 7:c.fern(Vector3(-17.8,5.99,-13+j*2.0),1.1,j*.7)
	palace.set_meta("altar_clearance",7.75)

func glasshouse():
	var house=model("ReconstructedGlasshouse",Vector3.ZERO)
	# Narrow mullions and individually missing panes, including both end walls.
	for z in [-3.84,7.44]:
		block(Vector3(.5,2.12,z),Vector3(21.0,1.54,.38),masonry,house)
		for i in 15:
			var x=-10+i*1.5
			beam(Vector3(x,2.9,z),Vector3(x,11.6,z),.037)
		for row in 6:
			var y=2.9+row*1.45
			beam(Vector3(-10,y,z),Vector3(11,y,z),.033)
			if row==5:continue
			for col in 14:
				if (col+row*3+(1 if z<0 else 0))%9 in [0,1]:continue
				pane(Vector3(-9.25+col*1.5,y+.725,z),Vector2(1.41,1.36),0,(col+row)%5==0)
	for x in [-10.07,11.07]:
		for col in 8:
			var z=-3.8+col*1.6
			beam(Vector3(x,1.35,z),Vector3(x,11.6,z),.043)
			for row in 6:
				var y=2.9+row*1.45
				if col<7:beam(Vector3(x,y,z),Vector3(x,y,z+1.6),.035)
				if col==7 or row==5:continue
				# Leave the entrance on the western wall visibly open.
				if x<0 and col in [4,5] and row<2:continue
				if (col+row)%7!=0:pane(Vector3(x,y+.725,z+.8),Vector2(1.51,1.36),PI/2,(col+row)%5==0)
	for side in [-1,1]:
		for row in 4:
			var z=1.8+side*(.73+row*1.38);var y=13.4-absf(z-1.8)*.3214
			beam(Vector3(-10,y,z),Vector3(11,y,z),.03)
			for col in 14:
				if (row*3+col)%8 in [0,1] or (col in [9,10,11] and row<2):continue
				var n=pane(Vector3(-9.25+col*1.5,y,z),Vector2(1.41,1.36),0,(col+row)%6==0)
				n.rotation.x=-PI/2+side*.311
	for x in [-9.8,-6.8,8.2,10.8]:
		curtain(Vector3(x,11.55,7.24),5.4,1.75)
		curtain(Vector3(x,11.55,-3.60),4.1,1.3)
	for x in [-7,-4,0,4,8]:
		curtain(Vector3(x,12.5,2),2.3,.9)
	# Grown plants, climbing poles and blossoms give the benches vertical layers.
	for pot in root.find_children("*","MeshInstance3D",true,false):
		if pot.material_override!=c.pot_material:continue
		plant(pot.position+Vector3(0,.50*pot.scale.y,0),1.0 if pot.position.y>2 else 1.6,int(absf(pot.position.x)*3)%3)
	for x in [-8,-4,0,4,8]:
		for j in 4:plant(Vector3(x-1+j*.66,1.72,-6),1.15+(j%2)*.3,j%3)
	for side in [-1,1]:
		for j in 7:
			var p=Vector3(side*(7.5+j%2),1.4,-2.5+j*1.35)
			plant(p,1.15,1);c.fern(p,.9,j*.5)
	# The opening CG has layered foliage rather than isolated pots: two low
	# nursery rows, hanging baskets and vines on the industrial supports.
	for x in [8.8,10.15]:
		for j in 8:
			var p=Vector3(x,1.35,-2.3+j*1.1)
			c.pot(p,.78+(j%3)*.10);plant(p+Vector3(0,.49,0),1.7+(j%3)*.23,j%3)
	for z in [-1.8,3.9,6.1]:
		var y=13.4-absf(z-1.8)*.3214
		beam(Vector3(-10,y,z),Vector3(11,y,z),.027)
	for x in [-8.9,9.8]:
		for z in [-1.8,3.9,6.1]:
			var p=Vector3(x,9.65,z)
			var suspension=Vector3(x,13.4-absf(z-1.8)*.3214,z)
			for side in [-1,1]:beam(p+Vector3(side*.23,.35,0),suspension,.015)
			var basket=MeshInstance3D.new();basket.name="HangingNurseryBasket";basket.mesh=c.pot_mesh;basket.material_override=c.wood_material
			basket.position=p;basket.scale=Vector3.ONE*.72;root.add_child(basket)
			plant(p+Vector3(0,.35,0),.9,1);curtain(p+Vector3(0,.28,.12),2.0,.72)
	for side in [-1,1]:
		curtain(Vector3(6+side*1.63,6.45,.18),4.5,.60)
	# Narrow steel service ribs break up the large existing cylindrical pier.
	for i in 24:
		var a=i*TAU/24
		beam(Vector3(6+cos(a)*1.73,.1,sin(a)*1.73),Vector3(6+cos(a)*1.73,6.60,sin(a)*1.73),.018)
	for node in c.garden.geometry.find_children("*","MeshInstance3D",true,false):
		if node.position.is_equal_approx(Vector3(6,3.25,0)) and node.mesh is CylinderMesh:
			node.material_override=c.wall_material
	house.set_meta("nursery_pots",16);house.set_meta("hanging_baskets",6)
	var daylight=ShaderMaterial.new();daylight.shader=preload("res://shaders/restoration_sunbeam.gdshader")
	daylight.set_shader_parameter("strength",.045)
	for i in 4:
		var a=Vector3(9.1+i*.4,12.2,4.6);var b=Vector3(7.7+i*.4,1.6,2.0)
		var mesh=QuadMesh.new();mesh.size=Vector2(.65,a.distance_to(b))
		var ray=MeshInstance3D.new();ray.name="NurseryMorningRay";ray.mesh=mesh;ray.material_override=daylight
		ray.position=(a+b)/2;ray.quaternion=Quaternion(Vector3.UP,(b-a).normalized());root.add_child(ray)
		ray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Steel trusses visibly carry the existing upper gallery and sun platform.
	for z in [-1.25,1.25]:
		beam(Vector3(3.7,6.63,z),Vector3(8.3,6.63,z),.07)
		beam(Vector3(3.7,5.55,z),Vector3(8.3,5.55,z),.05)
		for i in 4:
			beam(Vector3(3.7+i*1.15,5.55,z),Vector3(4.85+i*1.15,6.63,z),.046)
	for x in [4.15,7.85]:
		arch(house,Vector3(x,1.35,0),2.5,4.8,.50,.34,masonry,PI/2)
	house.set_meta("glazing_grid",Vector2(1.5,1.45))
	house.set_meta("entry_open",true)

func pane(p: Vector3,size_value: Vector2,yaw: float,broken: bool):
	# A clipped polygon has a real missing corner, not an opaque crack decal.
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts=[Vector3(-.5,-.5,0),Vector3(.5,-.5,0),Vector3(.5,.5,0),Vector3(-.5,.5,0)]
	if broken:pts=[Vector3(-.5,-.5,0),Vector3(.5,-.5,0),Vector3(.5,.18,0),Vector3(.15,.5,0),Vector3(-.5,.5,0)]
	for i in range(1,pts.size()-1):
		s.add_face(st,[pts[0],pts[i],pts[i+1]],Vector3.BACK,[Vector2(pts[0].x+.5,pts[0].y+.5),Vector2(pts[i].x+.5,pts[i].y+.5),Vector2(pts[i+1].x+.5,pts[i+1].y+.5)])
	st.index();st.generate_tangents()
	# Reuse the two pane meshes so hundreds of panels remain two batches.
	var key="broken_pane" if broken else "whole_pane"
	if key not in arch_cache:arch_cache[key]=st.commit()
	var n=MeshInstance3D.new();n.mesh=arch_cache[key];n.material_override=glass_mat
	n.position=p;n.rotation.y=yaw;n.scale=Vector3(size_value.x,size_value.y,1)
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(n);n.set_meta("cg_batch",true)
	return n

func orangery():
	var court=model("TerracedOrangery",Vector3.ZERO)
	for x in [-8.3,8.3]:
		for z in [-8,-3.5,1,5.5]:
			arch(court,Vector3(x,3.9,z),3.3,6.1,.62,.40,masonry,PI/2)
		block(Vector3(x,10.45,-1.25),Vector3(.84,.38,18.5),masonry,court)
		for z in [-8,-3.5,1,5.5]:
			beam(Vector3(x,10.6,z),Vector3(x,13.0,z),.06)
			beam(Vector3(x,13,z),Vector3(0,14.1,z),.05)
			curtain(Vector3(x,10.35,z),3.8,1.25)
		for z in [-6,-1.5,3]:
			c.pot(Vector3(x,3.9,z),1.15);plant(Vector3(x,4.51,z),2.2,2)
	for z in [-8,-3.5,1,5.5]:beam(Vector3(-8.3,13,z),Vector3(8.3,13,z),.06)
	for center in [Vector3(-5,0,0),Vector3(5,0,0),Vector3(0,0,-5)]:
		for side in [-1,1]:
			arch(court,center+Vector3(0,-1.7,side*1.35),2.4,7.05,.6,.38,c.paving_material)
			block(center+Vector3(side*1.46,2.03,0),Vector3(.62,7.46,2.75),c.paving_material,court)
		for j in 4:plant(center+Vector3((-1 if j<2 else 1)*1.22,6.30,-.65+(j%2)*1.3),.9,j%3)
	for side in [-1,1]:
		arch(court,Vector3(side*1.57,-1.7,-10),3.0,9.9,.65,.45,c.paving_material,PI/2)
		curtain(Vector3(side*1.58,8.4,-10.7),3.9,1.1)
	court.set_meta("underwater_foundation",-1.7)

func make_broad_leaf() -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var a=i/12.0;var b=(i+1)/12.0
		var wa=maxf(.008,pow(sin(a*PI),.65)*.32*(1.0+.04*sin(i*PI/2)))
		var wb=maxf(.008,pow(sin(b*PI),.65)*.32*(1.0+.04*sin((i+1)*PI/2)))
		for side in [-1,1]:
				s.add_face(st,[Vector3(0,sin(a*PI)*.13,a),Vector3(side*wa,sin(a*PI)*(.055+side*.035*sin(a*4)),a),Vector3(side*wb,sin(b*PI)*(.055+side*.035*sin(b*4)),b),Vector3(0,sin(b*PI)*.13,b)],Vector3.UP,[Vector2(.5,a),Vector2(0 if side<0 else 1,a),Vector2(0 if side<0 else 1,b),Vector2(.5,b)])
	st.index();st.generate_normals();st.generate_tangents();return st.commit()

func leaf(p: Vector3,direction: Vector3,size_value: float):
	# Roll around the petiole and vary breadth, keeping the attachment fixed.
	var basis=Basis(Quaternion(Vector3.BACK,direction.normalized()))
	basis=basis.rotated(direction.normalized(),rng.randf_range(-.38,.38))
	broad_leaves.append(Transform3D(basis.scaled_local(Vector3(size_value*rng.randf_range(.78,1.08),size_value,size_value*rng.randf_range(.85,1.12))),p))

func plant(p: Vector3,height: float,kind: int):
	if kind==0:
		block(p+Vector3(0,height*.48,0),Vector3(.033,height,.033),c.wood_material)
	for branch in (3 if kind==0 else 5):
		var angle=branch*2.399+height
		var out=Vector3(cos(angle),0,sin(angle))
		var previous=p
		for j in 7:
			var t=(j+1)/7.0
			var tip=p+out*(.13 if kind==0 else .40)*height*t+Vector3(.06*sin(t*9+branch),height*t*(.9 if kind==0 else .75+.17*sin(angle)),0)
			c.rod(previous,tip,.008);previous=tip
			for side in [-1,1]:
				var d=(out*side*.8+Vector3(0,.15,.25)).normalized()
				leaf(tip,d,height*(.27 if kind==0 else .23)*(1-t*.40))
			if kind==2 and j>3:
				for petal in 5:
					var d=Vector3(cos(petal*TAU/5),.35,sin(petal*TAU/5))
					petals.append(Transform3D(Basis(Quaternion(Vector3.BACK,d.normalized())).scaled_local(Vector3(.10,.10,.13)),tip+Vector3(0,.04,0)))

func curtain(p: Vector3,length_value: float,width: float):
	for branch in 8:
		var base=p+Vector3((branch/7.0-.5)*width,0,.08*sin(branch))
		var fall=length_value*(.45+.55*(.5+.5*sin(branch*2.3)))
		var previous=base
		for j in int(fall/.16):
			var h=j*.16
			var point=base+Vector3(sin(h*2.5+branch)*.12,-h,.15*sin(h*1.8))
			c.rod(previous,point,.006);previous=point
			for side in [-1,1]:leaf(point,Vector3(side*.7,-.55,.15),.31+.08*sin(h*4+branch))

func seed_crate():
	var p:Vector3=c.garden.nodes.arrival+Vector3(1.23,.04,-.70)
	c.crate(p)
	var lid=model("ProppedSeedCrateLid",p+Vector3(0,.70,-.55),0)
	lid.rotation.x=-1.08
	for j in 7:block(Vector3(0,.035,-.48+j*.16),Vector3(1.12,.07,.145),c.wood_material,lid)
	for x in [-.42,.42]:block(Vector3(x,-.022,0),Vector3(.075,.055,1.1),c.metal_material,lid)
	block(p+Vector3(0,.47,0),Vector3(.92,.06,.91),c.soil_material)
	plant(p+Vector3(0,.51,0),.73,1)
	root.set_meta("seedling_crate",p)

func bell_tower():
	var old=root.find_child("OldTownBellTower",true,false)
	if old:old.get_parent().remove_child(old);old.queue_free()
	var p=Vector3(-56,c.town_height(-56,-22),-22)
	var tower=model("OldTownBellTower",p)
	block(Vector3(0,9,0),Vector3(4.0,18,4),masonry,tower)
	for y in [3,10,17.9,22.3]:block(Vector3(0,y,0),Vector3(4.6,.33,4.6),c.wall_material,tower)
	for z in [-2.05,2.05]:
		arch(tower,Vector3(0,18.1,z),2.75,3.65,.5,.30,masonry)
	for x in [-2.05,2.05]:arch(tower,Vector3(x,18.1,0),2.75,3.65,.5,.30,masonry,PI/2)
	for x in [-1.8,1.8]:
		for z in [-1.8,1.8]:block(Vector3(x,20.2,z),Vector3(.50,4.1,.50),masonry,tower)
	var bell=CylinderMesh.new();bell.height=1.1;bell.top_radius=.38;bell.bottom_radius=.8;bell.radial_segments=24
	var n=MeshInstance3D.new();n.name="SuspendedBronzeBell";n.mesh=bell;n.material_override=c.metal_material;tower.add_child(n);n.position=Vector3(0,20.1,0)
	block(Vector3(0,21.7,0),Vector3(.15,1.8,.15),c.wood_material,tower)
	var roof=CylinderMesh.new();roof.height=3.6;roof.bottom_radius=3.3;roof.top_radius=.16;roof.radial_segments=4
	n=MeshInstance3D.new();n.mesh=roof;n.material_override=c.botany.clay_material;tower.add_child(n);n.position=Vector3(0,24.35,0);n.rotation.y=PI/4
	for j in 12:
		var x=-31-j%3*12;var z=-58+j/3*19;var base=Vector3(x,c.town_height(x,z),z)
		cypress(base,5.0+(j%3)*1.1)
	# Clock faces are real cylinders and metal hands, without an emissive billboard.
	for z in [-2.025,2.025]:
		var dial=CylinderMesh.new();dial.height=.055;dial.bottom_radius=.86;dial.top_radius=.86;dial.radial_segments=32
		n=MeshInstance3D.new();n.mesh=dial;n.material_override=c.paving_material;tower.add_child(n);n.position=Vector3(0,14,z);n.rotation.x=PI/2
		block(Vector3(0,14.25,z+signf(z)*.035),Vector3(.07,.56,.065),c.metal_material,tower)
		var hand=block(Vector3(.25,14,z+signf(z)*.04),Vector3(.6,.055,.065),c.metal_material,tower);hand.rotation.z=.20

func cypress(p: Vector3,height: float):
	c.rod(p,p+Vector3(0,height,0),.10)
	for j in 95:
		var h=.35+rng.randf()*.62;var a=rng.randf()*TAU
		var r=height*.12*pow(sin(h*PI),1.7)*rng.randf_range(.3,1)
		leaf(p+Vector3(cos(a)*r,height*h,sin(a)*r),Vector3(cos(a),.8,sin(a)),.50)

func mountain_height(x: float,z: float) -> float:
	var spine=-119+9*sin(z*.026)+3*sin(z*.089)
	var profile=pow(maxf(0,1-absf(x-spine)/35),1.65)
	var peaks=27+12*sin(z*.047)+8*sin(z*.105+.5)
	var erosion=5.5*terrain_noise.get_noise_2d(x,z)+3.2*sin(z*.42+x*.24)
	var boundary=smoothstep(-143,-136,x)*(1-smoothstep(-75,-65,x))
	boundary*=smoothstep(-99,-89,z)*(1-smoothstep(30,41,z))
	return -3+profile*maxf(0,peaks+erosion)*boundary

func mountain_shore():
	terrain_noise.seed=110212;terrain_noise.frequency=.06
	terrain_noise.fractal_octaves=4
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x_id in 52:
		for z_id in 70:
			var points=[]
			for pair in [Vector2(x_id,z_id),Vector2(x_id+1,z_id),Vector2(x_id+1,z_id+1),Vector2(x_id,z_id+1)]:
				var x=-143+pair.x*1.5;var z=-99+pair.y*2
				points.append(Vector3(x,mountain_height(x,z),z))
			for k in [0,1,2,0,2,3]:
				var p:Vector3=points[k]
				# Central differences keep lighting continuous across shared cells.
				var normal=Vector3(mountain_height(p.x-.15,p.z)-mountain_height(p.x+.15,p.z),.3,mountain_height(p.x,p.z-.15)-mountain_height(p.x,p.z+.15)).normalized()
				st.set_normal(normal);st.set_uv(Vector2(p.x*.12,p.z*.12));st.add_vertex(p)
	st.index();st.generate_tangents()
	var n=MeshInstance3D.new();n.name="CoastalMountainRange";n.mesh=st.commit()
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/coastal_rock.gdshader")
	mat.set_shader_parameter("rock_surface",preload("res://assets/scenery/coast_rocks_02/textures/coast_rocks_02_diff_1k.jpg"))
	mat.set_shader_parameter("rock_arm",preload("res://assets/scenery/coast_rocks_02/textures/coast_rocks_02_arm_1k.jpg"))
	mat.set_shader_parameter("soil_surface",preload("res://assets/scenery/brown_mud_02_albedo.jpg"))
	n.material_override=mat;root.add_child(n)
	n.set_meta("terrain_cells",Vector2i(52,70))
