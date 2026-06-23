extends CharacterBody3D
## AI hunter — hunts a DECAYING SOUND TRAIL.
##
## The hunter has NO knowledge of the player. Every frame it reads the global
## sound field (NoiseBus.get_clues()) and scores each live clue by PERCEIVED
## strength = current_strength - perception_falloff * nav-path-distance. The
## best-perceived clue is the LEAD, and the whole state machine is derived from
## it: a loud near lead -> HUNTING, a faint one -> SEARCHING, none -> WANDERING.
## Because fresh, loud clues keep appearing wherever the player moves, the lead
## keeps updating and the hunter pursues continuously instead of giving up.
##
## HARD RULE: the hunter MUST NOT read the player's position anywhere except the
## final proximity catch check (_check_catch). Everything else comes from clues.
##
## "Choose a destination" (_update_state_and_destination / _set_destination) is
## kept separate from "steer toward a destination" (_move_along_path /
## _steer_toward) so a director — or a human — could drive the same body later.

signal caught

enum State { INACTIVE, HUNTING, SEARCHING, WANDERING }

@export_group("Speeds")
@export var chase_speed: float = 7.0
@export var search_speed: float = 3.0
@export var wander_speed: float = 2.0

@export_group("Perception")
## Perceived strength lost per metre of NAV-PATH distance to a clue. Walls
## lengthen the path, so they muffle; a severed path is inaudible.
@export var perception_falloff: float = 0.6
## Perceived strength at/above which a clue triggers a full-speed HUNT.
@export var hunting_threshold: float = 3.0

@export_group("Behaviour")
@export var catch_range: float = 1.2
## Radius of the random pokes while searching around a faint lead.
@export var search_radius: float = 6.0
## Radius for uniform wandering before anything has ever been sensed.
@export var wander_range: float = 18.0
## After losing the trail, bias wander points to this radius around the last
## place a clue was sensed (a past SOUND location — never the live player).
@export var wander_bias_radius: float = 14.0
## Head start: the hunter is inactive for this long at round start. Also overlaps
## the runtime navmesh bake in Main3D.
@export var activation_delay: float = 3.0
@export var gravity: float = 20.0

@export_group("Audio")
## Generous so you hear it coming across the tunnel.
@export var hunter_audio_max_distance: float = 25.0
@export var idle_volume_db: float = -14.0
@export var move_volume_db: float = -6.0
@export var alert_volume_db: float = 0.0
## Horizontal speed (m/s) above which the move/shuffle sound plays.
@export var move_audio_threshold: float = 0.3

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _audio_idle: AudioStreamPlayer3D = $AudioIdle
@onready var _audio_move: AudioStreamPlayer3D = $AudioMove
@onready var _audio_alert: AudioStreamPlayer3D = $AudioAlert

# Observable state — read by the debug overlay. Never exposes player position.
var state: State = State.INACTIVE
var investigate_target: Vector3 = Vector3.ZERO
var has_target: bool = false
var has_lead: bool = false
var lead_position: Vector3 = Vector3.ZERO
var lead_strength: float = 0.0

var last_sensed: Vector3 = Vector3.ZERO
var _has_last_sensed: bool = false
var _lead = null  # the lead Clue object (NoiseBus.Clue) or null
var _lead_perceived: float = 0.0
var _path_age: int = 0
var _caught: bool = false
var _prev_audio_state: State = State.INACTIVE


func _ready() -> void:
	_setup_audio()
	# Head start: stay inactive for the delay, then begin wandering; from then on
	# perception of the sound field drives the state each frame.
	await get_tree().create_timer(activation_delay).timeout
	state = State.WANDERING


func _setup_audio() -> void:
	for p in [_audio_idle, _audio_move, _audio_alert]:
		p.max_distance = hunter_audio_max_distance
	_audio_idle.stream = AudioLib.load_stream("hunter_idle", true)
	_audio_move.stream = AudioLib.load_stream("hunter_move", true)
	_audio_alert.stream = AudioLib.load_stream("hunter_alert", false)
	_audio_idle.volume_db = idle_volume_db
	_audio_alert.volume_db = alert_volume_db
	# Idle growl/breath is a constant lurking presence, even while wandering.
	if _audio_idle.stream != null:
		_audio_idle.play()


## Audio only — reads the hunter's own velocity/state, never the player.
func _process(_delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if _audio_move.stream != null:
		if speed > move_audio_threshold:
			if not _audio_move.playing:
				_audio_move.play()
			# Louder the faster it moves.
			_audio_move.volume_db = move_volume_db + linear_to_db(clampf(speed / chase_speed, 0.25, 1.0))
		elif _audio_move.playing:
			_audio_move.stop()
	# One-shot stinger the moment it locks onto a fresh trail.
	if state == State.HUNTING and _prev_audio_state != State.HUNTING:
		if _audio_alert.stream != null:
			_audio_alert.play()
	_prev_audio_state = state


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

	_perceive()                      # read the sound field -> current lead
	_path_age += 1
	_update_state_and_destination()  # pick a destination (separate from steering)

	if has_target:
		_move_along_path(_current_speed())  # steer toward the destination
	else:
		_halt_horizontal()

	move_and_slide()


# --------------------------------------------------------------- perception

## Score every live clue by perceived strength and keep the best as the LEAD.
## Perceived strength falls off with NAV-PATH distance (occlusion), so a clue
## past a wall is muffled and a clue with no route is skipped entirely.
func _perceive() -> void:
	_lead = null
	_lead_perceived = 0.0
	for c in NoiseBus.get_clues():
		var path_len := _path_length_to(c.position)
		if path_len < 0.0:
			continue  # unreachable / no path -> not perceivable
		var perceived: float = c.current_strength - perception_falloff * path_len
		if perceived > _lead_perceived:  # perceivable only when > 0
			_lead_perceived = perceived
			_lead = c
	has_lead = _lead != null
	if has_lead:
		lead_position = _lead.position
		lead_strength = _lead_perceived
		# Remember where we last sensed a SOUND, for the wander nudge.
		last_sensed = _lead.position
		_has_last_sensed = true


## Derive the state purely from the perceived field, then choose a destination
## for that state. Steering is done separately in _move_along_path.
func _update_state_and_destination() -> void:
	var new_state: State
	if has_lead:
		new_state = State.HUNTING if _lead_perceived >= hunting_threshold else State.SEARCHING
	else:
		new_state = State.WANDERING
	var changed := new_state != state
	state = new_state

	match state:
		State.HUNTING:
			# Track the freshest/loudest clue, but only re-target when it has moved
			# enough. Re-pathing every single frame makes the agent recompute from
			# scratch and stall ~1 m short; a small threshold lets the path settle so
			# it arrives (and catches), while still following a moving trail.
			var dest := _snap_to_nav(lead_position)
			if changed or not has_target or investigate_target.distance_to(dest) > 0.3:
				_set_destination(dest)
		State.SEARCHING:
			# Move toward the faint lead while poking random points around it.
			if changed or not has_target or _reached_destination():
				_set_destination(_random_nav_point(lead_position, search_radius))
		State.WANDERING:
			if changed or not has_target or _reached_destination():
				_set_destination(_wander_point())


## A roam destination. Director nudge: after losing the trail, drift back toward
## where a clue was last sensed; otherwise wander uniformly.
func _wander_point() -> Vector3:
	if _has_last_sensed:
		return _random_nav_point(last_sensed, wander_bias_radius)
	return _random_nav_point(global_position, wander_range)


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


## Nav-path distance from the hunter to `to`, or -1 if there's no usable route.
## This IS the sound-occlusion model: distance is measured AROUND walls along the
## navmesh, not straight-line, so walls muffle (longer path) or block (no path).
## (Later: a closed door will carve the navmesh and lengthen/sever this path,
## blocking sound through it automatically, with no special-casing for doors.)
func _path_length_to(to: Vector3) -> float:
	var map := nav_agent.get_navigation_map()
	if not map.is_valid():
		return global_position.distance_to(to)  # pre-bake fallback: straight line
	var path := NavigationServer3D.map_get_path(map, global_position, to, true)
	if path.size() < 2:
		return -1.0
	# Reachability guard: map_get_path returns the closest reachable point when the
	# target is sealed off; if the path doesn't end at `to`, treat as unreachable.
	if path[path.size() - 1].distance_to(to) > 1.0:
		return -1.0
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i].distance_to(path[i - 1])
	return length


## True if a sound of the given `radius` at `position` reaches the hunter along
## the navmesh. Kept as the named occlusion-check entry point.
func can_hear(position: Vector3, radius: float) -> bool:
	var path_len := _path_length_to(position)
	return path_len >= 0.0 and path_len <= radius


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
	has_lead = false
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
