extends RefCounted
# Broken stone carries the surviving instructions. The text area stays intact;
# missing corners, a split foot and stained edges belong to the actual slab.
var stone: Material
var parent: Node3D
var rng=RandomNumberGenerator.new()
func build(board: Node3D,shapes: RefCounted,key: String):
	parent=board;rng.seed=11300+key.hash()
	stone=ShaderMaterial.new();stone.shader=preload("res://shaders/stele_stone.gdshader")
	stone.set_shader_parameter("stone_albedo",preload("res://assets/generated_materials/concrete_albedo.png"))
	stone.set_shader_parameter("stone_normal",preload("res://assets/generated_materials/concrete_normal.png"))
	stone.set_shader_parameter("stone_roughness",preload("res://assets/generated_materials/concrete_roughness.png"))
	stone.set_shader_parameter("inscription_depth",load("res://assets/inscriptions/"+key+"_depth.png"))
	stone.set_shader_parameter("age_offset",rng.randf()*20.0)
	var outline=PackedVector2Array([
		Vector2(-.57,.06),Vector2(.49,.02),Vector2(.64,.23),Vector2(.61,.68),
		Vector2(.65,1.04),Vector2(.60,1.30),Vector2(.55,1.33),Vector2(.62,1.40),
		Vector2(.61,1.71),Vector2(.43,1.87),Vector2(.18,1.81),Vector2(-.02,1.88),
		Vector2(-.13,1.79),Vector2(-.31,1.84),Vector2(-.51,1.75),Vector2(-.55,1.61),
		Vector2(-.66,1.57),Vector2(-.62,1.05),Vector2(-.59,.81),Vector2(-.65,.63)])
	# Six slabs have different broken silhouettes, without moving their clues.
	for i in outline.size():
		outline[i]+=Vector2(rng.randf_range(-.018,.018),rng.randf_range(-.018,.018))
	var slab=fragment("BrokenInscriptionStone",outline,.128,-.18)
	slab.create_trimesh_collision()
	slab.set_meta("broken_outline",outline)
	# Fallen chips and a split base replace the clean metal clipboard stand.
	fragment("SplitStoneFoot",PackedVector2Array([Vector2(-.70,.015),Vector2(.70,0),Vector2(.67,.16),Vector2(.12,.22),Vector2(-.64,.18)]),.21,-.26)
	for side in [-1,1]:
		var chip=shapes.detail(Vector3(side*.61,.035,.24),Vector3(.12,.065,.15),Color("827b65"),board)
		chip.material_override=stone;chip.rotation=Vector3(.11,side*.43,.17)
	# Hairline fractures travel through damaged margins and below the text.
	crack([Vector2(-.51,1.73),Vector2(-.55,1.64),Vector2(-.52,1.59),Vector2(-.56,1.49),Vector2(-.54,1.39)],.0025)
	crack([Vector2(.61,1.05),Vector2(.54,1.01),Vector2(.51,.96),Vector2(.55,.87),Vector2(.48,.80)],.003)
	crack([Vector2(-.39,.06),Vector2(-.29,.28),Vector2(-.33,.42),Vector2(-.19,.59),Vector2(-.14,.73)],.004)
	crack([Vector2(-.33,.42),Vector2(-.46,.48),Vector2(-.52,.57)],.002)
func triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3,shade: Color):
	var points=[a,b,c]
	if (b-a).cross(c-a).dot(normal)>0:points.reverse()
	for p in points:
		var uv=Vector2(p.x,p.y)
		if absf(normal.z)<.5:uv=Vector2(p.z,p.y) if absf(normal.x)>.5 else Vector2(p.x,p.z)
		st.set_normal(normal);st.set_color(shade);st.set_uv(uv);st.add_vertex(p)
func fragment(label: String,outline: PackedVector2Array,front: float,back: float) -> MeshInstance3D:
	var inset=PackedVector2Array()
	var center=Vector2.ZERO
	for p in outline:center+=p
	center/=outline.size()
	for p in outline:inset.append(center+(p-center)*.958)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices=Geometry2D.triangulate_polygon(inset)
	for i in range(0,indices.size(),3):
		triangle(st,Vector3(inset[indices[i]].x,inset[indices[i]].y,front),Vector3(inset[indices[i+1]].x,inset[indices[i+1]].y,front),Vector3(inset[indices[i+2]].x,inset[indices[i+2]].y,front),Vector3.BACK,Color.WHITE)
	var back_indices=Geometry2D.triangulate_polygon(outline)
	for i in range(0,back_indices.size(),3):
		triangle(st,Vector3(outline[back_indices[i]].x,outline[back_indices[i]].y,back),Vector3(outline[back_indices[i+1]].x,outline[back_indices[i+1]].y,back),Vector3(outline[back_indices[i+2]].x,outline[back_indices[i+2]].y,back),Vector3.FORWARD,Color(.78,.77,.72))
	for i in outline.size():
		var j=(i+1)%outline.size()
		var a=Vector3(outline[i].x,outline[i].y,front-.045)
		var b=Vector3(outline[j].x,outline[j].y,front-.045)
		var ai=Vector3(inset[i].x,inset[i].y,front)
		var bi=Vector3(inset[j].x,inset[j].y,front)
		var edge=outline[j]-outline[i];var outward=Vector3(edge.y,-edge.x,0).normalized()
		var bevel_normal=(outward+Vector3.BACK*.55).normalized()
		var shade=Color.WHITE* rng.randf_range(.78,.95);shade.a=1
		triangle(st,a,b,bi,bevel_normal,shade);triangle(st,a,bi,ai,bevel_normal,shade)
		var ab=Vector3(a.x,a.y,back);var bb=Vector3(b.x,b.y,back)
		triangle(st,a,ab,bb,outward,shade);triangle(st,a,bb,b,outward,shade)
	st.index();st.generate_tangents()
	var node=MeshInstance3D.new();node.name=label;node.mesh=st.commit();node.material_override=stone;parent.add_child(node)
	return node
func crack(points: Array,width: float):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size()-1:
		var a: Vector2=points[i];var b: Vector2=points[i+1]
		var direction=(b-a).normalized();var side=Vector2(-direction.y,direction.x)*width
		var v=[Vector3((a-side).x,(a-side).y,.129),Vector3((b-side*.6).x,(b-side*.6).y,.129),Vector3((b+side*.6).x,(b+side*.6).y,.129),Vector3((a+side).x,(a+side).y,.129)]
		triangle(st,v[0],v[1],v[2],Vector3.BACK,Color.WHITE);triangle(st,v[0],v[2],v[3],Vector3.BACK,Color.WHITE)
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("4b493e");mat.roughness=1
	var node=MeshInstance3D.new();node.name="StoneFracture";node.mesh=st.commit();node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)
