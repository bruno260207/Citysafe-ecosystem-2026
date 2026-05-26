from pydantic import BaseModel, Field, ConfigDict
from typing import Optional
from enum import Enum
from datetime import datetime


class IncidentType(str, Enum):
    robo = "robo"
    incendio = "incendio"
    salud = "salud"
    sospechoso = "sospechoso"
    accidente = "accidente"
    otros = "otros"


class IncidentStatus(str, Enum):
    pendiente = "pendiente"
    atendido = "atendido"
    resuelto = "resuelto"


class UserRole(str, Enum):
    ciudadano = "ciudadano"
    central = "central"


class UserCreate(BaseModel):
    email: str
    password: str = Field(..., min_length=6)


class UserLogin(BaseModel):
    email: str
    password: str = Field(..., min_length=6)


class IncidentCreate(BaseModel):
    type: IncidentType
    description: Optional[str] = None
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    urgency: int = Field(..., ge=1, le=5)


class IncidentStatusUpdate(BaseModel):
    status: IncidentStatus


class IncidentResponse(BaseModel):
    id: int
    type: IncidentType
    description: Optional[str] = None
    latitude: float
    longitude: float
    urgency: int
    status: IncidentStatus
    user_id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class IncidentDetailResponse(IncidentResponse):
    reporter_email: Optional[str] = None