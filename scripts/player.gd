extends CharacterBody3D

## Gameplay-first third-person character controller.
## The CharacterBody3D is the invisible physical root; Mixamo remains visual-only.

@onready var camera_mount: Node3D = $camera_mount
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
const CAMERA_MIN_PITCH: float = deg_to_rad(-62.0)
const CAMERA_MAX_PITCH: float = deg_to_rad(38.0)
const MOUSE_SENSITIVITY: float = 0.0022
const GAMEPAD_LOOK_SPEED: float = 2.35

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch: float = deg_to_rad(-10.0)
var current_speed: float = 0.0
var is_running: bool = false

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_mount.rotation.x = camera_pitch
	camera.current = true
	# These clips are intended to repeat during locomotion.
	for clip_name in ["idle", "walking", "running"]:
		if animation_player.has_animation(clip_name):
			animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	_play_animation("idle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw belongs to the camera/player root. Mouse right turns view right.
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pitch = clampf(
			camera_pitch - event.relative.y * MOUSE_SENSITIVITY,
			CAMERA_MIN_PITCH,
			CAMERA_MAX_PITCH
		)
		camera_mount.rotation.x = camera_pitch

func _physics_process(delta: float) -> void:
	# Right stick camera input; mouse look remains event-driven above.
	var look_axis := Vector2(Input.get_axis("look_left", "look_right"), Input.get_axis("look_up", "look_down"))
	if look_axis.length_squared() > 0.0004:
		rotate_y(-look_axis.x * GAMEPAD_LOOK_SPEED * delta)
		camera_pitch = clampf(
			camera_pitch - look_axis.y * GAMEPAD_LOOK_SPEED * delta,
			CAMERA_MIN_PITCH,
			CAMERA_MAX_PITCH
		)
		camera_mount.rotation.x = camera_pitch

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# get_vector normalizes diagonal input and also supports gamepad sticks.
	var input_vector: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	var local_input := Vector3(input_vector.x, 0.0, input_vector.y)
	var has_input := input_vector.length_squared() > 0.0004
	var movement_direction := (global_transform.basis * local_input).normalized() if has_input else Vector3.ZERO

	is_running = has_input and Input.is_action_pressed("run")
	var target_speed := RUN_SPEED if is_running else WALK_SPEED
	current_speed = target_speed if has_input else 0.0

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var target_velocity := movement_direction * target_speed
	var acceleration := GROUND_ACCELERATION if has_input else GROUND_DECELERATION
	if not is_on_floor():
		acceleration = AIR_CONTROL
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	# The source Mixamo rig faces local -Z. This angle maps input correctly:
	# forward=0, right=-90deg, left=+90deg, backward=180deg.
	if has_input and is_on_floor():
		var facing_angle := atan2(-input_vector.x, -input_vector.y)
		visuals.rotation.y = lerp_angle(
			visuals.rotation.y,
			facing_angle,
			minf(TURN_SMOOTHNESS * delta, 1.0)
		)

	_update_locomotion_animation(has_input, delta, horizontal_velocity.length())
	move_and_slide()

func _update_locomotion_animation(has_input: bool, _delta: float, horizontal_speed: float) -> void:
	if not is_on_floor():
		# The supplied asset has no jump/fall clip; keep the pose stable in air.
		_play_animation("idle")
		return
	if not has_input or horizontal_speed < 0.12:
		_play_animation("idle")
		return

	if is_running:
		_play_animation("running")
		animation_player.speed_scale = clampf(horizontal_speed / RUN_SPEED, 0.85, 1.2)
	else:
		_play_animation("walking")
		animation_player.speed_scale = clampf(horizontal_speed / WALK_SPEED, 0.75, 1.15)

func _play_animation(animation_name: String) -> void:
	if not animation_player.has_animation(animation_name):
		return
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name, 0.18)
	animation_player.speed_scale = 1.0

func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
