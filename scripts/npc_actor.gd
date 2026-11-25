extends Node3D

## Lightweight procedural idle/talk animation for the current NPC blockout.
## This can be replaced by a rigged citizen scene without changing interaction code.

@export var idle_bob_height: float = 0.025
@export var idle_sway: float = 0.035
var talking: bool = false
var _phase: float = 0.0
var _base_body_y: float = 1.05

func _process(delta: float) -> void:
    _phase += delta
    var body := get_node_or_null("Body") as MeshInstance3D
    var head := get_node_or_null("Head") as MeshInstance3D
    var left_arm := get_node_or_null("LeftArm") as MeshInstance3D
    var right_arm := get_node_or_null("RightArm") as MeshInstance3D
    if is_instance_valid(body):
        body.position.y = _base_body_y + sin(_phase * 1.7) * idle_bob_height
    if is_instance_valid(head):
        head.rotation.y = sin(_phase * 0.55) * (0.10 if talking else idle_sway)
        head.rotation.x = sin(_phase * 1.9) * (0.035 if talking else 0.012)
    var arm_swing := sin(_phase * (5.0 if talking else 1.15)) * (0.11 if talking else 0.025)
    if is_instance_valid(left_arm):
        left_arm.rotation.z = -0.08 + arm_swing
    if is_instance_valid(right_arm):
        right_arm.rotation.z = 0.08 - arm_swing

func set_talking(value: bool) -> void:
    talking = value
