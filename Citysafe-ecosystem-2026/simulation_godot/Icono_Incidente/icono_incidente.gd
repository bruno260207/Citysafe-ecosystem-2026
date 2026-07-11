extends Node2D
# IconoIncidente.gd
# Estructura de la escena:
#   IconoIncidente (Node2D, con este script)
#     └── Sprite2D (hijo, sin textura fija -- se asigna por codigo)
#
# Aparece con un pequeno "pop", se mantiene visible unos segundos, y se desvanece solo.

@onready var sprite: Sprite2D = $Sprite2D

# Une cada tipo de incidente (segun backend/app/schemas.py -> IncidentType)
# con su imagen. Cambia las rutas por donde guardes tus iconos.
const TEXTURAS := {
	"robo":       preload("res://Imagenes/Iconos/robo.png"),
	"sospechoso": preload("res://Imagenes/Iconos/sospechoso.png"),
	"accidente":  preload("res://Imagenes/Iconos/accidente.png"),
	"otros":      preload("res://Imagenes/Iconos/otros.png"),
}

const DURACION_VISIBLE := 3.0   # segundos que se mantiene antes de desvanecerse
const DURACION_FADE := 0.8      # segundos que tarda en desaparecer
const TAMANO_DESEADO_PX := 36.0 # ancho final deseado en pantalla, sin importar la resolucion del PNG original

var _escala_objetivo: float = 1.0
var _tiempo: float = 0.0


func configurar(tipo: String) -> void:
	var textura: Texture2D = TEXTURAS.get(tipo, TEXTURAS["otros"])
	sprite.texture = textura

	# Escala automatica: TAMANO_DESEADO_PX / ancho real de la imagen
	var ancho_real: float = float(textura.get_width())
	_escala_objetivo = TAMANO_DESEADO_PX / ancho_real

	sprite.scale = Vector2.ZERO
	sprite.modulate.a = 1.0


func _ready() -> void:
	set_process(true)
	# Animacion de aparicion ("pop") usando un Tween
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", Vector2.ONE * _escala_objetivo, 0.25)


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= DURACION_VISIBLE:
		var t_fade: float = (_tiempo - DURACION_VISIBLE) / DURACION_FADE
		sprite.modulate.a = clamp(1.0 - t_fade, 0.0, 1.0)
		if sprite.modulate.a <= 0.0:
			queue_free()
