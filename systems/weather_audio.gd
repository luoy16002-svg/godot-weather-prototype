extends Node
## Layered weather audio, synthesised at startup so the prototype ships with no sound files:
##   light rain hiss + heavy rain roar (crossfaded by intensity), wind (volume and pitch follow the
##   gusting wind), and thunder (near strikes get a sharp crack; distance lowers the volume and the
##   low-pass cutoff, so far thunder is a soft rumble). Each layer has its own bus for mixing.

@export var wind_system: Node

const RATE := 22050

var _rain_light := AudioStreamPlayer.new()
var _rain_heavy := AudioStreamPlayer.new()
var _wind := AudioStreamPlayer.new()
var _thunder_near: AudioStreamWAV
var _thunder_far: AudioStreamWAV
var _thunder_filter := AudioEffectLowPassFilter.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1234
	_make_bus("Rain", [])
	_make_bus("Wind", [])
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.9
	reverb.wet = 0.35
	_make_bus("Thunder", [_thunder_filter, reverb])

	_setup(_rain_light, _loop(_rain(0.35, 6.0), 3.0), "Rain")
	_setup(_rain_heavy, _loop(_rain(0.85, 26.0), 3.0), "Rain")
	_setup(_wind, _loop(_wind_noise(), 6.0), "Wind")
	_thunder_near = _wav(_thunder(true))
	_thunder_far = _wav(_thunder(false))
	Weather.thunder_arrived.connect(play_thunder)


func _process(_delta: float) -> void:
	var r := Weather.rain
	_rain_light.volume_db = linear_to_db(clampf(r * 1.6, 0.0, 1.0) * (1.0 - smoothstep(0.5, 1.0, r) * 0.6) + 0.0001)
	_rain_heavy.volume_db = linear_to_db(smoothstep(0.35, 1.0, r) * 0.9 + 0.0001)
	var w: float = (wind_system.current.length() / Weather.MAX_WIND_SPEED) if wind_system else Weather.wind
	_wind.volume_db = linear_to_db(clampf(w * 1.1, 0.0, 1.0) * 0.8 + 0.0001)
	_wind.pitch_scale = 0.75 + w * 0.6


func play_thunder(distance_m: float) -> void:
	var near := distance_m < 1200.0
	var p := AudioStreamPlayer.new()
	p.stream = _thunder_near if near else _thunder_far
	p.bus = "Thunder"
	var k := clampf(distance_m / 5000.0, 0.0, 1.0)
	p.volume_db = lerpf(0.0, -16.0, k)
	p.pitch_scale = _rng.randf_range(0.85, 1.1)
	_thunder_filter.cutoff_hz = lerpf(5000.0, 380.0, pow(k, 0.6))
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# ---------------------------------------------------------------- synthesis

func _make_bus(bus_name: String, effects: Array) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	for e in effects:
		AudioServer.add_bus_effect(i, e)


func _setup(player: AudioStreamPlayer, stream: AudioStreamWAV, bus_name: String) -> void:
	player.stream = stream
	player.bus = bus_name
	player.volume_db = -80.0
	player.autoplay = true
	add_child(player)


## Rain: high-passed white noise (the hiss) plus random droplet ticks. `body` shifts energy lower.
func _rain(body: float, ticks_per_s: float) -> PackedFloat32Array:
	var n := int(RATE * 3.3)
	var out := PackedFloat32Array(); out.resize(n)
	var lp := 0.0; var hp_prev := 0.0; var hp := 0.0
	var a := lerpf(0.55, 0.25, body)
	for i in n:
		var white := _rng.randf_range(-1.0, 1.0)
		lp += a * (white - lp)                      # low-pass: softens the hiss
		hp = 0.97 * (hp + lp - hp_prev); hp_prev = lp  # high-pass: removes rumble
		out[i] = hp * 0.6
	var ticks := int(ticks_per_s * n / RATE)
	for _k in ticks:
		var at := _rng.randi_range(0, n - 400)
		var amp := _rng.randf_range(0.2, 0.7)
		for j in 300:
			out[at + j] += amp * exp(-j / 40.0) * _rng.randf_range(-1.0, 1.0)
	return out


## Wind: brown noise (integrated white), band-limited, with a slow swell.
func _wind_noise() -> PackedFloat32Array:
	var n := int(RATE * 6.3)
	var out := PackedFloat32Array(); out.resize(n)
	var brown := 0.0; var lp := 0.0
	for i in n:
		brown = clampf(brown + _rng.randf_range(-1.0, 1.0) * 0.04, -1.0, 1.0) * 0.998
		lp += 0.08 * (brown - lp)
		var swell := 0.65 + 0.35 * sin(TAU * i / (RATE * 6.3 / 2.0))
		out[i] = (brown - lp * 0.5) * swell * 1.6
	return out


## Thunder: optional sharp crack, then a rolling low rumble that decays over ~6 s.
func _thunder(crack: bool) -> PackedFloat32Array:
	var n := int(RATE * 6.5)
	var out := PackedFloat32Array(); out.resize(n)
	var brown := 0.0; var lp := 0.0
	var rolls: Array[float] = []
	for _k in 5:
		rolls.append(_rng.randf_range(0.2, 4.0))
	for i in n:
		var t := float(i) / RATE
		brown = clampf(brown + _rng.randf_range(-1.0, 1.0) * 0.06, -1.0, 1.0)
		lp += 0.03 * (brown - lp)
		var env := (1.0 - exp(-t * 12.0)) * exp(-t * 0.55)
		for r in rolls:
			env += 0.5 * exp(-pow((t - r) * 3.0, 2.0))
		var s := lp * env * 2.2
		if crack and t < 0.35:
			s += _rng.randf_range(-1.0, 1.0) * exp(-t * 18.0) * 0.9
		out[i] = s
	return out


func _loop(samples: PackedFloat32Array, seconds: float) -> AudioStreamWAV:
	# Crossfade the extra tail into the head so the loop point is seamless.
	var length := int(RATE * seconds)
	var fade := samples.size() - length
	var out := samples.slice(0, length)
	for i in fade:
		var w := float(i) / fade
		out[i] = samples[i] * w + samples[length + i] * (1.0 - w)
	var wav := _wav(out)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = length
	return wav


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for s in samples:
		peak = maxf(peak, absf(s))
	var bytes := PackedByteArray(); bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
