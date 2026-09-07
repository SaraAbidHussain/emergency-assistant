from app.models.schemas import EmergencySession, TimelineEntry
from app.repository.json_store import load_json, save_json

# In-memory cache backed by a JSON file (data/sessions.json) so sessions
# survive a server restart. The in-memory dict is still the source of
# truth *during* a run (fast, no disk I/O on every read) — it's just
# loaded from disk once at import time and flushed back to disk after
# every write. Swap this module for a real DB (RDS/Redis) later without
# touching the service or router layers, since they only ever call the
# functions below.

_raw_sessions: dict[str, dict] = load_json("sessions", default={})
_sessions: dict[str, EmergencySession] = {
    user_id: EmergencySession.model_validate(data)
    for user_id, data in _raw_sessions.items()
}


def _persist() -> None:
    save_json(
        "sessions",
        {user_id: session.model_dump(mode="json") for user_id, session in _sessions.items()},
    )


def get_session(user_id: str) -> EmergencySession | None:
    return _sessions.get(user_id)


def get_or_create_session(user_id: str) -> EmergencySession:
    if user_id not in _sessions:
        _sessions[user_id] = EmergencySession(user_id=user_id)
        _persist()
    return _sessions[user_id]


def save_session(session: EmergencySession) -> None:
    _sessions[session.user_id] = session
    _persist()


def add_timeline_entry(user_id: str, entry: TimelineEntry) -> EmergencySession:
    session = get_or_create_session(user_id)
    session.timeline.append(entry)
    save_session(session)
    return session


def all_sessions() -> dict[str, EmergencySession]:
    return _sessions
