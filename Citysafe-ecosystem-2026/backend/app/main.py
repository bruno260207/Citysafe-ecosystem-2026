from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import Base, engine, get_db
from app import schemas, crud
from app.auth import create_token, verify_password, get_current_user
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.openapi.utils import get_openapi

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="CitySafe - Sistema de Monitoreo Urbano",
    description="""
API para la gestión de incidentes urbanos y alertas de seguridad ciudadana.

Este sistema permite a los ciudadanos reportar incidentes en tiempo real y a las autoridades
visualizar la información para una mejor toma de decisiones.

**Funcionalidades principales:**
* **Usuarios:** Registro y autenticación mediante JWT.
* **Incidentes:** Reporte de robos, emergencias y actividades sospechosas.
* **Geolocalización:** Los incidentes incluyen latitud y longitud.
* **Visualización:** Datos listos para integrarse con mapas y simuladores.

**Objetivo:**
Optimizar la respuesta ante incidentes y mejorar el patrullaje urbano mediante análisis de datos.
""",
    version="1.0.0",
    terms_of_service="http://citysafe.com/terms/",
    contact={
        "name": "Soporte Técnico CitySafe",
        "url": "http://citysafe.com",
        "email": "soporte@citysafe.com",
    },
    license_info={
        "name": "MIT",
        "url": "https://opensource.org/licenses/MIT",
    },
)

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        terms_of_service=app.terms_of_service,
        contact=app.contact,
        license_info=app.license_info,
        routes=app.routes,
    )
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer"
        }
    }
    for path, methods in openapi_schema["paths"].items():
        for method, details in methods.items():
            if path not in ["/register", "/login"]:
                details["security"] = [{"BearerAuth": []}]
    
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi

origins = [
    "http://localhost:3000",  # frontend
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 👤 REGISTER
@app.post(
    "/register",
    status_code=201,
    tags=["Autenticación"],
    summary="Registrar un nuevo usuario",
    description="Crea una cuenta de usuario en el sistema usando email y contraseña."
)
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):

    existing = crud.get_user_by_email(db, user.email)
    if existing:
        raise HTTPException(status_code=400, detail="Usuario ya existe")

    crud.create_user(db, user.email, user.password)
    return {"msg": "Usuario creado", "email": user.email}

# 🔐 LOGIN
@app.post(
    "/login",
    status_code=200,
    tags=["Autenticación"],
    summary="Iniciar sesión",
    description="Verifica las credenciales del usuario y retorna un token JWT para autenticación."
)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):

    db_user = crud.get_user_by_email(db, form_data.username)

    if not db_user or not verify_password(form_data.password, db_user.hashed_password):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")

    token = create_token({"sub": str(db_user.id)})

    return {"access_token": token, "token_type": "bearer"}

# 🚨 CREATE INCIDENT
@app.post(
    "/incidents",
    status_code=201,
    tags=["Incidentes"],
    summary="Registrar un incidente",
    description="Crea un nuevo incidente asociado al usuario autenticado.",
    response_model=schemas.IncidentResponse
)
def create_incident(
    incident: schemas.IncidentCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    return crud.create_incident(db, incident, current_user.id)

# 📡 GET INCIDENTS
@app.get(
    "/incidents",
    status_code=200,
    tags=["Incidentes"],
    summary="Obtener lista de incidentes",
    description="Retorna todos los incidentes registrados en el sistema.",
    response_model=list[schemas.IncidentResponse]
)
def get_incidents(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    return crud.get_incidents(db)