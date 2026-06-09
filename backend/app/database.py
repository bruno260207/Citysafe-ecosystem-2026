from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# 1. Dirección de la base de datos
# Se crea un archivo local llamado 'citysafe.db'.
# El prefijo 'sqlite:///' indica que usaremos SQLite.
SQLALCHEMY_DATABASE_URL = "sqlite:///./citysafe.db"

# 2. Creación del motor (Engine)
# 'connect_args' es necesario solo para SQLite para permitir múltiples hilos
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# 3. Fábrica de sesiones
# Genera las sesiones que usaremos en los endpoints para hacer consultas
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 4. Clase Base
# De aquí heredarán tus modelos 'User' e 'Incident' de models.py.
Base = declarative_base()

# 5. Dependencia get_db
# Esta función abre una conexión cuando se llama a un endpoint y la cierra al terminar.
def get_db():
    db = SessionLocal()
    try:
        yield db # Entrega la sesión al endpoint que la solicitó
    finally:
        db.close() # Cierra la conexión para no desperdiciar recursos