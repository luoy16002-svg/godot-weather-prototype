extends Node
## Single source of truth for the weather (autoload "Weather").
## Every system reads these values and listens to the signals, so a new system (snow, waves,
## an external controller over OSC or a socket) only has to talk to this node.

signal changed
## Emitted the instant a bolt is drawn. `distance_m` is measured from the listener.
signal lightning_struck(position: Vector3, distance_m: float)
## Emitted when the sound of a strike reaches the listener (distance / speed of sound later).
signal thunder_arrived(distance_m: float)

const SPEED_OF_SOUND := 343.0  # m/s at ~20 °C
const MAX_WIND_SPEED := 22.0   # m/s at wind = 1.0 (a strong gale)

const PRESETS := {
	"Clear":   {"rain": 0.0,  "wind": 0.12, "wind_direction": 40.0,  "lightning_per_minute": 0.0,  "auto_lightning": false},
	"Drizzle": {"rain": 0.25, "wind": 0.2,  "wind_direction": 70.0,  "lightning_per_minute": 0.0,  "auto_lightning": false},
	"Rain":    {"rain": 0.6,  "wind": 0.45, "wind_direction": 110.0, "lightning_per_minute": 2.0,  "auto_lightning": true},
	"Storm":   {"rain": 1.0,  "wind": 0.85, "wind_direction": 150.0, "lightning_per_minute": 10.0, "auto_lightning": true},
}

## 0 = dry, 1 = torrential.
var rain: float = 0.0:
	set(value):
		rain = clampf(value, 0.0, 1.0)
		changed.emit()
## 0 = still air, 1 = MAX_WIND_SPEED.
var wind: float = 0.1:
	set(value):
		wind = clampf(value, 0.0, 1.0)
		changed.emit()
## Direction the wind blows TOWARD, in degrees (0 = +Z, 90 = +X).
var wind_direction: float = 0.0:
	set(value):
		wind_direction = fposmod(value, 360.0)
		changed.emit()
var lightning_per_minute: float = 0.0:
	set(value):
		lightning_per_minute = clampf(value, 0.0, 30.0)
		changed.emit()
var auto_lightning: bool = false:
	set(value):
		auto_lightning = value
		changed.emit()

## Position the thunder delay is measured from (the camera sets this every frame).
var listener_position := Vector3.ZERO
## Delay scheduled for the most recent strike's thunder, in seconds (handy for UI and tests).
var last_thunder_delay := 0.0


func wind_vector() -> Vector3:
	var a := deg_to_rad(wind_direction)
	return Vector3(sin(a), 0.0, cos(a)) * wind * MAX_WIND_SPEED


static func thunder_delay(distance_m: float) -> float:
	return maxf(distance_m, 0.0) / SPEED_OF_SOUND


func apply_preset(preset_name: String) -> void:
	var p: Dictionary = PRESETS[preset_name]
	rain = p.rain
	wind = p.wind
	wind_direction = p.wind_direction
	lightning_per_minute = p.lightning_per_minute
	auto_lightning = p.auto_lightning


## Announces a strike and schedules its thunder. Systems draw/flash on `lightning_struck`
## and play audio on `thunder_arrived`, so they never need to know about each other.
func strike(position: Vector3) -> void:
	var distance := Vector2(position.x - listener_position.x, position.z - listener_position.z).length()
	last_thunder_delay = thunder_delay(distance)
	lightning_struck.emit(position, distance)
	get_tree().create_timer(last_thunder_delay).timeout.connect(func(): thunder_arrived.emit(distance))
