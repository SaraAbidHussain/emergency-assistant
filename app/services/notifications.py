from __future__ import annotations

import json
import os
from typing import Any

import firebase_admin
from firebase_admin import messaging

from app import firebase_init  # noqa: F401 -- import triggers Firebase Admin init


def _location_link(location: dict[str, Any]) -> str:
    """Turns {lat, lng} into a tappable Google Maps link instead of raw
    coordinates, so the person receiving the alert can open it directly."""
    lat = location.get("lat")
    lng = location.get("lng")
    if lat is None or lng is None:
        return "Location unavailable"
    return f"https://maps.google.com/?q={lat},{lng}"


def notify_trusted_contacts(user_id: str, severity: int, emergency_type: str, location: dict[str, Any]) -> list[str]:
    """Send real push notifications to each trusted contact for a user via Firebase.

    Only contacts the user has explicitly added (trusted_contacts[user_id]) are
    ever considered, AND only those who have separately registered a real
    device token via POST /devices/register (done once when they open the
    app themselves) actually receive anything. Being added to someone's
    trusted contacts list never triggers a notification by itself — the
    contact has to have opened the app at least once first. Anyone not yet
    registered is safely skipped, never silently messaged some other way.
    """
    from app.main import device_tokens, trusted_contacts

    contacts = trusted_contacts.get(user_id, [])
    notified: list[str] = []

    for contact_id in contacts:
        device_token = device_tokens.get(contact_id)
        if not device_token:
            print(f"No registered device token for {contact_id}, skipping.")
            continue

        title = f"EMERGENCY ALERT - {user_id}"
        body = (
            f"Type: {emergency_type}. Severity: {severity}. "
            f"Location: {_location_link(location)}"
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