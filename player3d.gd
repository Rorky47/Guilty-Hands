extends CharacterBody3D
## Third-person placeholder controller for the 3D rebuild.
##
## - WASD moves relative to where the camera (and body) is facing.
## - Mouse rotates the body (yaw) and the spring arm (pitch) for mouse-look.
## - Space jumps, gravity pulls down, Shift sprints.
## - Mouse is captured on start; Esc frees it, click recaptures.
##
## Horizontal movement uses acceleration + friction (not instant velocity), so
## grounded movement ramps with a little weight and air control is limited:
## you can nudge your direction mid-jump but can't instantly reverse, which
## makes jumps feel committal.
##
## The camera rides a SpringArm3D so it stays behind the player and slides in
## when a wall would otherwise clip the view.

@export_group("Speed")
@export var move_speed: float = 5.0
@export var sprint_speed: float = 9.0

@export_group("Jump & Gravity")
@export var jump_velocity: float = 7.0
## Upward/base gravity (m/s²). Higher than Godot's realistic 9.8 to cut apex hang.
@export var gravity: float = 20.0
## While falling, gravity is multiplied by this so you drop faster than you rise.
@export var fall_multiplier: float = 1.8

@export_group("Acceleration")
## How fast horizontal velocity ramps toward the target while grounded (m/s²).
@export var ground_accel: float = 60.0
## How fast horizontal velocity bleeds to zero while grounded with no input.
@export var ground_friction: float = 50.0
## Limited steering force while airborne — keeps jumps committal.
@export var air_accel: float = 12.0
## Minimal drag while airborne.
@export var air_friction: float = 2.0

@export_group("Look")
@export var mouse_sensitivity: float = 0.0025
## How far up/down mouse-look can pitch the camera, in degrees.
@export var min_pitch: float = -70.0
@export var max_pitch: float = 50.0

@export_group("Camera FOV")
@export var base_fov: float = 85.0
@export var sprint_fov: float = 92.0
## Roughly how long the sprint FOV kick takes to settle, in seconds.
@export var fov_kick_time: float = 0.15

@export_group("Noise & Stealth")
## Footstep noise radius while walking.
@export var walk_noise: float = 8.0
## Footstep noise radius while sprinting.
@export var sprint_noise: float = 20.0
## One-off noise radius when landing a jump.
@export var land_noise: float = 12.0
## Move speed while crouching/creeping — which is also completely silent.
@export var crouch_speed: float = 2.5
## Seconds between footstep noise events while moving.
@export var noise_interval: float = 0.4

@export_group("Audio")
@export var footstep_volume_db: float = -4.0
@export var crouch_volume_db: float = -16.0
@export var land_volume_db: float = 0.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var _footsteps: AudioStreamPlayer3D = $Footsteps
@onready var _listener: AudioListener3D = $AudioListener3D

var _crouching: bool = false
var _noise_accum: float = 0.0
var _was_on_floor: bool = true
var _air_time: float = 0.0

# Footstep sounds (loaded from res://audio/, or procedural placeholders).
var _crouch_audio_accum: float = 0.0
var _walk_sound: AudioStream
var _sprint_sound: AudioStream
var _crouch_sound: AudioStream
var _land_sound: AudioStream


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Keep the camera arm from colliding with the player's own body.
	spring_arm.add_excluded_object(get_rid())
	camera.fov = base_fov
	# Hear from the player's head, not from the camera behind them.
	_listener.make_current()
	_walk_sound = AudioLib.load_stream("footstep_walk")
	_sprint_sound = AudioLib.load_stream("footstep_sprint")
	_crouch_sound = AudioLib.load_stream("footstep_crouch")
	_land_sound = AudioLib.load_stream("land")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontal mouse turns the whole body so movement stays camera-relative.
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Vertical mouse only tilts the camera arm.
		spring_arm.rotation.x -= event.relative.y * mouse_sensitivity
		spring_arm.rotation.x = clampf(
			spring_arm.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch)
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif (
		event is InputEventMouseButton
		and event.pressed
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_CTRL
	):
		# Toggle crouch/creep: slower movement, and silent (emits no noise).
		_crouching = not _crouching


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	if not on_floor:
		# Asymmetric gravity: fall faster than you rise for a snappier, less floaty arc.
		var g: float = gravity * (fall_multiplier if velocity.y < 0.0 else 1.0)
		velocity.y -= g * delta

	if Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = jump_velocity

	# get_vector(neg_x, pos_x, neg_y, pos_y): forward maps to -Z (Godot's forward).
	var input_dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	# Crouch overrides sprint: you can't sprint while creeping.
	var sprinting := Input.is_action_pressed("sprint") and not _crouching
	var speed: float
	if _crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed
	else:
		speed = move_speed

	# Work with horizontal velocity as a Vector2 so move_toward stays
	# frame-rate independent across both axes at once.
	var horizontal := Vector2(velocity.x, velocity.z)
	if direction != Vector3.ZERO:
		var target := Vector2(direction.x, direction.z) * speed
		var accel := ground_accel if on_floor else air_accel
		horizontal = horizontal.move_toward(target, accel * delta)
	else:
		var friction := ground_friction if on_floor else air_friction
		horizontal = horizontal.move_toward(Vector2.ZERO, friction * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.y

	move_and_slide()

	_emit_movement_noise(delta, sprinting)


## Turn the player's movement into discrete noise events on the global Noise bus.
## Crouching is silent; walking and sprinting ring out at different radii; landing
## a jump is a one-off. The hunter decides for itself whether it's close enough.
func _emit_movement_noise(delta: float, sprinting: bool) -> void:
	var on_floor := is_on_floor()

	# Landing noise: an air -> ground transition after a real fall/jump.
	if on_floor and not _was_on_floor:
		if _air_time > 0.15:
			NoiseBus.emit_noise(global_position, land_noise)
			_play_footstep(_land_sound, land_volume_db)  # sound rides the same landing trigger
		_air_time = 0.0
	elif not on_floor:
		_air_time += delta
	_was_on_floor = on_floor

	# Footstep noise while actually moving on the ground (silent when crouching).
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5
	if on_floor and moving and not _crouching:
		_noise_accum += delta
		if _noise_accum >= noise_interval:
			_noise_accum = 0.0
			NoiseBus.emit_noise(global_position, sprint_noise if sprinting else walk_noise)
			_play_footstep(_sprint_sound if sprinting else _walk_sound, footstep_volume_db)
	else:
		# Idle/crouching: prime the timer so the first step rings out promptly.
		_noise_accum = noise_interval

	# Crouch footsteps are audible to the player but emit NO noise (silent to the
	# hunter). A separate accumulator keeps the noise logic above untouched.
	if on_floor and moving and _crouching:
		_crouch_audio_accum += delta
		if _crouch_audio_accum >= noise_interval:
			_crouch_audio_accum = 0.0
			_play_footstep(_crouch_sound, crouch_volume_db)
	else:
		_crouch_audio_accum = noise_interval


func _play_footstep(stream: AudioStream, vol_db: float) -> void:
	if stream == null:
		return
	_footsteps.stream = stream
	_footsteps.volume_db = vol_db
	_footsteps.play()


func _process(delta: float) -> void:
	# Sprint FOV kick: only while actually moving, not just holding Shift still.
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	var sprinting := Input.is_action_pressed("sprint") and moving and not _crouching
	var target_fov := sprint_fov if sprinting else base_fov
	# Frame-rate-independent smoothing that settles ~99% over fov_kick_time.
	var weight := 1.0 - pow(0.01, delta / maxf(fov_kick_time, 0.0001))
	camera.fov = lerpf(camera.fov, target_fov, weight)
