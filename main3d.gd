extends Node3D
## Round orchestration for the 3D prototype.
##
## - Bakes the navigation mesh at runtime from the level's static colliders, so
##   no manual editor bake is ever needed.
## - Wires the hunter's "caught" signal to the placeholder game-over UI.
## - Sets up the world audio beds (positional water in the flooded room, plus a
##   quiet non-positional ambient loop).

@export_group("World Audio")
## Centre of the flooded dead-end, where the positional water loop sits.
@export var water_position: Vector3 = Vector3(22, 0.5, 0)
@export var water_max_distance: float = 20.0
@export var water_volume_db: float = -6.0
@export var ambient_volume_db: float = -18.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var hunter: CharacterBody3D = $Hunter
@onready var catch_ui: CanvasLayer = $CatchUI


func _ready() -> void:
	hunter.caught.connect(catch_ui.show_caught)
	_setup_world_audio()
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


func _setup_world_audio() -> void:
	# Positional water in the flooded dead-end — proximity reveals it.
	var water := AudioStreamPlayer3D.new()
	water.name = "WaterAudio"
	water.bus = &"SFX"
	water.position = water_position
	water.max_distance = water_max_distance
	water.volume_db = water_volume_db
	water.stream = AudioLib.load_stream("water_loop", true)
	add_child(water)
	if water.stream != null:
		water.play()

	# Non-positional ambient bed, kept quiet, dry on Master (no reverb).
	var ambient := AudioStreamPlayer.new()
	ambient.name = "Ambient"
	ambient.bus = &"Master"
	ambient.volume_db = ambient_volume_db
	ambient.stream = AudioLib.load_stream("ambient", true)
	add_child(ambient)
	if ambient.stream != null:
		ambient.play()
