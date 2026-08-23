"""
Deterministic safety rule engine.

This module contains NO AI calls and NO side effects — it's pure logic
that takes inputs and returns a severity level. That's intentional:
the rule engine is the safety-critical layer that must behave the same
way every time, independent of whatever the AI classifier says, and it
must be trivially unit-testable without mocking a network call.
"""

UNRESPONSIVE_THRESHOLD_MINUTES = 0.17  # ~10 seconds


def decide_severity(
    ai_severity_hint: int,
    minutes_since_last_response: float,
    event_type: str,
) -> int:
    """
    Returns the final severity level (1-4) after applying safety overrides
    on top of the AI's severity hint.

    Rules (checked in order):
    1. If ai_severity_hint is 4 -> always return 4, no exceptions.
    2. If the user has been unresponsive for more than ~10 seconds
       (minutes_since_last_response > 0.17) AND this event is a "trigger"
       -> force severity to at least 3, even if the AI hint was lower.
    3. Otherwise -> return the AI's severity hint as-is.
    """
    if ai_severity_hint == 4:
        return 4

    if minutes_since_last_response > UNRESPONSIVE_THRESHOLD_MINUTES and event_type == "trigger":
        return max(ai_severity_hint, 3)

    return ai_severity_hint