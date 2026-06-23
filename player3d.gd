extends CharacterBody3D
## Third-person placeholder controller for the 3D rebuild.
##
## - WASD moves relative to where the camera (and body) is facing.
## - Mouse rotates the body (yaw) and the spring arm (pitch) for mouse-look.
## - Space jumps, gravity pulls down, Shift sprints.
## - Mouse is captured on start; Esc frees it, click recaptures.
##
## The camera rides a SpringArm3D so it stays behind the player and slides in
## when a wall would otherwise clip the view.

@export var move_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.0025

## How far up/down mouse-look can pitch the camera, in degrees.
@export var min_pitch: float = -70.0
@export var max_pitch: float = 50.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

# Project gravity (matches RigidBody/other physics), read once at startup.
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Keep the camera arm from colliding with the player's own body.
	spring_arm.add_excluded_object(get_rid())


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
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# get_vector(neg_x, pos_x, neg_y, pos_y): forward maps to -Z (Godot's forward).
	var input_dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else move_speed
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
