extends CharacterBody2D
## Top-down movement for the Guilty Hands prototype.
## Uses Godot's built-in ui_* actions (arrow keys), so it runs with no
## Input Map setup. Add WASD later in Project Settings > Input Map if you want.

@export var speed: float = 220.0

func _physics_process(_delta: float) -> void:
	velocity = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * speed
	move_and_slide()
