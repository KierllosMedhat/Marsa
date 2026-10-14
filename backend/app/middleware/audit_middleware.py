import time
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class AuditLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware for non-clinical request logging and telemetry."""

    async def dispatch(self, request: Request, call_next) -> Response:
        start_time = time.time()
        response = await call_next(request)
        process_time = time.time() - start_time

        # Attach process time header
        response.headers["X-Process-Time-Sec"] = f"{process_time:.4f}"
        return response
