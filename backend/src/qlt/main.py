import asyncio
from contextlib import asynccontextmanager
import logging
import uuid
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from qlt.config import get_settings
from qlt.db import check_db_ready, close_async_pool, close_pool, init_async_pool, init_pool
from qlt.messaging.client import check_nats_ready, close_nats, get_jetstream, get_nats_client
from qlt.messaging.stream import ensure_stream
from qlt.runtime import bind_backend_loop

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    bind_backend_loop(asyncio.get_running_loop())
    from qlt.push.providers import validate_push_configuration
    validate_push_configuration()
    # Initialize connection pools on startup
    init_pool()
    await init_async_pool()
    # Connect to NATS and ensure stream
    try:
        js = await get_jetstream()
        await ensure_stream(js)
    except RuntimeError:
        # Incompatible storage/retention is a deployment error, not an outage.
        raise
    except Exception as e:
        logger.warning(f"NATS initialization during startup deferred or failed: {e}")

    settings = get_settings()
    stop_event = asyncio.Event()
    worker_task = None
    reconcile_task = None
    if settings.environment != "test":
        try:
            from qlt.messaging.reconcile import run_reconciliation_coordinator
            from qlt.messaging.worker import run_outbox_worker
            worker_task = asyncio.create_task(run_outbox_worker(stop_event))
            reconcile_task = asyncio.create_task(run_reconciliation_coordinator(stop_event))
        except Exception as e:
            logger.warning(f"Background task startup deferred: {e}")

    yield

    # Clean shutdown
    stop_event.set()
    tasks_to_wait = []
    if worker_task:
        worker_task.cancel()
        tasks_to_wait.append(worker_task)
    if reconcile_task:
        reconcile_task.cancel()
        tasks_to_wait.append(reconcile_task)
    if tasks_to_wait:
        await asyncio.gather(*tasks_to_wait, return_exceptions=True)
    await close_nats()
    await close_async_pool()
    close_pool()
    bind_backend_loop(None)




app = FastAPI(
    title="Quản lý Tao API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_request_id_middleware(request: Request, call_next):
    request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["x-request-id"] = request_id
    return response


from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    request_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    if isinstance(exc.detail, dict):
        content = dict(exc.detail)
        content.setdefault("request_id", request_id)
        return JSONResponse(status_code=exc.status_code, content=content)
    return JSONResponse(
        status_code=exc.status_code,
        content={"code": "ERROR", "message": str(exc.detail), "request_id": request_id},
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    request_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    # Do not leak internal exception details to client
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "code": "INTERNAL_SERVER_ERROR",
            "message": "Đã xảy ra lỗi máy chủ nội bộ",
            "request_id": request_id,
        },
    )


@app.get("/v1/health/live", tags=["Health"])
def health_live():
    return {"status": "ok"}


@app.get("/v1/health/ready", tags=["Health"])
async def health_ready():
    db_ok = check_db_ready()
    broker_ok = await check_nats_ready()
    all_ready = db_ok and broker_ok
    status_code = status.HTTP_200_OK if all_ready else status.HTTP_503_SERVICE_UNAVAILABLE
    return JSONResponse(
        status_code=status_code,
        content={
            "status": "ready" if all_ready else "not_ready",
            "database": "connected" if db_ok else "disconnected",
            "broker": "connected" if broker_ok else "disconnected",
        },
    )


# Include routers
from qlt.admin.banks import router as admin_banks_router
from qlt.admin.collectors import router as admin_collectors_router
from qlt.admin.users import router as admin_users_router
from qlt.auth.routes import router as auth_router
from qlt.catalog.banks import router as banks_router
from qlt.catalog.categories import router as categories_router
from qlt.ingest.routes import router as ingest_router
from qlt.ledger.resolve_pending import router as resolve_pending_router
from qlt.ledger.routes import router as ledger_router
from qlt.push.routes import router as push_router
from qlt.realtime.routes import router as realtime_router
from qlt.secondary.debts import router as debts_router
from qlt.secondary.wallets import router as wallets_router
from qlt.sync.routes import router as sync_router
from qlt.widgets.routes import router as widgets_router

app.include_router(auth_router)
app.include_router(admin_users_router)
app.include_router(banks_router)
app.include_router(admin_banks_router)
app.include_router(admin_collectors_router)
app.include_router(ingest_router)
app.include_router(categories_router)
app.include_router(ledger_router)
app.include_router(resolve_pending_router)
app.include_router(sync_router)
app.include_router(debts_router)
app.include_router(wallets_router)
app.include_router(widgets_router)
app.include_router(realtime_router)
app.include_router(push_router)




