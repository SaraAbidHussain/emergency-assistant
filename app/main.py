from fastapi import FastAPI

from app.routers import emergency

app = FastAPI(title="Emergency Backend", version="0.1.0")

app.include_router(emergency.router)


@app.get("/")
def root():
    return {"status": "ok", "service": "emergency-backend"}