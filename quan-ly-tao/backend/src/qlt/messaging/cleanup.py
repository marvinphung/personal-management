from qlt.messaging.stream import build_event_subject


async def delete_event_payload(js, stream_name, user_id, event_id):
    """Idempotent exact-subject deletion, safe after restore or a lost delete ACK."""
    confirmed = await js.purge_stream(stream_name, subject=build_event_subject(user_id, event_id))
    if not confirmed:
        raise RuntimeError("Broker did not confirm event cleanup")
