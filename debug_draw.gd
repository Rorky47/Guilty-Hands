extends Node
## F3 debug overlay (autoload "DebugDraw") for tuning the hunter's sound trail.
##
## Toggling it on draws:
##  - every LIVE sound clue as a sphere whose size + alpha scale with its current
##    (decaying) strength, so you can watch the trail fade,
##  - a line from the hunter to its current LEAD clue (the one it's perceiving
##    strongest), with the lead clue tinted distinctly,
##  - the hunter's state + lead readout as on-screen text.
##
## It reads only the hunter's observable state and the public sound field, never
## the player's position, so switching it on doesn't change what the AI "knows".

@export var enabled: bool = false
## Metres of sphere radius per unit of clue strength.
@export var clue_size_scale: float = 0.12

var _layer: CanvasLayer
var _label: Label
var _clue_mesh: SphereMesh
var _line_mat: StandardMaterial3D

# Live in the 3D scene (rebuilt on restart), so refs can go stale -> recreated.
var _field_root: Node3D
var _clue_pool: Array[MeshInstance3D] = []
var _lead_line: MeshInstance3D


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

	_clue_mesh = SphereMesh.new()
	_clue_mesh.radius = 1.0
	_clue_mesh.height = 2.0
	_clue_mesh.radial_segments = 12
	_clue_mesh.rings = 6

	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.albedo_color = Color(1.0, 0.6, 0.1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		enabled = not enabled
		if not enabled:
			_label.visible = false
			_hide_field()


func _process(_delta: float) -> void:
	if not enabled:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	_ensure_field_nodes(scene)

	var hunter := get_tree().get_first_node_in_group("hunter")
	var clues := NoiseBus.get_clues()

	var has_lead: bool = hunter != null and hunter.has_lead
	var lead_pos: Vector3 = hunter.lead_position if has_lead else Vector3.ZERO

	# Draw / update one sphere per live clue (pooled).
	while _clue_pool.size() < clues.size():
		_clue_pool.append(_make_clue_sphere())
	for i in range(_clue_pool.size()):
		var mi := _clue_pool[i]
		if i >= clues.size():
			mi.visible = false
			continue
		var c = clues[i]
		var s: float = c.current_strength
		mi.visible = true
		mi.global_position = c.position + Vector3(0.0, 0.3, 0.0)
		var r := clampf(s * clue_size_scale, 0.3, 2.5)
		mi.scale = Vector3(r, r, r)
		var mat: StandardMaterial3D = mi.material_override
		if has_lead and c.position.is_equal_approx(lead_pos):
			mat.albedo_color = Color(1.0, 0.7, 0.15, clampf(s * 0.05 + 0.2, 0.25, 0.7))
		else:
			mat.albedo_color = Color(0.2, 0.8, 1.0, clampf(s * 0.03, 0.06, 0.45))

	# Draw the hunter -> lead line.
	var im := _lead_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if hunter != null and has_lead:
		im.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
		im.surface_add_vertex(hunter.global_position + Vector3(0.0, 0.8, 0.0))
		im.surface_add_vertex(lead_pos + Vector3(0.0, 0.8, 0.0))
		im.surface_end()
		_lead_line.visible = true
	else:
		_lead_line.visible = false

	# State readout.
	_label.visible = true
	if hunter == null:
		_label.text = "HUNTER DEBUG (F3)\nno hunter"
	else:
		var lead_txt := "none"
		if has_lead:
			lead_txt = "%.1f @ (%.0f, %.0f)" % [hunter.lead_strength, lead_pos.x, lead_pos.z]
		_label.text = "HUNTER DEBUG (F3)\nstate: %s\nlead: %s\nlive clues: %d" % [
			hunter.get_state_name(), lead_txt, clues.size()]


func _ensure_field_nodes(scene: Node) -> void:
	if is_instance_valid(_field_root) and _field_root.get_parent() == scene:
		return
	# First run, or the scene was rebuilt (restart): start a fresh pool.
	_clue_pool.clear()
	_field_root = Node3D.new()
	_field_root.name = "DebugSoundField"
	scene.add_child(_field_root)
	_lead_line = MeshInstance3D.new()
	_lead_line.mesh = ImmediateMesh.new()
	_field_root.add_child(_lead_line)


func _make_clue_sphere() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _clue_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	_field_root.add_child(mi)
	return mi


func _hide_field() -> void:
	for mi in _clue_pool:
		if is_instance_valid(mi):
			mi.visible = false
	if is_instance_valid(_lead_line):
		_lead_line.visible = false
