extends CharacterBody2D
## A simple AI hunter for the local prototype. It waits a short head start, then
## beelines toward the survivor and "catches" them on contact. Tune `speed` (keep
## it below the player's 220 so escape is possible), `catch_distance`, and
## `head_start`. To hand this seat to a human later, replace the chase math in
## _physics_process with Input (e.g. WASD), or drive `velocity` over the network.

@export var speed: float = 170.0
@export var catch_distance: float = 30.0
@export var head_start: float = 2.0

signal caught_player

var _target: Node2D = null
var _elapsed: float = 0.0

func _ready() -> void:
	_target = get_tree().get_first_node_in_group("player") as Node2D

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < head_start:
		return
	if _target == null:
		_target = get_tree().get_first_node_in_group("player") as Node2D
		return
	velocity = (_target.global_position - global_position).normalized() * speed
	move_and_slide()
	if global_position.distance_to(_target.global_position) <= catch_distance:
		caught_player.emit()
