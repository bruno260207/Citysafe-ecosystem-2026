Sistema de Monitoreo Urbano y Gestión de Alertas de Seguridad
Este proyecto tiene como finalidad permitir a los ciudadanos reportar incidentes (robos, emergencias, actos sospechosos) y que las autoridades puedan visualizar la densidad de estos eventos en un mapa y un simulador 3D para optimizar el patrullaje.

TECNOLOGÍAS UTILIZADAS
Backend: Python con FastAPI y SQLAlchemy
Fronted: Flutter

INSTALACIÓN:
Sigues estos pasos para configurar el proyecto localmente:
1. Clona el repositorio:
   git clone  https://github.com/bruno260207/Citysafe-ecosystem-2026.git

2. Ingresa a la carpeta del proyecto
   cd Citysafe-ecosystem-2026

3. Crea tu entorno virtual
python -m venv venv
venv\Scripts\activate
INSTALA REQUERIMIENTOS
cd Citysafe-ecosystem-2026
pip install -r requirements.txt
uvicorn app.main:app --reload
cd ..
cd mobile
flutter pub get
flutter doctor
flutter run
Escoger que medio usar para correr el programa.

