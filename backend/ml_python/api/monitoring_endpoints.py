"""
Monitoring API endpoints.
"""
from fastapi import APIRouter

monitoring_router = APIRouter()


@monitoring_router.get("/status")
async def monitoring_status():
    return {"status": "ok", "module": "monitoring"}


@monitoring_router.get("/health")
async def monitoring_health():
    return {
        "overall": "healthy",
        "checks": ["metrics", "drift", "alerts"],
    }
