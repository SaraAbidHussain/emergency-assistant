import json
import asyncio
import websockets

async def sender():
    uri = "ws://localhost:8000/ws/location/user-123"
    async with websockets.connect(uri) as ws:
        payload = {"lat": 24.86, "lng": 67.0, "timestamp": "2026-08-24T12:00:00Z"}
        await ws.send(json.dumps(payload))
        print(await ws.recv())

asyncio.run(sender())