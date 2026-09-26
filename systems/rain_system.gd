extends Node3D
## Rain streaks and ground splashes around the camera. Density follows Weather.rain through
## amount_ratio (no particle restart), and the streaks slant with the wind. Also drives the
## global "wetness" shader value, which rises with rain and dries slowly afterwards.

const MAX_DROPS := 9000
const AREA := 70.0
const DROP_SPEED := 18.0
const WET_RATE := 0.08   # per second while raining hard
const DRY_RATE := 0.015  # per second once the rain stops

@export var follow: Node3D

var wetness := 0.0
var _drops: GPUParticles3D
var _splashes: GPUParticles3D
var _drop_material: ParticleProcessMaterial


func _ready() -> void:
	_drops = GPUParticles3D.new()
	_drops.amount = MAX_DROPS
	_drops.lifetime = 1.6
	_drops.preprocess = 1.6
	_drops.visibility_aabb = AABB(Vector3(-AREA, -40, -AREA), Vector3(AREA * 2, 80, AREA * 2))
	_drop_material = ParticleProcessMaterial.new()
	_drop_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_drop_material.emission_box_extents = Vector3(AREA * 0.5, 1.0, AREA * 0.5)
	_drop_material.direction = Vector3.DOWN
	_drop_material.spread = 2.0
	_drop_material.initial_velocity_min = DROP_SPEED * 0.9
	_drop_material.initial_velocity_max = DROP_SPEED * 1.1
	_drop_material.gravity = Vector3.ZERO
	_drop_material.particle_flag_align_y = true
	_drops.process_material = _drop_material
	var streak := BoxMesh.new()
	streak.size = Vector3(0.015, 0.55, 0.015)
	var streak_mat := StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_mat.albedo_color = Color(0.78, 0.84, 0.92, 0.35)
	streak.material = streak_mat
	_drops.draw_pass_1 = streak
	_drops.position = Vector3(0, 26, 0)
	add_child(_drops)

	_splashes = GPUParticles3D.new()
	_splashes.amount = 2500
	_splashes.lifetime = 0.28
	_splashes.visibility_aabb = AABB(Vector3(-AREA, -2, -AREA), Vector3(AREA * 2, 4, AREA * 2))
	var splash_mat := ParticleProcessMaterial.new()
	splash_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	splash_mat.emission_box_extents = Vector3(AREA * 0.35, 0.0, AREA * 0.35)
	splash_mat.direction = Vector3.UP
	splash_mat.spread = 35.0
	splash_mat.initial_velocity_min = 1.0
	splash_mat.initial_velocity_max = 2.2
	splash_mat.gravity = Vector3(0, -9.8, 0)
	splash_mat.scale_min = 0.5
	splash_mat.scale_max = 1.0
	_splashes.process_material = splash_mat
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	dot.radial_segments = 4
	dot.rings = 2
	dot.material = streak_mat
	_splashes.draw_pass_1 = dot
	_splashes.position = Vector3(0, 0.03, 0)
	add_child(_splashes)

	Weather.changed.connect(_apply)
	_apply()


func _apply() -> void:
	_drops.amount_ratio = Weather.rain
	_splashes.amount_ratio = Weather.rain
	_drops.emitting = Weather.rain > 0.0
	_splashes.emitting = Weather.rain > 0.0
	# Falling drops carried by the wind: the velocity direction tilts toward the wind vector.
	var fall := Vector3.DOWN * DROP_SPEED + Weather.wind_vector() * 0.6
	_drop_material.direction = fall.normalized()


func _process(delta: float) -> void:
	if follow:
		var p := follow.global_position
		global_position = Vector3(p.x, 0.0, p.z)
		# Spawn up-wind so the slanted rain still covers the view.
		_drops.position = Vector3(0, 26, 0) - Weather.wind_vector() * 0.6 * (26.0 / DROP_SPEED)
	var target := Weather.rain
	wetness = move_toward(wetness, target, (WET_RATE * Weather.rain if target > wetness else DRY_RATE) * delta)
	RenderingServer.global_shader_parameter_set("wetness", wetness)
