extends Node3D

## Hinged door. The child AnimatableBody3D carries both the visible leaf and collision.
@export_range(35.0, 130.0, 1.0) var open_angle_degrees: float = 92.0
@export_range(0.1, 1.5, 0.05) var animation_duration: float = 0.38
var is_open: bool = false
var is_animating: bool = false
var _closed_yaw: float = 0.0
var _tween: Tween

func _ready() -> void:
    _closed_yaw = rotation.y

func set_open(value: bool) -> void:
    if is_open == value and not is_animating:
        return
    if _tween and _tween.is_running():
        _tween.kill()
    is_open = value
    is_animating = true
    var target_yaw := _closed_yaw + (deg_to_rad(open_angle_degrees) if is_open else 0.0)
    _tween = create_tween()
    _tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _tween.tween_property(self, "rotation:y", target_yaw, animation_duration)
    _tween.finished.connect(func() -> void:
        is_animating = false
    )

func toggle() -> void:
    set_open(not is_open)
