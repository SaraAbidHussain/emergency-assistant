import asyncio
import json
import websockets

USER_ID = "user-123"

async def sender():
    uri = f"ws://localhost:8000/ws/location/{USER_ID}"
    async with websockets.connect(uri) as ws:
        payload = {
            "lat": 12.34,
            "lng": 56.78,
            "timestamp": "2026-08-24T12:00:00Z"
        }
        await ws.send(json.dumps(payload))
        print("SENDER got:", await ws.recv())

async def subscriber():
    uri = f"ws://localhost:8000/ws/location/{USER_ID}"
    async with websockets.connect(uri) as ws:
        await ws.send(json.dumps({"type": "subscribe"}))
        print("SUBSCRIBER initial:", await ws.recv())
        print("SUBSCRIBER live:", await ws.recv())

async def main():
    await asyncio.gather(sender(), subscriber())

asyncio.run(main())