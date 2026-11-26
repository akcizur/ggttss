extends Node3D

## Citizen actor: plays the real Mixamo idle clip from the supplied character pack.
## Small procedural upper-body/root motion is layered as a placeholder for a future
## dedicated talking clip; it does not replace the skeletal idle animation.

@export var idle_sway: float = 0.025
@export var talking_sway: float = 0.065

var talking: bool = false
var mood: String = "neutral"
var _phase: float = 0.0
var _rig: Node3D
var _animation_player: AnimationPlayer
var _idle_clip: StringName = &""
var _talk_clip: StringName = &""

func _ready() -> void:
	_rig = get_node_or_null("CitizenRig") as Node3D
	if not is_instance_valid(_rig):
		_rig = self
	_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if is_instance_valid(_animation_player):
		_idle_clip = _find_clip("idle")
		_talk_clip = _find_clip("talk")
		if _idle_clip != &"":
			_play_clip(_idle_clip)

func _process(delta: float) -> void:
	_phase += delta
	if is_instance_valid(_rig) and _rig != self:
		var sway := talking_sway if talking else idle_sway
		_rig.rotation.y = sin(_phase * (2.0 if talking else 0.65)) * sway
		_rig.rotation.z = sin(_phase * 1.4) * (0.012 if talking else 0.004)

func _find_clip(wanted: String) -> StringName:
	if not is_instance_valid(_animation_player):
		return &""
	for clip in _animation_player.get_animation_list():
		if String(clip).get_file().to_lower() == wanted.to_lower() or String(clip).to_lower().ends_with("/" + wanted.to_lower()):
			return StringName(clip)
	return &""

func _play_clip(clip: StringName) -> void:
	if not is_instance_valid(_animation_player) or clip == &"":
		return
	if _animation_player.current_animation != clip:
		_animation_player.play(clip, 0.22)
	_animation_player.speed_scale = 1.0

func set_talking(value: bool) -> void:
	talking = value
	mood = "talking" if value else "neutral"
	# The supplied GLB has an idle clip but no dedicated lip-sync/talk clip.
	# Keep the real skeletal idle running and layer a subtle talk gesture above it.
	if is_instance_valid(_animation_player):
		if _talk_clip != &"" and talking:
			_play_clip(_talk_clip)
		elif _idle_clip != &"":
			_play_clip(_idle_clip)
		_animation_player.speed_scale = 1.08 if talking else 1.0

func set_mood(value: String) -> void:
	mood = value
