# CitySafe Ecosystem 2026 🛡️

Sistema de Monitoreo Urbano y Gestión de Alertas de Seguridad Ciudadana.

Permite a los ciudadanos reportar incidentes urbanos (robos, emergencias, actos sospechosos) 
con geolocalización en tiempo real, visualizar zonas de riesgo en un mapa de calor interactivo,
y a las autoridades gestionar y atender los incidentes desde una central de mando.

## Tecnologías

| Capa | Tecnología |
|------|-----------|
| Backend | Python, FastAPI, SQLAlchemy, SQLite, JWT |
| Frontend | Flutter (Web y Android) |
| IoT | Python, MQTT, paho-mqtt |
| Simulación 3D | Godot Engine 4.x |
| Contenedores | Docker, Docker Compose |

## Estructura del proyecto

Citysafe-ecosystem-2026/Citysafe-ecosystem-2026
├── backend/          ← API REST con FastAPI
├── mobile/           ← App Flutter
├── iot_industrial/   ← Simulador IoT y MQTT Bridge
├── simulation_godot/ ← Simulación 3D en Godot
├── docker-compose.yml
└── README.md

## Credenciales por defecto

| Usuario | Email | Contraseña | Rol |
|---------|-------|-----------|-----|
| Central de mando | central@citysafe.com | central123 | central |
| Dispositivo IoT | iot@citysafe.com | iot123 | ciudadano |
| Ciudadano | Registrarse desde la app | - | ciudadano |

---

## Opción A — Sin Docker (manual)

### Requisitos previos
- Python 3.10+
- Flutter SDK 3.x
- Git

### 1. Clonar el repositorio
```bash
git clone https://github.com/bruno260207/Citysafe-ecosystem-2026.git
cd Citysafe-ecosystem-2026/Citysafe-ecosystem-2026
```

### 2. Correr el Backend
```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```
✅ La API estará disponible en: `http://localhost:8000`  
✅ Swagger UI en: `http://localhost:8000/docs`

### 3. Correr el Frontend Flutter
Abre una nueva terminal:
```bash
cd Citysafe-ecosystem-2026
cd mobile
flutter pub get
flutter run -d chrome
```
✅ La app abrirá automáticamente en Chrome.

### ⚠️ Importante antes de correr el Bridge sin Docker

Abre `iot_industrial/mqtt_bridge.py` y cambia esta línea:

```python
# Cambia esto:
BASE_URL = os.environ.get("API_URL", "http://backend:8000/")

# Por esto:
BASE_URL = os.environ.get("API_URL", "http://localhost:8000")
```

> Esto es necesario porque `http://backend:8000` solo funciona dentro de Docker.
> Con Docker (Opción B) no necesitas hacer este cambio.

### 4. Correr el MQTT Bridge (IoT)
Abre una nueva terminal:
```bash
cd Citysafe-ecosystem-2026
cd iot_industrial
python mqtt_bridge.py
```
✅ El bridge se conectará al broker MQTT y comenzará a escuchar incidentes.

### 5. Correr el Simulador IoT
Abre una nueva terminal:
```bash
cd Citysafe-ecosystem-2026
cd iot_industrial
python station_sim.py
```
Elige el modo de simulación:
- `[1]` Simulación continua (reporte cada 5 segundos)
- `[2]` Activación masiva (10 incidentes de golpe)
- `[3]` Activación masiva personalizada

### 6. Simulación 3D (Godot)
1. Descarga Godot Engine 4.x desde https://godotengine.org/download
2. Abre Godot → Import → selecciona la carpeta `simulation_godot/`
3. Presiona el botón Play (F5)

### Resumen de terminales

Terminal 1 → uvicorn app.main:app --reload     (backend)
Terminal 2 → flutter run -d chrome             (frontend)
Terminal 3 → python mqtt_bridge.py             (IoT bridge)
Terminal 4 → python station_sim.py             (IoT simulador)
Terminal 5 → simulation_godot/.exe             (Godot 3D)

---

## Opción B — Con Docker

### Requisitos previos
- Docker Desktop instalado y corriendo
- Flutter SDK 3.x
- Git

### 1. Clonar el repositorio
```bash
git clone https://github.com/bruno260207/Citysafe-ecosystem-2026.git
cd Citysafe-ecosystem-2026/Citysafe-ecosystem-2026
```

### 2. Levantar Backend + Bridge con Docker
```bash
docker compose up --build
```
✅ Docker levanta automáticamente el backend y el MQTT bridge juntos.  
✅ La API estará en: `http://localhost:8000`  
✅ Swagger UI en: `http://localhost:8000/docs`

> La primera vez tarda unos minutos en descargar las imágenes. Las siguientes veces es instantáneo.

### 3. Correr el Frontend Flutter
Abre una nueva terminal:
```bash
cd Citysafe-ecosystem-2026
cd mobile
flutter pub get
flutter run -d chrome
```

### 4. Correr el Simulador IoT
Abre una nueva terminal:
```bash
cd Citysafe-ecosystem-2026
cd iot_industrial
python station_sim.py
```

### 5. Simulación 3D (Godot)
1. Descarga Godot Engine 4.x desde https://godotengine.org/download
2. Abre Godot → Import → selecciona la carpeta `simulation_godot/
3. Importante primero correr el backend y el simulador IoT
4. Presiona el botón Play
5. Esperar que se conecte con el MQTT

### Resumen de terminales

Terminal 1 → docker compose up --build    (backend + bridge automático)
Terminal 2 → flutter run -d chrome        (frontend)
Terminal 3 → python station_sim.py        (IoT simulador)
Terminal 4 → simulation_godot/.exe        (Godot 3D)

---

## Funcionalidades

- ✅ Registro e inicio de sesión con JWT
- ✅ Dos roles: Ciudadano y Central de Mando
- ✅ Reporte de incidentes con geolocalización automática (GPS)
- ✅ Categorías: Robo, Incendio, Salud, Sospechoso, Accidente, Otros
- ✅ Niveles de urgencia del 1 al 5
- ✅ Mapa de calor interactivo con zonas de riesgo
- ✅ Notificaciones en tiempo real via SSE
- ✅ Panel de administración para gestionar estados de incidentes
- ✅ Simulación IoT con 8 dispositivos distribuidos por Lima
- ✅ Comunicación MQTT entre dispositivos y backend
- ✅ Simulación 3D en Godot
- ✅ Dockerizado para despliegue fácil

## Integrantes

-Mamani Berrocal Bruno Gabriel
-Cruz Matos Brithny Zolanch de Elizabeth
-Butron Camarena Aldair Gabriel
-Salvador Soberon Jeremy Andres
..
