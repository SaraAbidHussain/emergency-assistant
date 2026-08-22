import uuid
from datetime import datetime, timezone

from app.models.schemas import (
    ClassifyRequest,
    ClassifyResponse,
    EscalateRequest,
    EscalateResponse,
    EventRequest,
    EventResponse,
    Location,
    StatusResponse,
    TimelineEntry,
)
from app.repository import session_store


def classify_emergency(request: ClassifyRequest) -> ClassifyResponse:
    """
    MOCK for now — Member 3 (ai-classification branch) will replace the
    body of this function with a real Qwen call. The shape must keep
    matching ClassifyResponse / CONTRACT.md.
    """
    return ClassifyResponse(
        emergency_type="injury",
        severity_hint=3,
        confidence=0.85,
        reasoning=f"Mock classification based on description: '{request.description[:50]}'",
    )


def record_event(request: EventRequest) -> EventResponse:
    """
    Logs an event against the user's session, bumps a mock severity,
    and returns the event id + current severity per the contract.
    Real rule-engine wiring (decide_severity) comes in Step 2.3.
    """
    session = session_store.get_or_create_session(request.user_id)

    # Mock severity bump logic — replaced by the real rule engine later.
    severity_map = {
        "trigger": 3,
        "answer": session.severity,
        "escalation": 4,
        "location_update": session.severity,
    }
    session.severity = severity_map.get(request.type, session.severity)
    session.active = True

    now = datetime.now(timezone.utc)
    entry = TimelineEntry(timestamp=now, event=f"{request.type} received")
    session.timeline.append(entry)
    session_store.save_session(session)

    return EventResponse(
        event_id=str(uuid.uuid4()),
        timestamp=now,
        current_severity=session.severity,
    )


def get_status(user_id: str) -> StatusResponse:
    """
    Returns realistic mock status data. If no session exists yet for this
    user_id, we create one so the endpoint still returns a valid shape
    instead of a 404 — matches "return realistic mock data" from Step 2.1.
    """
    session = session_store.get_or_create_session(user_id)

    if session.location is None:
        session.location = Location(lat=31.5204, lng=74.3587)  # Lahore, mock default
        session_store.save_session(session)

    if not session.timeline:
        session.timeline.append(
            TimelineEntry(timestamp=datetime.now(timezone.utc), event="session created")
        )
        session_store.save_session(session)

    return StatusResponse(
        active=session.active,
        severity=session.severity,
        type=session.type if session.type != "unknown" else "injury",
        status=session.status,
        location=session.location,
        timeline=session.timeline,
    )


def escalate_emergency(user_id: str, request: EscalateRequest) -> EscalateResponse:
    """
    MOCK for now — Member 4 (realtime-infra branch) owns the real
    notify_trusted_contacts() call. Here we just mark the session
    escalated and return mock contact ids.
    """
    session = session_store.get_or_create_session(user_id)
    session.severity = max(session.severity, 3)
    session.status = "responding"
    session.timeline.append(
        TimelineEntry(
            timestamp=datetime.now(timezone.utc),
            event=f"escalated: {request.reason}",
        )
    )
    session_store.save_session(session)

    return EscalateResponse(
        escalated=True,
        contacts_notified=["contact_001", "contact_002"],
    )