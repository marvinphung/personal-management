# Runbook: Backend Server Operations & Deployment

This runbook documents the deployment, operational configuration, network topology, and maintenance for the `quanlytao` backend service.

---

## 1. Architectural Overview

- **Service:** FastAPI application (`qlt.main:app`) serving RESTful APIs under `/v1/`.
- **Database:** PostgreSQL 15+ database hosting the dedicated `qlt` schema.
- **Reverse Proxy / TLS:** Caddy 2 automatically managing Let's Encrypt certificates or Cloudflare Tunnel terminating public TLS.
- **Downtime Tolerance:** Mobile clients (`user_app` and `collector_app`) maintain durable SQLite outboxes and tolerate server downtime. When the backend is offline, collector buffers notifications locally and user app continues offline classification.

---

## 2. Environment Configuration (`.env`)

Create `.env` in the repository root (or `/etc/quanlytao/.env` in production) with restricted permissions:

```bash
touch .env && chmod 600 .env
```

Required variables:

```bash
# Database connection string (dedicated qlt schema)
DATABASE_URL=postgresql://postgres:secret@db.example.com:5432/postgres?sslmode=require
DATABASE_SCHEMA=qlt

# Cryptographic secret for stable transaction deduplication hashing (64-char hex)
# KEEP PRIVATE: Never leak to clients or commit to Git.
DEDUP_KEY=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef

# Service binding
ENVIRONMENT=production
HOST=0.0.0.0
PORT=8000

# Public domain for Caddy TLS
SERVER_DOMAIN=api.quanlytao.app
ACME_EMAIL=admin@quanlytao.app
```

---

## 3. Deployment Options

### Option A: Docker Compose (VPS / Linux Server - Recommended)

From the repository root:

```bash
# Verify environment file exists
ls -l .env

# Build and start services in background
docker compose -f deploy/compose.yaml up -d --build

# Inspect logs
docker compose -f deploy/compose.yaml logs -f backend
```

Check health:

```bash
curl -i http://localhost:8000/v1/health/live
curl -i http://localhost:8000/v1/health/ready
```

### Option B: macOS Host (Mac mini / Home Server)

If running directly on macOS (Apple Silicon M1/M2/M3):

1. **Prevent System Sleep:**
   A Mac home server must not sleep while running the service:
   ```bash
   sudo pmset -a disablesleep 1
   sudo pmset -a displaysleep 10
   ```

2. **Install Service via launchd:**
   Copy `deploy/macos/app.quanlytao.backend.plist` to `/Library/LaunchDaemons/`:
   ```bash
   sudo mkdir -p /var/log/quanlytao
   sudo cp deploy/macos/app.quanlytao.backend.plist /Library/LaunchDaemons/
   sudo chown root:wheel /Library/LaunchDaemons/app.quanlytao.backend.plist
   sudo launchctl load -w /Library/LaunchDaemons/app.quanlytao.backend.plist
   ```

3. **Check status:**
   ```bash
   sudo launchctl list | grep quanlytao
   tail -f /var/log/quanlytao/backend.stdout.log
   ```

### 3.3 Administrator Account Bootstrap

Before first login to the Collector App or Admin endpoints, bootstrap the initial administrator account:

```bash
# Interactive password prompt:
uv --project backend run python src/qlt/bootstrap_admin.py admin

# Or via Docker:
docker compose -f deploy/compose.yaml exec backend python -m qlt.bootstrap_admin admin
```

The bootstrap command normalizes the username, hashes the password with Argon2id, and creates/updates the user record with `role='admin'` and `status='active'`.

---

## 4. Public Network Ingress & TLS

> [!CRITICAL]
> **Never configure a private LAN IP (e.g. `192.168.1.x`) as the production mobile endpoint.** Mobile phones switch between home Wi-Fi and 4G/5G mobile networks; private IPs fail immediately when leaving Wi-Fi.

Recommended options:
1. **Public VPS with Caddy:** Run `deploy/compose.yaml` on a cloud VPS with an A record pointing to its public IP. Caddy obtains automated Let's Encrypt certificates.
2. **Cloudflare Tunnel (Zero Trust):** For home-based Mac mini or Raspberry Pi:
   ```bash
   cloudflared tunnel run quanlytao-backend
   ```
   Routes public HTTPS (e.g. `https://api.quanlytao.app`) directly to local port 8000 without opening router ports.

---

## 5. Secret Safety & Auditing

Run the mobile secret scanner before releasing any client builds:

```bash
python3 tool/check_mobile_secrets.py
```

Mobile binaries MUST ONLY contain `API_BASE_URL`. They must NEVER contain database passwords, `DEDUP_KEY`, or `service_role` tokens.
