from pydantic import BaseModel, Field, ConfigDict
from typing import Optional

# USER
class UserCreate(BaseModel):
    email: str
    password: str = Field(..., min_length=6)

class UserLogin(BaseModel):
    email: str
    password: str = Field(..., min_length=6)

# INCIDENT
class IncidentCreate(BaseModel):
    type: str
    description: Optional[str] = None
    latitude: float
    longitude: float
    urgency: int = Field(..., ge=1, le=5)

class IncidentResponse(BaseModel):
    id: int
    type: str
    description: Optional[str] = None
    latitude: float
    longitude: float
    urgency: int
    user_id: int

    model_config = ConfigDict(from_attributes=True)