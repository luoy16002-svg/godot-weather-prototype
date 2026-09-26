extends CanvasLayer
## Local control panel. It only writes to the Weather autoload and mirrors it back, so the same
## values could equally come from a network controller later. H hides it, L strikes lightning.

@export var lightning: Node

var _sliders := {}
var _info := Label.new()
var _panel := PanelContainer.new()
var _auto := CheckBox.new()
var _pending_thunder := -1.0
var _last_distance := 0.0


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.1, 0.82)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(20, 20)
	_panel.custom_minimum_size = Vector2(340, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Weather controls"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	var presets := HBoxContainer.new()
	for p in Weather.PRESETS.keys():
		var b := Button.new()
		b.text = p
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(Weather.apply_preset.bind(p))
		presets.add_child(b)
	box.add_child(presets)

	_add_slider(box, "rain", "Rain intensity", 0.0, 1.0, 0.01)
	_add_slider(box, "wind", "Wind strength", 0.0, 1.0, 0.01)
	_add_slider(box, "wind_direction", "Wind direction", 0.0, 359.0, 1.0)
	_add_slider(box, "lightning_per_minute", "Lightning per minute", 0.0, 30.0, 0.5)

	_auto.text = "Automatic lightning"
	_auto.toggled.connect(func(on: bool): Weather.auto_lightning = on)
	box.add_child(_auto)
	var strike := Button.new()
	strike.text = "Strike now (L)"
	strike.pressed.connect(_strike)
	box.add_child(strike)

	_info.add_theme_color_override("font_color", Color(0.8, 0.86, 0.9))
	box.add_child(_info)
	var hint := Label.new()
	hint.text = "Drag to look around · wheel to zoom · H hides this panel"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.66, 0.7))
	box.add_child(hint)

	Weather.changed.connect(_sync)
	Weather.lightning_struck.connect(_on_strike)
	Weather.thunder_arrived.connect(func(_d): _pending_thunder = -1.0)
	_sync()


func _add_slider(box: VBoxContainer, key: String, label: String, lo: float, hi: float, step: float) -> void:
	var name_label := Label.new()
	box.add_child(name_label)
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = step
	s.custom_minimum_size = Vector2(300, 22)
	s.value_changed.connect(func(v: float): Weather.set(key, v))
	box.add_child(s)
	_sliders[key] = [s, name_label, label]


func _sync() -> void:
	for key in _sliders:
		var s: HSlider = _sliders[key][0]
		var v: float = Weather.get(key)
		s.set_value_no_signal(v)
		var text: String = _sliders[key][2]
		match key:
			"rain", "wind": text += "  %d%%" % roundi(v * 100)
			"wind_direction": text += "  %d°  (%.1f m/s)" % [roundi(v), Weather.wind_vector().length()]
			_: text += "  %.1f" % v
		_sliders[key][1].text = text
	_auto.set_pressed_no_signal(Weather.auto_lightning)


func _strike() -> void:
	if lightning:
		lightning.strike_random()


func _on_strike(_pos: Vector3, distance: float) -> void:
	_last_distance = distance
	_pending_thunder = Weather.thunder_delay(distance)


func _process(delta: float) -> void:
	if _pending_thunder >= 0.0:
		_pending_thunder = maxf(_pending_thunder - delta, 0.0)
		_info.text = "Last strike %.2f km away · thunder in %.1f s" % [_last_distance / 1000.0, _pending_thunder]
	elif _last_distance > 0.0:
		_info.text = "Last strike %.2f km away · thunder heard" % [_last_distance / 1000.0]
	else:
		_info.text = "No lightning yet"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		_panel.visible = not _panel.visible
	elif event.is_action_pressed("strike_now"):
		_strike()
