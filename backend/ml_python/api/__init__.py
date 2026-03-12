"""API endpoints for ML services."""

from .ml_api import ml_router
from .prediction_endpoints import prediction_router
from .monitoring_endpoints import monitoring_router

__all__ = [
    "ml_router",
    "prediction_router",
    "monitoring_router"
]