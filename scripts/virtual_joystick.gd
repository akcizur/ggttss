extends Control

signal value_changed(value: Vector2)

@export var knob_color: Color = Color(0.93, 0.79, 0.46, 0.88)
@export var base_color: Color = Color(0.06, 0.08, 0.10, 0.42)
@export var outline_color: Color = Color(0.90, 0.92, 0.94, 0.48)

var _touch_index: int = -1
var _value: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(156.0, 156.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_update_from_position(event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_set_value(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_from_position(event.position)
		accept_event()

func _update_from_position(position: Vector2) -> void:
	var local_position := position
	var center := size * 0.5
	var offset := local_position - center
	var radius := minf(size.x, size.y) * 0.36
	var raw_value := offset / maxf(radius, 1.0)
	var strength := raw_value.length()
	if strength < 0.12:
		_set_value(Vector2.ZERO)
	else:
		var remapped_strength := clampf((strength - 0.12) / 0.88, 0.0, 1.0)
		_set_value(raw_value.normalized() * remapped_strength)

func _set_value(value: Vector2) -> void:
	_value = value.limit_length(1.0)
	value_changed.emit(_value)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var base_radius := minf(size.x, size.y) * 0.43
	var knob_radius := minf(size.x, size.y) * 0.19
	var travel_radius := minf(size.x, size.y) * 0.36
	draw_circle(center, base_radius, base_color)
	draw_arc(center, base_radius, 0.0, TAU, 64, outline_color, 2.0, true)
	draw_circle(center + _value * travel_radius, knob_radius, knob_color)
	draw_arc(center + _value * travel_radius, knob_radius, 0.0, TAU, 48, Color(1.0, 0.94, 0.78, 0.8), 1.5, true)
