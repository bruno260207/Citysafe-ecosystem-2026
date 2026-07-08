import paho.mqtt.client as mqtt
import requests
import random
import time
import json
from datetime import datetime

# ── CONFIGURACIÓN ──────────────────────────────────────────────────────────────

BASE_URL = "http://localhost:8000"
IOT_EMAIL = "iot@citysafe.com"
IOT_PASSWORD = "iot123"
BROKER = "test.mosquitto.org"
PORT = 1883
mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
mqtt_client.connect(BROKER, PORT)

# ── DISPOSITIVOS SIMULADOS ─────────────────────────────────────────────────────

DISPOSITIVOS = [
    {"id": "CAM-001", "nombre": "Cámara Plaza Mayor",      "lat": -12.0464, "lng": -77.0428},
    {"id": "CAM-002", "nombre": "Cámara Miraflores",       "lat": -12.1190, "lng": -77.0282},
    {"id": "CAM-003", "nombre": "Cámara San Isidro",       "lat": -12.0971, "lng": -77.0331},
    {"id": "CAM-004", "nombre": "Cámara San Miguel",       "lat": -12.0780, "lng": -77.0819},
    {"id": "POST-001","nombre": "Poste San Borja",          "lat": -12.1028, "lng": -77.0013},
    {"id": "POST-002","nombre": "Poste Surquillo",          "lat": -12.1100, "lng": -77.0200},
    {"id": "POST-003","nombre": "Poste Plaza Norte",          "lat": -12.0072, "lng": -77.0609},
    {"id": "POST-004","nombre": "Poste San Martin",          "lat": -12.0285, "lng": -77.0875},
]

# Tipos de incidentes que puede detectar un dispositivo IoT
TIPOS_INCIDENTE = ["robo", "sospechoso", "accidente", "otros"]

# ── AUTENTICACIÓN ──────────────────────────────────────────────────────────────

def login() -> str | None:
    """Obtiene el token JWT del backend."""
    print(f"\n[IoT] Autenticando como {IOT_EMAIL}...")
    try:
        response = requests.post(
            f"{BASE_URL}/login",
            data={"username": IOT_EMAIL, "password": IOT_PASSWORD},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=5
        )
        if response.status_code == 200:
            token = response.json()["access_token"]
            print("[IoT] ✓ Autenticación exitosa")
            return token
        else:
            print(f"[IoT] ✗ Error al autenticar: {response.status_code}")
            return None
    except Exception as e:
        print(f"[IoT] ✗ No se pudo conectar al backend: {e}")
        return None

# ── REPORTE DE INCIDENTE ───────────────────────────────────────────────────────

def reportar_incidente_mqtt(dispositivo: dict, tipo: str, urgencia: int) -> bool:
    """Publica el incidente en MQTT en vez de llamar al backend directamente."""
    lat = dispositivo["lat"] + random.uniform(-0.002, 0.002)
    lng = dispositivo["lng"] + random.uniform(-0.002, 0.002)

    payload = {
        "type": tipo,
        "description": f"[{dispositivo['id']}] {dispositivo['nombre']} detectó actividad anómala.",
        "latitude": round(lat, 6),
        "longitude": round(lng, 6),
        "urgency": urgencia,
    }

    topic = f"citysafe/incidentes/{dispositivo['id']}"
    mqtt_client.publish(topic, json.dumps(payload))
    print(f"  📡 [{dispositivo['id']}] Publicado en MQTT → {topic}")
    return True

# ── MODO 1: SIMULACIÓN CONTINUA ────────────────────────────────────────────────

def modo_continuo(token:str, intervalo: int = 5):
    """
    Simula dispositivos reportando incidentes aleatoriamente
    cada X segundos de forma indefinida.
    """
    print(f"\n[IoT] Modo continuo activo — reportando cada {intervalo} segundos")
    print("[IoT] Presiona Ctrl+C para detener\n")
    
    reporte_num = 0
    while True:
        reporte_num += 1
        dispositivo = random.choice(DISPOSITIVOS)
        tipo = random.choice(TIPOS_INCIDENTE)
        urgencia = random.randint(1, 5)
        
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Reporte #{reporte_num}")
        reportar_incidente_mqtt(dispositivo, tipo, urgencia)
        
        time.sleep(intervalo)

# ── MODO 2: ACTIVACIÓN MASIVA ──────────────────────────────────────────────────

def modo_masivo(token:str, cantidad: int = 10):
    """
    Simula una activación masiva — todos los dispositivos
    reportan múltiples incidentes de alta urgencia al mismo tiempo.
    Útil para estresar el sistema y probar el mapa de calor.
    """
    print(f"\n[IoT] ⚠ ACTIVACIÓN MASIVA — {cantidad} incidentes en área de Lima")
    print("[IoT] Simulando emergencia urbana...\n")
    
    exitosos = 0
    fallidos = 0
    
    for i in range(cantidad):
        dispositivo = random.choice(DISPOSITIVOS)
        tipo = random.choice(TIPOS_INCIDENTE)
        # En modo masivo la urgencia es alta (3-5)
        urgencia = random.randint(1, 5)
        
        ok = reportar_incidente_mqtt(dispositivo, tipo, urgencia)
        if ok:
            exitosos += 1
        else:
            fallidos += 1
        
        # Pequeña pausa para no saturar el backend
        time.sleep(0.5)
    
    print(f"\n[IoT] Activación masiva completada:")
    print(f"  ✓ Exitosos: {exitosos}")
    print(f"  ✗ Fallidos: {fallidos}")
    print(f"  Total:      {cantidad}")

# ── MENÚ PRINCIPAL ─────────────────────────────────────────────────────────────

def main():
    print("=" * 50)
    print("   CitySafe — Simulador IoT")
    print("   UNMSM FISI 2026")
    print("=" * 50)
    
    # Autenticación
    token = login()
    if not token:
        print("[IoT] No se pudo obtener token. Verifica que el backend esté corriendo.")
        return
    
    # Menú
    print("\n¿Qué modo deseas ejecutar?")
    print("  [1] Simulación continua (reporte cada 5 segundos)")
    print("  [2] Activación masiva (10 incidentes de golpe)")
    print("  [3] Activación masiva personalizada")
    print("  [4] Salir")
    
    opcion = input("\nOpción: ").strip()
    
    if opcion == "1":
        modo_continuo(token, intervalo=5)
    
    elif opcion == "2":
        modo_masivo(token, cantidad=10)
    
    elif opcion == "3":
        try:
            cantidad = int(input("¿Cuántos incidentes? "))
            modo_masivo(token, cantidad=cantidad)
        except ValueError:
            print("[IoT] Número inválido.")
    
    elif opcion == "4":
        print("[IoT] Saliendo...")
    
    else:
        print("[IoT] Opción inválida.")

if __name__ == "__main__":
    main()