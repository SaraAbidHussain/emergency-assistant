from unittest.mock import patch

from app.services.level_actions import get_level_actions


SAMPLE_LOCATION = {"lat": 31.5204, "lng": 74.3587}


# ---------- Level 1 — Minor ----------

def test_level_1_no_contacts_notified_and_no_nearby_help():
    result = get_level_actions(
        severity=1, user_id="u1", emergency_type="injury", location=SAMPLE_LOCATION
    )
    assert result["level_label"] == "minor"
    assert result["contacts_notified"] == []
    assert result["nearby_help"] == []
    assert "minor injury" in result["user_message"].lower()
    assert len(result["actions_taken"]) > 0


def test_level_1_does_not_call_notify_or_hospitals():
    with patch("app.services.level_actions.notify_trusted_contacts") as mock_notify, \
         patch("app.services.level_actions.find_nearby_hospitals") as mock_hospitals:
        get_level_actions(severity=1, user_id="u1", emergency_type="injury", location=SAMPLE_LOCATION)
        mock_notify.assert_not_called()
        mock_hospitals.assert_not_called()


# ---------- Level 2 — Moderate ----------

def test_level_2_calls_hospitals_but_not_notify():
    with patch("app.services.level_actions.notify_trusted_contacts") as mock_notify, \
         patch("app.services.level_actions.find_nearby_hospitals", return_value=[{"name": "Test Clinic"}]) as mock_hospitals:
        result = get_level_actions(severity=2, user_id="u1", emergency_type="injury", location=SAMPLE_LOCATION)

        mock_notify.assert_not_called()
        mock_hospitals.assert_called_once()
        assert result["level_label"] == "moderate"
        assert result["contacts_notified"] == []
        assert result["nearby_help"] == [{"name": "Test Clinic"}]


def test_level_2_without_location_skips_hospitals_call():
    with patch("app.services.level_actions.find_nearby_hospitals") as mock_hospitals:
        result = get_level_actions(severity=2, user_id="u1", emergency_type="injury", location=None)
        mock_hospitals.assert_not_called()
        assert result["nearby_help"] == []


# ---------- Level 3 — Serious ----------

def test_level_3_calls_both_notify_and_hospitals():
    with patch("app.services.level_actions.notify_trusted_contacts", return_value=["c1", "c2"]) as mock_notify, \
         patch("app.services.level_actions.find_nearby_hospitals", return_value=[{"name": "General Hospital"}]) as mock_hospitals:
        result = get_level_actions(severity=3, user_id="u1", emergency_type="injury", location=SAMPLE_LOCATION)

        mock_notify.assert_called_once()
        mock_hospitals.assert_called_once()
        assert result["level_label"] == "serious"
        assert result["contacts_notified"] == ["c1", "c2"]
        assert result["nearby_help"] == [{"name": "General Hospital"}]
        assert "emergency mode activated" in result["user_message"].lower()


def test_level_3_without_location_still_calls_notify_with_empty_location():
    with patch("app.services.level_actions.notify_trusted_contacts", return_value=["c1"]) as mock_notify, \
         patch("app.services.level_actions.find_nearby_hospitals") as mock_hospitals:
        result = get_level_actions(severity=3, user_id="u1", emergency_type="injury", location=None)

        mock_notify.assert_called_once()
        # location kwarg should be {} when None was passed in
        _, kwargs = mock_notify.call_args
        assert kwargs["location"] == {}
        mock_hospitals.assert_not_called()
        assert result["nearby_help"] == []


# ---------- Level 4 — Critical ----------

def test_level_4_calls_both_notify_and_hospitals_with_critical_messaging():
    with patch("app.services.level_actions.notify_trusted_contacts", return_value=["c1", "c2", "c3"]) as mock_notify, \
         patch("app.services.level_actions.find_nearby_hospitals", return_value=[{"name": "ER"}]) as mock_hospitals:
        result = get_level_actions(severity=4, user_id="u1", emergency_type="injury", location=SAMPLE_LOCATION)

        mock_notify.assert_called_once()
        mock_hospitals.assert_called_once()
        assert result["level_label"] == "critical"
        assert result["contacts_notified"] == ["c1", "c2", "c3"]
        assert "critical emergency mode" in result["user_message"].lower()
        assert any("continuous monitoring" in a.lower() for a in result["actions_taken"])


# ---------- Edge case: downstream service raises an exception ----------

def test_notify_exception_is_caught_and_returns_empty_list():
    with patch("app.services.level_actions.notify_trusted_contacts", side_effect=RuntimeError("FCM down")), \
         patch("app.services.level_actions.find_nearby_hospitals", return_value=[]):
        result = get_level_actions(severity=3, user_id="u1", emergency_type="injury", location=SAMPLE_LOCATION)
        # Should not raise — falls back to an empty list.
        assert result["contacts_notified"] == []


def test_hospitals_exception_is_caught_and_returns_empty_list():
    with patch("app.services.level_actions.notify_trusted_contacts", return_value=["c1"]), \
         patch("app.services.level_actions.find_nearby_hospitals", side_effect=RuntimeError("Overpass API down")):
        result = get_level_actions(severity=3, user_id="u1", emergency_type="injury", location=SAMPLE_LOCATION)
        # Should not raise — falls back to an empty list.
        assert result["nearby_help"] == []


def test_hospitals_exception_at_level_2_is_caught():
    with patch("app.services.level_actions.find_nearby_hospitals", side_effect=RuntimeError("network error")):
        result = get_level_actions(severity=2, user_id="u1", emergency_type="injury", location=SAMPLE_LOCATION)
        assert result["nearby_help"] == []


# ---------- Level 2 — optional location sharing (opt-in) ----------

def test_level_2_without_opt_in_does_not_notify_contacts():
    with patch("app.services.level_actions.notify_trusted_contacts") as mock_notify, \
         patch("app.services.level_actions.find_nearby_hospitals", return_value=[]):
        result = get_level_actions(
            severity=2, user_id="u1", emergency_type="injury",
            location=SAMPLE_LOCATION, share_location_opt_in=False,
        )
        mock_notify.assert_not_called()
        assert result["contacts_notified"] == []


def test_level_2_with_opt_in_notifies_contacts():
    with patch("app.services.level_actions.notify_trusted_contacts", return_value=["demo-contact-1"]) as mock_notify, \
         patch("app.services.level_actions.find_nearby_hospitals", return_value=[]):
        result = get_level_actions(
            severity=2, user_id="u1", emergency_type="injury",
            location=SAMPLE_LOCATION, share_location_opt_in=True,
        )
        mock_notify.assert_called_once()
        assert result["contacts_notified"] == ["demo-contact-1"]
        assert "shared" in result["user_message"].lower()


# ---------- chat_available flag ----------

def test_chat_available_true_for_level_1():
    result = get_level_actions(severity=1, user_id="u1", emergency_type="injury", location=None)
    assert result["chat_available"] is True


def test_chat_available_true_for_level_2():
    with patch("app.services.level_actions.find_nearby_hospitals", return_value=[]):
        result = get_level_actions(severity=2, user_id="u1", emergency_type="injury", location=None)
        assert result["chat_available"] is True


def test_chat_available_false_for_level_3():
    with patch("app.services.level_actions.notify_trusted_contacts", return_value=[]), \
         patch("app.services.level_actions.find_nearby_hospitals", return_value=[]):
        result = get_level_actions(severity=3, user_id="u1", emergency_type="injury", location=None)
        assert result["chat_available"] is False


def test_chat_available_false_for_level_4():
    with patch("app.services.level_actions.notify_trusted_contacts", return_value=[]), \
         patch("app.services.level_actions.find_nearby_hospitals", return_value=[]):
        result = get_level_actions(severity=4, user_id="u1", emergency_type="injury", location=None)
        assert result["chat_available"] is False


# ---------- Unexpected severity values ----------

def test_unexpected_severity_above_4_treated_as_critical():
    with patch("app.services.level_actions.notify_trusted_contacts", return_value=["c1"]), \
         patch("app.services.level_actions.find_nearby_hospitals", return_value=[]):
        result = get_level_actions(severity=5, user_id="u1", emergency_type="injury", location=SAMPLE_LOCATION)
        assert result["level_label"] == "critical"