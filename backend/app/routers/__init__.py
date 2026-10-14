from app.routers.auth import router as auth_router
from app.routers.patients import router as patients_router
from app.routers.clinical import router as clinical_router
from app.routers.appointments import router as appointments_router
from app.routers.health import router as health_router

__all__ = [
    "auth_router",
    "patients_router",
    "clinical_router",
    "appointments_router",
    "health_router",
]
