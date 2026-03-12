"""
Main entry point for ML Python system
=====================================

FastAPI application for transport analytics ML services.
Provides RESTful API endpoints for machine learning operations.
"""

import asyncio
import uvicorn
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from contextlib import asynccontextmanager
import logging

# Local imports
from .config.settings import Settings, get_settings
from .config.logging_config import setup_logging
from .api.ml_api import ml_router
from .api.prediction_endpoints import prediction_router
from .api.monitoring_endpoints import monitoring_router
from .core.model_manager import ModelManager
from .automation.scheduler import AutomationScheduler

# Initialize logging
logger = logging.getLogger(__name__)

# Global instances
model_manager: ModelManager = None
scheduler: AutomationScheduler = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup and shutdown."""
    global model_manager, scheduler
    
    settings = get_settings()
    setup_logging()
    logger.info("🚀 Starting ML Python system...")
    
    # Initialize core services
    try:
        model_manager = ModelManager()
        await model_manager.initialize()
        logger.info("✅ Model manager initialized")
        
        scheduler = AutomationScheduler()
        await scheduler.start()
        logger.info("✅ Automation scheduler started")
        
        app.state.model_manager = model_manager
        app.state.scheduler = scheduler
        
        logger.info("🎯 ML Python system ready!")
        
    except Exception as e:
        logger.error(f"❌ Failed to initialize ML system: {e}")
        raise
    
    yield
    
    # Cleanup on shutdown
    logger.info("🔄 Shutting down ML Python system...")
    if scheduler:
        await scheduler.stop()
        logger.info("✅ Automation scheduler stopped")
        
    if model_manager:
        await model_manager.cleanup()
        logger.info("✅ Model manager cleaned up")
    
    logger.info("👋 ML Python system shutdown complete")


def create_app() -> FastAPI:
    """Create and configure FastAPI application."""
    settings = get_settings()
    
    app = FastAPI(
        title="ML Python - Transport Analytics API",
        description="Machine Learning system for Acees Group transport analytics",
        version="1.0.0",
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan
    )
    
    # Add security middleware
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=settings.ALLOWED_HOSTS
    )
    
    # Add CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # Include routers
    app.include_router(
        ml_router,
        prefix="/api/v1/ml",
        tags=["Machine Learning"]
    )
    
    app.include_router(
        prediction_router,
        prefix="/api/v1/predictions",
        tags=["Predictions"]
    )
    
    app.include_router(
        monitoring_router,
        prefix="/api/v1/monitoring",
        tags=["Monitoring"]
    )
    
    @app.get("/")
    async def root():
        """Health check endpoint."""
        return {
            "status": "healthy",
            "service": "ML Python Transport Analytics",
            "version": "1.0.0",
            "timestamp": asyncio.get_event_loop().time()
        }
    
    @app.get("/health")
    async def health_check():
        """Detailed health check."""
        try:
            model_status = "unknown"
            scheduler_status = "unknown"
            
            if hasattr(app.state, 'model_manager') and app.state.model_manager:
                model_status = "healthy" if await app.state.model_manager.health_check() else "unhealthy"
            
            if hasattr(app.state, 'scheduler') and app.state.scheduler:
                scheduler_status = "running" if app.state.scheduler.is_running() else "stopped"
            
            return {
                "status": "healthy",
                "components": {
                    "model_manager": model_status,
                    "scheduler": scheduler_status,
                    "database": "connected",  # TODO: Add actual DB health check
                    "redis": "connected"      # TODO: Add actual Redis health check
                },
                "uptime": asyncio.get_event_loop().time()
            }
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return {
                "status": "unhealthy",
                "error": str(e)
            }
    
    return app


# Create the FastAPI app
app = create_app()


def get_model_manager():
    """Dependency to get model manager instance."""
    if hasattr(app.state, 'model_manager'):
        return app.state.model_manager
    raise RuntimeError("Model manager not initialized")


def get_scheduler():
    """Dependency to get scheduler instance.""" 
    if hasattr(app.state, 'scheduler'):
        return app.state.scheduler
    raise RuntimeError("Scheduler not initialized")


if __name__ == "__main__":
    settings = get_settings()
    
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        log_level=settings.LOG_LEVEL.lower(),
        reload=settings.DEBUG,
        access_log=True,
        workers=1 if settings.DEBUG else settings.WORKERS
    )