extends RefCounted
const IVORY = Color("b7ae96")
const STONE = Color("8e8977")
const TEAL = Color("71816a")
const CORAL = Color("956d50")
const GOLD = Color("b99b59")
const INK = Color("373c34")
const PURPLE = Color("787866")
var stone_grain: NoiseTexture2D
var stone_normal: NoiseTexture2D
var bevel_meshes: Dictionary = {}
var architectural_materials: Dictionary = {}
var parent: Node3D

func _init(p: Node3D):
	parent = p
	var noise = FastNoiseLite.new()
	noise.seed = 4107
	noise.frequency = 0.12
	noise.fractal_octaves = 3
	stone_grain = NoiseTexture2D.new()
	stone_grain.width = 256
	stone_grain.height = 256
	stone_grain.seamless = true
	stone_grain.noise = noise
	var ramp = Gradient.new()
	ramp.set_color(0, Color(0.88, 0.89, 0.87))
	ramp.set_color(1, Color(1.0, 0.98, 0.94))
	stone_grain.color_ramp = ramp
	stone_normal = NoiseTexture2D.new()
	stone_normal.width = 256
	stone_normal.height = 256
	stone_normal.seamless = true
	stone_normal.noise = noise
	stone_normal.as_normal_map = true
	stone_normal.bump_strength = 0.3

func material(color: Color, glow = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.86
	m.vertex_color_use_as_albedo = true
	if color.a == 1 and color.r > 0.65 and color.g > 0.6:
		m.albedo_texture = stone_grain
		m.normal_enabled = true
		m.normal_texture = stone_normal
		m.normal_scale = 0.22
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.8
	if color.a == 1 and color.r > color.b * 1.2 and color.g < color.r * 0.88:
		m.metallic = 0.18
		m.roughness = 0.63
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.35
	if color.a < 1:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func mesh_node(mesh: Mesh, p: Vector3, color: Color, target: Node3D = null) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material(color)
	(target if target else parent).add_child(n)
	n.position = p
	n.create_trimesh_collision()
	return n

func add_face(surface: SurfaceTool, vertices: Array, normal: Vector3, uvs: Array=[]):
	var shade = 0.96 if normal.y > -0.1 else 0.78
	for i in range(1, vertices.size() - 1):
		var tri = [vertices[0],vertices[i],vertices[i+1]]
		# Godot's front faces use clockwise winding viewed from outside.
		if (tri[1]-tri[0]).cross(tri[2]-tri[0]).dot(normal) > 0:
			tri.reverse()
		if (tri[1]-tri[0]).cross(tri[2]-tri[0]).length_squared()<0.000000000001:continue
		for point in tri:
			surface.set_normal(normal)
			surface.set_color(Color(shade,shade,shade))
			if not uvs.is_empty():surface.set_uv(uvs[vertices.find(point)])
			surface.add_vertex(point)

func bevel_box(size: Vector3) -> Mesh:
	if minf(size.x,minf(size.y,size.z)) < 0.10:
		var plain = BoxMesh.new()
		plain.size = size
		return plain
	if size in bevel_meshes: return bevel_meshes[size]
	var h = size / 2
	var bevel = minf(0.055,minf(h.x,minf(h.y,h.z))*0.22)
	var inner = h - Vector3.ONE * bevel
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var j = (axis+1)%3
		var k = (axis+2)%3
		for sign_value in [-1,1]:
			var verts = []
			for pair in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]:
				var p = Vector3.ZERO
				p[axis] = h[axis]*sign_value
				p[j] = inner[j]*pair.x
				p[k] = inner[k]*pair.y
				verts.append(p)
			var normal = Vector3.ZERO
			normal[axis] = sign_value
			add_face(surface,verts,normal)
	for axis in 3:
		var j = (axis+1)%3
		var k = (axis+2)%3
		for sj in [-1,1]:
			for sk in [-1,1]:
				var a = Vector3.ZERO
				a[axis] = -inner[axis]
				a[j] = sj*h[j]
				a[k] = sk*inner[k]
				var b = a; b[axis] = inner[axis]
				var c = b; c[j] = sj*inner[j]; c[k] = sk*h[k]
				var d = c; d[axis] = -inner[axis]
				var normal = Vector3.ZERO; normal[j] = sj; normal[k] = sk
				add_face(surface,[a,b,c,d],normal.normalized())
	for sx in [-1,1]:
		for sy in [-1,1]:
			for sz in [-1,1]:
				var a = Vector3(sx*h.x,sy*inner.y,sz*inner.z)
				var b = Vector3(sx*inner.x,sy*h.y,sz*inner.z)
				var c = Vector3(sx*inner.x,sy*inner.y,sz*h.z)
				add_face(surface,[a,b,c],Vector3(sx,sy,sz).normalized())
	var mesh = surface.commit()
	bevel_meshes[size] = mesh
	return mesh

func block(p: Vector3, size: Vector3, color = IVORY, target: Node3D = null) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var n = mesh_node(mesh, p, color, target)
	# Keep the original box collision; only the visible geometry receives a bevel.
	n.mesh = bevel_box(size)
	if color in [IVORY,STONE,CORAL,PURPLE]: n.material_override=weathered_material(color,color in [CORAL,PURPLE])
	return n

func column(p: Vector3, radius: float, height: float, color = IVORY, target: Node3D = null, top_radius = -1.0) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	var n=mesh_node(mesh,p,color,target)
	if color in [IVORY,STONE]: n.material_override=weathered_material(color)
	return n

func sphere(p: Vector3, radius: float, color = IVORY, target: Node3D = null, hemisphere = false) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.is_hemisphere = hemisphere
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh_node(mesh, p, color, target)

func ring(p: Vector3, radius: float, thickness: float, color = GOLD, target: Node3D = null) -> MeshInstance3D:
	var mesh = TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius
	mesh.rings = 32
	mesh.ring_segments = 12
	return mesh_node(mesh, p, color, target)

func detail(p: Vector3, size: Vector3, color: Color, target: Node3D = null) -> MeshInstance3D:
	var mesh = bevel_box(size)
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material(color)
	# Millimetre-scale inlays cannot produce useful separate shadow silhouettes.
	if minf(size.x,minf(size.y,size.z)) < .02:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(target if target else parent).add_child(n)
	n.position = p
	return n

func deck(p: Vector3, width: float, depth: float, color = IVORY):
	block(p - Vector3(0, 0.18, 0), Vector3(width, 0.36, depth), color)
	block(p - Vector3(0, 0.41, 0), Vector3(width + 0.18, 0.12, depth + 0.18), STONE)
	# Thin inlaid joints make paving legible from eye height without obstructing paths.
	for i in range(1, int(width / 0.85)):
		detail(p + Vector3(-width / 2 + i * 0.85, 0.014, 0), Vector3(0.014, 0.006, depth), STONE.darkened(0.23))
	for i in range(1, int(depth / 0.85)):
		detail(p + Vector3(0, 0.014, -depth / 2 + i * 0.85), Vector3(width, 0.006, 0.014), STONE.darkened(0.23))
	for x in [-1, 1]:
		for z in [-1, 1]:
			var h = p.y + 0.5
			column(Vector3(p.x + x * (width / 2 - 0.35), p.y - h / 2 - 0.45, p.z + z * (depth / 2 - 0.35)), 0.22, h, STONE)

func bridge(a: Vector3, b: Vector3, width = 1.35, target: Node3D = null, accent = CORAL):
	var length = a.distance_to(b)
	var center = (a + b) / 2
	var platform = Node3D.new()
	(target if target else parent).add_child(platform)
	platform.position = center
	platform.rotation.y = atan2(b.x - a.x, b.z - a.z)
	# Stair side ledges use this builder too: align their actual 3D span so
	# they do not become horizontal beams projecting into the lower landing.
	platform.rotation.x = -atan2(b.y-a.y,Vector2(b.x-a.x,b.z-a.z).length())
	block(Vector3(0, -0.20, 0), Vector3(width, 0.36, length), IVORY, platform)
	var tread=block(Vector3(0, 0.008, 0), Vector3(width * 0.55, 0.015, length), accent, platform)
	tread.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1, 1]:
		block(Vector3(side * (width / 2 - 0.045), 0.055, 0), Vector3(0.07, 0.11, length), STONE, platform)
	if length > 2.5:
		for side in [-1, 1]:
			for i in range(int(length / 1.7) + 1):
				var z = -length / 2 + 0.2 + i * (length - 0.4) / maxf(1, int(length / 1.7))
				detail(Vector3(side * (width / 2 + 0.035), 0.31, z), Vector3(0.11, 0.62, 0.11), STONE, platform)
	return platform

func stairs(a: Vector3, b: Vector3, width = 1.5):
	var count = maxi(1, int(absf(a.y - b.y) / 0.18))
	var direction = Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var length = Vector2(b.x - a.x, b.z - a.z).length()
	var yaw = atan2(direction.x, direction.z)
	for i in count:
		var t = (i + 0.5) / count
		var p = a.lerp(b, t)
		var step = block(p - Vector3(0, 0.13, 0), Vector3(width, 0.26, length / count + 0.03), IVORY)
		step.rotation.y = yaw
	for side in [-1, 1]:
		var offset = direction.cross(Vector3.UP) * side * (width * 0.5 + 0.07)
		var rail = bridge(a + offset, b + offset, 0.12, null, STONE)
		rail.position.y -= 0.18

# Industrial door frames preserve passage width while removing the ornamental arches.
func arch(p: Vector3, width: float, height: float, color = IVORY, yaw = 0.0, target: Node3D = null):
	var group=Node3D.new();group.name="RuinDoorFrame"
	(target if target else parent).add_child(group);group.position=p;group.rotation.y=yaw
	group.set_meta("industrial_portal",true)
	var r=width/2.0
	for side in [-1,1]:
		var leg=block(Vector3(side*(r+.12),height/2,0),Vector3(.24,height,.5),STONE,group)
		leg.material_override=weathered_material(STONE)
		block(Vector3(side*(r+.12),.1,0),Vector3(.4,.2,.7),STONE,group)
		var scar=detail(Vector3(side*(r+.12),height*.55,.255),Vector3(.16,.38,.015),INK,group)
		scar.rotation.z=side*.17
		for j in 2:
			rust_rod(Vector3(side*(r+.15),height+.1,.13+j*.11),Vector3(side*(r+.23),height+.45+j*.12,.13+j*.11),.018,group)
	var lintel=block(Vector3(0,height+.12,0),Vector3(width+.5,.24,.56),STONE,group)
	lintel.material_override=weathered_material(STONE)
	detail(Vector3(0,height-.015,.3),Vector3(width+.44,.065,.06),Color("765540"),group)
	for side in [-1,1]:
		detail(Vector3(side*(r+.15),height*.75,.3),Vector3(.25,.42,.07),Color("765540"),group)
	return group

func pavilion(p: Vector3, width: float, color = CORAL, roof = true):
	deck(p,width+.7,width+.7)
	for side in [-1,1]:
		arch(p+Vector3(side*width/2,0,0),width-.7,2.6,STONE,PI/2)
		arch(p+Vector3(0,0,side*width/2),width-.7,2.6,STONE)
	if roof:
		# Missing roof panels reveal the sky, with no hidden dome collision.
		for side in [-1,1]:
			var panel=detail(p+Vector3(side*width*.34,3.05,0),Vector3(width*.29,.14,width+.45),Color("765540"))
			panel.material_override=weathered_material(Color("765540"),true)
			panel.rotation.z=side*.035
			for z in [-width*.44,width*.44]:
				rust_rod(p+Vector3(-width*.54,2.93,z),p+Vector3(width*.54,2.93,z),.045)

func rust_rod(a: Vector3,b: Vector3,radius: float,target: Node3D=null):
	var mesh=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=8
	var n=MeshInstance3D.new();n.mesh=mesh;n.material_override=weathered_material(Color("765540"),true)
	(target if target else parent).add_child(n);n.position=(a+b)/2
	n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return n

func weathered_material(color: Color,metal=false) -> Material:
	var key=str(color)+str(metal)
	if key in architectural_materials: return architectural_materials[key]
	if not metal:
		# Native triplanar PBR reconstructs imported two-channel normal maps safely.
		var pbr=generated_surface("concrete",color.lerp(Color("b0aca1"),.28).lightened(.22),.4)
		architectural_materials[key]=pbr
		return pbr
	var m=ShaderMaterial.new();m.shader=preload("res://shaders/wasteland_surface.gdshader")
	m.set_shader_parameter("base_tint",color);m.set_shader_parameter("metal_surface",metal)
	architectural_materials[key]=m;return m

func generated_surface(asset: String,tint: Color,scale_value: float) -> StandardMaterial3D:
	var key="generated/"+asset+str(tint)+str(scale_value)
	if key in architectural_materials:return architectural_materials[key]
	var mat=StandardMaterial3D.new()
	mat.albedo_color=tint;mat.vertex_color_use_as_albedo=true
	mat.albedo_texture=load("res://assets/generated_materials/"+asset+"_albedo.png")
	mat.normal_enabled=true;mat.normal_scale=.22 if asset=="plaster" else .18
	mat.normal_texture=load("res://assets/generated_materials/"+asset+"_normal.png")
	mat.roughness_texture=load("res://assets/generated_materials/"+asset+"_roughness.png")
	mat.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness=1.0;mat.metallic=0.0
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar=true;mat.uv1_world_triplanar=true
	mat.uv1_scale=Vector3.ONE*scale_value
	architectural_materials[key]=mat
	return mat

func surface_pbr(asset: String,tint: Color,scale_value: float,metallic=0.0) -> StandardMaterial3D:
	var key=asset+str(tint)+str(scale_value)
	if key in architectural_materials:return architectural_materials[key]
	var mat=StandardMaterial3D.new()
	mat.albedo_color=tint;mat.vertex_color_use_as_albedo=true
	mat.albedo_texture=load("res://assets/scenery/"+asset+"_albedo.jpg")
	mat.normal_enabled=true;mat.normal_scale=.45
	mat.normal_texture=load("res://assets/scenery/"+asset+"_normal.jpg")
	mat.roughness_texture=load("res://assets/scenery/"+asset+"_roughness.jpg")
	mat.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness=1.0;mat.metallic=metallic
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar=true;mat.uv1_world_triplanar=true
	mat.uv1_scale=Vector3.ONE*scale_value
	architectural_materials[key]=mat
	return mat

# Curved, tapered leaves have an explicit midrib and tip rather than ellipsoid silhouettes.
func leaf(p: Vector3, length: float, width: float, angle: float, color: Color, target: Node3D):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 8:
		var t0 = float(segment) / 8
		var t1 = float(segment + 1) / 8
		for side in [-1, 1]:
			var points = []
			for t in [t0,t1]:
				var edge = sin(PI * t) * width * side
				points.append(Vector3(edge, sin(t * PI * 0.7) * length * 0.22, t * length))
				points.append(Vector3(0, sin(t * PI * 0.7) * length * 0.22 + sin(PI*t)*width*0.22, t*length))
			var t=(t0+t1)*.5
			var normal=Vector3(0,1,-cos(t*PI*.7)*.22*PI*.7).normalized()
			add_face(st,[points[0],points[2],points[3],points[1]],normal,[Vector2(.5+side*.5,t0),Vector2(.5+side*.5,t1),Vector2(.5,t1),Vector2(.5,t0)])
	var n = MeshInstance3D.new()
	n.mesh = st.commit()
	var key="botanical"+str(color)
	if key not in architectural_materials:
		var leaf_mat=ShaderMaterial.new();leaf_mat.shader=preload("res://shaders/botanical_leaf.gdshader")
		leaf_mat.set_shader_parameter("leaf_tint",color)
		leaf_mat.set_shader_parameter("petal",color.r>color.g)
		leaf_mat.set_shader_parameter("leaf_surface",preload("res://assets/generated_materials/leaf_albedo.png"))
		architectural_materials[key]=leaf_mat
	var m=architectural_materials[key]
	n.material_override = m
	target.add_child(n)
	n.position = p
	n.rotation.y = angle
	return n

func plant(p: Vector3, scale_value = 1.0, kind = 0, target: Node3D = null):
	var group = Node3D.new()
	(target if target else parent).add_child(group)
	group.position = p
	group.set_meta("wind_foliage",true)
	group.scale = Vector3.ONE * scale_value
	var variation = sin(p.x * 3.1 + p.z * 2.7)
	column(Vector3(0, 0.5, 0), 0.035, 1, TEAL.darkened(0.22), group)
	if kind == 2:
		column(Vector3(0,0.8,0),0.065,1.6,Color("817768"),group,0.032)
		for tier in 3:
			for j in 5:
				var angle = j * TAU / 5 + tier * 0.71 + variation
				var height = 0.85 + tier * 0.38
				leaf(Vector3(0,height,0),0.8-tier*0.13,0.25-tier*0.035,angle,TEAL.lightened(0.04*tier),group)
		leaf(Vector3(0,1.85,0),0.48,0.14,variation,TEAL.lightened(0.1),group)
	else:
		for j in 5:
			leaf(Vector3(0,0.28+j*0.13,0),0.46+(j%2)*0.09,0.13,j*2.4+variation,TEAL.lightened(j*0.018),group)
		if kind == 0:
			for i in 6:
				var angle = i * TAU / 6
				leaf(Vector3(0,1.03,0),0.23,0.105,angle,CORAL.lightened((i%2)*0.06),group)
			var heart = sphere(Vector3(0,1.07,0),0.065,GOLD,group)
			heart.scale.y = 0.6
	# Botanical decoration must never obstruct walking or the clue ray.
	for body in group.find_children("*","StaticBody3D",true,false):
		body.collision_layer = 0
		body.collision_mask = 0
	return group

func urn(p: Vector3, color = TEAL):
	var drum=column(p + Vector3(0, 0.2, 0), 0.36, 0.4, color, null, 0.45)
	drum.material_override=weathered_material(color,true)
	for height in [.08,.34]:
		var band=ring(p+Vector3(0,height,0),.405,.018,INK)
		for body in band.find_children("*","StaticBody3D",true,false): body.collision_layer=0
	column(p + Vector3(0, 0.43, 0), 0.45, 0.08, STONE)
	column(p + Vector3(0, 0.46, 0), 0.36, 0.02, INK)

func traveler() -> Node3D:
	var root = Node3D.new()
	parent.add_child(root)
	for side in [-1, 1]:
		column(Vector3(side * 0.09, 0.1, 0), 0.055, 0.2, INK, root)
	column(Vector3(0, 0.43, 0), 0.27, 0.65, TEAL.darkened(0.12), root, 0.13)
	sphere(Vector3(0, 0.92, 0), 0.23, TEAL.darkened(0.12), root)
	var face = sphere(Vector3(0, 0.94, 0.17), 0.15, IVORY, root)
	face.scale = Vector3(0.85, 1, 0.5)
	block(Vector3(0, 0.62, -0.18), Vector3(0.22, 0.3, 0.14), GOLD, root)
	sphere(Vector3(0, 0.66, -0.27), 0.065, GOLD.lightened(0.2), root)
	return root

# Rounded industrial housings: projected face grids share smooth normals across fillets.
func rounded_box(size: Vector3, radius: float) -> Mesh:
	var key = str(size)+":"+str(radius)
	if key in bevel_meshes: return bevel_meshes[key]
	var h=size/2
	var r=minf(radius,minf(h.x,minf(h.y,h.z))*.7)
	var inner=h-Vector3.ONE*r
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var j=(axis+1)%3;var k=(axis+2)%3
		var xs=[-h[j],-inner[j]-r*.86,-inner[j]-r*.5,-inner[j],inner[j],inner[j]+r*.5,inner[j]+r*.86,h[j]]
		var ys=[-h[k],-inner[k]-r*.86,-inner[k]-r*.5,-inner[k],inner[k],inner[k]+r*.5,inner[k]+r*.86,h[k]]
		for sign_value in [-1,1]:
			for x in xs.size()-1:
				for y in ys.size()-1:
					var vertices=[];var normals=[]
					for pair in [Vector2(xs[x],ys[y]),Vector2(xs[x+1],ys[y]),Vector2(xs[x+1],ys[y+1]),Vector2(xs[x],ys[y+1])]:
						var raw=Vector3.ZERO;raw[axis]=h[axis]*sign_value;raw[j]=pair.x;raw[k]=pair.y
						var nearest=raw.clamp(-inner,inner)
						var normal=(raw-nearest).normalized()
						vertices.append(nearest+normal*r);normals.append(normal)
					var indices=[0,1,2,0,2,3]
					if (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).dot(normals[0])>0: indices=[0,2,1,0,3,2]
					for index in indices:
						surface.set_normal(normals[index]);surface.set_color(Color.WHITE);surface.add_vertex(vertices[index])
	var mesh=surface.commit();bevel_meshes[key]=mesh
	return mesh

func rounded_detail(p: Vector3,size: Vector3,color: Color,radius=.08,target: Node3D=null) -> MeshInstance3D:
	var n=MeshInstance3D.new();n.mesh=rounded_box(size,radius);n.material_override=material(color)
	(target if target else parent).add_child(n);n.position=p
	return n
