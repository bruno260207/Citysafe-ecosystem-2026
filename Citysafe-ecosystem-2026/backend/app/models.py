from sqlalchemy import Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import relationship # <-- Agrega esta línea
from app.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True)
    hashed_password = Column(String)
    
    # RELACIÓN: Esto permite que desde un objeto "user" puedas ver todos sus incidentes
    # Ej: usuario.incidents
    incidents = relationship("Incident", back_populates="user") 

class Incident(Base):
    __tablename__ = "incidents"

    id = Column(Integer, primary_key=True, index=True)
    type = Column(String)
    description = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    urgency = Column(Integer)

    # LLAVE FORÁNEA: Conecta el incidente con el usuario 
    user_id = Column(Integer, ForeignKey("users.id"))
    
    # RELACIÓN: Esto permite que desde un incidente sepas quién lo creó
    # Ej: incidente.user.email
    user = relationship("User", back_populates="incidents")

    