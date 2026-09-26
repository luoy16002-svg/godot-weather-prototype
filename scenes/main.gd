extends Node3D
## Wires the prototype together. Each system is its own node and only talks to the Weather
## autoload, so adding snow, waves or an external controller means adding one more node here.
##
## Command line (after `--`):
##   --selftest          run logic checks headless and exit with 0/1
##   --capture=<dir>     render clear / rain / storm screenshots into <dir> and exit

const RainSystem := preload("res://systems/rain_system.gd")
const WindSystem := preload("res://systems/wind_system.gd")
const LightningSystem := preload("res://systems/lightning_system.gd")
const AtmosphereSystem := preload("res://systems/atmosphere_system.gd")
const WeatherAudio := preload("res://systems/weather_audio.gd")
const PlaceholderWorld := preload("res://world/placeholder_world.gd")
const CameraRig := preload("res://world/camera_rig.gd")
const ControlPanel := preload("res://ui/control_panel.gd")

var sun := DirectionalLight3D.new()
var env := WorldEnvironment.new()
var rig: Node3D
var rain: Node3D
var wind: Node
var lightning: Node3D
var audio: Node


func _ready() -> void:
	_build_environment()
	add_child(PlaceholderWorld.new())
	rig = CameraRig.new()
	add_child(rig)

	wind = WindSystem.new()
	wind.name = "Wind"
	add_child(wind)
	rain = RainSystem.new()
	rain.name = "Rain"
	rain.follow = rig.camera
	add_child(rain)
	lightning = LightningSystem.new()
	lightning.name = "Lightning"
	lightning.sun = sun
	lightning.environment = env
	add_child(lightning)
	var atmosphere := AtmosphereSystem.new()
	atmosphere.sun = sun
	atmosphere.environment = env
	atmosphere.lightning = lightning
	add_child(atmosphere)
	audio = WeatherAudio.new()
	audio.name = "Audio"
	audio.wind_system = wind
	add_child(audio)
	var panel := ControlPanel.new()
	panel.lightning = lightning
	add_child(panel)

	Weather.apply_preset("Rain")

	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		_selftest.call_deferred()
	for a in args:
		if a.begins_with("--capture="):
			_capture.call_deferred(a.trim_prefix("--capture="))


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_density = 0.002
	e.fog_sky_affect = 0.6
	env.environment = e
	add_child(env)
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)


# ---------------------------------------------------------------- automation

func _selftest() -> void:
	var failures: Array[String] = []   # lambdas capture locals by value, so collect into an array
	var check := func(what: String, pass_: bool) -> void:
		print(("PASS  " if pass_ else "FAIL  ") + what)
		if not pass_:
			failures.append(what)
	check.call("thunder 343 m away arrives after 1.0 s", is_equal_approx(Weather.thunder_delay(343.0), 1.0))
	check.call("thunder 3.43 km away arrives after 10 s", is_equal_approx(Weather.thunder_delay(3430.0), 10.0))
	Weather.rain = 2.0
	check.call("rain is clamped to 0..1", Weather.rain == 1.0)
	Weather.wind_direction = 450.0
	check.call("wind direction wraps to 0..360", is_equal_approx(Weather.wind_direction, 90.0))
	Weather.wind = 0.5
	var v := Weather.wind_vector()
	check.call("wind 50% toward 90° blows +X at 11 m/s", is_equal_approx(v.x, 11.0) and absf(v.z) < 0.001)
	Weather.apply_preset("Storm")
	check.call("Storm preset turns on automatic lightning", Weather.auto_lightning and Weather.lightning_per_minute == 10.0)
	check.call("rain particles scale with intensity", is_equal_approx(rain._drops.amount_ratio, 1.0))
	check.call("rain + wind + thunder audio layers synthesised", audio._rain_light.stream != null and audio._wind.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and audio._thunder_near != null)
	# End to end: a strike 34.3 m away schedules its thunder 0.1 s later and the signal arrives.
	await get_tree().create_timer(0.3).timeout      # let start-up frames settle
	Weather.listener_position = Vector3.ZERO
	var heard: Array[float] = []
	Weather.thunder_arrived.connect(func(d): heard.append(d), CONNECT_ONE_SHOT)
	Weather.strike(Vector3(34.3, 0, 0))
	check.call("strike at 34.3 m schedules thunder 0.10 s later", is_equal_approx(Weather.last_thunder_delay, 0.1))
	await get_tree().create_timer(0.6).timeout
	check.call("thunder_arrived fires once with the strike distance", heard.size() >= 1 and is_equal_approx(heard[0], 34.3))
	print("ALL CHECKS PASSED" if failures.is_empty() else "%d CHECK(S) FAILED" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_tree().root.get_viewport().size = Vector2i(1600, 900)
	for shot in [["Clear", "clear.png", false], ["Rain", "rain.png", false], ["Storm", "storm.png", true]]:
		Weather.apply_preset(shot[0])
		Weather.auto_lightning = false
		rain.wetness = Weather.rain          # skip the slow soak for screenshots
		await get_tree().create_timer(4.0).timeout
		if shot[2]:
			var fwd: Vector3 = -rig.camera.global_transform.basis.z
			fwd.y = 0.0
			var target: Vector3 = rig.camera.global_position + fwd.normalized() * 700.0
			Weather.strike(Vector3(target.x, 0.0, target.z))
			await get_tree().process_frame
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join(shot[1]))
		print("saved ", dir.path_join(shot[1]))
	get_tree().quit(0)
