import paho.mqtt.client as mqtt
import requests
import json
import time
import threading
import os
# ── CONFIGURACIÓN ──────────────────────────────────────────────────────────────

BROKER = "test.mosquitto.org"
PORT = 1883
TOPIC = "citysafe/incidentes/#"
BASE_URL = os.environ.get("API_URL", "http://backend:8000/")
IOT_EMAIL = "iot@citysafe.com"
IOT_PASSWORD = "iot123"

# Rastrea el último mensaje de cada dispositivo
last_seen = {}
token = None

# ── AUTENTICACIÓN ──────────────────────────────────────────────────────────────

def login() -> str | None:
    print("[Bridge] Autenticando con el backend...")
    try:
        response = requests.post(
            f"{BASE_URL}/login",
            data={"username": IOT_EMAIL, "password": IOT_PASSWORD},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=5
        )
        if response.status_code == 200:
            t = response.json()["access_token"]
            print("[Bridge] ✓ Token obtenido")
            return t
        print(f"[Bridge] ✗ Error al autenticar: {response.status_code}")
        return None
    except Exception as e:
        print(f"[Bridge] ✗ No se pudo conectar: {e}")
        return None

# ── CALLBACK — MENSAJE RECIBIDO ────────────────────────────────────────────────

def on_message(client, userdata, msg):
    global token
    try:
        payload = json.loads(msg.payload.decode())
        device_id = msg.topic.split("/")[-1]
        last_seen[device_id] = time.time()

        print(f"\n[Bridge] 📩 Mensaje de {device_id}: {payload}")

        response = requests.post(
            f"{BASE_URL}/incidents",
            json={
                "type": payload["type"],
                "description": payload["description"],
                "latitude": payload["latitude"],
                "longitude": payload["longitude"],
                "urgency": payload["urgency"],
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        )

        if response.status_code == 201:
            print(f"[Bridge] ✓ Incidente guardado en DB — {payload['type'].upper()} urgencia {payload['urgency']}")
        else:
            print(f"[Bridge] ✗ Error API {response.status_code}: {response.text}")

    except Exception as e:
        print(f"[Bridge] ✗ Error procesando mensaje: {e}")

def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print(f"[Bridge] ✓ Conectado al broker MQTT")
        client.subscribe(TOPIC)
        print(f"[Bridge] Escuchando tópico: {TOPIC}")
    else:
        print(f"[Bridge] ✗ Error de conexión MQTT: {rc}")

# ── MONITOR DE DISPOSITIVOS OFFLINE ───────────────────────────────────────────

def monitor_offline():
    """Detecta dispositivos que dejaron de enviar datos."""
    while True:
        now = time.time()
        for device_id, last_time in list(last_seen.items()):
            segundos = now - last_time
            if segundos > 30:
                print(f"[Bridge] 🚨 ALERTA: Dispositivo {device_id} OFFLINE hace {int(segundos)}s")
        time.sleep(10)

# ── MAIN ───────────────────────────────────────────────────────────────────────

def main():
    global token

    print("=" * 50)
    print("   CitySafe — MQTT Bridge")
    print("   UNMSM FISI 2026")
    print("=" * 50)

    token = login()
    if not token:
        print("[Bridge] Sin token. Verifica el backend.")
        return

    # Hilo de monitoreo de dispositivos offline
    threading.Thread(target=monitor_offline, daemon=True).start()

    # Cliente MQTT
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_message = on_message

    print(f"\n[Bridge] Conectando al broker {BROKER}...")
    client.connect(BROKER, PORT)
    client.loop_forever()

if __name__ == "__main__":
    main()