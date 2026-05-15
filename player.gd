extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _physics_process(delta):

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

	move_and_slide()

var mouse_sensitivity = 0.002

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
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
