from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_contacts_endpoints_seed_and_add():
    response = client.get("/contacts/user-123")
    assert response.status_code == 200
    contacts = response.json()
    assert "contacts" in contacts
    assert contacts["contacts"] == ["demo-contact-1", "demo-contact-2"]

    add_response = client.post("/contacts/user-123/add", json={"contact_id": "demo-contact-3"})
    assert add_response.status_code == 200
    assert add_response.json()["contact_id"] == "demo-contact-3"

    updated = client.get("/contacts/user-123")
    assert updated.status_code == 200
    assert updated.json()["contacts"] == ["demo-contact-1", "demo-contact-2", "demo-contact-3"]
