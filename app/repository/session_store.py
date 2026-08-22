from app.models.schemas import EmergencySession, TimelineEntry

# In-memory store: user_id -> EmergencySession
# NOTE: this resets whenever the server restarts. Fine for Tier 1 / demo.
# Swap this module for a real DB (RDS/Redis) later without touching the
# service or router layers, since they only ever call the functions below.
_sessions: dict[str, EmergencySession] = {}


def get_session(user_id: str) -> EmergencySession | None:
    return _sessions.get(user_id)


def get_or_create_session(user_id: str) -> EmergencySession:
    if user_id not in _sessions:
        _sessions[user_id] = EmergencySession(user_id=user_id)
    return _sessions[user_id]


def save_session(session: EmergencySession) -> None:
    _sessions[session.user_id] = session


def add_timeline_entry(user_id: str, entry: TimelineEntry) -> EmergencySession:
    session = get_or_create_session(user_id)
    session.timeline.append(entry)
    save_session(session)
    return session


def all_sessions() -> dict[str, EmergencySession]:
    return _sessions