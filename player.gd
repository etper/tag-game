extends CharacterBody3D

const SPEED = 25.0

const GRAVITY = 20.0

var mouse_sensitivity = 0.002

var is_it = false

func _physics_process(delta):

	if is_multiplayer_authority():

		var input_dir = Input.get_vector(
			"move_left",
			"move_right",
			"move_forward",
			"move_back"
		)

		var direction = (
			transform.basis *
			Vector3(input_dir.x, 0, input_dir.y)
		).normalized()

		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

		if !is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = 0

		move_and_slide()

		update_transform.rpc(global_transform)

@rpc("any_peer")
func update_transform(new_transform):
	if !is_multiplayer_authority():
		global_transform = new_transform

func _ready():
	if is_multiplayer_authority():
		$Camera3D.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		$Camera3D.current = false

func _input(event):

	if !is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:

		rotate_y(-event.relative.x * mouse_sensitivity)

		$Camera3D.rotate_x(
			-event.relative.y * mouse_sensitivity
		)

		$Camera3D.rotation.x = clamp(
			$Camera3D.rotation.x,
			deg_to_rad(-80),
			deg_to_rad(80)
		)

func set_is_it(value):

	is_it = value

	var material = $PlayerBody.material_override

	if material == null:
		material = StandardMaterial3D.new()
		$PlayerBody.material_override = material

	if is_it:
		material.albedo_color = Color.RED
	else:
		material.albedo_color = Color.WHITE

@rpc("any_peer", "call_local")
func force_teleport(new_position):

	global_position = new_position
	velocity = Vector3.ZERO
