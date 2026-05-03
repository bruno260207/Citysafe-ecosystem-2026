from sqlalchemy import Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    
    # RELACIÓN: Esto permite que desde un objeto "user" puedas ver todos sus incidentes
    # Ej: usuario.incidents
    incidents = relationship(
    "Incident",
    back_populates="user",
    cascade="all, delete"
)

class Incident(Base):
    __tablename__ = "incidents"

    id = Column(Integer, primary_key=True, index=True)
    type = Column(String, nullable=False)
    description = Column(String)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    urgency = Column(Integer, nullable=False)

    # LLAVE FORÁNEA: Conecta el incidente con el usuario 
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # RELACIÓN: Esto permite que desde un incidente sepas quién lo creó
    # Ej: incidente.user.email
    user = relationship("User", back_populates="incidents")

    