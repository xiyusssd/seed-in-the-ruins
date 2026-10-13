extends Node
func _ready():run.call_deferred()
func run():
	Journey.fresh()
	var garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.capture=true;garden.set_process(false);garden.geometry.hide();garden.walker.set_physics_process(false)
	garden.ui.close_panel();garden.ui.hide();garden.set_recovery(1)
	for i in 3:
		var tree=load("res://assets/scenery/tree_small_02/tree_small_02.gltf").instantiate();garden.add_child(tree)
		tree.position=Vector3((i-1)*4,0,0)
		for node in tree.find_children("*","MeshInstance3D",true,false):
			for surface in node.mesh.get_surface_count():
				var original=node.mesh.surface_get_material(surface)
				if original is StandardMaterial3D and "leaves" in original.resource_name and i>0:
					var mat=ShaderMaterial.new()
					if i==1:mat.shader=load("res://shaders/scanned_leaves.gdshader")
					else:
						var shader=Shader.new();shader.code="shader_type spatial;render_mode cull_disabled;uniform sampler2D albedo_texture : source_color,filter_linear_mipmap;void fragment(){ALBEDO=texture(albedo_texture,UV).rgb;ROUGHNESS=.88;BACKLIGHT=ALBEDO*.22;}"
						mat.shader=shader
					mat.set_shader_parameter("albedo_texture",original.albedo_texture)
					mat.set_shader_parameter("normal_texture",original.normal_texture)
					print("LEAF_SOURCE ",i," ",original.albedo_texture.resource_path)
					node.set_surface_override_material(surface,mat)
	garden.camera.position=Vector3(0,4,12);garden.camera.look_at(Vector3(0,2,0));garden.camera.fov=60
	for i in 6:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/review/leaf-material-comparison.png")
	print("LEAF_COMPARISON: left original StandardMaterial, centre wind+normal, right diffuse-only")
	garden.environment.ssao_enabled=false;garden.environment.ssil_enabled=false;garden.environment.ssr_enabled=false
	for i in 4:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/review/leaf-no-screen-effects.png")
	for tree in garden.get_children():
		if tree is Node3D and tree!=garden.geometry:
			for node in tree.find_children("*","MeshInstance3D",true,false):node.lod_bias=100000
	for i in 4:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/review/leaf-no-lod.png")
	garden.queue_free();await get_tree().process_frame
	get_tree().quit()
