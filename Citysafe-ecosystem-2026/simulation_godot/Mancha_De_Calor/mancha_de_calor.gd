extends Node2D

var radio_max: float = 40.0
var duracion: float = 3.0
var color_base: Color = Color(1, 0, 0, 0.6)

var _tiempo: float = 0.0
var _radio_actual: float = 6.0
var _color_actual: Color


func _ready() -> void:
	_color_actual = color_base
	set_process(true)


# Llamar justo después de instanciar la escena, antes de que pase un frame.
func configurar(radio_max_: float, duracion_: float, color_: Color = Color(1, 0, 0, 0.6)) -> void:
	radio_max = radio_max_
	duracion = duracion_
	color_base = color_
	_color_actual = color_base


func _process(delta: float) -> void:
	_tiempo += delta
	var progreso: float = clamp(_tiempo / duracion, 0.0, 1.0)

	# Crecimiento rápido al inicio, luego se estabiliza (efecto "onda de choque")
	_radio_actual = lerp(6.0, radio_max, ease(progreso, 0.3))

	# Se desvanece conforme avanza el tiempo
	_color_actual.a = color_base.a * (1.0 - progreso)

	queue_redraw()

	if progreso >= 1.0:
		queue_free()


func _draw() -> void:
	# Halo exterior, difuso
	draw_circle(Vector2.ZERO, _radio_actual, _color_actual)
	# Núcleo más intenso, simula el centro "caliente" del incidente
	var nucleo_color := Color(_color_actual.r, _color_actual.g, _color_actual.b, min(_color_actual.a * 1.8, 1.0))
	draw_circle(Vector2.ZERO, _radio_actual * 0.35, nucleo_color)
