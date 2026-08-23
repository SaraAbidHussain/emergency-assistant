from __future__ import annotations

from typing import Any
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_status_includes_nearby_help_list_with_mocked_api_response():
    user_id = "user-123"
    latest_location = {"lat": 24.86, "lng": 67.00}

    with patch("app.hospitals.requests.post") as mock_post:
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

        from app.main import latest_locations
        latest_locations[user_id] = latest_location

        response = client.get(f"/emergency/{user_id}/status")

    assert response.status_code == 200
    payload = response.json()
    assert "nearby_help" in payload
    assert isinstance(payload["nearby_help"], list)
    assert len(payload["nearby_help"]) >= 1
    assert payload["nearby_help"][0]["name"] in {"Demo Hospital", "Demo Clinic"}
