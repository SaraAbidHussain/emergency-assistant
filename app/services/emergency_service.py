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
from app.services.level_actions import get_level_actions
from app.services.notifications import notify_trusted_contacts
from app.services.safety_rule_engine import decide_severity


def classify_emergency(request: ClassifyRequest) -> ClassifyResponse:
    """
    Calls the real Qwen classification through ai_service.py.
    ai_service handles API failures safely.
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
    Records an event against the user's emergency session.

    Behavior:
    1. If the event contains a description, classify it normally with Qwen.
    2. If the event is an answer event, classify the NEW answer using
       the existing emergency type as context.
    3. The previous session severity is NOT used as the new AI severity hint.
       This is important because otherwise a previous severity of 4 would
       permanently lock the session at severity 4.
    4. The deterministic safety rule engine applies safety overrides.
    5. The resulting severity is saved to the session.
    """

    session = session_store.get_or_create_session(request.user_id)
    now = datetime.now(timezone.utc)

    description = request.payload.get("description", "").strip()

    ai_severity_hint = None
    ai_emergency_type = None

    # ---------------------------------------------------------
    # CASE 1: Normal event with a description
    # ---------------------------------------------------------
    if description:
        classification = ai_service.classify_emergency(description)

        ai_severity_hint = classification["severity_hint"]
        ai_emergency_type = classification.get("emergency_type")

    # ---------------------------------------------------------
    # CASE 2: Answer event
    # ---------------------------------------------------------
    else:
        answer = str(request.payload.get("answer", "")).strip()
        question_id = str(request.payload.get("question_id", "")).strip()

        if answer:
            # IMPORTANT:
            # Do NOT do:
            #
            # ai_severity_hint = session.severity
            #
            # because if session.severity is already 4, the safety rule
            # engine will keep receiving 4 forever.
            #
            # Instead, ask the AI for a NEW classification based on the
            # emergency type and the user's latest answer.

            current_type = (
                session.type
                if session.type and session.type != "unknown"
                else "unknown"
            )

            answer_context = (
                f"Emergency type: {current_type}. "
                f"User's answer to first-aid question "
                f"(question_id: {question_id}): {answer}. "
                f"Reassess the current emergency severity based on this "
                f"new information. Do not automatically preserve the "
                f"previous severity. Return the severity that best matches "
                f"the updated situation."
            )

            classification = ai_service.classify_emergency(answer_context)

            # This is now a FRESH AI severity assessment.
            ai_severity_hint = classification["severity_hint"]
            ai_emergency_type = classification.get("emergency_type")

        else:
            # If an event has neither a description nor an answer,
            # there is no new information to classify.
            #
            # In this case, preserve the existing severity rather than
            # pretending that it is a fresh AI classification.
            ai_severity_hint = session.severity
            ai_emergency_type = None

    # ---------------------------------------------------------
    # Calculate time since the user's previous response
    # ---------------------------------------------------------
    if session.last_response_at is None:
        minutes_since_last_response = 0.0
    else:
        elapsed_seconds = (
            now - session.last_response_at
        ).total_seconds()

        minutes_since_last_response = elapsed_seconds / 60.0

    # ---------------------------------------------------------
    # Apply deterministic safety rules
    # ---------------------------------------------------------
    final_severity = decide_severity(
        ai_severity_hint=ai_severity_hint,
        minutes_since_last_response=minutes_since_last_response,
        event_type=request.type,
    )

    # ---------------------------------------------------------
    # Update session
    # ---------------------------------------------------------
    session.severity = final_severity
    session.active = True

    # Only update the emergency type when AI actually classified
    # something meaningful this turn.
    if ai_emergency_type and ai_emergency_type != "unknown":
        session.type = ai_emergency_type

    # Answer events mean the user is actively responding,
    # so reset the response timer.
    if request.type == "answer":
        session.last_response_at = now

    # ---------------------------------------------------------
    # Add event to timeline
    # ---------------------------------------------------------
    entry = TimelineEntry(
        timestamp=now,
        event=f"{request.type} received",
    )

    session.timeline.append(entry)

    session_store.save_session(session)

    location_dict = (
        {"lat": session.location.lat, "lng": session.location.lng}
        if session.location
        else None
    )
    level_result = get_level_actions(
        severity=session.severity,
        user_id=request.user_id,
        emergency_type=session.type,
        location=location_dict,
    )

    # ---------------------------------------------------------
    # Return response
    # ---------------------------------------------------------
    return EventResponse(
        event_id=str(uuid.uuid4()),
        timestamp=now,
        current_severity=session.severity,
        level_label=level_result["level_label"],
        actions_taken=level_result["actions_taken"],
        user_message=level_result["user_message"],
        contacts_notified=level_result["contacts_notified"],
        nearby_help=level_result["nearby_help"],
    )


def _build_summary(session) -> str:
    """
    Builds a plain-text emergency summary.
    No AI call is made here.
    """

    severity_labels = {
        1: "minor",
        2: "moderate",
        3: "serious",
        4: "critical",
    }

    severity_word = severity_labels.get(
        session.severity,
        "unknown",
    )

    emergency_type = (
        session.type
        if session.type != "unknown"
        else "unspecified"
    )

    action_count = len(session.timeline)

    if action_count == 0:
        actions_text = "No actions have been logged yet."
    elif action_count == 1:
        actions_text = "1 action has been logged so far."
    else:
        actions_text = (
            f"{action_count} actions have been logged so far."
        )

    last_event_text = ""

    if session.timeline:
        last_event_text = (
            f" Most recent: {session.timeline[-1].event}."
        )

    return (
        f"User is experiencing a {severity_word} "
        f"({session.severity}/4) "
        f"{emergency_type} emergency. "
        f"Current status: {session.status}. "
        f"{actions_text}"
        f"{last_event_text}"
    )


def get_status(user_id: str) -> StatusResponse:
    """
    Returns the current emergency session status.
    """

    session = session_store.get_or_create_session(user_id)

    # Add default location if none exists.
    if session.location is None:
        session.location = Location(
            lat=31.5204,
            lng=74.3587,
        )

        session_store.save_session(session)

    # Add initial timeline entry.
    if not session.timeline:
        session.timeline.append(
            TimelineEntry(
                timestamp=datetime.now(timezone.utc),
                event="session created",
            )
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
        type=(
            session.type
            if session.type != "unknown"
            else "injury"
        ),
        status=session.status,
        location=session.location,
        timeline=session.timeline,
        summary=_build_summary(session),
        nearby_help=nearby_help,
    )


def escalate_emergency(
    user_id: str,
    request: EscalateRequest,
) -> EscalateResponse:
    """
    Manually escalates the emergency.

    Manual escalation can increase severity to at least 3,
    but does not reduce an already higher severity.
    """

    session = session_store.get_or_create_session(user_id)

    session.severity = max(
        session.severity,
        3,
    )

    session.status = "responding"

    session.timeline.append(
        TimelineEntry(
            timestamp=datetime.now(timezone.utc),
            event=f"escalated: {request.reason}",
        )
    )

    session_store.save_session(session)

    location_dict = (
        {
            "lat": session.location.lat,
            "lng": session.location.lng,
        }
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

