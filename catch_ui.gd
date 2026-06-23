extends CanvasLayer
## Placeholder catch outcome: show a CAUGHT banner, freeze the game, restart on R.
##
## This node is set to PROCESS_MODE_ALWAYS in the scene so it still receives input
## while the tree is paused — that pause is what freezes player and hunter.

@onready var label: Label = $Label


func _ready() -> void:
	label.visible = false


func show_caught() -> void:
	label.visible = true
	# Free the mouse so the banner is readable, and pause to freeze movement.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not label.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().paused = false
		get_tree().reload_current_scene()
