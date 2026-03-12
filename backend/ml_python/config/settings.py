"""
Application settings and configuration management.
"""

import os
from typing import List, Optional, Any, Dict
from functools import lru_cache
from pydantic import BaseSettings, Field, validator
import logging

logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    """Application settings with environment variable support."""
    
    # Application Settings
    APP_NAME: str = Field(default="ML Python Transport Analytics", env="APP_NAME")
    VERSION: str = Field(default="1.0.0", env="VERSION")
    DEBUG: bool = Field(default=False, env="DEBUG")
    ENVIRONMENT: str = Field(default="development", env="ENVIRONMENT")
    
    # Server Configuration
    HOST: str = Field(default="0.0.0.0", env="HOST")
    PORT: int = Field(default=8000, env="PORT")
    WORKERS: int = Field(default=4, env="WORKERS")
    
    # Security
    SECRET_KEY: str = Field(default="ml-python-secret-key-change-in-production", env="SECRET_KEY")
    ALLOWED_HOSTS: List[str] = Field(default=["*"], env="ALLOWED_HOSTS")
    CORS_ORIGINS: List[str] = Field(default=["*"], env="CORS_ORIGINS")
    
    # Database Configuration
    MONGODB_URL: str = Field(default="mongodb://localhost:27017/aceesgroup_ml", env="MONGODB_URL")
    MONGODB_DB_NAME: str = Field(default="aceesgroup_ml", env="MONGODB_DB_NAME")
    MONGODB_MAX_CONNECTIONS: int = Field(default=100, env="MONGODB_MAX_CONNECTIONS")
    MONGODB_MIN_CONNECTIONS: int = Field(default=10, env="MONGODB_MIN_CONNECTIONS")
    
    # Redis Configuration
    REDIS_URL: str = Field(default="redis://localhost:6379/0", env="REDIS_URL")
    REDIS_MAX_CONNECTIONS: int = Field(default=20, env="REDIS_MAX_CONNECTIONS")
    REDIS_TTL_SECONDS: int = Field(default=3600, env="REDIS_TTL_SECONDS")
    
    # Model Storage Paths
    ML_MODEL_PATH: str = Field(default="./models", env="ML_MODEL_PATH")
    DATA_PATH: str = Field(default="./data", env="DATA_PATH")
    LOG_PATH: str = Field(default="./logs", env="LOG_PATH")
    
    # ML Configuration
    DEFAULT_MODEL_VERSION: str = Field(default="v1.0", env="DEFAULT_MODEL_VERSION")
    MAX_PREDICTION_BATCH_SIZE: int = Field(default=1000, env="MAX_PREDICTION_BATCH_SIZE")
    MODEL_CACHE_TTL: int = Field(default=86400, env="MODEL_CACHE_TTL")  # 24 hours
    
    # Training Configuration
    AUTO_TRAINING_ENABLED: bool = Field(default=True, env="AUTO_TRAINING_ENABLED")
    TRAINING_SCHEDULE_CRON: str = Field(default="0 2 * * *", env="TRAINING_SCHEDULE_CRON")  # Daily at 2 AM
    MAX_TRAINING_TIME_HOURS: int = Field(default=6, env="MAX_TRAINING_TIME_HOURS")
    
    # Monitoring
    ENABLE_METRICS: bool = Field(default=True, env="ENABLE_METRICS")
    METRICS_RETENTION_DAYS: int = Field(default=30, env="METRICS_RETENTION_DAYS")
    ALERT_EMAIL_RECIPIENTS: List[str] = Field(default=[], env="ALERT_EMAIL_RECIPIENTS")
    
    # Logging
    LOG_LEVEL: str = Field(default="INFO", env="LOG_LEVEL")
    LOG_FORMAT: str = Field(default="structured", env="LOG_FORMAT")  # structured or simple
    LOG_ROTATION_SIZE: str = Field(default="10MB", env="LOG_ROTATION_SIZE")
    LOG_RETENTION_COUNT: int = Field(default=10, env="LOG_RETENTION_COUNT")
    
    # Performance Thresholds (User Stories)
    TARGET_R2_SCORE: float = Field(default=0.7, env="TARGET_R2_SCORE")  # RF009.1
    TARGET_PEAK_ACCURACY: float = Field(default=0.8, env="TARGET_PEAK_ACCURACY")  # US037
    TARGET_SILHOUETTE_SCORE: float = Field(default=0.5, env="TARGET_SILHOUETTE_SCORE")  # RF009.2
    MIN_CLUSTER_SIZE: int = Field(default=10, env="MIN_CLUSTER_SIZE")
    MAX_CLUSTERS: int = Field(default=20, env="MAX_CLUSTERS")
    
    # Data Quality Thresholds
    MIN_DATA_COMPLETENESS: float = Field(default=0.85, env="MIN_DATA_COMPLETENESS")  # US030
    MAX_OUTLIER_PERCENTAGE: float = Field(default=0.05, env="MAX_OUTLIER_PERCENTAGE")
    MIN_SAMPLE_SIZE: int = Field(default=100, env="MIN_SAMPLE_SIZE")
    
    # API Rate Limiting
    API_RATE_LIMIT: str = Field(default="1000/hour", env="API_RATE_LIMIT")
    PREDICTION_RATE_LIMIT: str = Field(default="10000/hour", env="PREDICTION_RATE_LIMIT")
    
    # External Services
    NOTIFICATION_SERVICE_URL: Optional[str] = Field(default=None, env="NOTIFICATION_SERVICE_URL")
    EMAIL_SMTP_HOST: Optional[str] = Field(default=None, env="EMAIL_SMTP_HOST")
    EMAIL_SMTP_PORT: int = Field(default=587, env="EMAIL_SMTP_PORT")
    EMAIL_USERNAME: Optional[str] = Field(default=None, env="EMAIL_USERNAME")
    EMAIL_PASSWORD: Optional[str] = Field(default=None, env="EMAIL_PASSWORD")
    
    # Feature Flags
    ENABLE_ADVANCED_ALGORITHMS: bool = Field(default=True, env="ENABLE_ADVANCED_ALGORITHMS")
    ENABLE_REAL_TIME_PREDICTIONS: bool = Field(default=True, env="ENABLE_REAL_TIME_PREDICTIONS")
    ENABLE_MODEL_DRIFT_DETECTION: bool = Field(default=True, env="ENABLE_MODEL_DRIFT_DETECTION")
    ENABLE_AUTO_SCALING: bool = Field(default=False, env="ENABLE_AUTO_SCALING")
    
    @validator('LOG_LEVEL')
    def validate_log_level(cls, v):
        """Validate log level."""
        valid_levels = ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']
        if v.upper() not in valid_levels:
            raise ValueError(f'LOG_LEVEL must be one of: {valid_levels}')
        return v.upper()
    
    @validator('ENVIRONMENT')
    def validate_environment(cls, v):
        """Validate environment."""
        valid_envs = ['development', 'staging', 'production']
        if v.lower() not in valid_envs:
            raise ValueError(f'ENVIRONMENT must be one of: {valid_envs}')
        return v.lower()
    
    @validator('TARGET_R2_SCORE', 'TARGET_PEAK_ACCURACY', 'TARGET_SILHOUETTE_SCORE')
    def validate_score_range(cls, v):
        """Validate score ranges."""
        if not 0 <= v <= 1:
            raise ValueError('Score must be between 0 and 1')
        return v
    
    @validator('MIN_DATA_COMPLETENESS', 'MAX_OUTLIER_PERCENTAGE')
    def validate_percentage_range(cls, v):
        """Validate percentage ranges.""" 
        if not 0 <= v <= 1:
            raise ValueError('Percentage must be between 0 and 1')
        return v
    
    def get_database_config(self) -> Dict[str, Any]:
        """Get database configuration dictionary."""
        return {
            "url": self.MONGODB_URL,
            "db_name": self.MONGODB_DB_NAME,
            "max_connections": self.MONGODB_MAX_CONNECTIONS,
            "min_connections": self.MONGODB_MIN_CONNECTIONS
        }
    
    def get_redis_config(self) -> Dict[str, Any]:
        """Get Redis configuration dictionary."""
        return {
            "url": self.REDIS_URL,
            "max_connections": self.REDIS_MAX_CONNECTIONS,
            "default_ttl": self.REDIS_TTL_SECONDS
        }
    
    def get_ml_thresholds(self) -> Dict[str, Any]:
        """Get ML performance thresholds."""
        return {
            "r2_score": self.TARGET_R2_SCORE,
            "peak_accuracy": self.TARGET_PEAK_ACCURACY,
            "silhouette_score": self.TARGET_SILHOUETTE_SCORE,
            "min_cluster_size": self.MIN_CLUSTER_SIZE,
            "max_clusters": self.MAX_CLUSTERS,
            "data_completeness": self.MIN_DATA_COMPLETENESS,
            "max_outlier_pct": self.MAX_OUTLIER_PERCENTAGE,
            "min_sample_size": self.MIN_SAMPLE_SIZE
        }
    
    def is_production(self) -> bool:
        """Check if running in production environment."""
        return self.ENVIRONMENT == "production"
    
    def is_development(self) -> bool:
        """Check if running in development environment."""
        return self.ENVIRONMENT == "development"
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    try:
        settings = Settings()
        logger.info(f"Settings loaded for environment: {settings.ENVIRONMENT}")
        return settings
    except Exception as e:
        logger.error(f"Failed to load settings: {e}")
        raise RuntimeError(f"Configuration error: {e}")


# Global settings instance for easy access
settings = get_settings()