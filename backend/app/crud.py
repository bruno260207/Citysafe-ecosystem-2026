from sqlalchemy.orm import Session
from app.models import User, Incident
from app.auth import hash_password


def create_user(db: Session, email: str, password: str, role: str = "ciudadano"):
    user = User(
        email=email,
        hashed_password=hash_password(password),
        role=role
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def get_user_by_email(db: Session, email: str):
    return db.query(User).filter(User.email == email).first()


def seed_iot(db: Session):
    """Crea el usuario IoT si no existe."""
    iot_email = "iot@citysafe.com"
    existing = get_user_by_email(db, iot_email)
    if not existing:
        create_user(db, email=iot_email, password="iot123", role="ciudadano")
        print("Usuario IoT creado: iot@citysafe.com / iot123")
    
    """Crea el usuario central"""
    if not get_user_by_email(db, "central@citysafe.com"):
        create_user(db, email="central@citysafe.com", password="central123", role="central")
        print("Usuario central creado: central@citysafe.com / central123")

def create_incident(db: Session, incident_data, user_id: int):
    incident = Incident(
        **incident_data.dict(),
        user_id=user_id,
        status="pendiente"
    )
    db.add(incident)
    db.commit()
    db.refresh(incident)
    return incident


def get_incidents(db: Session, skip: int = 0, limit: int = 100):
    return db.query(Incident).offset(skip).limit(limit).all()


def get_incident_by_id(db: Session, incident_id: int):
    return db.query(Incident).filter(Incident.id == incident_id).first()


def update_incident_status(db: Session, incident_id: int, new_status: str):
    incident = get_incident_by_id(db, incident_id)
    if incident:
        incident.status = new_status
        db.commit()
        db.refresh(incident)
    return incident