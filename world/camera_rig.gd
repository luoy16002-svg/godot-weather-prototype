extends Node3D
## Orbit camera: right-drag (or left-drag outside the panel) to look around, wheel to zoom.
## It also reports its position to Weather so thunder delay is measured from the viewer.

@export var distance := 26.0
@export var yaw := -35.0
@export var pitch := -14.0

var camera := Camera3D.new()
var _dragging := false


func _ready() -> void:
	camera.fov = 65.0
	camera.far = 8000.0
	add_child(camera)
	_update()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_LEFT]:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = maxf(distance * 0.9, 6.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = minf(distance * 1.1, 90.0)
		_update()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.25
		pitch = clampf(pitch - mm.relative.y * 0.2, -60.0, 8.0)
		_update()


func _update() -> void:
	rotation_degrees = Vector3(pitch, yaw, 0)
	camera.position = Vector3(0, 0, distance)
	position = Vector3(0, 4.0, 0)


func _process(_delta: float) -> void:
	Weather.listener_position = camera.global_position
