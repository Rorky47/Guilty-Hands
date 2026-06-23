extends Node3D
## Round orchestration for the 3D prototype.
##
## - Bakes the navigation mesh at runtime from the level's static colliders, so
##   no manual editor bake is ever needed.
## - Wires the hunter's "caught" signal to the placeholder game-over UI.

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var hunter: CharacterBody3D = $Hunter
@onready var catch_ui: CanvasLayer = $CatchUI


func _ready() -> void:
	# Bake from the static colliders tagged into the "nav_source" group (see the
	# NavigationMesh's geometry settings). The hunter's activation_delay covers
	# the bake + nav map sync before it starts pathfinding.
	nav_region.bake_navigation_mesh()
	hunter.caught.connect(catch_ui.show_caught)
