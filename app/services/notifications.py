from __future__ import annotations

from typing import Any


def notify_trusted_contacts(user_id: str, severity: int, emergency_type: str, location: dict[str, Any]) -> list[str]:
    """Simulate sending push notifications to each trusted contact for a user.

    This is a stub so the hackathon demo can work without Firebase configured yet.
    """
    # Import lazily to avoid a circular dependency with app.main while still reusing the
    # same in-memory trusted_contacts dictionary defined there.
    from app.main import trusted_contacts

    contacts = trusted_contacts.get(user_id, [])
    notified: list[str] = []

    for contact_id in contacts:
        device_token = f"stub-token-{contact_id}"
        title = f"EMERGENCY ALERT - {user_id}"
        body = (
            f"Type: {emergency_type}. Severity: {severity}. "
            f"Location: lat={location.get('lat')}, lng={location.get('lng')}"
        )
        print(f"Would send push to {device_token}: title={title!r}, body={body!r}")
        notified.append(contact_id)

    return notified
