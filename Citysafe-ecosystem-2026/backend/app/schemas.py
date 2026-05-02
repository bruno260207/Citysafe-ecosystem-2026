from pydantic import BaseModel

# USER
class UserCreate(BaseModel):
    email: str
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

# INCIDENT
class IncidentCreate(BaseModel):
    type: str
    description: str
    latitude: float
    longitude: float
    urgency: int