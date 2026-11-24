extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

var player: CharacterBody3D
var speed_label: Label
var message_label: Label
var interaction_available: bool = false
var interaction_message: String = ""
var message_timer: float = 0.0

func _ready() -> void:
	_build_environment()
	_build_city_block()
	_spawn_player()
	_build_hud()
	_build_pause_menu()

func _process(delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(speed_label):
		speed_label.text = "%03d km/h" % int(round(player.get_horizontal_speed() * 3.6))
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0 and is_instance_valid(message_label):
			message_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and interaction_available and not get_tree().paused:
		_show_message(interaction_message)
		get_viewport().set_input_as_handled()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.20, 0.31)
	sky_material.sky_horizon_color = Color(0.58, 0.64, 0.69)
	sky_material.ground_bottom_color = Color(0.12, 0.13, 0.14)
	sky_material.ground_horizon_color = Color(0.42, 0.45, 0.46)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.48, 0.55, 0.61)
	environment.fog_density = 0.0018
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

func _build_city_block() -> void:
	var asphalt := _material(Color(0.095, 0.11, 0.125))
	var concrete := _material(Color(0.39, 0.40, 0.39))
	var curb_material := _material(Color(0.55, 0.54, 0.50))
	var lane_material := _material(Color(0.82, 0.76, 0.56))

	# Ground and broad asphalt street. All walkable surfaces have real collision.
	_add_box("CityGround", Vector3(0, -0.35, 0), Vector3(100, 0.7, 120), _material(Color(0.20, 0.24, 0.22)), true)
	_add_box("MainStreet", Vector3(0, 0.015, 0), Vector3(14, 0.08, 112), asphalt, true)
	for side in [-1.0, 1.0]:
		_add_box("Sidewalk", Vector3(side * 9.0, 0.10, 0), Vector3(4.0, 0.22, 112), concrete, true)
		_add_box("Curb", Vector3(side * 7.05, 0.13, 0), Vector3(0.22, 0.28, 112), curb_material, true)

	for z in range(-50, 55, 10):
		_add_box("RoadMarking", Vector3(0, 0.065, float(z)), Vector3(0.16, 0.02, 4.0), lane_material, false)
	# Crosswalk near the player spawn.
	for i in range(7):
		_add_box("CrosswalkStripe", Vector3(-4.5 + i * 1.5, 0.067, 16.0), Vector3(0.8, 0.025, 2.4), _material(Color(0.78, 0.79, 0.75)), false)

	# A compact urban block: street-facing low-rise buildings on both sides.
	var facades: Array[Color] = [
		Color(0.35, 0.38, 0.40), Color(0.47, 0.40, 0.34),
		Color(0.39, 0.43, 0.42), Color(0.46, 0.45, 0.40),
		Color(0.32, 0.36, 0.40)
	]
	for side in [-1.0, 1.0]:
		for index in range(5):
			var z := -39.0 + float(index) * 19.0
			var height := 9.0 + float((index * 7 + int(side * 3)) % 4) * 2.0
			var x := side * 21.0
			var facade := _material(facades[(index + (1 if side > 0.0 else 0)) % facades.size()])
			_add_box("Building_%s_%d" % ["R" if side > 0.0 else "L", index], Vector3(x, height * 0.5, z), Vector3(17.0, height, 14.0), facade, true)
			_add_building_facade(x, z, height, side, index)

	# Street furniture: lamps, trees, waste bins and benches.
	for z in range(-42, 49, 14):
		for side in [-1.0, 1.0]:
			_add_lamp(side * 9.9, float(z))
	for z in [-31.0, -3.0, 25.0, 43.0]:
		_add_tree(-12.1, z)
		_add_tree(12.1, z + 5.0)
	_add_bin(Vector3(-10.8, 0.0, 8.5))
	_add_bench(Vector3(11.7, 0.0, -7.0))
	_add_interaction_point(Vector3(12.15, 0.0, -18.0), "Obchod je zatím zavřený. Další mise a interakce přijdou v další verzi.")

func _add_building_facade(x: float, z: float, height: float, side: float, index: int) -> void:
	var street_face_x := x - side * 8.56
	var window_material := _material(Color(0.08, 0.15, 0.20), 0.28)
	var lit_window := _material(Color(0.52, 0.43, 0.26), 0.35)
	var trim := _material(Color(0.18, 0.19, 0.19))
	for floor_index in range(1, int(height / 2.8)):
		for column in range(3):
			var window_z := z - 4.4 + float(column) * 4.4
			var window_y := 1.8 + float(floor_index) * 2.65
			var window_mat := lit_window if (floor_index + column + index) % 4 == 0 else window_material
			_add_box("Window", Vector3(street_face_x, window_y, window_z), Vector3(0.08, 1.25, 1.75), window_mat, false)
			_add_box("WindowSill", Vector3(street_face_x - side * 0.05, window_y - 0.69, window_z), Vector3(0.14, 0.10, 1.95), trim, false)
	# A lit storefront/entrance at ground level.
	_add_box("EntryDoor", Vector3(street_face_x, 1.15, z + 4.7), Vector3(0.09, 2.3, 1.25), _material(Color(0.07, 0.10, 0.12), 0.25), false)
	_add_box("ShopSign", Vector3(street_face_x - side * 0.08, 3.0, z), Vector3(0.16, 0.65, 5.2), _material(Color(0.52, 0.24, 0.10)), false)

func _add_lamp(x: float, z: float) -> void:
	_add_cylinder("LampPole", Vector3(x, 2.8, z), 0.09, 5.4, _material(Color(0.12, 0.14, 0.16), 0.55))
	_add_box("LampArm", Vector3(x - signf(x) * 0.48, 5.35, z), Vector3(0.95, 0.10, 0.12), _material(Color(0.12, 0.14, 0.16)), false)
	_add_box("LampHead", Vector3(x - signf(x) * 0.9, 5.18, z), Vector3(0.42, 0.16, 0.34), _material(Color(0.86, 0.73, 0.47), 0.35), false)

func _add_tree(x: float, z: float) -> void:
	_add_cylinder("TreeTrunk", Vector3(x, 1.1, z), 0.25, 2.2, _material(Color(0.26, 0.17, 0.11)))
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.25
	crown_mesh.height = 2.5
	crown.mesh = crown_mesh
	crown.position = Vector3(x, 2.7, z)
	crown.material_override = _material(Color(0.13, 0.25, 0.17))
	add_child(crown)

func _add_bin(position: Vector3) -> void:
	_add_box("StreetBin", position + Vector3(0, 0.55, 0), Vector3(0.75, 1.1, 0.75), _material(Color(0.14, 0.20, 0.19)), true)

func _add_bench(position: Vector3) -> void:
	var wood := _material(Color(0.35, 0.22, 0.12))
	_add_box("BenchSeat", position + Vector3(0, 0.55, 0), Vector3(1.9, 0.14, 0.65), wood, true)
	_add_box("BenchBack", position + Vector3(0, 1.0, -0.25), Vector3(1.9, 0.75, 0.12), wood, true)

func _add_interaction_point(position: Vector3, message: String) -> void:
	var area := Area3D.new()
	area.name = "ShopInteraction"
	area.position = position + Vector3(0, 1.0, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 2.2, 3.0)
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_interaction_entered.bind(message))
	area.body_exited.connect(_on_interaction_exited)
	add_child(area)

func _on_interaction_entered(body: Node3D, message: String) -> void:
	if body.is_in_group("player"):
		interaction_available = true
		interaction_message = message
		_show_message("E  INTERAKCE")

func _on_interaction_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		interaction_available = false
		interaction_message = ""
		if is_instance_valid(message_label):
			message_label.text = ""

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.position = Vector3(0.0, 0.05, 22.0)
	add_child(player)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "GameplayHUD"
	canvas.layer = 10
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var title := Label.new()
	title.text = "URBAN DISTRICT  /  FREE ROAM"
	title.position = Vector2(26, 22)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.91, 0.91, 0.84))
	root.add_child(title)

	speed_label = Label.new()
	speed_label.text = "000 km/h"
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.anchor_left = 1.0
	speed_label.anchor_right = 1.0
	speed_label.offset_left = -190
	speed_label.offset_right = -26
	speed_label.offset_top = 22
	speed_label.offset_bottom = 54
	speed_label.add_theme_font_size_override("font_size", 18)
	speed_label.add_theme_color_override("font_color", Color(0.93, 0.79, 0.46))
	root.add_child(speed_label)

	var controls := Label.new()
	controls.text = "WASD  POHYB     SHIFT  BĚH     SPACE  SKOK     E  INTERAKCE     ESC  PAUZA"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.anchor_left = 0.0
	controls.anchor_right = 1.0
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_left = 12
	controls.offset_top = -48
	controls.offset_right = -12
	controls.offset_bottom = -14
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color(0.9, 0.9, 0.87))
	root.add_child(controls)

	message_label = Label.new()
	message_label.position = Vector2(0, 74)
	message_label.anchor_left = 0.25
	message_label.anchor_right = 0.75
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.48))
	root.add_child(message_label)

func _build_pause_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "PauseLayer"
	canvas.layer = 20
	add_child(canvas)
	var pause_menu := Control.new()
	pause_menu.set_script(load("res://scripts/pause_menu.gd"))
	canvas.add_child(pause_menu)

func _show_message(text: String) -> void:
	if is_instance_valid(message_label):
		message_label.text = text
		message_timer = 3.5


func _add_cylinder(node_name: String, position: Vector3, radius: float, height: float, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.78
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _material(color: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _add_box(
	box_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	with_collision: bool
) -> void:
	if with_collision:
		var body := StaticBody3D.new()
		body.name = box_name
		body.position = position
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		body.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	else:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = box_name
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.position = position
		mesh_instance.material_override = material
		add_child(mesh_instance)
