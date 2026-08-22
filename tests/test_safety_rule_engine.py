from app.services.safety_rule_engine import decide_severity


# ---------- Rule 1: ai_severity_hint == 4 always wins ----------

def test_severity_4_always_returned_regardless_of_other_factors():
    assert decide_severity(ai_severity_hint=4, minutes_since_last_response=0.0, event_type="answer") == 4


def test_severity_4_wins_even_with_short_unresponsive_time_and_trigger():
    assert decide_severity(ai_severity_hint=4, minutes_since_last_response=0.01, event_type="trigger") == 4


def test_severity_4_wins_even_with_long_unresponsive_time():
    assert decide_severity(ai_severity_hint=4, minutes_since_last_response=5.0, event_type="trigger") == 4


# ---------- Rule 2: unresponsive trigger forces at least severity 3 ----------

def test_unresponsive_trigger_forces_minimum_severity_3():
    # AI thought it was mild (severity 1), but user has been unresponsive
    # for longer than the threshold on a trigger event -> force to 3.
    assert decide_severity(ai_severity_hint=1, minutes_since_last_response=0.5, event_type="trigger") == 3


def test_unresponsive_trigger_does_not_downgrade_severity_3_or_higher():
    # AI already said 3 -> stays 3 (max(3, 3) == 3), rule doesn't need to raise it further.
    assert decide_severity(ai_severity_hint=3, minutes_since_last_response=0.5, event_type="trigger") == 3


def test_unresponsive_trigger_with_hint_above_3_keeps_the_higher_hint():
    # Only severity 4 is capped earlier by Rule 1, so test the max() behavior
    # with a value between the override floor and the cap doesn't apply here
    # since ai_severity_hint can only be 1-4; this covers ai_severity_hint == 3 kept as-is.
    assert decide_severity(ai_severity_hint=3, minutes_since_last_response=1.0, event_type="trigger") == 3


def test_at_exact_threshold_does_not_trigger_override():
    # Rule uses a strict ">" comparison, so exactly 0.17 should NOT trigger the override.
    assert decide_severity(ai_severity_hint=1, minutes_since_last_response=0.17, event_type="trigger") == 1


def test_just_above_threshold_triggers_override():
    assert decide_severity(ai_severity_hint=1, minutes_since_last_response=0.171, event_type="trigger") == 3


def test_unresponsive_time_alone_without_trigger_type_does_not_force_severity():
    # Long unresponsive time, but event_type is not "trigger" -> no override.
    assert decide_severity(ai_severity_hint=1, minutes_since_last_response=5.0, event_type="answer") == 1


def test_unresponsive_time_alone_with_escalation_type_does_not_force_severity():
    assert decide_severity(ai_severity_hint=2, minutes_since_last_response=5.0, event_type="escalation") == 2


# ---------- Rule 3: otherwise, pass through the AI hint unchanged ----------

def test_short_response_time_passes_through_hint_unchanged():
    assert decide_severity(ai_severity_hint=2, minutes_since_last_response=0.05, event_type="trigger") == 2


def test_answer_event_type_passes_through_hint_unchanged():
    assert decide_severity(ai_severity_hint=1, minutes_since_last_response=0.0, event_type="answer") == 1


def test_location_update_event_type_passes_through_hint_unchanged():
    assert decide_severity(ai_severity_hint=3, minutes_since_last_response=0.0, event_type="location_update") == 3