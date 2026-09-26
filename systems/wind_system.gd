extends Node
## Turns Weather.wind into a living wind: slow gusts on top of the base speed, smoothed so a
## slider change eases in. Publishes the result as the global shader value "wind" (vec3, m/s),
## which foliage and flags read, and exposes `current` for scripts (audio, flags, debris).

var current := Vector3.ZERO
var gust := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.08
	_noise.seed = 7


func _process(delta: float) -> void:
	_t += delta
	gust = _noise.get_noise_1d(_t) * 0.5 + 0.5          # 0..1, a few seconds per gust
	var base := Weather.wind_vector()
	var target := base * (0.75 + gust * 0.55)
	current = current.lerp(target, 1.0 - exp(-delta * 1.5))
	RenderingServer.global_shader_parameter_set("wind", current)
