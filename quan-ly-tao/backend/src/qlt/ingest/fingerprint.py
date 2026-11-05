import hmac
import hashlib
from qlt.config import get_settings


def compute_event_fingerprint(
    bank_code: str,
    owner_account: str,
    direction: str,
    amount_vnd: int,
    occurred_at_iso: str,
    bank_description: str,
    bank_reference: str | None,
    source_event_key: str,
) -> str:
    settings = get_settings()
    key = settings.dedup_key.encode("utf-8")

    bank = bank_code.strip().lower()
    acc = owner_account.strip()
    dir_str = direction.strip().lower()

    if bank_reference and bank_reference.strip():
        # Canonical identity with reliable bank reference
        canonical = f"{bank}|{acc}|{dir_str}|{amount_vnd}|{bank_reference.strip()}"
    else:
        # Canonical identity without reference: use precise occurred_at, normalized description, and source event key
        norm_desc = " ".join(bank_description.strip().split())
        canonical = f"{bank}|{acc}|{dir_str}|{amount_vnd}|{occurred_at_iso}|{norm_desc}|{source_event_key.strip()}"

    digest = hmac.new(key, canonical.encode("utf-8"), hashlib.sha256).hexdigest()
    return digest
