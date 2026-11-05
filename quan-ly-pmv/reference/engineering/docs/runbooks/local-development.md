# Local development stack (PostgreSQL 17)

This option runs the current backend, PostgreSQL 17, NATS JetStream, and the
Flutter user app entirely on the development Mac. It does not use or migrate the
production database.

## Configuration

Copy `.env.example` to `.env` and set at least these values:

```dotenv
API_BASE_URL=http://127.0.0.1:8001/v1
DATABASE_URL=postgresql://YOUR_MAC_USER@127.0.0.1:5432/qlt_local?sslmode=disable
DATABASE_SCHEMA=qlt
ENVIRONMENT=development
HOST=127.0.0.1
PORT=8001
NATS_URL=nats://127.0.0.1:4222
NATS_USER=qlt_backend
NATS_PASSWORD=CHOOSE_A_LOCAL_PASSWORD
NATS_HOST=127.0.0.1
NATS_MONITOR_LISTEN=127.0.0.1:8222
NATS_STORE_DIR=/ABSOLUTE/PATH/TO/personal-management/data/jetstream
DEMO_USER_USERNAME=demo
DEMO_USER_PASSWORD=CHOOSE_A_DEMO_PASSWORD
```

`.env` is ignored by Git. `tool/flutter_client.py` passes only
`API_BASE_URL` to Flutter and never exposes backend credentials.

## Start and seed

```bash
brew services start postgresql@17
createdb -h 127.0.0.1 qlt_local
uv --project backend run python -m qlt.migrate
uv --project backend run python -m qlt.messaging.run_nats
uv --project backend run python -m qlt.seed_demo
uv --project backend run python -m qlt.run
```

The seed command is idempotent. It creates an approved (`active`) user using
the `DEMO_USER_*` values, default categories and tags, sample transactions, a
bank binding, a cash wallet, a debt, a note, and three pending bank events in
JetStream.

## Run the iOS user app

With the backend running:

```bash
python3 tool/flutter_client.py user run -d "iPhone 16 Pro"
```

Useful local endpoints:

- API readiness: `http://127.0.0.1:8001/v1/health/ready`
- Swagger UI: `http://127.0.0.1:8001/docs`
- NATS monitoring JSON: `http://127.0.0.1:8222/`
