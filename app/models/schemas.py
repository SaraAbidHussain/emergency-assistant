from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field


# ---------- POST /emergency/classify ----------

class ClassifyRequest(BaseModel):
    description: str
    user_id: str


class ClassifyResponse(BaseModel):
    emergency_type: str
    severity_hint: int = Field(ge=1, le=4)
    confidence: float = Field(ge=0.0, le=1.0)
    reasoning: str


# ---------- POST /emergency/event ----------

class EventRequest(BaseModel):
    user_id: str
    type: Literal["trigger", "answer", "escalation", "location_update"]
    payload: dict[str, Any] = Field(default_factory=dict)


class EventResponse(BaseModel):
    event_id: str
    timestamp: datetime
    current_severity: int = Field(ge=1, le=4)
    # Additive fields, not in the original CONTRACT.md shape — output of
    # level_actions.get_level_actions(), safe to ignore for any consumer
    # that only reads the original contract fields.
    level_label: str = ""
    actions_taken: list[str] = Field(default_factory=list)
    user_message: str = ""
    contacts_notified: list[str] = Field(default_factory=list)
    nearby_help: list[dict[str, Any]] = Field(default_factory=list)


# ---------- GET /emergency/{user_id}/status ----------

class Location(BaseModel):
    lat: float
    lng: float


class TimelineEntry(BaseModel):
    timestamp: datetime
    event: str


class StatusResponse(BaseModel):
    active: bool
    severity: int = Field(ge=1, le=4)
    type: str
    status: Literal["unresponsive", "responding", "resolved"]
    location: Location
    timeline: list[TimelineEntry]
    # Additive fields, not in the original CONTRACT.md shape.
    summary: str
    nearby_help: list[dict[str, Any]] = Field(default_factory=list)


# ---------- POST /emergency/{user_id}/escalate ----------

class EscalateRequest(BaseModel):
    reason: str


class EscalateResponse(BaseModel):
    escalated: bool
    contacts_notified: list[str]


# ---------- Internal: what we keep per active session in the store ----------

class EmergencySession(BaseModel):
    user_id: str
    active: bool = True
    severity: int = 1
    type: str = "unknown"
    status: Literal["unresponsive", "responding", "resolved"] = "responding"
    location: Optional[Location] = None
    timeline: list[TimelineEntry] = Field(default_factory=list)
    # Timestamp of the last event where the user actively responded
    # (e.g. an "answer" event). Used by the safety rule engine to compute
    # minutes_since_last_response. None means "no response tracked yet".
    last_response_at: Optional[datetime] = None