from __future__ import annotations

from collections import defaultdict
from typing import Any

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

app = FastAPI(title="Emergency Assistant Location Service")

# Store the latest known location per user_id. This is intentionally a dict now so it
# can be replaced later with Redis without changing the API contract or call sites.
latest_locations: dict[str, dict[str, Any]] = {}

# Each user_id can have multiple dashboard clients subscribed for live updates.
subscribers: defaultdict[str, set[WebSocket]] = defaultdict(set)

# Trusted contacts are kept in-memory for the demo service and can later be backed by Redis.
trusted_contacts: dict[str, list[str]] = {
    "user-123": ["demo-contact-1", "demo-contact-2"],
}


class ContactAddRequest(BaseModel):
    contact_id: str


@app.post("/contacts/{user_id}/add")
async def add_contact(user_id: str, payload: ContactAddRequest) -> dict[str, str]:
    if not payload.contact_id or not payload.contact_id.strip():
        raise HTTPException(status_code=400, detail="contact_id is required")

    contact_list = trusted_contacts.setdefault(user_id, [])
    if payload.contact_id not in contact_list:
        contact_list.append(payload.contact_id)

    return {"user_id": user_id, "contact_id": payload.contact_id, "status": "added"}


@app.get("/contacts/{user_id}")
async def get_contacts(user_id: str) -> dict[str, Any]:
    return {"user_id": user_id, "contacts": trusted_contacts.get(user_id, [])}


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


@app.get("/health")
async def healthcheck() -> dict[str, str]:
    return {"status": "ok"}


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

                ack = {"type": "ack", "status": "received", "user_id": user_id, "location": {"lat": lat, "lng": lng}, "timestamp": timestamp}
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
                ack = {"type": "ack", "status": "received", "user_id": user_id, "location": {"lat": lat, "lng": lng}, "timestamp": timestamp}
                await websocket.send_json(ack)
                await broadcast_to_subscribers(user_id, payload)
                continue

            await websocket.send_json({"type": "error", "error": "Unsupported message format"})

    except WebSocketDisconnect:
        subscribers[user_id].discard(websocket)
    except Exception:
        subscribers[user_id].discard(websocket)
        await websocket.close(code=1011)


# Local test idea: run uvicorn app.main:app --reload and open two browser WebSocket clients
# or a quick Python client for the same user_id; connect one client as a mobile sender and
# one or more clients as subscribers to confirm live updates are broadcast.
