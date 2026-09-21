from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import database
from models import SyncRequest, SyncResponse, HealthResponse

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize database tables on startup
    database.init_db()
    yield

app = FastAPI(
    title="LNote Sync Backend",
    description="Cross-device synchronization server for LNote attendance & session tracker",
    version="1.0.0",
    lifespan=lifespan,
)

# Enable CORS for cross-device & web communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {
        "service": "LNote Backend",
        "status": "online",
        "health_check": "/api/health",
        "sync_endpoint": "/api/sync"
    }

@app.get("/api/health", response_model=HealthResponse)
def health_check():
    days_count, sessions_count = database.get_stats()
    return HealthResponse(
        status="ok",
        version="1.0.0",
        serverTimestamp=database.now_iso(),
        totalDays=days_count,
        totalSessions=sessions_count,
    )

@app.post("/api/sync", response_model=SyncResponse)
def sync_data(request: SyncRequest):
    try:
        merged = database.merge_sync_data(request)
        return merged
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sync error: {str(e)}")

@app.get("/api/sync", response_model=SyncResponse)
def get_sync_state():
    try:
        return database.get_full_state()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Fetch error: {str(e)}")

@app.post("/api/reset")
def reset_database():
    try:
        database.reset_db()
        return {"status": "success", "message": "Database reset successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Reset error: {str(e)}")
