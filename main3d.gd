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
	hunter.caught.connect(catch_ui.show_caught)
	# Let the region register on the navigation map for a couple of physics frames
	# before baking. Baking during _ready — especially with the level as an
	# instanced scene — can update the mesh before the region is on the map, so the
	# bake never syncs and the map stays empty. The hunter's activation_delay still
	# covers this before it starts pathfinding.
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Bake from the static colliders tagged into the "nav_source" group (see the
	# NavigationMesh's geometry settings).
	nav_region.bake_navigation_mesh()
