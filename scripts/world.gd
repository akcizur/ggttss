extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const VIRTUAL_JOYSTICK_SCRIPT: Script = preload("res://scripts/virtual_joystick.gd")
const NPC_ACTOR_SCRIPT: Script = preload("res://scripts/npc_actor.gd")
const DOOR_CONTROLLER_SCRIPT: Script = preload("res://scripts/door_controller.gd")
const SAVE_PATH: String = "user://urban_rpg_save.cfg"

var player: CharacterBody3D
var speed_label: Label
var money_label: Label
var message_label: Label
var nearby_interactables: Array[Area3D] = []
var current_interactable: Area3D
var message_timer: float = 0.0
var money: int = 500
var quest_started: bool = false
var quest_package_carried: bool = false
var quest_completed: bool = false
var quest_stage: int = 0
var npc_nodes: Dictionary = {}
var package_node: Node3D
var prompt_label: Label
var mission_label: Label
var inventory_items: Dictionary = {}
var inventory_open: bool = false
var inventory_panel: PanelContainer
var inventory_content: Label
var dialogue_open: bool = false
var dialogue_overlay: ColorRect
var dialogue_title: Label
var dialogue_body: Label
var dialogue_next_button: Button
var dialogue_lines: PackedStringArray = PackedStringArray()
var dialogue_index: int = 0
var dialogue_completion_action: String = ""
var talking_npc: Node3D
var package_area: Area3D
var autosave_elapsed: float = 0.0

func _ready() -> void:
	add_to_group("game_world")
	_build_environment()
	_build_city_block()
	_spawn_player()
	_build_hud()
	_build_pause_menu()
	_load_game()
	_refresh_inventory_ui()

func _process(delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(speed_label):
		speed_label.text = "%03d km/h" % int(round(float(player.call("get_horizontal_speed")) * 3.6))
	if is_instance_valid(money_label):
		money_label.text = "$ %d" % money
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0 and is_instance_valid(message_label):
			message_label.text = ""
	_refresh_interactable_target()
	autosave_elapsed += delta
	if autosave_elapsed >= 30.0:
		autosave_elapsed = 0.0
		save_game(false)

func _unhandled_input(event: InputEvent) -> void:
	if dialogue_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
			_advance_dialogue()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			_close_dialogue()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if inventory_open:
		if event.is_action_pressed("pause"):
			_toggle_inventory()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and not get_tree().paused:
		request_interaction()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game(false)

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
		_add_box("Sidewalk", Vector3(side * 9.0, 0.055, 0), Vector3(4.0, 0.08, 112), concrete, true)
		# Curbs are visible blockout trim, not tall collision walls that trap the player.
		_add_box("Curb", Vector3(side * 7.05, 0.10, 0), Vector3(0.22, 0.16, 112), curb_material, false)

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
	_add_npc(Vector3(-10.8, 0.0, 13.0))
	_add_package_pickup(Vector3(10.9, 0.24, 10.0))
	var street_door := _create_swing_door("StreetShopDoor", Vector3(12.44, 0.0, 3.7), 1.25, 2.3, Color(0.07, 0.10, 0.12), PI * 0.5)
	var enter_area := _add_interactable_area(Vector3(10.9, 1.0, 3.7), 1.8, "door_enter", "E  OTEVŘÍT A VSTOUPIT", "Vstupuješ do obchodu.", Vector3(42.0, 0.08, 28.0))
	enter_area.set_meta("door_node", street_door)
	_build_shop_interior()

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
	if not (side > 0.0 and index == 2):
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

func _add_interactable_area(
	world_position: Vector3,
	radius: float,
	action: String,
	prompt: String,
	message: String = "",
	destination: Vector3 = Vector3.ZERO
) -> Area3D:
	var area := Area3D.new()
	area.name = "Interactable_%s" % action
	area.position = world_position
	area.set_meta("interaction_type", action)
	area.set_meta("prompt", prompt)
	area.set_meta("message", message)
	area.set_meta("destination", destination)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_interactable_entered.bind(area))
	area.body_exited.connect(_on_interactable_exited.bind(area))
	add_child(area)
	return area

func _on_interactable_entered(body: Node3D, area: Area3D) -> void:
	if body.is_in_group("player") and not nearby_interactables.has(area):
		nearby_interactables.append(area)
		_refresh_interactable_target()

func _on_interactable_exited(body: Node3D, area: Area3D) -> void:
	if body.is_in_group("player"):
		nearby_interactables.erase(area)
		_refresh_interactable_target()

func _refresh_interactable_target() -> void:
	var best: Area3D
	var best_distance := INF
	for area in nearby_interactables:
		if not is_instance_valid(area) or not area.monitoring:
			continue
		var distance := player.global_position.distance_squared_to(area.global_position) if is_instance_valid(player) else INF
		if distance < best_distance:
			best_distance = distance
			best = area
	current_interactable = best
	if is_instance_valid(prompt_label):
		prompt_label.text = str(best.get_meta("prompt", "E  INTERAKCE")) if is_instance_valid(best) else ""

func _add_npc(position: Vector3, npc_id: String = "resident") -> void:
	var npc := Node3D.new()
	npc.set_script(NPC_ACTOR_SCRIPT)
	npc.name = "NPC_%s" % npc_id.capitalize()
	npc.position = position
	npc.set_meta("npc_id", npc_id)
	npc.set_meta("talk_count", 0)
	npc.set_meta("mood", "neutral")
	# Use the supplied rigged Mixamo character for citizens as well as the player.
	# Each instance owns its own AnimationPlayer and can play idle/walking independently.
	var rig_scene := load("res://assets/models/mixamo_base.glb") as PackedScene
	if rig_scene != null:
		var rig := rig_scene.instantiate() as Node3D
		rig.name = "CitizenRig"
		npc.add_child(rig)
	else:
		# Safe visible fallback if the model import is temporarily unavailable.
		var jacket := _material(Color(0.16, 0.31, 0.43))
		var trousers := _material(Color(0.10, 0.13, 0.17))
		var skin := _material(Color(0.72, 0.52, 0.38))
		_add_npc_capsule(npc, "Body", Vector3(0.0, 1.05, 0.0), 0.34, 0.95, jacket)
		_add_npc_sphere(npc, "Head", Vector3(0.0, 1.82, 0.0), 0.23, skin)
		_add_npc_capsule(npc, "LeftLeg", Vector3(-0.14, 0.43, 0.0), 0.12, 0.72, trousers)
		_add_npc_capsule(npc, "RightLeg", Vector3(0.14, 0.43, 0.0), 0.12, 0.72, trousers)
		_add_npc_capsule(npc, "LeftArm", Vector3(-0.42, 1.13, 0.0), 0.10, 0.62, jacket)
		_add_npc_capsule(npc, "RightArm", Vector3(0.42, 1.13, 0.0), 0.10, 0.62, jacket)
	var npc_body := StaticBody3D.new()
	npc_body.name = "NpcCollision"
	var npc_collision := CollisionShape3D.new()
	var npc_shape := CapsuleShape3D.new()
	npc_shape.radius = 0.34
	npc_shape.height = 1.9
	npc_collision.shape = npc_shape
	npc_collision.position = Vector3(0.0, 0.95, 0.0)
	npc_body.add_child(npc_collision)
	npc.add_child(npc_body)
	add_child(npc)
	npc_nodes[npc_id] = npc
	var display_name := "MÍSTNÍ OBYVATEL" if npc_id == "resident" else "PRODAVAČ"
	var prompt := "E  PROMLOUVIT SI" if npc_id == "resident" else "E  OSLOVIT PRODAVAČE"
	var interaction := _add_interactable_area(position + Vector3(0.0, 1.0, 0.0), 2.25, "npc", prompt, "")
	interaction.set_meta("npc_id", npc_id)
	interaction.set_meta("npc_name", display_name)
	interaction.set_meta("npc_node", npc)
	npc.add_to_group("npc")

func _add_npc_capsule(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

func _add_npc_sphere(parent: Node3D, node_name: String, local_position: Vector3, radius: float, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

func _add_package_pickup(position: Vector3) -> void:
	package_node = Node3D.new()
	package_node.name = "DeliveryPackage"
	package_node.position = position
	add_child(package_node)
	_add_box_child(package_node, "Parcel", Vector3.ZERO, Vector3(0.58, 0.48, 0.48), _material(Color(0.58, 0.36, 0.17)))
	_add_box_child(package_node, "Ribbon", Vector3(0.0, 0.245, 0.0), Vector3(0.60, 0.045, 0.10), _material(Color(0.82, 0.69, 0.42)))
	package_area = _add_interactable_area(position, 1.55, "pickup", "E  SEBRAT BALÍČEK", "")
	package_area.set_meta("pickup_node", package_node)
	var pickup := package_area
	pickup.set_meta("pickup_active", true)

func _build_shop_interior() -> void:
	var floor_material := _material(Color(0.34, 0.32, 0.28))
	var wall_material := _material(Color(0.60, 0.57, 0.50))
	_add_box("ShopInteriorFloor", Vector3(42.0, -0.08, 32.0), Vector3(16.0, 0.16, 18.0), floor_material, true)
	_add_box("ShopBackWall", Vector3(42.0, 2.0, 23.0), Vector3(16.0, 4.0, 0.25), wall_material, true)
	_add_box("ShopLeftWall", Vector3(34.0, 2.0, 32.0), Vector3(0.25, 4.0, 18.0), wall_material, true)
	_add_box("ShopRightWall", Vector3(50.0, 2.0, 32.0), Vector3(0.25, 4.0, 18.0), wall_material, true)
	_add_box("ShopFrontWallLeft", Vector3(37.0, 2.0, 41.0), Vector3(6.0, 4.0, 0.25), wall_material, true)
	_add_box("ShopFrontWallRight", Vector3(47.0, 2.0, 41.0), Vector3(6.0, 4.0, 0.25), wall_material, true)
	_add_box("ShopCounter", Vector3(42.0, 0.65, 25.5), Vector3(5.0, 1.3, 1.0), _material(Color(0.25, 0.18, 0.12)), true)
	_add_interactable_area(Vector3(42.0, 1.0, 26.5), 2.0, "quest_deliver", "E  PŘEDAT BALÍČEK", "")
	_add_npc(Vector3(46.0, 0.0, 31.5), "shopkeeper")
	var interior_door := _create_swing_door("ShopInteriorDoor", Vector3(41.0, 0.0, 41.0), 2.0, 2.3, Color(0.14, 0.12, 0.10), 0.0)
	var exit_area := _add_interactable_area(Vector3(42.0, 1.0, 39.5), 2.1, "door_exit", "E  OTEVŘÍT A ODEJÍT", "Opouštíš obchod.", Vector3(10.9, 0.08, 5.2))
	exit_area.set_meta("door_node", interior_door)

func _create_swing_door(door_name: String, world_position: Vector3, width: float, height: float, color: Color, closed_yaw: float) -> Node3D:
	var hinge := Node3D.new()
	hinge.name = door_name
	hinge.position = world_position
	hinge.rotation.y = closed_yaw
	hinge.set_script(DOOR_CONTROLLER_SCRIPT)
	add_child(hinge)
	var body := AnimatableBody3D.new()
	body.name = "DoorBody"
	body.sync_to_physics = true
	body.position = Vector3(width * 0.5, height * 0.5, 0.0)
	hinge.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, 0.12)
	mesh_instance.mesh = mesh
	var door_material := _material(color, 0.42)
	mesh_instance.material_override = door_material
	body.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.12)
	collider.shape = shape
	body.add_child(collider)
	var handle := MeshInstance3D.new()
	var handle_mesh := SphereMesh.new()
	handle_mesh.radius = 0.055
	handle_mesh.height = 0.11
	handle.mesh = handle_mesh
	handle.position = Vector3(width * 0.82 - width * 0.5, 0.0, -0.085)
	handle.material_override = _material(Color(0.78, 0.59, 0.27), 0.24)
	body.add_child(handle)
	return hinge

func _add_box_child(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

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

	money_label = Label.new()
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.anchor_left = 1.0
	money_label.anchor_right = 1.0
	money_label.offset_left = -190
	money_label.offset_right = -26
	money_label.offset_top = 54
	money_label.offset_bottom = 82
	money_label.add_theme_font_size_override("font_size", 17)
	money_label.add_theme_color_override("font_color", Color(0.70, 0.86, 0.67))
	root.add_child(money_label)

	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		_build_touch_controls(root)
	else:
		var controls := Label.new()
		controls.text = "WASD  POHYB     SHIFT  BĚH     SPACE  SKOK     E  INTERAKCE     I  INVENTÁŘ     ESC  PAUZA"
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

	prompt_label = Label.new()
	prompt_label.position = Vector2(0, 112)
	prompt_label.anchor_left = 0.25
	prompt_label.anchor_right = 0.75
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.62))
	root.add_child(prompt_label)

	mission_label = Label.new()
	mission_label.position = Vector2(26, 54)
	mission_label.add_theme_font_size_override("font_size", 15)
	mission_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.80))
	mission_label.text = "VOLNÁ HRA  /  PROMLOUV SI S MÍSTNÍM"
	root.add_child(mission_label)
	_build_dialogue_ui(root)
	_build_inventory_ui(root)

func _build_touch_controls(root: Control) -> void:
	var move_stick := VIRTUAL_JOYSTICK_SCRIPT.new() as Control
	move_stick.name = "MoveJoystick"
	move_stick.anchor_left = 0.0
	move_stick.anchor_top = 1.0
	move_stick.anchor_right = 0.0
	move_stick.anchor_bottom = 1.0
	move_stick.offset_left = 24.0
	move_stick.offset_top = -184.0
	move_stick.offset_right = 180.0
	move_stick.offset_bottom = -28.0
	root.add_child(move_stick)
	move_stick.connect("value_changed", func(value: Vector2) -> void:
		if is_instance_valid(player):
			player.call("set_touch_move", value)
	)

	var look_stick := VIRTUAL_JOYSTICK_SCRIPT.new() as Control
	look_stick.name = "CameraJoystick"
	look_stick.anchor_left = 1.0
	look_stick.anchor_top = 1.0
	look_stick.anchor_right = 1.0
	look_stick.anchor_bottom = 1.0
	look_stick.offset_left = -180.0
	look_stick.offset_top = -184.0
	look_stick.offset_right = -24.0
	look_stick.offset_bottom = -28.0
	look_stick.set("knob_color", Color(0.48, 0.72, 0.92, 0.9))
	root.add_child(look_stick)
	look_stick.connect("value_changed", func(value: Vector2) -> void:
		if is_instance_valid(player):
			player.call("set_touch_look", value)
	)

	var jump_button := _make_touch_button(root, "JUMP", -164.0, -252.0, -24.0, -194.0)
	jump_button.pressed.connect(func() -> void:
		if is_instance_valid(player):
			player.call("request_jump")
	)
	var run_button := _make_touch_button(root, "RUN", -320.0, -252.0, -180.0, -194.0)
	run_button.button_down.connect(func() -> void:
		if is_instance_valid(player):
			player.call("set_touch_run", true)
	)
	run_button.button_up.connect(func() -> void:
		if is_instance_valid(player):
			player.call("set_touch_run", false)
	)
	var use_button := _make_touch_button(root, "USE", -320.0, -316.0, -180.0, -258.0)
	use_button.pressed.connect(func() -> void:
		request_interaction()
	)
	var pause_button := _make_touch_button(root, "PAUSE", -118.0, 18.0, -24.0, 66.0)
	pause_button.anchor_top = 0.0
	pause_button.anchor_bottom = 0.0
	pause_button.pressed.connect(func() -> void:
		get_tree().call_group("game_ui", "toggle_pause")
	)

func _make_touch_button(root: Control, caption: String, left: float, top: float, right: float, bottom: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.anchor_left = 1.0
	button.anchor_top = 1.0
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = left
	button.offset_top = top
	button.offset_right = right
	button.offset_bottom = bottom
	button.add_theme_font_size_override("font_size", 17)
	button.focus_mode = Control.FOCUS_NONE
	root.add_child(button)
	return button

func request_interaction() -> void:
	if not is_instance_valid(current_interactable) or get_tree().paused or dialogue_open or inventory_open:
		return
	var area := current_interactable
	var action := str(area.get_meta("interaction_type", "message"))
	match action:
		"door_enter", "door_exit":
			await _use_door(area)
		"npc":
			_interact_with_npc(area)
		"pickup":
			_collect_package(area)
		"quest_deliver":
			_deliver_package()
		_:
			_show_message(str(area.get_meta("message", "Nemáš co použít.")))

func _use_door(area: Area3D) -> void:
	var door := area.get_meta("door_node") as Node3D
	if not is_instance_valid(door) or not is_instance_valid(player):
		return
	if bool(door.get("is_animating")):
		return
	door.call("set_open", true)
	await get_tree().create_timer(0.42).timeout
	if not is_instance_valid(player):
		return
	var destination: Vector3 = area.get_meta("destination", Vector3.ZERO)
	if destination != Vector3.ZERO:
		player.velocity = Vector3.ZERO
		player.global_position = destination
		_show_message(str(area.get_meta("message", "")))
	await get_tree().create_timer(1.25).timeout
	if is_instance_valid(door):
		door.call("set_open", false)

func _interact_with_npc(area: Area3D) -> void:
	var npc_id := str(area.get_meta("npc_id", "resident"))
	var npc := area.get_meta("npc_node") as Node3D
	if is_instance_valid(npc):
		talking_npc = npc
		npc.set_meta("talk_count", int(npc.get_meta("talk_count", 0)) + 1)
		npc.set_meta("mood", "talking")
		if npc.has_method("set_talking"):
			npc.call("set_talking", true)
	if npc_id == "shopkeeper":
		if quest_stage == 2 and quest_package_carried:
			_open_dialogue("PRODAVAČ", PackedStringArray([
				"To je zásilka, na kterou čekáme.",
				"Všechno sedí. Tady máš potvrzení o převzetí. Vrať ho člověku, který tě poslal."
			]), "clerk_issue_receipt")
		elif quest_stage >= 3:
			_open_dialogue("PRODAVAČ", PackedStringArray(["Potvrzení už máš. Vrať se s ním za místním obyvatelem."]))
		else:
			_open_dialogue("PRODAVAČ", PackedStringArray(["Dobrý den. Vítejte v obchodě."]))
		return
	match quest_stage:
		0:
			_open_dialogue("MÍSTNÍ OBYVATEL", PackedStringArray([
				"Ahoj. V téhle čtvrti je poslední dobou docela rušno.",
				"Pomůžeš mi? Ztratil se mi balíček. Najdi ho na chodníku a dones ho do obchodu.",
				"Prodavač ti dá potvrzení. Pak se vrať za mnou."
			]), "start_delivery_quest")
		1:
			_open_dialogue("MÍSTNÍ OBYVATEL", PackedStringArray(["Balíček je na chodníku poblíž obchodu. Až ho najdeš, promluv si s prodavačem."]))
		2:
			_open_dialogue("MÍSTNÍ OBYVATEL", PackedStringArray(["Balíček už máš. V obchodě ho ukaž prodavači a vezmi si potvrzení."]))
		3:
			_open_dialogue("MÍSTNÍ OBYVATEL", PackedStringArray(["Prodavač ti vystavil potvrzení. Vrať se za mnou, prosím."]))
		4:
			_open_dialogue("MÍSTNÍ OBYVATEL", PackedStringArray([
				"Výborně, balíček i potvrzení dorazily. Moc jsi mi pomohl.",
				"Tady je odměna za tvůj čas. Díky!"
			]), "finish_delivery_quest")
		_:
			_open_dialogue("MÍSTNÍ OBYVATEL", PackedStringArray(["Díky ještě jednou za pomoc. Měj se!"]))

func _build_dialogue_ui(root: Control) -> void:
	dialogue_overlay = ColorRect.new()
	dialogue_overlay.name = "DialogueOverlay"
	dialogue_overlay.color = Color(0.015, 0.022, 0.03, 0.76)
	dialogue_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_overlay.visible = false
	dialogue_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dialogue_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-340.0, -175.0)
	panel.size = Vector2(680.0, 350.0)
	panel.custom_minimum_size = Vector2(680.0, 350.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.09, 0.98)
	style.border_color = Color(0.68, 0.53, 0.29, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	dialogue_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	dialogue_title = Label.new()
	dialogue_title.add_theme_font_size_override("font_size", 24)
	dialogue_title.add_theme_color_override("font_color", Color(0.94, 0.77, 0.43))
	column.add_child(dialogue_title)
	dialogue_body = Label.new()
	dialogue_body.custom_minimum_size = Vector2(0.0, 170.0)
	dialogue_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_body.add_theme_font_size_override("font_size", 19)
	dialogue_body.add_theme_color_override("font_color", Color(0.91, 0.92, 0.88))
	column.add_child(dialogue_body)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var close_button := Button.new()
	close_button.text = "ZAVŘÍT"
	close_button.custom_minimum_size = Vector2(130.0, 48.0)
	close_button.pressed.connect(func() -> void:
		_close_dialogue())
	buttons.add_child(close_button)
	dialogue_next_button = Button.new()
	dialogue_next_button.text = "DALŠÍ  ›"
	dialogue_next_button.custom_minimum_size = Vector2(150.0, 48.0)
	dialogue_next_button.pressed.connect(_advance_dialogue)
	buttons.add_child(dialogue_next_button)

func _open_dialogue(title: String, lines: PackedStringArray, completion_action: String = "") -> void:
	if lines.is_empty():
		return
	dialogue_lines = lines
	dialogue_index = 0
	dialogue_completion_action = completion_action
	dialogue_title.text = title
	dialogue_open = true
	dialogue_overlay.visible = true
	if is_instance_valid(player):
		player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_dialogue_line()

func _show_dialogue_line() -> void:
	dialogue_body.text = dialogue_lines[dialogue_index]
	dialogue_next_button.text = "DOKONČIT" if dialogue_index >= dialogue_lines.size() - 1 else "DALŠÍ  ›"

func _advance_dialogue() -> void:
	if not dialogue_open:
		return
	if dialogue_index < dialogue_lines.size() - 1:
		dialogue_index += 1
		_show_dialogue_line()
	else:
		_close_dialogue(true)

func _close_dialogue(completed: bool = false) -> void:
	if not dialogue_open:
		return
	dialogue_open = false
	dialogue_overlay.visible = false
	if is_instance_valid(talking_npc):
		talking_npc.set_meta("mood", "neutral")
		if talking_npc.has_method("set_talking"):
			talking_npc.call("set_talking", false)
	talking_npc = null
	if is_instance_valid(player):
		player.set_physics_process(true)
		if not OS.has_feature("mobile") and not DisplayServer.is_touchscreen_available():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if completed:
		match dialogue_completion_action:
			"start_delivery_quest":
				quest_started = true
				quest_stage = 1
				mission_label.text = "ÚKOL 1/4  /  NAJDI BALÍČEK NA CHODNÍKU"
				_show_message("Nový úkol: 1/4 — najdi balíček")
			"clerk_issue_receipt":
				quest_stage = 3
				inventory_items["shop_receipt"] = 1
				mission_label.text = "ÚKOL 3/4  /  PŘEDEJ BALÍČEK U PULTU"
				_show_message("Získal jsi potvrzení od prodavače.")
			"finish_delivery_quest":
				quest_stage = 5
				quest_completed = true
				inventory_items.erase("shop_receipt")
				money += 150
				mission_label.text = "ÚKOL SPLNĚN  /  ODMĚNA: 150 $"
				_show_message("Úkol dokončen! Získáváš 150 $.")
			_refresh_inventory_ui()
	dialogue_completion_action = ""
	# Persist NPC talk counters/mood even when the player closes dialogue early.
	save_game(false)

func _build_inventory_ui(root: Control) -> void:
	var shade := ColorRect.new()
	shade.name = "InventoryOverlay"
	shade.color = Color(0.01, 0.02, 0.03, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	inventory_panel = PanelContainer.new()
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.position = Vector2(-250.0, -210.0)
	inventory_panel.size = Vector2(500.0, 420.0)
	inventory_panel.custom_minimum_size = Vector2(500.0, 420.0)
	shade.add_child(inventory_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.add_theme_constant_override("margin_left", 20)
	column.add_theme_constant_override("margin_right", 20)
	inventory_panel.add_child(column)
	var title := Label.new()
	title.text = "INVENTÁŘ"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.94, 0.77, 0.43))
	column.add_child(title)
	inventory_content = Label.new()
	inventory_content.custom_minimum_size = Vector2(0.0, 250.0)
	inventory_content.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	inventory_content.add_theme_font_size_override("font_size", 18)
	column.add_child(inventory_content)
	var close_button := Button.new()
	close_button.text = "ZAVŘÍT  (I / ESC)"
	close_button.custom_minimum_size = Vector2(0.0, 46.0)
	close_button.pressed.connect(_toggle_inventory)
	column.add_child(close_button)
	# The shade is stored on the panel as metadata so it can be toggled cheaply.
	inventory_panel.set_meta("overlay", shade)
	_refresh_inventory_ui()

func _toggle_inventory() -> void:
	if dialogue_open:
		return
	inventory_open = not inventory_open
	var shade := inventory_panel.get_meta("overlay") as ColorRect
	shade.visible = inventory_open
	if is_instance_valid(player):
		player.set_physics_process(not inventory_open)
	if inventory_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not OS.has_feature("mobile") and not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_inventory_ui()

func _refresh_inventory_ui() -> void:
	if not is_instance_valid(inventory_content):
		return
	var parcel_count := int(inventory_items.get("parcel", 0))
	var receipt_count := int(inventory_items.get("shop_receipt", 0))
	var key_count := int(inventory_items.get("shop_key", 0))
	var lines := PackedStringArray([
		"💵  PENĚŽENKA     $ %d" % money,
		"",
		"🎒  PŘEDMĚTY",
		"📦  Balíček                 x %d" % parcel_count,
		"🧾  Potvrzení obchodu      x %d" % receipt_count,
		"🔑  Klíč od obchodu        x %d" % key_count
	])
	if parcel_count == 0 and receipt_count == 0 and key_count == 0:
		lines.append("")
		lines.append("Inventář je prázdný.")
	inventory_content.text = "\n".join(lines)

func _collect_package(area: Area3D) -> void:
	if quest_stage < 1:
		_show_message("Nejdřív si promluv s místním obyvatelem.")
		return
	if quest_stage != 1:
		_show_message("Teď není čas sbírat další balíček.")
		return
	if quest_package_carried:
		_show_message("Už jeden balíček neseš.")
		return
	if not bool(area.get_meta("pickup_active", true)):
		return
	quest_package_carried = true
	quest_stage = 2
	inventory_items["parcel"] = 1
	area.set_meta("pickup_active", false)
	area.monitoring = false
	if is_instance_valid(package_node):
		package_node.visible = false
	nearby_interactables.erase(area)
	_refresh_interactable_target()
	mission_label.text = "ÚKOL 2/4  /  UKAŽ BALÍČEK PRODAVAČI"
	_refresh_inventory_ui()
	_show_message("Balíček sebral. Zanes ho prodavači v obchodě.")
	save_game(false)

func _deliver_package() -> void:
	if quest_completed:
		_show_message("Balíček už byl doručen.")
	elif not quest_package_carried:
		_show_message("Nemáš u sebe balíček.")
	elif quest_stage != 3:
		_show_message("Nejdřív ukaž balíček prodavači a vyzvedni potvrzení.")
	else:
		quest_package_carried = false
		inventory_items.erase("parcel")
		quest_stage = 4
		mission_label.text = "ÚKOL 4/4  /  VRAŤ SE ZA MÍSTNÍM OBYVATELEM"
		_show_message("Balíček předán. Vrať se za člověkem, který tě poslal.")
		_refresh_inventory_ui()
		save_game(false)

func save_game(show_feedback: bool = true) -> void:
	var config := ConfigFile.new()
	var saved_position := Vector3(0.0, 0.05, 22.0)
	var visual_yaw := 0.0
	var camera_yaw := 0.0
	if is_instance_valid(player):
		saved_position = player.global_position
		var player_visuals := player.get_node_or_null("visuals") as Node3D
		if is_instance_valid(player_visuals):
			visual_yaw = player_visuals.rotation.y
		camera_yaw = float(player.get("camera_yaw"))
	config.set_value("player", "position", saved_position)
	config.set_value("player", "visual_yaw", visual_yaw)
	config.set_value("player", "camera_yaw", camera_yaw)
	config.set_value("progress", "money", money)
	config.set_value("progress", "quest_started", quest_started)
	config.set_value("progress", "quest_package_carried", quest_package_carried)
	config.set_value("progress", "quest_completed", quest_completed)
	config.set_value("progress", "quest_stage", quest_stage)
	config.set_value("inventory", "items", inventory_items)
	for npc_id in npc_nodes.keys():
		var npc := npc_nodes[npc_id] as Node3D
		if is_instance_valid(npc):
			config.set_value("npcs", str(npc_id) + "_position", npc.global_position)
			config.set_value("npcs", str(npc_id) + "_rotation", npc.global_rotation.y)
			config.set_value("npcs", str(npc_id) + "_talk_count", int(npc.get_meta("talk_count", 0)))
			config.set_value("npcs", str(npc_id) + "_mood", str(npc.get_meta("mood", "neutral")))
	var error := config.save(SAVE_PATH)
	if show_feedback:
		_show_message("Hra uložena." if error == OK else "Uložení se nezdařilo.")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		_show_message("Uloženou hru se nepodařilo načíst.")
		return
	money = int(config.get_value("progress", "money", money))
	quest_started = bool(config.get_value("progress", "quest_started", false))
	quest_package_carried = bool(config.get_value("progress", "quest_package_carried", false))
	quest_completed = bool(config.get_value("progress", "quest_completed", false))
	quest_stage = int(config.get_value("progress", "quest_stage", 5 if quest_completed else (2 if quest_package_carried else (1 if quest_started else 0))))
	var saved_items: Variant = config.get_value("inventory", "items", {})
	if saved_items is Dictionary:
		inventory_items = saved_items
	else:
		inventory_items.clear()
	if quest_package_carried and int(inventory_items.get("parcel", 0)) == 0:
		inventory_items["parcel"] = 1
	for npc_id in npc_nodes.keys():
		var npc := npc_nodes[npc_id] as Node3D
		if is_instance_valid(npc):
			var saved_npc_position: Variant = config.get_value("npcs", str(npc_id) + "_position", npc.global_position)
			if saved_npc_position is Vector3:
				npc.global_position = saved_npc_position
			npc.global_rotation.y = float(config.get_value("npcs", str(npc_id) + "_rotation", npc.global_rotation.y))
			npc.set_meta("talk_count", int(config.get_value("npcs", str(npc_id) + "_talk_count", 0)))
			var saved_mood := str(config.get_value("npcs", str(npc_id) + "_mood", "neutral"))
			npc.set_meta("mood", saved_mood)
			if npc.has_method("set_mood"):
				npc.call("set_mood", saved_mood)
	if is_instance_valid(player):
		var saved_position: Variant = config.get_value("player", "position", player.global_position)
		if saved_position is Vector3:
			player.global_position = saved_position
			player.velocity = Vector3.ZERO
		var visuals := player.get_node_or_null("visuals") as Node3D
		if is_instance_valid(visuals):
			visuals.rotation.y = float(config.get_value("player", "visual_yaw", visuals.rotation.y))
		player.set("camera_yaw", float(config.get_value("player", "camera_yaw", 0.0)))
		player.call("_update_camera_rotation")
	var package_available := quest_stage <= 1
	if is_instance_valid(package_node):
		package_node.visible = package_available
	if is_instance_valid(package_area):
		package_area.monitoring = package_available
	match quest_stage:
		0:
			mission_label.text = "VOLNÁ HRA  /  PROMLOUV SI S MÍSTNÍM"
		1:
			mission_label.text = "ÚKOL 1/4  /  NAJDI BALÍČEK NA CHODNÍKU"
		2:
			mission_label.text = "ÚKOL 2/4  /  UKAŽ BALÍČEK PRODAVAČI"
		3:
			mission_label.text = "ÚKOL 3/4  /  PŘEDEJ BALÍČEK U PULTU"
		4:
			mission_label.text = "ÚKOL 4/4  /  VRAŤ SE ZA MÍSTNÍM"
		_:
			mission_label.text = "ÚKOL SPLNĚN  /  ODMĚNA: 150 $"
	_refresh_inventory_ui()

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
