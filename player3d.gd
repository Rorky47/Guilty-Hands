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

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Keep the camera arm from colliding with the player's own body.
	spring_arm.add_excluded_object(get_rid())
	camera.fov = base_fov


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

	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else move_speed

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


func _process(delta: float) -> void:
	# Sprint FOV kick: only while actually moving, not just holding Shift still.
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	var sprinting := Input.is_action_pressed("sprint") and moving
	var target_fov := sprint_fov if sprinting else base_fov
	# Frame-rate-independent smoothing that settles ~99% over fov_kick_time.
	var weight := 1.0 - pow(0.01, delta / maxf(fov_kick_time, 0.0001))
	camera.fov = lerpf(camera.fov, target_fov, weight)
