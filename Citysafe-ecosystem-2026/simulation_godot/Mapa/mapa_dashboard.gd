extends Node2D

@onready var marcadores: Node2D = $Marcadores

var mqtt := MqttNode.new()

const BROKER := "wss://test.mosquitto.org:8081"
const TOPIC := "citysafe/incidentes/#"
const ManchaCalorScene := preload("res://Mancha_De_Calor/mancha_de_calor.tscn")
const IconoIncidenteScene := preload("res://Icono_Incidente/IconoIncidente.tscn")
 
func _ready() -> void:
	mqtt.broker = BROKER
	mqtt.auto_connect = true
 
	mqtt.connecting.connect(func(): print("[Dashboard] Conectando al broker..."))
	mqtt.connecting_failed.connect(func(): print("[Dashboard] Fallo la conexion al broker"))
	mqtt.connected.connect(_on_connected)
	mqtt.disconnected.connect(func(): print("[Dashboard] Desconectado del broker"))
	mqtt.message.connect(_on_msg)
 
	add_child(mqtt)
 
 
func _on_connected() -> void:
	print("[Dashboard] Conectado al Broker MQTT")
	mqtt.subscribe(TOPIC)
 
 
func _on_msg(topic: String, msg: PackedByteArray) -> void:
	var message := msg.get_string_from_utf8()
	var data = JSON.parse_string(message)
	if data == null:
		print("[Dashboard] Mensaje no es JSON valido: ", message)
		return
 
	var partes := topic.split("/")
	var device_id: String = partes[partes.size() - 1]
 
	var urgencia: int = int(data.get("urgency", 1))
	var tipo: String = str(data.get("type", "otros"))
 
	var punto: Node2D = marcadores.get_node_or_null(device_id)
	if punto == null:
		print("[Dashboard] Dispositivo sin marcador calibrado: ", device_id)
		return
 
	print("[Dashboard] Incidente '%s' urgencia %d en %s" % [tipo, urgencia, device_id])
	generar_evento(to_local(punto.global_position), urgencia, tipo)
 
 
func generar_evento(pos: Vector2, urgencia: int, tipo: String) -> void:
	generar_mancha(pos, urgencia)
	generar_icono(pos, tipo)
 
 
func generar_mancha(pos: Vector2, urgencia: int) -> void:
	var mancha = ManchaCalorScene.instantiate()
	add_child(mancha)
	mancha.position = pos
 
	var radio: float = 20.0 + (urgencia * 12.0)
	var duracion: float = 2.5 + (urgencia * 0.3)
	var intensidad: float = clamp(float(urgencia) / 5.0, 0.35, 1.0)
 
	mancha.configurar(radio, duracion, Color(1, 0, 0, intensidad))
 
 
func generar_icono(pos: Vector2, tipo: String) -> void:
	var icono = IconoIncidenteScene.instantiate()
	add_child(icono)
	icono.position = pos
	icono.configurar(tipo)
