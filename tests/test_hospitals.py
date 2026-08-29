from __future__ import annotations

import os
from unittest.mock import patch

os.environ.setdefault("BAILIAN_API_KEY", "test-key")
os.environ.setdefault("OPENAI_API_KEY", "test-key")

from fastapi.testclient import TestClient

from app.main import app
from app.models.schemas import Location
from app.repository import session_store


client = TestClient(app)


def test_status_includes_nearby_help_list_with_mocked_api_response():
    user_id = "user-123"
    latest_location = {"lat": 24.86, "lng": 67.00}
    session = session_store.get_or_create_session(user_id)
    session.location = Location(lat=latest_location["lat"], lng=latest_location["lng"])
    session_store.save_session(session)

    with patch("app.services.hospitals.requests.post") as mock_post:
        mock_post.return_value.json.return_value = {
            "elements": [
                {
                    "type": "node",
                    "lat": 24.861,
                    "lon": 67.01,
                    "tags": {"name": "Demo Hospital", "addr:street": "Main Street"},
                },
                {
                    "type": "node",
                    "lat": 24.87,
                    "lon": 67.02,
                    "tags": {"name": "Demo Clinic", "addr:street": "Park Avenue"},
                },
            ]
        }
        mock_post.return_value.raise_for_status.return_value = None

        response = client.get(f"/emergency/{user_id}/status")

    assert response.status_code == 200
    payload = response.json()
    assert "nearby_help" in payload
    assert isinstance(payload["nearby_help"], list)
    assert len(payload["nearby_help"]) >= 1
    assert payload["nearby_help"][0]["name"] in {"Demo Hospital", "Demo Clinic"}
