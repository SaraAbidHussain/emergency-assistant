"""
AI classification service — STUB for now.

Member 3 (ai-classification branch) owns this file and will replace the
body of classify_emergency() with a real call to Alibaba Model Studio
(Qwen). The function signature and return shape must stay the same so
nothing else in the backend needs to change on integration day.
"""


def classify_emergency(description: str) -> dict:
    """
    STUB — returns a mock classification instead of calling Qwen.

    Real version (Member 3) will call qwen-plus with the description and
    return the same shape: {emergency_type, severity_hint, confidence}.
    """
    if not description:
        return {
            "emergency_type": "unknown",
            "severity_hint": 1,
            "confidence": 0.0,
        }

    return {
        "emergency_type": "injury",
        "severity_hint": 3,
        "confidence": 0.85,
    }