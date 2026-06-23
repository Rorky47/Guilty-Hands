extends SceneTree
## One-shot greybox generator: builds the first underground tunnel segment as
## tunnel.tscn (a "Tunnel" Node3D with "Floors", "Walls", "Water" children).
## Run headless:  godot --headless --script gen_tunnel.gd
##
## Layout (top-down, X east/west, Z north/south, floor top at y=0, metres):
## a ring-with-a-cross network in ~44x44, 5-wide corridors, hub in the middle,
## a start room off the north corridor, and a flooded dead-end off the east
## corridor through a ~2-wide chokepoint.

var unit_box: BoxMesh
var unit_shape: BoxShape3D
var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var water_mat: StandardMaterial3D
var tunnel_root: Node3D

const CHOKE_HALF := 1.0  # half-width of the flooded dead-end mouth (=> ~2 wide)


func _init() -> void:
	unit_box = BoxMesh.new()
	unit_box.size = Vector3(1, 1, 1)
	unit_shape = BoxShape3D.new()
	unit_shape.size = Vector3(1, 1, 1)

	floor_mat = _mat(Color(0.11, 0.13, 0.12), 0.95, 0.0)   # dark wet floor
	wall_mat = _mat(Color(0.23, 0.28, 0.26), 0.9, 0.0)     # cool grey-green walls
	water_mat = _mat(Color(0.13, 0.34, 0.55), 0.25, 0.1)   # translucent blue water
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color.a = 0.45

	tunnel_root = Node3D.new()
	tunnel_root.name = "Tunnel"

	var floors := Node3D.new()
	floors.name = "Floors"
	tunnel_root.add_child(floors)
	floors.owner = tunnel_root
	floors.add_to_group("nav_source", true)

	var walls := Node3D.new()
	walls.name = "Walls"
	tunnel_root.add_child(walls)
	walls.owner = tunnel_root
	walls.add_to_group("nav_source", true)

	var water := Node3D.new()
	water.name = "Water"
	tunnel_root.add_child(water)
	water.owner = tunnel_root

	# ---- FLOORS: cx, cz, size_x, size_z (thin, top at y=0) ----
	var fl := [
		["Hub", 0, 0, 8, 8],
		["WestCorridor", -13, 0, 5, 31],
		["EastCorridor", 13, 0, 5, 31],
		["NorthCorridor", 0, -13, 31, 5],
		["SouthCorridor", 0, 13, 31, 5],
		["CrossCorridor", 0, 0, 31, 5],
		["StartRoom", -13, -20, 8, 8],
		["StartConnector", -12.25, -13.5, 6.5, 6],
		["FloodedRoom", 22, 0, 8, 8],
		["FloodedConnector", 16.25, 0, 4.5, 5],
	]
	for f in fl:
		_box(floors, f[0], floor_mat, f[1], f[2], f[3], f[4], -0.25, 0.5)

	# ---- WALLS: cx, cz, size_x, size_z (3.5 tall, 0.5 thick) ----
	var wl := [
		# Outer ring perimeter
		["OuterW", -15.5, -0.25, 0.5, 31.5],
		["OuterS", 0, 15.5, 31, 0.5],
		["OuterE_N", 15.5, (-15.5 - CHOKE_HALF) / 2.0, 0.5, 15.5 - CHOKE_HALF],
		["OuterE_S", 15.5, (15.5 + CHOKE_HALF) / 2.0, 0.5, 15.5 - CHOKE_HALF],
		["OuterN", 3.25, -15.5, 24.5, 0.5],
		# Start room
		["StartW", -17, -20, 0.5, 8],
		["StartS", -13, -24, 8, 0.5],
		["StartE", -9, -19.75, 0.5, 8.5],
		["StartN_left", -16.25, -16, 1.5, 0.5],
		# Flooded dead-end
		["FloodW_n", 18, -3.25, 0.5, 1.5],
		["FloodW_s", 18, 3.25, 0.5, 1.5],
		["FloodN", 22, -4, 8, 0.5],
		["FloodS", 22, 4, 8, 0.5],
		["FloodE", 26, 0, 0.5, 8],
		["FloodConnN", 16.75, 2.5, 2.5, 0.5],
		["FloodConnS", 16.75, -2.5, 2.5, 0.5],
		# North hole (between ring and cross), hub bulge carved out
		["Hn1", 0, -10.5, 21, 0.5],
		["Hn2", 10.5, -6.5, 0.5, 8],
		["Hn3", 7.25, -2.5, 6.5, 0.5],
		["Hn4", 4, -3.25, 0.5, 1.5],
		["Hn5", 0, -4, 8, 0.5],
		["Hn6", -4, -3.25, 0.5, 1.5],
		["Hn7", -7.25, -2.5, 6.5, 0.5],
		["Hn8", -10.5, -6.5, 0.5, 8],
		# South hole (mirror of north)
		["Hs1", 0, 10.5, 21, 0.5],
		["Hs2", 10.5, 6.5, 0.5, 8],
		["Hs3", 7.25, 2.5, 6.5, 0.5],
		["Hs4", 4, 3.25, 0.5, 1.5],
		["Hs5", 0, 4, 8, 0.5],
		["Hs6", -4, 3.25, 0.5, 1.5],
		["Hs7", -7.25, 2.5, 6.5, 0.5],
		["Hs8", -10.5, 6.5, 0.5, 8],
	]
	for w in wl:
		_box(walls, w[0], wall_mat, w[1], w[2], w[3], w[4], 1.75, 3.5)

	# ---- WATER: visual-only translucent plane in the flooded dead-end ----
	var wm := MeshInstance3D.new()
	wm.name = "WaterPlane"
	var wbox := BoxMesh.new()
	wbox.size = Vector3(7.2, 0.1, 7.2)
	wm.mesh = wbox
	wm.material_override = water_mat
	wm.position = Vector3(22, 0.3, 0)
	water.add_child(wm)
	wm.owner = tunnel_root

	var packed := PackedScene.new()
	packed.pack(tunnel_root)
	var err := ResourceSaver.save(packed, "res://tunnel.tscn")
	print("save tunnel.tscn err=%d floors=%d walls=%d" % [err, fl.size(), wl.size()])
	quit()


func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


func _box(parent: Node3D, n: String, mat: StandardMaterial3D, cx: float, cz: float,
		sx: float, sz: float, cy: float, sy: float) -> void:
	var body := StaticBody3D.new()
	body.name = n
	parent.add_child(body)
	body.owner = tunnel_root
	body.position = Vector3(cx, cy, cz)
	body.scale = Vector3(sx, sy, sz)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = unit_box
	mi.material_override = mat
	body.add_child(mi)
	mi.owner = tunnel_root
	var cs := CollisionShape3D.new()
	cs.name = "Col"
	cs.shape = unit_shape
	body.add_child(cs)
	cs.owner = tunnel_root
