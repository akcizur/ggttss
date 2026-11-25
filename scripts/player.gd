extends CharacterBody3D

## Third-person gameplay controller.
## Physics/collision live on CharacterBody3D; the Mixamo rig is visual-only.

@onready var camera_mount: Node3D = $camera_mount
@onready var spring_arm: SpringArm3D = $camera_mount/SpringArm3D
@onready var camera: Camera3D = $camera_mount/SpringArm3D/Camera3D
@onready var animation_player: AnimationPlayer = $visuals/mixamo_base/AnimationPlayer
@onready var visuals: Node3D = $visuals

const WALK_SPEED: float = 3.4
const RUN_SPEED: float = 6.2
const JUMP_VELOCITY: float = 4.8
const GROUND_ACCELERATION: float = 20.0
const GROUND_DECELERATION: float = 24.0
const AIR_CONTROL: float = 5.0
const TURN_SMOOTHNESS: float = 13.0
const CAMERA_MIN_PITCH: float = deg_to_rad(-55.0)
const CAMERA_MAX_PITCH: float = deg_to_rad(12.0)
const CAMERA_MIN_DISTANCE: float = 2.6
const CAMERA_MAX_DISTANCE: float = 6.5
const MOUSE_SENSITIVITY: float = 0.0022
const GAMEPAD_LOOK_SPEED: float = 2.35

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_yaw: float = 0.0
var camera_pitch: float = deg_to_rad(-10.0)
var current_speed: float = 0.0
var is_running: bool = false
var touch_move: Vector2 = Vector2.ZERO
var touch_look: Vector2 = Vector2.ZERO
var touch_run: bool = false
var jump_buffer_remaining: float = 0.0
var coyote_remaining: float = 0.0
const JUMP_BUFFER_TIME: float = 0.14
const COYOTE_TIME: float = 0.12

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.28
	floor_max_angle = deg_to_rad(48.0)
	camera_mount.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	# The spring arm must ignore the player's own capsule or it retracts into the body.
	spring_arm.add_excluded_object(get_rid())
	camera.current = true
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	for clip_name in ["idle", "walking", "running"]:
		if animation_player.has_animation(clip_name):
			animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	_play_animation("idle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = maxf(CAMERA_MIN_DISTANCE, spring_arm.spring_length - 0.35)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = minf(CAMERA_MAX_DISTANCE, spring_arm.spring_length + 0.35)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * MOUSE_SENSITIVITY
		camera_pitch = clampf(
			camera_pitch - event.relative.y * MOUSE_SENSITIVITY,
			CAMERA_MIN_PITCH,
			CAMERA_MAX_PITCH
		)
		_update_camera_rotation()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	_update_camera_input(delta)
	_apply_gravity(delta)

	var input_vector: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	input_vector += touch_move
	input_vector = input_vector.limit_length(1.0)
	var input_strength: float = input_vector.length()
	var has_input: bool = input_strength > 0.06

	# Camera yaw is deliberately independent from player body yaw.
	# Moving forward always follows the camera's horizontal look direction.
	var camera_basis := Basis(Vector3.UP, camera_yaw)
	var camera_forward: Vector3 = camera_basis * Vector3(0.0, 0.0, -1.0)
	var camera_right: Vector3 = camera_basis * Vector3(1.0, 0.0, 0.0)
	var movement_direction := Vector3.ZERO
	if has_input:
		movement_direction = (camera_right * input_vector.x - camera_forward * input_vector.y).normalized()

	is_running = has_input and (Input.is_action_pressed("run") or touch_run)
	var max_speed: float = RUN_SPEED if is_running else WALK_SPEED
	var target_speed: float = max_speed * input_strength if has_input else 0.0
	current_speed = target_speed

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var target_velocity := movement_direction * target_speed
	var acceleration: float = GROUND_ACCELERATION if has_input else GROUND_DECELERATION
	if not is_on_floor():
		acceleration = AIR_CONTROL
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if Input.is_action_just_pressed("jump"):
		jump_buffer_remaining = JUMP_BUFFER_TIME
	else:
		jump_buffer_remaining = maxf(0.0, jump_buffer_remaining - delta)

	if is_on_floor():
		coyote_remaining = COYOTE_TIME
	else:
		coyote_remaining = maxf(0.0, coyote_remaining - delta)

	if jump_buffer_remaining > 0.0 and coyote_remaining > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_remaining = 0.0
		coyote_remaining = 0.0
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.55

	if has_input and is_on_floor():
		# Mixamo visual mesh faces local -Z; rotate only the visual, never the camera root.
		var facing_angle: float = atan2(-movement_direction.x, -movement_direction.z)
		visuals.rotation.y = lerp_angle(
			visuals.rotation.y,
			facing_angle,
			minf(TURN_SMOOTHNESS * delta, 1.0)
		)

	move_and_slide()
	_update_locomotion_animation(has_input, Vector2(velocity.x, velocity.z).length())

func _update_camera_input(delta: float) -> void:
	var gamepad_look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var look := (gamepad_look + touch_look).limit_length(1.0)
	if look.length_squared() > 0.0004:
		camera_yaw -= look.x * GAMEPAD_LOOK_SPEED * delta
		camera_pitch = clampf(
			camera_pitch - look.y * GAMEPAD_LOOK_SPEED * delta,
			CAMERA_MIN_PITCH,
			CAMERA_MAX_PITCH
		)
		_update_camera_rotation()

func _update_camera_rotation() -> void:
	camera_mount.rotation = Vector3(camera_pitch, camera_yaw, 0.0)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

func _update_locomotion_animation(has_input: bool, horizontal_speed: float) -> void:
	if not is_on_floor():
		# The source pack has get_up/knock_down but no jump loop; don't play a false clip.
		_play_animation("idle")
		return
	if not has_input or horizontal_speed < 0.12:
		_play_animation("idle")
		return

	if is_running:
		_play_animation("running")
		animation_player.speed_scale = clampf(horizontal_speed / RUN_SPEED, 0.80, 1.25)
	else:
		_play_animation("walking")
		animation_player.speed_scale = clampf(horizontal_speed / WALK_SPEED, 0.70, 1.20)

func _play_animation(animation_name: String) -> void:
	if not animation_player.has_animation(animation_name):
		return
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name, 0.18)
	animation_player.speed_scale = 1.0

func set_touch_move(value: Vector2) -> void:
	touch_move = value.limit_length(1.0)

func set_touch_look(value: Vector2) -> void:
	touch_look = value.limit_length(1.0)

func set_touch_run(value: bool) -> void:
	touch_run = value

func request_jump() -> void:
	jump_buffer_remaining = JUMP_BUFFER_TIME

func request_interact() -> void:
	get_tree().call_group("game_world", "request_interaction")

func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
