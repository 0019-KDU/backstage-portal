"""${{ values.name }}: DevOps94 IDP golden-path service (Python / FastAPI on ECS Fargate).

Golden-path contract:
  * listens on $PORT (8080)
  * serves GET $BASE_PATH/health -> 200 (ALB health check)
  * logs JSON lines to stdout (CloudWatch Logs)
"""
import json
import logging
import os
import sys
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import APIRouter, FastAPI, Request

BASE_PATH = os.environ.get("BASE_PATH", "").rstrip("/")  # e.g. /dev/${{ values.name }}
INFO = {
    "service": os.environ.get("SERVICE_NAME", "${{ values.name }}"),
    "environment": os.environ.get("ENVIRONMENT", "local"),
    "version": os.environ.get("APP_VERSION", "dev"),
}


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        entry = {
            "time": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname.lower(),
            "msg": record.getMessage(),
            **INFO,
            **getattr(record, "extra_fields", {}),
        }
        return json.dumps(entry)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
log = logging.getLogger("app")
log.handlers = [handler]
log.setLevel(logging.INFO)
log.propagate = False

@asynccontextmanager
async def lifespan(_app: FastAPI):
    log.info("listening", extra={"extra_fields": {"port": int(os.environ.get("PORT", "8080")), "basePath": BASE_PATH}})
    yield
    # ECS sends SIGTERM before stopping a task; uvicorn finishes in-flight requests first.
    log.info("shutting down")


app = FastAPI(
    title="${{ values.name }}",
    docs_url=f"{BASE_PATH}/docs",
    openapi_url=f"{BASE_PATH}/openapi.json",
    lifespan=lifespan,
)
# The ALB forwards the full path (/dev/<name>/...), so all routes live under BASE_PATH.
router = APIRouter(prefix=BASE_PATH)


@app.middleware("http")
async def access_log(request: Request, call_next):
    started = time.perf_counter()
    response = await call_next(request)
    if not request.url.path.endswith("/health"):  # keep health checks out of the logs
        log.info("request", extra={"extra_fields": {
            "method": request.method,
            "path": request.url.path,
            "status": response.status_code,
            "ms": round((time.perf_counter() - started) * 1000, 1),
        }})
    return response


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.get("/")
def root() -> dict:
    return {
        **INFO,
        "message": "Hello from the DevOps94 IDP",
        "time": datetime.now(timezone.utc).isoformat(),
    }


app.include_router(router)

