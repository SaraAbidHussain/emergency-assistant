from __future__ import annotations

from typing import Any

import firebase_admin
from firebase_admin import credentials, messaging

# Initialize Firebase once, when this module is first imported.
import json
import os

_firebase_creds_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
if _firebase_creds_json:
    cred = credentials.Certificate(json.loads(_firebase_creds_json))
else:
    cred = credentials.Certificate("firebase-service-account.json")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

# TEMPORARY: for testing, map your real device token to a contact_id.
# Replace "demo-contact-1" with your own real FCM token below.
TEST_DEVICE_TOKENS = {
    "demo-contact-1": "fD3_8GdmQnKB6X8hI8hjFZ:APA91bHm04TvV6hWUHnskEBZYD3UOVOg68z6yHgp-GxoQnRmBH5byk5W-PBJWkihDy4IM1gsIcUYDWShY6WiDeexQtp2O_tZgBnorSChVR9chybyMBmXGWI",
}


def notify_trusted_contacts(user_id: str, severity: int, emergency_type: str, location: dict[str, Any]) -> list[str]:
    """Send real push notifications to each trusted contact for a user via Firebase."""
    from app.main import trusted_contacts

    contacts = trusted_contacts.get(user_id, [])
    notified: list[str] = []

    for contact_id in contacts:
        device_token = TEST_DEVICE_TOKENS.get(contact_id)
        if not device_token:
            print(f"No real device token for {contact_id}, skipping.")
            continue

        title = f"EMERGENCY ALERT - {user_id}"
        body = (
            f"Type: {emergency_type}. Severity: {severity}. "
            f"Location: lat={location.get('lat')}, lng={location.get('lng')}"
        )

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=device_token,
        )

        try:
            response = messaging.send(message)
            print(f"Successfully sent notification to {contact_id}: {response}")
            notified.append(contact_id)
        except Exception as e:
            print(f"Failed to notify {contact_id}: {e}")

    return notified