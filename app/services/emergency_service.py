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
from app.services import ai_service
from app.services.hospitals import find_nearby_hospitals
from app.services.notifications import notify_trusted_contacts
from app.services.safety_rule_engine import decide_severity


def classify_emergency(request: ClassifyRequest) -> ClassifyResponse:
    """
    Calls the real Qwen classification (ai_service.py — Member 3's module).
    Falls back safely inside ai_service itself if the API call fails.
    """
    result = ai_service.classify_emergency(request.description)
    return ClassifyResponse(
        emergency_type=result["emergency_type"],
        severity_hint=result["severity_hint"],
        confidence=result["confidence"],
        reasoning=result["reasoning"],
    )


def record_event(request: EventRequest) -> EventResponse:
    """
    Logs an event against the user's session:
    1. Pulls a description out of the payload, if any, and sends it to
       classify_emergency() (ai_service.py). If there's no description —
       e.g. an "answer" event, which carries {question_id, answer} instead
       of a description per Member 1's mobile implementation — we skip the
       AI call entirely and keep the session's current type/severity as
       the starting point, rather than letting an empty-string classification
       silently reset them to "unknown"/severity 1.
    2. Computes minutes_since_last_response from the session's tracked
       last_response_at.
    3. Passes the resulting severity hint into decide_severity() (the
       deterministic rule engine) — the rule engine has the final say,
       not the AI hint alone.
    4. Updates the session and timeline, returns the contract shape.
    """
    session = session_store.get_or_create_session(request.user_id)
    now = datetime.now(timezone.utc)

    description = request.payload.get("description", "").strip()

    if description:
        classification = ai_service.classify_emergency(description)
        ai_severity_hint = classification["severity_hint"]
        ai_emergency_type = classification.get("emergency_type")
    else:
        # No description in this event — don't call the AI on an empty
        # string, and don't let type/severity regress. Keep them as-is;
        # the rule engine below can still raise severity (e.g. unresponsive
        # trigger override) even without a fresh AI hint.
        ai_severity_hint = session.severity
        ai_emergency_type = None

    if session.last_response_at is None:
        minutes_since_last_response = 0.0
    else:
        elapsed_seconds = (now - session.last_response_at).total_seconds()
        minutes_since_last_response = elapsed_seconds / 60.0

    final_severity = decide_severity(
        ai_severity_hint=ai_severity_hint,
        minutes_since_last_response=minutes_since_last_response,
        event_type=request.type,
    )

    session.severity = final_severity
    session.active = True
    # Only overwrite the type when the AI actually classified something
    # this turn — never let a description-less event downgrade a known
    # type (e.g. "injury") back to "unknown".
    if ai_emergency_type and ai_emergency_type != "unknown":
        session.type = ai_emergency_type

    # "answer" events count as the user actively responding — reset the clock.
    if request.type == "answer":
        session.last_response_at = now

    entry = TimelineEntry(timestamp=now, event=f"{request.type} received")
    session.timeline.append(entry)
    session_store.save_session(session)

    return EventResponse(
        event_id=str(uuid.uuid4()),
        timestamp=now,
        current_severity=session.severity,
    )


def _build_summary(session) -> str:
    """
    Plain string formatting, no AI call — more reliable for a live demo
    than relying on another model call on the status-check hot path.
    """
    severity_labels = {1: "minor", 2: "moderate", 3: "serious", 4: "critical"}
    severity_word = severity_labels.get(session.severity, "unknown")
    emergency_type = session.type if session.type != "unknown" else "unspecified"

    action_count = len(session.timeline)
    if action_count == 0:
        actions_text = "No actions have been logged yet."
    elif action_count == 1:
        actions_text = "1 action has been logged so far."
    else:
        actions_text = f"{action_count} actions have been logged so far."

    last_event_text = ""
    if session.timeline:
        last_event_text = f" Most recent: {session.timeline[-1].event}."

    return (
        f"User is experiencing a {severity_word} ({session.severity}/4) "
        f"{emergency_type} emergency. Current status: {session.status}. "
        f"{actions_text}{last_event_text}"
    )


def get_status(user_id: str) -> StatusResponse:
    """
    Returns realistic mock status data plus a generated summary. If no
    session exists yet for this user_id, we create one so the endpoint
    still returns a valid shape instead of a 404 — matches "return
    realistic mock data" from Step 2.1.
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

    nearby_help = find_nearby_hospitals(
        lat=session.location.lat,
        lng=session.location.lng,
        emergency_type=session.type,
    )

    return StatusResponse(
        active=session.active,
        severity=session.severity,
        type=session.type if session.type != "unknown" else "injury",
        status=session.status,
        location=session.location,
        timeline=session.timeline,
        summary=_build_summary(session),
        nearby_help=nearby_help,
    )


def escalate_emergency(user_id: str, request: EscalateRequest) -> EscalateResponse:
    """
    Escalates the session and notifies trusted contacts via
    notifications.notify_trusted_contacts() (Member 4's realtime-infra
    module — currently a stub that prints instead of hitting real FCM,
    but returns real contact ids from app.main.trusted_contacts).
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

    location_dict = (
        {"lat": session.location.lat, "lng": session.location.lng}
        if session.location
        else {}
    )
    notified = notify_trusted_contacts(
        user_id=user_id,
        severity=session.severity,
        emergency_type=session.type,
        location=location_dict,
    )

    return EscalateResponse(
        escalated=True,
        contacts_notified=notified,
    )