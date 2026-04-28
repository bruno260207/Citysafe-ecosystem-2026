# (rutas)
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import Base, engine, get_db
from app import models, schemas, crud
from app.auth import create_token, verify_password, get_current_user

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title = "City Safe 2026"
)

# 👤 REGISTER
@app.post("/register")
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):

    existing = crud.get_user_by_email(db, user.email)
    if existing:
        raise HTTPException(status_code=400, detail="Usuario ya existe")

    crud.create_user(db, user.email, user.password)
    return {"msg": "Usuario creado"}

# 🔐 LOGIN
@app.post("/login")
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):

    db_user = crud.get_user_by_email(db, user.email)

    if not db_user or not verify_password(user.password, db_user.hashed_password):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")

    token = create_token({"sub": str(db_user.id)})

    return {"access_token": token, "token_type": "bearer"}

# 🚨 CREATE INCIDENT
@app.post("/incidents")
def create_incident(
    incident: schemas.IncidentCreate,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_current_user)
):
    return crud.create_incident(db, incident, int(user_id))

# 📡 GET INCIDENTS
@app.get("/incidents")
def get_incidents(db: Session = Depends(get_db)):
    return crud.get_incidents(db)