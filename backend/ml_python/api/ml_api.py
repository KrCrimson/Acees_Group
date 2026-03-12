"""
Core ML API endpoints.
"""
from fastapi import APIRouter

ml_router = APIRouter()


@ml_router.get("/status")
async def ml_status():
    return {"status": "ok", "module": "ml"}


@ml_router.get("/models")
async def list_models():
    return {
        "models": [
            "linear_regression",
            "clustering",
            "time_series",
            "ensemble",
        ]
    }
