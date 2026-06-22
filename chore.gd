extends Area2D
## A "chore" the player finishes by standing on it and holding Enter (ui_accept).
## Fills 0..1 and emits `completed`. The mundane chores are the cover story that
## lets players act on their secret objectives without standing out.
##
## NOTE: this single-player version reads global Input directly. When you add
## multiplayer, have the *player* tell the chore who is interacting instead.

signal completed

@export var fill_time: float = 2.0  # seconds of holding to finish

var _player_in_range: bool = false
var _progress: float = 0.0
var _done: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if _done or not _player_in_range:
		return
	if Input.is_action_pressed("ui_accept"):
		_progress += delta / fill_time
		if _progress >= 1.0:
			_progress = 1.0
			_done = true
			completed.emit()
			print("Chore complete: ", name)
		queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_in_range = false

## Tiny built-in visual so you can see progress without making any UI yet.
func _draw() -> void:
	draw_circle(Vector2.ZERO, 20.0, Color(0.30, 0.30, 0.35))
	if _progress > 0.0:
		draw_arc(Vector2.ZERO, 20.0, -PI / 2.0, -PI / 2.0 + TAU * _progress, 48, Color(0.40, 0.90, 0.55), 4.0)
