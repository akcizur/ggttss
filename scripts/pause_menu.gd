extends Control

var overlay: Control
var panel: PanelContainer
var status_label: Label
var is_open: bool = false

func _ready() -> void:
	add_to_group("game_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_menu()

func _build_menu() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_shade_input)
	overlay.add_child(shade)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 450)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -225)
	panel.size = Vector2(380, 450)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	status_label = Label.new()
	status_label.text = "URBAN DISTRICT"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.82))
	column.add_child(status_label)

	var resume_button := _make_button("POKRAČOVAT")
	resume_button.pressed.connect(resume_game)
	column.add_child(resume_button)

	var save_button := _make_button("ULOŽIT HRU")
	save_button.pressed.connect(func() -> void:
		get_tree().call_group("game_world", "save_game")
		status_label.text = "HRA ULOŽENA"
	)
	column.add_child(save_button)

	var load_button := _make_button("NAČÍST HRU")
	load_button.pressed.connect(func() -> void:
		get_tree().call_group("game_world", "load_game")
		status_label.text = "HRA NAČTENA"
		resume_game()
	)
	column.add_child(load_button)

	var restart_button := _make_button("RESTART POZICE")
	restart_button.pressed.connect(restart_game)
	column.add_child(restart_button)

	var quit_button := _make_button("UKONČIT HRU")
	quit_button.pressed.connect(quit_game)
	column.add_child(quit_button)

func _on_shade_input(event: InputEvent) -> void:
	# Clicking the dimmed area outside the modal closes it.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		resume_game()

func _make_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 46)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if is_open:
		resume_game()
	else:
		open_pause()

func open_pause() -> void:
	is_open = true
	overlay.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _restore_pointer_mode() -> void:
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func resume_game() -> void:
	is_open = false
	overlay.visible = false
	get_tree().paused = false
	_restore_pointer_mode()

func restart_game() -> void:
	get_tree().paused = false
	_restore_pointer_mode()
	get_tree().reload_current_scene()

func quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()
