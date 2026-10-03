# Architectural and Technical Decisions

This document records architectural, technical, and implementation decisions and justified deviations as required by `docs/plans/2026-10-03-quan-ly-tao-implementation.md`.

## 1. Application and Packaging Structure
- **Two Applications:**
  - `apps/user_app`: Flutter client targeting Android and iOS (`app.quanlytao.user`).
  - `apps/collector_app`: Native Android + lightweight Flutter administration shell (`app.quanlytao.collector`).
- **Coexistence:** Both apps can be installed on the same Android device simultaneously. No shared package names, service action conflicts, or database file conflicts.
- **Retirement of Linux Desktop:** The Linux desktop runner under `linux/` will be cleanly retired after extracting shared packages (`packages/finance_core`, `packages/api_client`, tool scripts, and signing references).

## 2. Backend and Data Architecture
- **Service:** Dedicated FastAPI backend (Python 3.12+, uv, Pydantic, psycopg v3, Argon2id).
- **PostgreSQL Database:** Supabase-hosted PostgreSQL instance. All application data lives in a new, isolated `qlt` schema. Old public schemas and existing tables will NOT be dropped or reset.
- **Access Control:** No Supabase public anon keys or direct client-to-database connections. All client and collector traffic routes through the FastAPI backend via HTTPS.
- **Authentication:** Username/password only (ASCII `[a-z0-9_.]{3,32}`). Passwords hashed with Argon2id. Opaque 256-bit bearer session tokens hashed (SHA-256) in the database. No JWT, no email/phone requirement.
- **User Roles & Lifecycle:** Administrator bootstrap CLI. Public registration creates `pending` users requiring administrator approval. Administrator can toggle capture, issue temporary passwords (forcing password change on first login), soft-delete, restore, and permanently purge.
- **Money & Numbers:** Positive `bigint` VND amounts (limit `9_000_000_000_000_000`) with explicit `direction` (`income` | `expense`). Decimal strings across JSON APIs. Account numbers stored as exact text preserving leading zeros. No bank balance tracking.

## 3. Bank Notification Capture & Routing
- **Full Account Number Routing:** Notification parsing extracts the full owner account number. No suffix hints (like `takeLast(4)`), no counterparty account routing, and no fuzzy matching.
- **Supported Banks in Phase A:** BIDV, VietinBank, Vietcombank, and Techcombank.
  - MB Bank is permanently excluded because notifications mask the account number.
  - BIDV and VietinBank have verified package names and payload structures.
  - Vietcombank and Techcombank require real Android notification fixture evidence before live capture enablement. In the absence of live fixtures, the parsers are implemented but live capture is gated behind a verified fixture gate.
- **Deduplication:** Server-side HMAC-SHA256 fingerprinting (`DEDUP_KEY`) with content-free ingest receipts. Duplicate notifications return terminal ACK to allow local queue pruning without creating duplicate pending events.

## 4. Pending Event Lifecycle & Three-Second Undo
- **Atomic Operations:**
  - Ingestion: pending bank event + ingest receipt inserted in one transaction.
  - Acceptance: ledger transaction inserted + pending event hard-deleted in one transaction.
  - Discard: pending event hard-deleted after local undo deadline.
- **Durable Three-Second Dismissal:** Client maintains a persisted 3-second undo slot with an absolute deadline. Dismissing a second transaction commits the first immediately. App death or restart does not extend the deadline.
- **Hard Deletion & Anti-Replay:** Ingest receipts contain no transaction details/content but retain the HMAC fingerprint indefinitely, preventing replay even if an accepted ledger transaction is subsequently deleted.

## 5. Offline Synchronization & Native Widgets
- **Local Store:** SQLite via Drift in `packages/finance_core`, scoped per user ID.
- **Reconciliation:** Consistent snapshot reconciliation using `user_revisions` under REPEATABLE READ. No offset pagination or unsafe `updated_at` polling.
- **Widget Policy:** Native Android `AppWidgetProvider` and iOS `WidgetKit` extension display count-only ("Có X giao dịch cần phân loại" / "Không có giao dịch cần phân loại"). No monetary amounts or personal details on the widget. Deep-link `quanlytao://bank-inbox` opens the Biến động tab. Best-effort background refresh (15+ min interval); no promise of guaranteed 5-minute background updates.
