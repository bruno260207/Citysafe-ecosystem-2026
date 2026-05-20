from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from app.database import Base, engine, get_db
from app import schemas, crud
from app.auth import create_token, verify_password, get_current_user
from app.models import User
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.openapi.utils import get_openapi
import asyncio
import json

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="CitySafe - Sistema de Monitoreo Urbano",
description="""
API para la gestión de incidentes urbanos y alertas de seguridad ciudadana.

**Roles:**
* **ciudadano** — reporta incidentes desde la app móvil.
* **central** — recibe y gestiona los incidentes (admin).

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
    version="2.0.0",
)


def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {"type": "http", "scheme": "bearer"}
    }
    for path, methods in openapi_schema["paths"].items():
        for method, details in methods.items():
            if path not in ["/register", "/login"]:
                details["security"] = [{"BearerAuth": []}]
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Cola SSE en memoria para notificar a la central en tiempo real
_sse_clients: list[asyncio.Queue] = []


async def _broadcast_incident(incident):
    payload = json.dumps({
        "id": incident.id,
        "type": incident.type,
        "description": incident.description,
        "latitude": incident.latitude,
        "longitude": incident.longitude,
        "urgency": incident.urgency,
        "status": incident.status,
        "user_id": incident.user_id,
        "created_at": incident.created_at.isoformat() if incident.created_at else None,
    })
    for queue in list(_sse_clients):
        await queue.put(payload)


@app.on_event("startup")
def startup_event():
    db = next(get_db())
    try:
        crud.seed_admin(db)
    finally:
        db.close()


# ── AUTH ──────────────────────────────────────────────────────────────────────

@app.post("/register", status_code=201, tags=["Autenticación"])
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = crud.get_user_by_email(db, user.email)
    if existing:
        raise HTTPException(status_code=400, detail="Usuario ya existe")
    crud.create_user(db, user.email, user.password, role="ciudadano")
    return {"msg": "Usuario creado", "email": user.email}


@app.post("/login", status_code=200, tags=["Autenticación"])
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, form_data.username)
    if not db_user or not verify_password(form_data.password, db_user.hashed_password):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    token = create_token({"sub": str(db_user.id), "role": db_user.role})
    return {
        "access_token": token,
        "token_type": "bearer",
        "role": db_user.role,
    }


# ── CIUDADANO ─────────────────────────────────────────────────────────────────

@app.post("/incidents", status_code=201, tags=["Incidentes"], response_model=schemas.IncidentResponse)
async def create_incident(
    incident: schemas.IncidentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "ciudadano":
        raise HTTPException(status_code=403, detail="Solo los ciudadanos pueden reportar incidentes")
    new_incident = crud.create_incident(db, incident, current_user.id)
    await _broadcast_incident(new_incident)
    return new_incident


@app.get("/incidents", status_code=200, tags=["Incidentes"], response_model=list[schemas.IncidentResponse])
def get_incidents(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return crud.get_incidents(db)


# ── CENTRAL ───────────────────────────────────────────────────────────────────

def require_central(current_user: User = Depends(get_current_user)):
    if current_user.role != "central":
        raise HTTPException(status_code=403, detail="Acceso restringido a la central")
    return current_user


@app.get("/central/incidents", status_code=200, tags=["Central"], response_model=list[schemas.IncidentDetailResponse])
def central_get_incidents(
    db: Session = Depends(get_db),
    _: User = Depends(require_central),
):
    incidents = crud.get_incidents(db, limit=500)
    result = []
    for inc in incidents:
        data = schemas.IncidentDetailResponse.model_validate(inc)
        data.reporter_email = inc.user.email if inc.user else None
        result.append(data)
    return result


@app.patch("/central/incidents/{incident_id}/status", status_code=200, tags=["Central"], response_model=schemas.IncidentResponse)
def central_update_status(
    incident_id: int,
    body: schemas.IncidentStatusUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_central),
):
    incident = crud.update_incident_status(db, incident_id, body.status)
    if not incident:
        raise HTTPException(status_code=404, detail="Incidente no encontrado")
    return incident


@app.get("/central/stream", tags=["Central"])
async def central_stream(
    request: Request,
    current_user: User = Depends(get_current_user),
):
    if current_user.role != "central":
        raise HTTPException(status_code=403, detail="Acceso restringido a la central")

    queue: asyncio.Queue = asyncio.Queue()
    _sse_clients.append(queue)

    async def event_generator():
        try:
            yield 'data: {"ping": true}\n\n'
            while True:
                if await request.is_disconnected():
                    break
                try:
                    payload = await asyncio.wait_for(queue.get(), timeout=30)
                    yield f"data: {payload}\n\n"
                except asyncio.TimeoutError:
                    yield ": keepalive\n\n"
        finally:
            _sse_clients.remove(queue)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )