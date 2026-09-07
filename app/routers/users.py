from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.services import auth_service

router = APIRouter(prefix="/users", tags=["users"])


class ProfileRequest(BaseModel):
    name: str
    phone_number: str
    blood_group: str
    dob: str  # "YYYY-MM-DD"


@router.post("/profile")
def create_or_update_profile(
    payload: ProfileRequest,
    decoded_token: dict = Depends(auth_service.verify_token),
) -> dict:
    """
    Call this once right after the frontend signs the user up (or on
    first login if no profile exists yet) via Firebase Auth. Requires
    an `Authorization: Bearer <firebase_id_token>` header — the uid and
    email come from that verified token, not from the request body, so
    a user can never write another user's profile.
    """
    uid = decoded_token["uid"]
    email = decoded_token.get("email", "")
    return auth_service.save_profile(
        uid=uid,
        name=payload.name,
        email=email,
        phone_number=payload.phone_number,
        blood_group=payload.blood_group,
        dob=payload.dob,
    )


@router.get("/profile/me")
def get_my_profile(decoded_token: dict = Depends(auth_service.verify_token)) -> dict:
    """Returns the signed-in user's own profile. Requires the same Authorization header."""
    uid = decoded_token["uid"]
    profile = auth_service.get_profile(uid)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found — call POST /users/profile first")
    return profile
