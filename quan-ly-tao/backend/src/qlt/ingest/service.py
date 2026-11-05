from typing import Any
from qlt.messaging.ingestion import CollectorEventItem, process_collector_events_async

__all__ = ["CollectorEventItem", "process_collector_events"]


def process_collector_events(events: list[CollectorEventItem], active_collector: dict[str, Any]) -> list[dict[str, Any]]:
    from qlt.runtime import run_backend_coroutine
    return run_backend_coroutine(process_collector_events_async(events, active_collector))
