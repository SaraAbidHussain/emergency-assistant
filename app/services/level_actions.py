"""
level_actions.py

Turns a decided severity (1-4) into the concrete actions and user-facing
message described in the "Injury Severity Levels" spec:

  Level 1 — Minor:    basic first-aid guidance, no automatic notification.
  Level 2 — Moderate: first-aid + nearby help shown, notification is a
                       suggestion, not automatic.
  Level 3 — Serious:  emergency mode — automatic contact notification +
                       nearby hospitals + live location sharing.
  Level 4 — Critical: same automatic actions as Level 3, more urgent
                       messaging, continuous monitoring framing.

This module only orchestrates calls to the existing service functions
(notify_trusted_contacts, find_nearby_hospitals) — it makes no AI calls
and no severity decisions of its own; decide_severity() in
safety_rule_engine.py has already decided the level by the time this
runs.
"""

from __future__ import annotations

import logging
from typing import Any, Optional

from app.services.hospitals import find_nearby_hospitals
from app.services.notifications import notify_trusted_contacts

logger = logging.getLogger(__name__)

LEVEL_LABELS = {
    1: "minor",
    2: "moderate",
    3: "serious",
    4: "critical",
}


def _safe_find_nearby_hospitals(
    location: Optional[dict[str, Any]], emergency_type: str
) -> list[dict[str, Any]]:
    """Never let a hospitals lookup failure break the response."""
    if not location:
        return []
    try:
        return find_nearby_hospitals(
            lat=location["lat"],
            lng=location["lng"],
            emergency_type=emergency_type,
        )
    except Exception as exc:
        logger.warning("find_nearby_hospitals failed: %s", exc)
        return []


def _safe_notify_trusted_contacts(
    user_id: str, severity: int, emergency_type: str, location: Optional[dict[str, Any]]
) -> list[str]:
    """Never let a notification failure break the response."""
    try:
        return notify_trusted_contacts(
            user_id=user_id,
            severity=severity,
            emergency_type=emergency_type,
            location=location or {},
        )
    except Exception as exc:
        logger.warning("notify_trusted_contacts failed: %s", exc)
        return []


def get_level_actions(
    severity: int,
    user_id: str,
    emergency_type: str,
    location: Optional[dict[str, Any]],
) -> dict[str, Any]:
    """
    Returns:
    {
      "level_label": str,
      "actions_taken": list[str],
      "user_message": str,
      "contacts_notified": list[str],
      "nearby_help": list[dict],
    }
    """
    level_label = LEVEL_LABELS.get(severity, "unknown")

    if severity == 1:
        return {
            "level_label": level_label,
            "actions_taken": [
                "Provided basic first-aid guidance",
                "Asked user to confirm safety",
            ],
            "user_message": (
                "You appear to have a minor injury. Clean the wound and "
                "apply appropriate basic first aid. Are you safe?"
            ),
            "contacts_notified": [],
            "nearby_help": [],
        }

    if severity == 2:
        nearby_help = _safe_find_nearby_hospitals(location, emergency_type)
        return {
            "level_label": level_label,
            "actions_taken": [
                "Provided immediate first-aid instructions",
                "Recommended nearby medical assistance",
                "Suggested contacting a trusted friend",
            ],
            "user_message": (
                "This looks like a moderate injury. Please follow the "
                "first-aid steps and consider contacting a trusted friend."
            ),
            "contacts_notified": [],
            "nearby_help": nearby_help,
        }

    if severity == 3:
        contacts_notified = _safe_notify_trusted_contacts(
            user_id, severity, emergency_type, location
        )
        nearby_help = _safe_find_nearby_hospitals(location, emergency_type)
        return {
            "level_label": level_label,
            "actions_taken": [
                "Activated emergency mode",
                "Shared live location with trusted contacts",
                "Recommended nearest appropriate hospital",
                "Generated emergency summary",
            ],
            "user_message": (
                "Emergency mode activated. Your trusted contacts have been "
                "notified and your location is being shared."
            ),
            "contacts_notified": contacts_notified,
            "nearby_help": nearby_help,
        }

    # severity == 4 (or any unexpected value >= 4) — treat as critical,
    # the most cautious option, rather than silently doing nothing.
    contacts_notified = _safe_notify_trusted_contacts(
        user_id, severity, emergency_type, location
    )
    nearby_help = _safe_find_nearby_hospitals(location, emergency_type)
    return {
        "level_label": LEVEL_LABELS.get(4, "critical"),
        "actions_taken": [
            "Activated critical emergency mode",
            "Immediately notified trusted contacts",
            "Shared live location",
            "Displaying nearby emergency facilities",
            "Continuous monitoring active",
        ],
        "user_message": (
            "Critical emergency mode activated. Emergency contacts have "
            "been notified immediately. Stay as still and calm as possible."
        ),
        "contacts_notified": contacts_notified,
        "nearby_help": nearby_help,
    }
