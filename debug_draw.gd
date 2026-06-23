extends Node
## F3 debug overlay (autoload "DebugDraw") for tuning the blind hunter.
##
## Toggling it on draws:
##  - every noise event as a translucent sphere of its radius (~1s), so you can
##    see exactly how far each sound reaches,
##  - the hunter's current state as on-screen text,
##  - the hunter's current investigate target as a floating marker.
##
## It only reads the hunter's *observable* state (state/target), never the
## player's position, so switching it on doesn't change what the AI "knows".

@export var enabled: bool = false
@export var noise_marker_lifetime: float = 1.0

var _layer: CanvasLayer
var _label: Label
var _marker: MeshInstance3D
var _noise_mat: StandardMaterial3D
var _marker_mat: StandardMaterial3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # respond to F3 even while paused

	_layer = CanvasLayer.new()
	add_child(_layer)
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_label.visible = false
	_layer.add_child(_label)

	_noise_mat = StandardMaterial3D.new()
	_noise_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_noise_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_noise_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_noise_mat.albedo_color = Color(0.2, 0.8, 1.0, 0.12)

	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.albedo_color = Color(1.0, 0.25, 0.8)

	NoiseBus.noise_made.connect(_on_noise_made)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		enabled = not enabled
		if not enabled:
			_label.visible = false
			if is_instance_valid(_marker):
				_marker.visible = false


func _process(_delta: float) -> void:
	if not enabled:
		return
	var hunter := get_tree().get_first_node_in_group("hunter")
	if hunter == null:
		_label.visible = false
		return
	_label.visible = true
	var target_text := "none"
	if hunter.has_target:
		var t: Vector3 = hunter.investigate_target
		target_text = "(%.1f, %.1f)" % [t.x, t.z]
	_label.text = "HUNTER DEBUG (F3)\nstate: %s\ntarget: %s" % [hunter.get_state_name(), target_text]
	_update_marker(hunter)


func _on_noise_made(position: Vector3, radius: float) -> void:
	if not enabled:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var bubble := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	bubble.mesh = mesh
	bubble.material_override = _noise_mat
	bubble.scale = Vector3(radius, radius, radius)
	bubble.position = position
	scene.add_child(bubble)
	var timer := get_tree().create_timer(noise_marker_lifetime)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(bubble):
			bubble.queue_free())


func _update_marker(hunter: Node) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	# (Re)create lazily — the marker lives in the 3D scene, which is rebuilt on
	# restart, so its reference can go stale.
	if not is_instance_valid(_marker):
		_marker = MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.4
		mesh.height = 0.8
		mesh.radial_segments = 10
		mesh.rings = 6
		_marker.mesh = mesh
		_marker.material_override = _marker_mat
		scene.add_child(_marker)
	_marker.visible = hunter.has_target
	if hunter.has_target:
		_marker.global_position = (hunter.investigate_target as Vector3) + Vector3(0.0, 1.0, 0.0)
