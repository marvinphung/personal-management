FROM python:3.12-slim

WORKDIR /app

# Install system dependencies needed for PostgreSQL client / healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast package management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# Copy project definition
COPY pyproject.toml uv.lock README.md ./
COPY src/ ./src/
COPY migrations/ ./migrations/

# Install dependencies into system python
RUN uv sync --frozen --no-dev
ENV PATH="/app/.venv/bin:$PATH"

# Copy backend source code and migrations

# Expose default HTTP port
EXPOSE 8000

# Healthcheck targeting backend readiness probe
HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/v1/health/ready || exit 1

# Run FastAPI service
CMD ["uvicorn", "qlt.main:app", "--host", "0.0.0.0", "--port", "8000"]
