extends CharacterBody3D

const MAX_SPEED = 15.0

const ACCELERATION = 60.0
const AIR_ACCELERATION = 20.0

const FRICTION = 45.0
const AIR_FRICTION = 5.0

const JUMP_FORCE = 10.0
const GRAVITY = 20.0

const DASH_FORCE = 32.0
const DASH_COOLDOWN = 3.5
const DASH_UPWARD_BOOST = 0.5

@onready var it_icon = $ItIcon

var dash_ready = true

var danger_amount := 0.0

var nickname = "Player"

const MAX_JUMPS = 2

var jumps_left = MAX_JUMPS

var shake_strength = 0.0

var speed_boost = 1.0

@onready var heartbeat_player = $HeartbeatPlayer

var mouse_sensitivity = 0.002

var is_it = false

func _physics_process(delta):

	shake_strength = move_toward(
	shake_strength,
	0.0,
	delta * 20.0
	)
	
	danger_amount = move_toward(
	danger_amount,
	0.0,
	delta * 2.5
	)

	if is_multiplayer_authority():
		
		var total_shake = shake_strength + danger_amount * 0.05

		$Camera3D.position = Vector3(
			randf_range(-total_shake, total_shake),
			randf_range(-total_shake, total_shake),
			0
		)

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

		# current horizontal velocity
		var horizontal_velocity = Vector3(
			velocity.x,
			0,
			velocity.z
		)

		var target_velocity = direction * MAX_SPEED * speed_boost

		# choose accel/friction
		var accel = ACCELERATION
		var friction = FRICTION

		if !is_on_floor():
			accel = AIR_ACCELERATION
			friction = AIR_FRICTION

		# movement
		if direction != Vector3.ZERO:

			horizontal_velocity = horizontal_velocity.move_toward(
				target_velocity,
				accel * delta
			)

		else:

			horizontal_velocity = horizontal_velocity.move_toward(
				Vector3.ZERO,
				friction * delta
			)

		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z

		# gravity
		if !is_on_floor():
			velocity.y -= GRAVITY * delta
		else:

			if velocity.y < 0:
				velocity.y = 0

			jumps_left = MAX_JUMPS

		# jumping
		if Input.is_action_just_pressed("jump") and jumps_left > 0:
			velocity.y = JUMP_FORCE
			jumps_left -= 1
			
		if (
			Input.is_action_just_pressed("dash")
			and is_it
			and dash_ready
		):
			
			dash_ready = false
			
			var dash_direction = -transform.basis.z.normalized()
			
			velocity += dash_direction * DASH_FORCE
			
			add_screenshake(0.08)
			
			await get_tree().create_timer(DASH_COOLDOWN).timeout
			
			dash_ready = true

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

	it_icon.visible = is_it

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

@rpc("any_peer", "call_local")
func add_screenshake(amount):
	shake_strength = max(shake_strength, amount)

@rpc("any_peer", "call_local")
func apply_speed_boost():

	speed_boost = 3.0

	await get_tree().create_timer(0.7).timeout

	speed_boost = 1.0

@rpc("any_peer", "call_local")
func set_danger_level(value):

	danger_amount = clamp(value, 0.0, 1.0)

	if danger_amount > 0.05:

		if !heartbeat_player.playing:
			heartbeat_player.play()

		heartbeat_player.volume_db = lerp(
			-25.0,
			-3.0,
			danger_amount
		)

		heartbeat_player.pitch_scale = lerp(
			0.8,
			1.3,
			danger_amount
		)

	else:

		heartbeat_player.stop()

func set_nickname(value):

	nickname = value

	$NameLabel.text = value

func _process(delta):

	if it_icon.visible:

		it_icon.position.y = 2.2 + sin(Time.get_ticks_msec() * 0.005) * 0.15
