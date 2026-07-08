extends Camera2D

# --- Zoom ---
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.5

# --- Arrastre (pan) ---
@export var boton_arrastre: MouseButton = MOUSE_BUTTON_RIGHT  # cambia a MOUSE_BUTTON_MIDDLE si prefieres

var _arrastrando := false
var _mouse_anterior := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	# --- Zoom con la rueda del mouse ---
	if event.is_action_pressed("mouse_button_wheel_up"):
		zoom_camera(zoom_speed)
	elif event.is_action_pressed("mouse_button_wheel_down"):
		zoom_camera(-zoom_speed)

	# --- Iniciar / terminar arrastre ---
	if event is InputEventMouseButton:
		if event.button_index == boton_arrastre:
			_arrastrando = event.pressed
			_mouse_anterior = event.position

	# --- Mover la camara mientras se arrastra ---
	if event is InputEventMouseMotion and _arrastrando:
		var delta: Vector2 = event.position - _mouse_anterior
		_mouse_anterior = event.position
		# Dividimos por el zoom para que el movimiento se sienta igual
		# de "rapido" sin importar cuan acercado estes.
		position -= delta / zoom.x


func zoom_camera(amount: float) -> void:
	var target_zoom = zoom.x + amount
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)
	zoom = Vector2(target_zoom, target_zoom)
