extends CharacterBody3D
## AI hunter — step 2 of 3: BLIND. It hunts purely by hearing.
##
## The hunter no longer knows where the player is. It listens on the global Noise
## bus; a noise is only "heard" if the hunter is within that noise's radius.
## Hearing sends it to investigate (HUNTING). With nothing left to chase it
## SEARCHES the area, then falls back to WANDERING until it hears something again.
##
## HARD RULE: the hunter MUST NOT read the player's position anywhere except the
## final proximity catch check (_check_catch). Everything else it knows about the
## player comes from noise events delivered by the bus.
##
## "Choose a destination" (the state machine + _set_destination) is kept separate
## from "move toward a destination" (_move_along_path / _steer_toward) so a
## director — or a human — could drive the same body later.

signal caught

enum State { INACTIVE, HUNTING, SEARCHING, WANDERING }

@export_group("Speeds")
@export var chase_speed: float = 7.0
@export var search_speed: float = 3.0
@export var wander_speed: float = 2.0

@export_group("Behaviour")
@export var catch_range: float = 1.2
@export var search_radius: float = 6.0
@export var search_seconds: float = 4.0
## How far wandering scatters its random roam points.
@export var wander_range: float = 18.0
## Head start: the hunter is deaf and still for this long at round start. Also
## overlaps the runtime navmesh bake in Main3D.
@export var activation_delay: float = 3.0
@export var gravity: float = 20.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# Observable state — read by the debug overlay. Never exposes player position.
var state: State = State.INACTIVE
var investigate_target: Vector3 = Vector3.ZERO
var has_target: bool = false

var _last_heard: Vector3 = Vector3.ZERO
var _search_timer: float = 0.0
var _path_age: int = 0
var _caught: bool = false


func _ready() -> void:
	NoiseBus.noise_made.connect(_on_noise_made)
	# Head start: stay inactive (and deaf) for the delay, then start wandering.
	await get_tree().create_timer(activation_delay).timeout
	_enter_wandering()


func _physics_process(delta: float) -> void:
	if _caught:
		return
	_apply_gravity(delta)

	if state == State.INACTIVE:
		_halt_horizontal()
		move_and_slide()
		return

	_check_catch()  # the ONLY place the player's position may be read
	if _caught:
		_halt_horizontal()
		move_and_slide()
		return

	# Move toward the current destination (this also drives path computation)...
	if has_target:
		_move_along_path(_current_speed())
	else:
		_halt_horizontal()

	# ...then update the state machine based on arrival / timers.
	_advance_state(delta)

	move_and_slide()


# ----------------------------------------------------------------- hearing

func _on_noise_made(position: Vector3, radius: float) -> void:
	if _caught or state == State.INACTIVE:
		return
	# Heard only if within the noise's radius. This uses the noise *event's*
	# position, never the player node — it's the hunter's sole knowledge of the
	# player's whereabouts (i.e. a last-known-location).
	if global_position.distance_to(position) <= radius:
		_last_heard = position
		state = State.HUNTING
		_set_destination(_snap_to_nav(position))


# ------------------------------------------------------------ state machine

func _advance_state(delta: float) -> void:
	match state:
		State.HUNTING:
			if _reached_destination():
				_enter_searching()
		State.SEARCHING:
			_search_timer -= delta
			if _search_timer <= 0.0:
				_enter_wandering()
			elif _reached_destination():
				_pick_search_point()
		State.WANDERING:
			if _reached_destination():
				_pick_wander_point()
	_path_age += 1


func _enter_searching() -> void:
	state = State.SEARCHING
	_search_timer = search_seconds
	_pick_search_point()


func _enter_wandering() -> void:
	state = State.WANDERING
	_pick_wander_point()


func _pick_search_point() -> void:
	# Poke around random spots near where the noise was last heard.
	_set_destination(_random_nav_point(_last_heard, search_radius))


func _pick_wander_point() -> void:
	_set_destination(_random_nav_point(global_position, wander_range))


# --------------------------------------------------- destinations & movement

## Choose a destination. The single entry point a director/human could call to
## drive this body without touching the locomotion below.
func _set_destination(point: Vector3) -> void:
	investigate_target = point
	has_target = true
	nav_agent.target_position = point
	_path_age = 0


func _reached_destination() -> bool:
	# Ignore is_navigation_finished for the first couple of frames so a freshly
	# set target (path not yet built) doesn't immediately read as "arrived".
	return has_target and _path_age >= 2 and nav_agent.is_navigation_finished()


## Move toward the current destination at the given speed.
func _move_along_path(speed: float) -> void:
	_steer_toward(nav_agent.get_next_path_position(), speed)


## Locomotion primitive: drive horizontal velocity toward a world-space point.
func _steer_toward(point: Vector3, speed: float) -> void:
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.length() > 0.01:
		var dir := to_point.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		_halt_horizontal()


func _halt_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _current_speed() -> float:
	match state:
		State.HUNTING:
			return chase_speed
		State.SEARCHING:
			return search_speed
		State.WANDERING:
			return wander_speed
	return 0.0


# ----------------------------------------------------------------- helpers

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _random_nav_point(center: Vector3, radius: float) -> Vector3:
	var angle := randf() * TAU
	var dist := sqrt(randf()) * radius  # sqrt for uniform area distribution
	var raw := center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	return _snap_to_nav(raw)


func _snap_to_nav(point: Vector3) -> Vector3:
	var map := nav_agent.get_navigation_map()
	if not map.is_valid():
		return point
	return NavigationServer3D.map_get_closest_point(map, point)


func _check_catch() -> void:
	var player := _nearest_player()
	if player != null and global_position.distance_to(player.global_position) <= catch_range:
		_trigger_caught()


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
	has_target = false
	caught.emit()


## Human-readable state, for the debug overlay.
func get_state_name() -> String:
	match state:
		State.INACTIVE:
			return "INACTIVE"
		State.HUNTING:
			return "HUNTING"
		State.SEARCHING:
			return "SEARCHING"
		State.WANDERING:
			return "WANDERING"
	return "?"
