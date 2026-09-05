from fastapi import APIRouter

from app.models.schemas import (
    ChatRequest,
    ChatResponse,
    ClassifyRequest,
    ClassifyResponse,
    EscalateRequest,
    EscalateResponse,
    EventRequest,
    EventResponse,
    StatusResponse,
)
from app.services import emergency_service

router = APIRouter(prefix="/emergency", tags=["emergency"])


@router.post("/classify", response_model=ClassifyResponse)
def classify(request: ClassifyRequest) -> ClassifyResponse:
    return emergency_service.classify_emergency(request)


@router.post("/event", response_model=EventResponse)
def event(request: EventRequest) -> EventResponse:
    return emergency_service.record_event(request)


@router.get("/{user_id}/status", response_model=StatusResponse)
def status(user_id: str) -> StatusResponse:
    return emergency_service.get_status(user_id)


@router.post("/{user_id}/escalate", response_model=EscalateResponse)
def escalate(user_id: str, request: EscalateRequest) -> EscalateResponse:
    return emergency_service.escalate_emergency(user_id, request)


@router.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    """
    Level 1-2 only — Level 3-4 sessions get a fixed safety message instead
    of an AI reply (see emergency_service.handle_chat).
    """
    return emergency_service.handle_chat(request)