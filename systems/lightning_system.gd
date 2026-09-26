extends Node3D
## Schedules strikes (Poisson-like, from Weather.lightning_per_minute) and draws each one:
## a jagged bolt, a sky/sun flash scaled by distance, and a short flicker. Thunder is not played
## here: Weather.strike() emits thunder_arrived after distance / speed of sound.

@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment

const MIN_DISTANCE := 250.0
const MAX_DISTANCE := 5000.0

var _next_in := 5.0
var _flash := 0.0          # 0..1 current flash brightness
var _flicker: Array[float] = []
var _bolt: MeshInstance3D
var _bolt_mesh := ImmediateMesh.new()
var _bolt_time := 0.0


func _ready() -> void:
	_bolt = MeshInstance3D.new()
	_bolt.mesh = _bolt_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.93, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.85, 1.0)
	mat.emission_energy_multiplier = 8.0
	mat.disable_fog = true   # a bolt 3 km away must still read through the rain haze
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt.material_override = mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bolt)
	Weather.lightning_struck.connect(_on_strike)


func _process(delta: float) -> void:
	if Weather.auto_lightning and Weather.lightning_per_minute > 0.0:
		_next_in -= delta
		if _next_in <= 0.0:
			strike_random()
			var mean := 60.0 / Weather.lightning_per_minute
			_next_in = -log(maxf(randf(), 0.001)) * mean   # exponential gaps feel natural
	# Flash decays fast; queued flickers re-light it a few times like a real multi-stroke bolt.
	_flash = maxf(_flash - delta * 6.0, 0.0)
	if not _flicker.is_empty():
		_flicker[0] -= delta
		if _flicker[0] <= 0.0:
			_flicker.pop_front()
			_flash = maxf(_flash, randf_range(0.5, 1.0) * _last_strength)
	_bolt_time -= delta
	_bolt.visible = _bolt_time > 0.0 and _flash > 0.05


var _last_strength := 1.0


func strike_random(distance: float = -1.0) -> void:
	if distance < 0.0:
		# More distant strikes are more common, like a storm on the horizon.
		distance = lerpf(MIN_DISTANCE, MAX_DISTANCE, pow(randf(), 1.6))
	var angle := randf() * TAU
	var here := Weather.listener_position
	Weather.strike(Vector3(here.x + sin(angle) * distance, 0.0, here.z + cos(angle) * distance))


func flash_level() -> float:
	return _flash


func _on_strike(pos: Vector3, distance: float) -> void:
	_last_strength = clampf(1.6 - distance / MAX_DISTANCE * 1.3, 0.3, 1.0)
	_flash = _last_strength
	_flicker.assign([0.07, 0.09, 0.12].slice(0, randi_range(1, 3)))
	_build_bolt(pos, distance)
	_bolt_time = 0.35


func _build_bolt(pos: Vector3, distance: float) -> void:
	_bolt_mesh.clear_surfaces()
	var top := 600.0 + distance * 0.05
	var width := 0.006 * distance + 1.5
	var segments := 26
	var points: Array[Vector3] = []
	for i in segments + 1:
		var t := float(i) / segments
		var jitter := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (18.0 + distance * 0.004) * sin(t * PI)
		points.append(pos + Vector3(0, top * (1.0 - t), 0) + jitter)
	_bolt_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var to_cam := (Weather.listener_position - pos).normalized()
	var side := to_cam.cross(Vector3.UP).normalized() * width
	for i in segments:
		var a := points[i]
		var b := points[i + 1]
		for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
			_bolt_mesh.surface_add_vertex(v)
	_bolt_mesh.surface_end()
