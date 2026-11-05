# Runbook: Bank Notification Fixtures & Parser Verification

This runbook documents the format, requirements, gating policy, and sanitization guidelines for bank notification test fixtures used in `apps/collector_app`.

---

## 1. Supported Banks & Gating Policy

| Bank | Status | Verification Requirement |
|---|---|---|
| **BIDV** (`bidv`) | Fully Enabled | Verified real notification fixtures with distinct timestamps and identical posting times. |
| **VietinBank** (`vietinbank`) | Fully Enabled | Verified real notification fixtures for income/expense and balance transitions. |
| **Vietcombank** (`vietcombank`) | Gated Behind Real Fixtures | Live capture remains disabled until real notification evidence is provided. |
| **Techcombank** (`techcombank`) | Gated Behind Real Fixtures | Live capture remains disabled until real notification evidence is provided. |
| **MB Bank** (`mb`) | **EXCLUDED** | Explicitly out of scope per architectural decision. Parsers must reject MB notifications immediately. |

---

## 2. Notification Fixture Location & Schema

Notification fixtures are stored in:
`apps/collector_app/android/app/src/test/resources/bank_notifications/`

### Directory Structure:
```
bank_notifications/
├── bidv/
│   ├── income_valid.json
│   ├── expense_valid.json
│   └── same_posting_time_distinct.json
├── vietinbank/
│   ├── income_valid.json
│   └── expense_valid.json
├── vietcombank/
│   └── (gated until real evidence provided)
└── techcombank/
    └── (gated until real evidence provided)
```

### Fixture JSON Schema:
```json
{
  "bank_code": "bidv",
  "title": "BIDV SmartBanking",
  "content": "TK 1234567890 tai BIDV -50,000VND vao 22:20 03/10/2026. ND: An trua",
  "post_time": 1727968800000,
  "expected": {
    "direction": "expense",
    "amount": 50000,
    "owner_account": "1234567890",
    "description": "An trua"
  }
}
```

---

## 3. Sanitization Guidelines for Adding Real Fixtures

When capturing and adding new fixtures from real bank notifications:

1. **Remove Real Account Numbers:** Replace private account numbers with standardized mock accounts (e.g. `0123456789`), **preserving leading zeros and exact character length**.
2. **Remove Real Balances:** Never include actual user account balances in fixtures.
3. **Remove Personal Counterparty Details:** Replace counterparty names and notes with sanitized values.
4. **Never Include OTPs or Security Codes:** OTPs, verification codes, or PIN messages must be rejected by parsers and never stored.

---

## 4. Parser Invariants

All bank notification parsers (`BidvParser`, `VietinParser`, `VcbParser`, `TechcomParser`) must uphold:
- Exact full owner account string with leading zeros preserved (never truncated suffix hints).
- Integer VND amounts only (no floating point calculations).
- Immediate rejection of promotional notifications, loan advertisements, OTP messages, and transaction failure alerts.
