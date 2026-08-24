# Shared API contract — Tier 1

## POST /emergency/classify
Request:
{ "description": "string", "user_id": "string" }
Response:
{ "emergency_type": "injury", "severity_hint": 1-4, "confidence": 0.0-1.0, "reasoning": "string" }

## POST /emergency/event
Request:
{ "user_id": "string", "type": "trigger|answer|escalation|location_update", "payload": {} }
Response:
{ "event_id": "string", "timestamp": "iso8601", "current_severity": 1-4 }

## GET /emergency/{user_id}/status
Response:
{ "active": true, "severity": 1-4, "type": "injury", "status": "unresponsive|responding|resolved",
  "location": { "lat": 0.0, "lng": 0.0 }, "timeline": [ { "timestamp": "", "event": "" } ] }

## POST /emergency/{user_id}/escalate
Request: { "reason": "string" }
Response: { "escalated": true, "contacts_notified": ["string"] }