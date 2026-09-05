"""
location_service.py

Single source of truth for "what is this user's current location right now?"

Before this module existed, the app had two separate location stores that
never talked to each other:
  1. app.main.latest_locations — real GPS fixes pushed by the mobile app
     over Member 4's WebSocket (/ws/location/{user_id}).
  2. session.location — only ever set by get_status()'s hardcoded Lahore
     default, never updated from real GPS.

That's why location sharing on escalation looked broken: notify_trusted_contacts()
was either getting no location at all, or always the same hardcoded default,
never the user's real position.

resolve_location() fixes that by checking the live WebSocket data first,
falling back to whatever is stored on the session, and only returning None
if neither source has anything — callers (level_actions.py) already handle
None safely without crashing.
"""

from __future__ import annotations

from typing import Any, Optional


def get_realtime_location(user_id: str) -> Optional[dict[str, float]]:
    """
    Reads the most recent GPS fix Member 4's WebSocket handler has stored
    for this user. Lazy import to avoid a circular import with app.main
    (same pattern notifications.py already uses for trusted_contacts).
    """
    try:
        from app.main import latest_locations
    except Exception:
        return None

    cached = latest_locations.get(user_id)
    if not cached:
        return None

    try:
        return {"lat": float(cached["lat"]), "lng": float(cached["lng"])}
    except (KeyError, TypeError, ValueError):
        return None


def resolve_location(user_id: str, session_location: Any) -> Optional[dict[str, float]]:
    """
    Priority order:
    1. The freshest GPS fix from the WebSocket stream — this is the live
       location the mobile app is actively pushing, so it wins whenever
       it's available.
    2. The session's stored location (e.g. set by a location_update event,
       or a previous fallback), as a fallback.
    3. None — the caller must handle this gracefully (level_actions.py
       already skips the hospitals/location-sharing calls when this
       happens rather than crashing).
    """
    realtime = get_realtime_location(user_id)
    if realtime:
        return realtime

    if session_location is not None:
        return {"lat": session_location.lat, "lng": session_location.lng}

    return None