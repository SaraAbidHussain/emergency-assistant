import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def test_location_websocket_streams_location_updates(client):
    with client.websocket_connect("/ws/location/user-123") as sender:
        sender.send_json({"lat": 12.34, "lng": 56.78, "timestamp": "2026-08-23T12:00:00Z"})
        ack = sender.receive_json()
        assert ack["type"] == "ack"
        assert ack["location"] == {"lat": 12.34, "lng": 56.78}

    with client.websocket_connect("/ws/location/user-123") as subscriber:
        subscriber.send_json({"type": "subscribe"})
        subscription_ack = subscriber.receive_json()
        assert subscription_ack["type"] == "location"

        with client.websocket_connect("/ws/location/user-123") as sender:
            sender.send_json({"lat": 23.45, "lng": 67.89, "timestamp": "2026-08-23T12:00:01Z"})
            sender_ack = sender.receive_json()
            assert sender_ack["location"] == {"lat": 23.45, "lng": 67.89}

            dashboard_message = subscriber.receive_json()
            assert dashboard_message["user_id"] == "user-123"
            assert dashboard_message["location"] == {"lat": 23.45, "lng": 67.89}
