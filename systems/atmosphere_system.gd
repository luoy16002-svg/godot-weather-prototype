extends Node
## Sky, sun and fog react to the weather: rain darkens and greys the sky, dims the sun and thickens
## the fog; lightning adds a brief blue-white flash on top.

@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment
@export var lightning: Node  # lightning_system.gd

var _sky: ProceduralSkyMaterial
var _overcast := 0.0

const CLEAR_TOP := Color(0.28, 0.5, 0.82)
const CLEAR_HORIZON := Color(0.68, 0.76, 0.84)
const STORM_TOP := Color(0.12, 0.13, 0.15)
const STORM_HORIZON := Color(0.3, 0.32, 0.34)


func _ready() -> void:
	_sky = (environment.environment.sky.sky_material as ProceduralSkyMaterial)


func _process(delta: float) -> void:
	_overcast = move_toward(_overcast, clampf(Weather.rain * 1.1, 0.0, 1.0), delta * 0.25)
	var flash: float = lightning.flash_level() if lightning else 0.0
	var env := environment.environment
	_sky.sky_top_color = CLEAR_TOP.lerp(STORM_TOP, _overcast).lerp(Color(0.42, 0.44, 0.58), flash * 0.6)
	_sky.sky_horizon_color = CLEAR_HORIZON.lerp(STORM_HORIZON, _overcast).lerp(Color(0.5, 0.52, 0.66), flash * 0.6)
	_sky.ground_horizon_color = _sky.sky_horizon_color
	sun.light_energy = lerpf(1.3, 0.25, _overcast) + flash * 1.6
	sun.shadow_enabled = _overcast < 0.7
	env.ambient_light_energy = lerpf(1.0, 0.55, _overcast) + flash * 0.9
	env.fog_density = lerpf(0.0015, 0.009, _overcast)
	env.fog_light_color = _sky.sky_horizon_color
