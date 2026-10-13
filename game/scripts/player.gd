extends CharacterBody3D
var camera: Camera3D
var active = false
var step_time = 0.0
var owner_world: Node3D

func _ready():
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape.shape = capsule
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 0.65
	camera.fov = 76
	camera.far = 180
	add_child(camera)
	camera.current = true

func _unhandled_input(event):
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0022)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0022, -1.3, 1.3)

func _physics_process(delta):
	if not active:
		return
	var axis = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction = (transform.basis * Vector3(axis.x, 0, axis.y)).normalized()
	var speed = 6.2 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.8
	if State.demo:
		speed *= 1.15
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y -= 18 * delta
	move_and_slide()
	if position.y < -5:
		position = Vector3(0, 1, 15)
	State.position = position
	State.elapsed += delta
	if direction.length() > 0.1 and is_on_floor():
		step_time += delta
		camera.position.y = 0.65 + sin(step_time * 10) * 0.025
		if step_time > 0.48:
			step_time = 0
			owner_world.play_sound("step", -24)
