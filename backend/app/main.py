from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.middleware.audit_middleware import AuditLoggingMiddleware
from app.redis_client import close_redis_pool
from app.routers import (
    appointments_router,
    auth_router,
    clinical_router,
    health_router,
    patients_router,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup actions
    yield
    # Shutdown actions
    await close_redis_pool()


def create_app() -> FastAPI:
    """Application factory for Marsa psychiatric clinic management backend."""
    app = FastAPI(
        title="مرساة - نظام إدارة العيادة النفسية",
        description="FastAPI Backend for Marsa Psychiatric Clinic Management Platform",
        version="0.1.0",
        lifespan=lifespan,
    )

    # CORS configuration
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Telemetry and audit middleware
    app.add_middleware(AuditLoggingMiddleware)

    # Register API routers
    app.include_router(health_router)
    app.include_router(auth_router)
    app.include_router(patients_router)
    app.include_router(clinical_router)
    app.include_router(appointments_router)

    # Mount Static Web Portals
    import os
    from fastapi.staticfiles import StaticFiles
    web_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "web"))
    receptionist_dir = os.path.join(web_dir, "receptionist")
    public_dir = os.path.join(web_dir, "public")

    if os.path.exists(receptionist_dir):
        app.mount("/receptionist", StaticFiles(directory=receptionist_dir, html=True), name="receptionist")
    if os.path.exists(public_dir):
        app.mount("/", StaticFiles(directory=public_dir, html=True), name="public_site")

    return app


app = create_app()
