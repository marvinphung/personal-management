# Realtime Gateway Protocol Specification (v1)

## 1. Overview & Transport

The Realtime Gateway provides authenticated, bidirectional, low-latency communication over WebSocket between the QLT backend and mobile clients (`user_app`). Its primary role is pushing live bank inbox updates (inbox snapshots) and sync invalidation signals without continuous HTTP polling.

- **Endpoint:** `GET /v1/realtime`
- **Transport:** WebSocket (`ws://` or `wss://`)
- **Authentication:** Standard Bearer token via HTTP header:
  `Authorization: Bearer <session_token>`
  *(Query-string tokens are explicitly rejected to prevent token leakage in server/proxy access logs).*
- **User Scoping:** The user identity is strictly derived from the verified session token on the server. Clients cannot subscribe to arbitrary user IDs or message subjects.
- **Protocol Version:** `"1.0"`

---

## 2. Framing & Message Envelope

All frames exchanged over `/v1/realtime` are UTF-8 encoded JSON objects matching the standard envelope schema:

```json
{
  "protocol_version": "1.0",
  "type": "<message_type>",
  "connection_id": "<uuid>",
  "inbox_revision": 42,
  "data": {}
}
```

### Envelope Fields
| Field | Type | Description |
|---|---|---|
| `protocol_version` | String | Fixed to `"1.0"`. Unsupported versions trigger closure with code 4400. |
| `type` | String | Message discriminator (see below). |
| `connection_id` | String (UUID) | Unique identifier assigned to the WebSocket connection. |
| `inbox_revision` | Integer (int64) | Latest bank inbox revision number known to the server for this user. |
| `data` | Object | Payload specific to the message `type`. |

---

## 3. Frame Types & Flow

### 3.1 `hello` (Server -> Client)
Sent immediately upon successful handshake and authentication.

```json
{
  "protocol_version": "1.0",
  "type": "hello",
  "connection_id": "c1f7a049-74d1-4ee2-b439-e70a93b58955",
  "inbox_revision": 15,
  "data": {
    "user_id": "87b0a701-d72b-47e1-88fc-8f78f8705b0d",
    "server_time": "2026-10-03T20:50:00.000Z",
    "heartbeat_interval_seconds": 30,
    "max_frame_bytes": 262144
  }
}
```

### 3.2 `inbox.snapshot` (Server -> Client)
Sent immediately after `hello`, and whenever the user's pending bank inbox changes (new ingest, accepted, discarded, or purged), provided the serialized payload does not exceed the chunk threshold (256 KiB).

```json
{
  "protocol_version": "1.0",
  "type": "inbox.snapshot",
  "connection_id": "c1f7a049-74d1-4ee2-b439-e70a93b58955",
  "inbox_revision": 16,
  "data": {
    "pending_count": 1,
    "events": [
      {
        "id": "e8d91fb2-0922-4886-90a1-6e3e56a738bf",
        "user_id": "87b0a701-d72b-47e1-88fc-8f78f8705b0d",
        "binding_id": "b3046f10-b992-4981-8b39-c12e2f693cb8",
        "source_type": "vietcombank",
        "account_number_mask": "...1234",
        "amount": 150000,
        "direction": "outflow",
        "booking_time": "2026-10-03T20:45:00.000Z",
        "transaction_code": "MBVCB.987654321",
        "counterparty_account": "999888777",
        "counterparty_bank": "Techcombank",
        "counterparty_name": "NGUYEN VAN A",
        "raw_description": "Chuyen tien an toi",
        "suggested_category_id": "c71a3998-cb58-45e5-aa01-4be34df6bb55",
        "suggested_tags": ["food", "dinner"],
        "created_at": "2026-10-03T20:45:10.123Z"
      }
    ]
  }
}
```

### 3.3 Chunked Snapshots (`inbox.snapshot_chunk` and `inbox.snapshot_complete`)
If the full snapshot exceeds 256 KiB (e.g. dozens of pending items with verbose raw descriptions), the server transmits ordered chunks followed by a completion delimiter. The client must buffer chunks in memory and apply the snapshot atomically upon receiving `inbox.snapshot_complete`.

#### `inbox.snapshot_chunk`
```json
{
  "protocol_version": "1.0",
  "type": "inbox.snapshot_chunk",
  "connection_id": "c1f7a049-74d1-4ee2-b439-e70a93b58955",
  "inbox_revision": 17,
  "data": {
    "snapshot_id": "s88a-9921-chunk-uuid",
    "chunk_index": 0,
    "total_chunks": 3,
    "events": [ ... ]
  }
}
```

#### `inbox.snapshot_complete`
```json
{
  "protocol_version": "1.0",
  "type": "inbox.snapshot_complete",
  "connection_id": "c1f7a049-74d1-4ee2-b439-e70a93b58955",
  "inbox_revision": 17,
  "data": {
    "snapshot_id": "s88a-9921-chunk-uuid",
    "total_chunks": 3,
    "total_events": 45,
    "pending_count": 45
  }
}
```

### 3.4 `sync.required` (Server -> Client)
Sent when the user's regular sync state changes (transactions accepted, category created, tag modified, budget adjusted). Informs the client to trigger its HTTP sync pull.

```json
{
  "protocol_version": "1.0",
  "type": "sync.required",
  "connection_id": "c1f7a049-74d1-4ee2-b439-e70a93b58955",
  "inbox_revision": 17,
  "data": {
    "entity_types": ["transactions", "categories"],
    "server_revision": 58
  }
}
```

### 3.5 `ping` and `pong` (Bidirectional)
Keep-alive heartbeat.
- Client may send `ping`:
  ```json
  {
    "protocol_version": "1.0",
    "type": "ping",
    "connection_id": "c1f7a049-74d1-4ee2-b439-e70a93b58955",
    "inbox_revision": 17,
    "data": { "timestamp": 1791039000000 }
  }
  ```
- Server responds with `pong`:
  ```json
  {
    "protocol_version": "1.0",
    "type": "pong",
    "connection_id": "c1f7a049-74d1-4ee2-b439-e70a93b58955",
    "inbox_revision": 17,
    "data": { "client_timestamp": 1791039000000, "server_timestamp": 1791039000005 }
  }
  ```

### 3.6 `error` (Server -> Client)
Sent prior to closing the socket or when a recoverable error occurs.

```json
{
  "protocol_version": "1.0",
  "type": "error",
  "connection_id": "c1f7a049-74d1-4ee2-b439-e70a93b58955",
  "inbox_revision": 0,
  "data": {
    "code": "AUTHENTICATION_EXPIRED",
    "message": "User session has expired or been revoked.",
    "retryable": false
  }
}
```

---

## 4. Client Behavior & State Management

### 4.1 Local Undo Overlay (Three-Second Undo Rule)
When a user taps "Discard" on a bank item:
1. The client hides the item immediately from the local UI and begins a 3-second local undo timer.
2. The HTTP command `POST /v1/pending-events/{id}/discard` is **not sent** until the timer expires without cancellation.
3. If an `inbox.snapshot` frame arrives while an item is in the local discard-undo window, the client must **overlay** its local state: the item must remain hidden in the UI and not resurrect.
4. If the user cancels the discard within 3 seconds, the item is restored in the UI without network traffic.
5. If the 3-second timer completes, the client queues the discard command in its durable local outbox and sends it.

### 4.2 Reconnection & Backoff
- Client uses exponential backoff with jitter on disconnect (e.g., initial 1.0s, max 30s, factor 1.5, ±20% jitter).
- On reconnect:
  1. Complete standard WebSocket handshake with current bearer token.
  2. Receive `hello`.
  3. Receive latest `inbox.snapshot` (or chunked sequence).
  4. Compare received `inbox_revision` with locally stored revision; if newer, replace pending items and recalculate badge count.
  5. Check if local outbox contains uncommitted resolutions and overlay them.

### 4.3 Slow Client & Backpressure Handling
- Server buffers at most 32 outgoing frames per connection.
- If a slow client fails to consume frames and the buffer fills, the server drops superseded snapshots (coalescing to the latest revision).
- If non-coalescible frames overflow or socket write blocks beyond 10 seconds, the server terminates the connection with code `4008` (Policy Violation / Slow Consumer). The client reconnects cleanly and receives an authoritative snapshot.
