from __future__ import annotations

from collections import defaultdict
from typing import Any

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from app.routers import emergency, users
from app.repository.json_store import load_json, save_json

app = FastAPI(title="Emergency Backend", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(emergency.router)
app.include_router(users.router)


@app.get("/")
def root():
    return {"status": "ok", "service": "emergency-backend"}


# ---------------------------------------------------------------------------
# Realtime infra (Member 4) — location sharing + trusted contacts.
# Kept here (not a separate router) because notifications.py does a lazy
# `from app.main import trusted_contacts` import to reuse this same dict.
# These are intentionally simple dict/set structures so they can later be
# swapped for Redis without changing the API layer.
# ---------------------------------------------------------------------------

# latest_locations/subscribers are genuinely live/ephemeral (an open
# WebSocket can't survive a restart anyway), so these stay in-memory only.
latest_locations: dict[str, dict[str, Any]] = {}
subscribers: defaultdict[str, set[WebSocket]] = defaultdict(set)

# trusted_contacts and device_tokens are backed by data/contacts.json so
# they survive a server restart (previously pure in-memory dicts, wiped
# every restart — this is the fix for that).
_contacts_data = load_json(
    "contacts",
    default={
        "trusted_contacts": {"user-123": ["demo-contact-1", "demo-contact-2"]},
        "device_tokens": {},
    },
)
trusted_contacts: dict[str, list[str]] = _contacts_data.get("trusted_contacts", {})

# contact_id -> real FCM device token. Populated when a person opens the
# app and it registers their device (POST /devices/register). A contact_id
# appearing in someone's trusted_contacts list does NOT mean they get
# notified — they must have ALSO registered their own device here first.
# This is the safety boundary: adding a phone number/identifier as a
# trusted contact never sends anything by itself; the person on the other
# end has to have opened the app at least once for their device to be
# reachable at all.
device_tokens: dict[str, str] = _contacts_data.get("device_tokens", {})


def _persist_contacts() -> None:
    save_json(
        "contacts",
        {"trusted_contacts": trusted_contacts, "device_tokens": device_tokens},
    )


class ContactAddRequest(BaseModel):
    contact_id: str


class DeviceRegisterRequest(BaseModel):
    contact_id: str
    device_token: str


@app.get("/health")
async def healthcheck() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/contacts/{user_id}/add")
async def add_contact(user_id: str, payload: ContactAddRequest) -> dict[str, str]:
    if not payload.contact_id or not payload.contact_id.strip():
        raise HTTPException(status_code=400, detail="contact_id is required")

    contact_list = trusted_contacts.setdefault(user_id, [])
    if payload.contact_id not in contact_list:
        contact_list.append(payload.contact_id)
    _persist_contacts()

    return {"user_id": user_id, "contact_id": payload.contact_id, "status": "added"}


@app.get("/contacts/{user_id}")
async def get_contacts(user_id: str) -> dict[str, Any]:
    return {"user_id": user_id, "contacts": trusted_contacts.get(user_id, [])}


@app.post("/devices/register")
async def register_device(payload: DeviceRegisterRequest) -> dict[str, str]:
    """
    Called once when the app opens (any user — whether or not they're
    anyone's trusted contact yet). Saves their real FCM device token under
    their own identifier (e.g. phone number), so that whenever someone
    else adds that identifier as a trusted contact, notify_trusted_contacts()
    can actually reach their device.
    """
    if not payload.contact_id.strip() or not payload.device_token.strip():
        raise HTTPException(status_code=400, detail="contact_id and device_token are required")

    device_tokens[payload.contact_id] = payload.device_token
    _persist_contacts()
    return {"contact_id": payload.contact_id, "status": "registered"}


@app.get("/users")
async def list_users(exclude: str | None = None) -> dict[str, Any]:
    """
    Every identifier that has called POST /devices/register is, by
    definition, a real reachable user — so device_tokens.keys() doubles as
    the user directory without needing a separate store. `exclude` lets the
    caller hide their own identifier from the browse list.
    """
    usernames = [u for u in device_tokens.keys() if u != exclude]
    return {"users": usernames}


@app.get("/users/search")
async def search_users(q: str = "", exclude: str | None = None) -> dict[str, Any]:
    """
    Case-insensitive substring search over registered usernames, so the
    app can offer a "search and add" UI. Add the matched username as a
    trusted contact via the existing POST /contacts/{user_id}/add.
    """
    query = q.strip().lower()
    matches = [
        u for u in device_tokens.keys()
        if u != exclude and (query == "" or query in u.lower())
    ]
    return {"users": matches}


@app.websocket("/ws/location/{user_id}")
async def location_socket(websocket: WebSocket, user_id: str) -> None:
    await websocket.accept()

    try:
        while True:
            raw_message = await websocket.receive_json()
            message_type = raw_message.get("type")
            location_fields = {"lat", "lng", "timestamp"}

            # A dashboard client can subscribe to a user's live location stream.
            if message_type == "subscribe":
                subscribers[user_id].add(websocket)
                cached = latest_locations.get(user_id)
                if cached:
                    await websocket.send_json(
                        {
                            "type": "location",
                            "user_id": user_id,
                            "location": {"lat": cached["lat"], "lng": cached["lng"]},
                            "timestamp": cached.get("timestamp"),
                        }
                    )
                continue

            # Mobile clients send periodic updates in the format {lat, lng, timestamp}.
            if set(raw_message.keys()).issuperset(location_fields):
                lat = float(raw_message["lat"])
                lng = float(raw_message["lng"])
                timestamp = str(raw_message["timestamp"])

                latest_locations[user_id] = {
                    "lat": lat,
                    "lng": lng,
                    "timestamp": timestamp,
                }

                payload = {
                    "type": "location",
                    "user_id": user_id,
                    "location": {"lat": lat, "lng": lng},
                    "timestamp": timestamp,
                }

                ack = {
                    "type": "ack",
                    "status": "received",
                    "user_id": user_id,
                    "location": {"lat": lat, "lng": lng},
                    "timestamp": timestamp,
                }
                await websocket.send_json(ack)
                await broadcast_to_subscribers(user_id, payload)
                continue

            if message_type == "location":
                nested_location = raw_message.get("location", {})
                if not isinstance(nested_location, dict):
                    await websocket.send_json({"type": "error", "error": "location payload must be an object"})
                    continue

                lat = float(nested_location.get("lat"))
                lng = float(nested_location.get("lng"))
                timestamp = str(raw_message.get("timestamp"))

                latest_locations[user_id] = {
                    "lat": lat,
                    "lng": lng,
                    "timestamp": timestamp,
                }

                payload = {
                    "type": "location",
                    "user_id": user_id,
                    "location": {"lat": lat, "lng": lng},
                    "timestamp": timestamp,
                }
                ack = {
                    "type": "ack",
                    "status": "received",
                    "user_id": user_id,
                    "location": {"lat": lat, "lng": lng},
                    "timestamp": timestamp,
                }
                await websocket.send_json(ack)
                await broadcast_to_subscribers(user_id, payload)
                continue

            await websocket.send_json({"type": "error", "error": "Unsupported message format"})

    except WebSocketDisconnect:
        subscribers[user_id].discard(websocket)
    except Exception:
        subscribers[user_id].discard(websocket)
        await websocket.close(code=1011)


async def broadcast_to_subscribers(user_id: str, payload: dict[str, Any]) -> None:
    """Send a location update to all currently connected dashboard clients for a user."""
    stale_connections: set[WebSocket] = set()

    for websocket in list(subscribers.get(user_id, set())):
        try:
            await websocket.send_json(payload)
        except RuntimeError:
            stale_connections.add(websocket)
        except WebSocketDisconnect:
            stale_connections.add(websocket)

    for stale in stale_connections:
        subscribers[user_id].discard(stale)