extends Node3D
# One shared wind drives dust, cloth, foliage and the ambience envelope.
var garden: Node3D
var wind_clock = 0.0
var gust = 0.5
var drift_distance = 0.0
var direction = Vector3(1,0,.28).normalized()
var dust: MultiMeshInstance3D
var dust_material: ShaderMaterial
var cloth_material: ShaderMaterial
var foliage: Array[Node3D] = []
var leaf_materials: Array[ShaderMaterial] = []
const COUNT = 24
func _ready():
	name="WastelandWind"
	dust_material=ShaderMaterial.new();dust_material.shader=preload("res://shaders/wind_dust.gdshader")
	var quad=QuadMesh.new();quad.size=Vector2(2.8,.52)
	var multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.mesh=quad;multimesh.instance_count=COUNT
	dust=MultiMeshInstance3D.new();dust.multimesh=multimesh;dust.material_override=dust_material
	dust.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(dust)
	dust.custom_aabb=AABB(Vector3(-80,-10,-80),Vector3(160,40,160))
	cloth_material=ShaderMaterial.new();cloth_material.shader=preload("res://shaders/wind_cloth.gdshader")
	for offset in [Vector3(1.35,1.5,-.75),Vector3(-1.35,2.0,-.6)]:
		var cloth=MeshInstance3D.new();var sheet=PlaneMesh.new();sheet.size=Vector2(.48,.9)
		sheet.subdivide_width=6;sheet.subdivide_depth=10
		cloth.name="WindCloth"
		cloth.mesh=sheet;cloth.material_override=cloth_material;cloth.rotation.x=PI/2
		cloth.rotation.y=atan2(direction.x,direction.z)
		cloth.position=garden.nodes.arrival+offset
		cloth.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(cloth)
		var left=cloth.position-cloth.basis.x*.3
		garden.s.rust_rod(left+Vector3(0,.45,0),cloth.position+cloth.basis.x*.3+Vector3(0,.45,0),.016,self)
		garden.s.rust_rod(left+Vector3(0,-offset.y,0),left+Vector3(0,.48,0),.025,self)
	for node in garden.geometry.find_children("*","Node3D",true,false):
		if node.has_meta("wind_foliage"): foliage.append(node)
		if node.has_meta("wind_leaf_material") and node.material_override not in leaf_materials:
			leaf_materials.append(node.material_override)
		if node.has_meta("wind_materials"):
			for mat in node.get_meta("wind_materials"):
				if mat not in leaf_materials:leaf_materials.append(mat)
	update_visuals()
func active() -> bool:
	return garden and garden.playing and garden.ui and not garden.ui.panel_open()
func register_foliage(plant: Node3D):
	foliage=foliage.filter(func(n):return is_instance_valid(n) and not n.is_queued_for_deletion())
	if plant not in foliage:foliage.append(plant)
func envelope(t: float) -> float:
	return clampf(.55+.26*sin(t*.29)+.18*sin(t*.71+1.4),.1,1.0)
func _process(delta):
	if not active(): return
	wind_clock+=delta;gust=envelope(wind_clock)
	drift_distance+=delta*(1.5+gust)
	update_visuals()
func update_visuals():
	var crosswind=Vector3(-direction.z,0,direction.x)
	var origin: Vector3=garden.nodes.arrival if not is_instance_valid(garden.walker) else garden.walker.position
	for i in COUNT:
		var lane=(i%8-3.5)*1.6
		var travel=fposmod(drift_distance+i*3.71,28.0)-14.0
		var p=origin+direction*travel+crosswind*lane+Vector3(0,.25+(i%3)*.42,0)
		var scale_value=.65+(i%5)*.16
		dust.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),p))
	dust_material.set_shader_parameter("wind_clock",wind_clock);dust_material.set_shader_parameter("gust",gust)
	dust_material.set_shader_parameter("opacity",lerpf(.10,.055,garden.recovery))
	cloth_material.set_shader_parameter("wind_clock",wind_clock);cloth_material.set_shader_parameter("gust",gust)
	for material in leaf_materials:
		material.set_shader_parameter("wind_clock",wind_clock)
		material.set_shader_parameter("gust",gust)
	for plant in foliage:
		if is_instance_valid(plant):
			var phase=plant.global_position.x*.27+plant.global_position.z*.13
			var lean=gust*.6+.25*sin(wind_clock*1.3+phase)
			plant.rotation.z=-direction.x*lean*.085
			plant.rotation.x=direction.z*lean*.07
