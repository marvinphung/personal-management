# Collector enrollment contract

The Collector/Admin Android app enrolls through the public HTTPS API. NATS and
PostgreSQL remain private backend dependencies and must never be configured in
the mobile app.

## Enroll or rotate the active collector credential

```http
POST /v1/admin/collectors/enroll
Authorization: Bearer <admin-session-token>
Content-Type: application/json

{"handover": false}
```

Only an authenticated user with `role=admin` may call this endpoint.

- `handover: false` is the default. It rotates the credential on the current
  active collector while preserving both `collector_id` and `collector_epoch`.
  The previous collector token stops working immediately.
- `handover: true` retires the current collector, creates a new collector ID,
  and increments `collector_epoch` once. Use it only when transferring capture
  responsibility to another physical device.
- The first enrollment creates epoch `1`; there is no earlier device to hand
  over from.
- Each successful call issues a new token. Clients must not automatically retry
  an enrollment after an ambiguous timeout. Ask the administrator to enroll
  again deliberately instead.

Successful response: `201 Created`, with `Cache-Control: no-store` and
`Pragma: no-cache`.

```json
{
  "collector_id": "527e41ef-b842-46d3-ac62-f4dd881fab17",
  "collector_token": "qlt_collector_<random-credential>",
  "credential_type": "Bearer",
  "collector_epoch": 3,
  "state": "active",
  "handover_performed": false,
  "issued_at": "2026-10-05T01:30:00Z",
  "token_displayed_once": true,
  "bindings": [
    {
      "binding_id": "bf6289dc-9e92-48d0-af1b-01921e43d31d",
      "bank_code": "bidv",
      "account_number": "0123456789",
      "binding_version": 1,
      "capture_epoch": 1
    }
  ]
}
```

The plaintext `collector_token` exists only in this response. The backend stores
only its SHA-256 hash and cannot display the token again.

## Collector-authenticated calls

After enrollment, use the collector token—not the admin session token—for:

```http
GET  /v1/collector/registry
POST /v1/collector/events
POST /v1/collector/heartbeat
Authorization: Bearer <collector-token>
```

`GET /v1/collector/registry` returns the current `collector_epoch` and active
bank bindings. Refresh it after enrollment and periodically while the collector
is active.

## Android storage requirements

Store `collector_token` with Android Keystore-backed encrypted storage, such as
`EncryptedSharedPreferences` or a Flutter secure-storage implementation using
the Android Keystore. Store the epoch and registry as non-secret cached metadata.

The Android app must:

1. Persist the token before dismissing the enrollment success screen.
2. Never write it to logcat, analytics, crash reports, clipboard, screenshots,
   ordinary SharedPreferences, source code, or backup exports.
3. Send it only to the HTTPS API hostname in an `Authorization: Bearer` header.
4. Exclude the encrypted credential store from Android Auto Backup/device
   transfer, because Keystore keys are device-bound.
5. Delete the local token when the server returns `401 COLLECTOR_FENCED`, then
   require an administrator to enroll again.
6. Keep the admin session credential separate from the collector credential.

The API hostname is:

```text
https://api.xn--qun-l-tao-49a0064f.id.vn/v1
```
