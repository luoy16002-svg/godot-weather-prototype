extends Node3D
## Deliberately simple placeholder environment: ground, trees, a few houses and a flag. Everything
## that should react to weather uses the shared shaders, so final art can swap in the same way.

const FOLIAGE := preload("res://shaders/foliage.gdshader")
const GROUND := preload("res://shaders/ground.gdshader")
const FLAG := preload("res://shaders/flag.gdshader")

var flag_pivot: Node3D


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_ground()
	for i in 90:
		var r := rng.randf_range(12.0, 95.0)
		var a := rng.randf() * TAU
		_tree(Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(0.7, 1.4), rng)
	for p in [Vector3(-9, 0, 6), Vector3(10, 0, -7), Vector3(-4, 0, -14)]:
		_house(p, rng)
	_flag(Vector3(4, 0, 5))


func _ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(400, 400)
	mesh.subdivide_width = 4
	mesh.subdivide_depth = 4
	var mat := ShaderMaterial.new()
	mat.shader = GROUND
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.noise = FastNoiseLite.new()
	(noise.noise as FastNoiseLite).frequency = 0.02
	mat.set_shader_parameter("puddle_noise", noise)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	add_child(inst)


func _foliage(color: Color, stiffness: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("stiffness", stiffness)
	return m


func _tree(pos: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * s
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12; cyl.bottom_radius = 0.2; cyl.height = 3.0
	trunk.mesh = cyl
	trunk.position.y = 1.5
	trunk.material_override = _foliage(Color(0.33, 0.24, 0.16), 1.0)
	tree.add_child(trunk)
	# Canopy as a separate mesh whose origin sits at ground level, so bending grows with height.
	var canopy := MeshInstance3D.new()
	if rng.randf() < 0.5:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0; cone.bottom_radius = 1.4; cone.height = 4.0
		canopy.mesh = cone
		canopy.position.y = 0.0
		canopy.mesh = _offset_mesh(cone, 4.2)
		canopy.material_override = _foliage(Color(0.17, 0.34, 0.2), 1.0)
	else:
		var ball := SphereMesh.new()
		ball.radius = 1.5; ball.height = 3.0
		canopy.mesh = _offset_mesh(ball, 4.0)
		canopy.material_override = _foliage(Color(0.26, 0.45, 0.2), 1.0)
	tree.add_child(canopy)
	add_child(tree)


## Moves a primitive's vertices up so its local origin is at the tree's base.
func _offset_mesh(src: PrimitiveMesh, lift: float) -> ArrayMesh:
	var arrays := src.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i].y += lift
	arrays[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _house(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(rng.randf_range(4, 6), 3.0, rng.randf_range(4, 6))
	body.mesh = box
	body.position = pos + Vector3(0, 1.5, 0)
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.82, 0.78, 0.7)
	body.material_override = wall
	add_child(body)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(box.size.x + 0.6, 1.6, box.size.z + 0.6)
	roof.mesh = prism
	roof.position = pos + Vector3(0, 3.8, 0)
	var tile := StandardMaterial3D.new()
	tile.albedo_color = Color(0.45, 0.2, 0.16)
	roof.material_override = tile
	add_child(roof)


func _flag(pos: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05; cyl.bottom_radius = 0.06; cyl.height = 7.0
	pole.mesh = cyl
	pole.position = pos + Vector3(0, 3.5, 0)
	add_child(pole)
	flag_pivot = Node3D.new()
	flag_pivot.position = pos + Vector3(0, 6.3, 0)
	add_child(flag_pivot)
	var cloth := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.4, 1.4)
	plane.orientation = PlaneMesh.FACE_Z
	plane.subdivide_width = 24
	plane.subdivide_depth = 8
	cloth.mesh = plane
	cloth.position = Vector3(1.2, 0, 0)   # hinge on the pole side
	var mat := ShaderMaterial.new()
	mat.shader = FLAG
	cloth.material_override = mat
	flag_pivot.add_child(cloth)


func _process(delta: float) -> void:
	# The flag streams down-wind: its +X axis turns toward the wind vector.
	var w := Weather.wind_vector()
	if flag_pivot and w.length() > 0.2:
		var target := atan2(-w.z, w.x)
		flag_pivot.rotation.y = lerp_angle(flag_pivot.rotation.y, target, 1.0 - exp(-delta * 1.2))
