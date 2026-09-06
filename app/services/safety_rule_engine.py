"""
Deterministic safety rule engine.

Hardcoded safety rules always have priority over AI classification.
AI can help understand the user's description, but it cannot downgrade
a dangerous answer given to a safety-critical question.
"""

UNRESPONSIVE_THRESHOLD_SECONDS = 10


def severity_from_answers(answers: dict) -> int:
    """
    Convert hardcoded emergency assessment answers into a minimum severity.

    The deterministic rules have priority over the AI classifier.
    """

    severity = 1

    conscious = answers.get("conscious")
    breathing = answers.get("breathing")
    heavy_bleeding = answers.get("heavy_bleeding")

    # No consciousness is immediately critical.
    if conscious == "No":
        severity = max(severity, 4)

    # Not breathing normally is immediately critical.
    if breathing == "No":
        severity = max(severity, 4)

    # Heavy bleeding is at least serious.
    if heavy_bleeding == "Yes":
        severity = max(severity, 3)

    # Unsure on a critical symptom should be treated cautiously.
    if breathing == "Unsure":
        severity = max(severity, 3)

    if conscious == "Unsure":
        severity = max(severity, 2)

    if heavy_bleeding == "Unsure":
        severity = max(severity, 2)

    return severity


def decide_severity(
    ai_severity_hint: int,
    minutes_since_last_response: float,
    event_type: str,
    hardcoded_severity: int = 1,
) -> int:
    """
    Combine deterministic safety rules with the AI severity hint.

    Priority:
    1. Critical hardcoded answer -> 4
    2. AI says 4 -> 4
    3. Hardcoded safety severity
    4. AI severity
    """

    # Hardcoded safety rules can always force the severity upward.
    if hardcoded_severity >= 4:
        return 4

    # AI can identify a critical situation too.
    if ai_severity_hint == 4:
        return 4

    # Otherwise use the highest severity found.
    return max(
        hardcoded_severity,
        ai_severity_hint,
    )