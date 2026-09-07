"""
firebase_init.py

Single shared initialization of the Firebase Admin SDK. Both push
notifications (notifications.py) and auth token verification
(auth_service.py) need the same initialized firebase_admin App — this
module centralizes that so it only happens once, regardless of which
one gets imported first.
"""

import json
import os

import firebase_admin
from firebase_admin import credentials

_firebase_creds_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
if _firebase_creds_json:
    cred = credentials.Certificate(json.loads(_firebase_creds_json))
else:
    cred = credentials.Certificate("firebase-service-account.json")

if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
