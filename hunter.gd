extends CharacterBody3D
## AI hunter — step 1 of 3: navigation only.
##
## Pathfinds around the level to reach the nearest player using a
## NavigationAgent3D. There is no line-of-sight or search behaviour yet: the
## hunter always knows where the player is and heads straight for them along the
## navmesh.
##
## Catching is by distance (catch_range), NOT physical collision: the hunter and
## player sit on separate collision layers and pass through one another, so they
## never shove each other around.
##
## Target selection (_nearest_player) is kept separate from locomotion
## (_steer_toward) so the same body could later be driven by a smarter AI — or a
## human — without touching how it moves.

## Emitted once when the hunter reaches the player.
signal caught

@export var chase_speed: float = 6.0
@export var catch_range: float = 1.2
## Seconds the hunter holds still at round start, giving the player a head start.
## Also comfortably covers the runtime navmesh bake finishing in Main3D.
@export var activation_delay: float = 3.0
@export var gravity: float = 20.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var _active: bool = false
var _caught: bool = false


func _ready() -> void:
	# Hold still, then activate. The timer also overlaps the navmesh bake so the
	# nav map has synced by the time the hunter wants a path.
	await get_tree().create_timer(activation_delay).timeout
	_active = true


func _physics_process(delta: float) -> void:
	if _caught:
		return

	_apply_gravity(delta)

	if _active:
		var target: Node3D = _nearest_player()  # target selection
		if target != null:
			nav_agent.target_position = target.global_position
			if global_position.distance_to(target.global_position) <= catch_range:
				_trigger_caught()
			else:
				_steer_toward(nav_agent.get_next_path_position())  # locomotion
		else:
			_halt_horizontal()
	else:
		_halt_horizontal()

	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


## Locomotion primitive: drive horizontal velocity toward a world-space point at
## chase_speed. Any controller that can supply a point to move toward can reuse
## this — it doesn't care whether the point came from a navmesh or a human.
func _steer_toward(point: Vector3) -> void:
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.length() > 0.01:
		var dir := to_point.normalized()
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed
	else:
		_halt_horizontal()


func _halt_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


## Target selection: nearest body in the "player" group (single-player today,
## but ready for more).
func _nearest_player() -> Node3D:
	var nearest: Node3D = null
	var best := INF
	for p in get_tree().get_nodes_in_group("player"):
		var node := p as Node3D
		if node != null:
			var d := global_position.distance_squared_to(node.global_position)
			if d < best:
				best = d
				nearest = node
	return nearest


func _trigger_caught() -> void:
	if _caught:
		return
	_caught = true
	velocity = Vector3.ZERO
	caught.emit()
