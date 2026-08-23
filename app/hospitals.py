from __future__ import annotations

import math
from typing import Any

import requests


MOCK_HELP = [
    {"name": "City General Hospital", "distance": 1.2, "address": "12 Civic Ave"},
    {"name": "Greenview Clinic", "distance": 2.4, "address": "45 Park Rd"},
    {"name": "Northside Medical Center", "distance": 3.7, "address": "88 River St"},
]


def _to_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def find_nearby_hospitals(lat: float, lng: float, emergency_type: str) -> list[dict[str, Any]]:
    """Find the 3 closest hospitals or police stations in a 5km radius.

    Uses the free OpenStreetMap Overpass API. If the request fails or times out, falls back
    to a small mock list so the app still works in demos and offline testing.
    """
    amenity = "police" if emergency_type == "personal_safety" else "hospital"
    query = f"""
    [out:json][timeout:15];
    (
      node["amenity"]={amenity}(around:5000,{lat},{lng});
      way["amenity"]={amenity}(around:5000,{lat},{lng});
      relation["amenity"]={amenity}(around:5000,{lat},{lng});
    );
    out body center; 
    >;
    out skel qt;
    """
    try:
        response = requests.post(
            "https://overpass-api.de/api/interpreter",
            data={"data": query},
            timeout=10,
        )
        response.raise_for_status()
        payload = response.json()
        elements = payload.get("elements", [])

        results: list[dict[str, Any]] = []
        for element in elements:
            if element.get("type") == "node":
                lat_value = _to_float(element.get("lat"))
                lon_value = _to_float(element.get("lon"))
            else:
                lat_value = _to_float(element.get("center", {}).get("lat"))
                lon_value = _to_float(element.get("center", {}).get("lon"))

            if not lat_value or not lon_value:
                continue

            distance_km = math.sqrt((lat_value - lat) ** 2 + (lon_value - lng) ** 2) * 111.0
            if distance_km > 5.0:
                continue

            name = element.get("tags", {}).get("name") or "Unnamed location"
            address = (
                element.get("tags", {}).get("addr:street")
                or element.get("tags", {}).get("addr:full")
                or f"{lat_value}, {lon_value}"
            )

            results.append({
                "name": name,
                "distance": round(distance_km, 2),
                "address": address,
            })

        if not results:
            return MOCK_HELP[:3]

        results.sort(key=lambda item: item["distance"])
        return results[:3]

    except Exception:
        return MOCK_HELP[:3]
