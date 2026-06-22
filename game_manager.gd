extends Node
## Local prototype of the "escape the hunter" loop.
## You are the lone survivor (arrow keys). Finish every task — stand on a chore
## and hold Enter — to escape alive. But a monster is hunting you: get caught and
## it's over. This runs single-player today with an AI monster; later a human can
## take the monster's seat (see "Networking" in the README).

signal tasks_changed(done: int, total: int)
signal game_over(escaped: bool)

var _total: int = 0
var _done: int = 0
var _finished: bool = false

var _counter: Label
var _banner: Label

func _ready() -> void:
	# Keep ticking while the tree is paused so we can catch the restart key.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	# Wait one frame so every chore/monster has registered in its group.
	await get_tree().process_frame
	_wire_up()

func _wire_up() -> void:
	var chores := get_tree().get_nodes_in_group("chores")
	_total = chores.size()
	for chore in chores:
		chore.connect("completed", _on_task_done)
	var monster = get_tree().get_first_node_in_group("monster")
	if monster:
		monster.connect("caught_player", _on_caught)
	print("=== ESCAPE THE HUNTER ===")
	print("Finish all %d tasks to escape — and don't get caught." % _total)
	_update_counter()

func _on_task_done() -> void:
	if _finished:
		return
	_done += 1
	print("Task %d / %d done." % [_done, _total])
	tasks_changed.emit(_done, _total)
	_update_counter()
	if _done >= _total:
		_end(true)

func _on_caught() -> void:
	_end(false)

func _end(escaped: bool) -> void:
	if _finished:
		return
	_finished = true
	game_over.emit(escaped)
	if escaped:
		print("=== ESCAPED! Every task done — you got out alive. ===")
		_banner.text = "YOU ESCAPED\n\nPress Enter to play again"
		_banner.modulate = Color(0.45, 0.95, 0.55)
	else:
		print("=== CAUGHT! The hunter got you. ===")
		_banner.text = "CAUGHT\n\nPress Enter to play again"
		_banner.modulate = Color(1.0, 0.42, 0.42)
	_banner.show()
	get_tree().paused = true

func _process(_delta: float) -> void:
	if _finished and Input.is_action_just_pressed("ui_accept"):
		get_tree().paused = false
		get_tree().reload_current_scene()

func _update_counter() -> void:
	_counter.text = "Tasks  %d / %d" % [_done, _total]

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_counter = Label.new()
	_counter.position = Vector2(16, 10)
	_counter.add_theme_font_size_override("font_size", 24)
	layer.add_child(_counter)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 46)
	_banner.hide()
	layer.add_child(_banner)
