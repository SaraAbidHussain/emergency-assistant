from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_escalate_endpoint_notifies_all_seeded_contacts():
    user_id = "user-123"
    response = client.post(f"/emergency/{user_id}/escalate", json={"reason": "Emergency detected"})

    assert response.status_code == 200
    assert response.json() == {
        "escalated": True,
        "contacts_notified": ["demo-contact-1", "demo-contact-2"],
    }
