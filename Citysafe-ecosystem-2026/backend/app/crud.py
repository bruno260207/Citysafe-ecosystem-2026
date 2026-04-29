# ESTE
from sqlalchemy.orm import Session
from app.models import User, Incident
from app.auth import hash_password

# 👤 USER
def create_user(db: Session, email: str, password: str):
    user = User(
        email=email,
        hashed_password=hash_password(password)
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

def get_user_by_email(db: Session, email: str):
    return db.query(User).filter(User.email == email).first()


# 🚨 INCIDENT
def create_incident(db: Session, incident_data, user_id: int):
    incident = Incident(
        **incident_data.dict(),
        user_id=user_id
    )
    db.add(incident)
    db.commit()
    db.refresh(incident)
    return incident

def get_incidents(db: Session):
    return db.query(Incident).all()