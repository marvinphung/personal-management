from contextlib import asynccontextmanager
import uuid
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from qlt.db import check_db_ready, close_pool, init_pool


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize connection pool on startup
    init_pool()
    yield
    # Close connection pool on shutdown
    close_pool()


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
def health_ready():
    is_ready = check_db_ready()
    if is_ready:
        return {"status": "ready", "database": "connected"}
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"status": "not_ready", "database": "disconnected"},
    )


# Include routers
from qlt.admin.banks import router as admin_banks_router
from qlt.admin.users import router as admin_users_router
from qlt.auth.routes import router as auth_router
from qlt.catalog.banks import router as banks_router
from qlt.catalog.categories import router as categories_router
from qlt.ingest.routes import router as ingest_router
from qlt.ledger.resolve_pending import router as resolve_pending_router
from qlt.ledger.routes import router as ledger_router
from qlt.secondary.debts import router as debts_router
from qlt.secondary.wallets import router as wallets_router
from qlt.sync.routes import router as sync_router
from qlt.widgets.routes import router as widgets_router

app.include_router(auth_router)
app.include_router(admin_users_router)
app.include_router(banks_router)
app.include_router(admin_banks_router)
app.include_router(ingest_router)
app.include_router(categories_router)
app.include_router(ledger_router)
app.include_router(resolve_pending_router)
app.include_router(sync_router)
app.include_router(debts_router)
app.include_router(wallets_router)
app.include_router(widgets_router)








