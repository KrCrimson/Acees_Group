"""
ML Python Package for Acees Group Transport Analytics
====================================================

This package provides a comprehensive machine learning system for transport
data analysis, including prediction models, clustering, time series analysis,
and real-time monitoring capabilities.

Author: Acees Group Development Team
Version: 1.0.0
"""

__version__ = "1.0.0"
__author__ = "Acees Group Development Team"
__email__ = "dev@aceesgroup.com"

# Core imports for easy access
from .config.settings import Settings
from .config.ml_config import MLConfig
from .core.base_ml_service import BaseMLService

# Make key classes available at package level
__all__ = [
    "Settings",
    "MLConfig", 
    "BaseMLService",
]

# Package metadata
PACKAGE_INFO = {
    "name": "ml_python",
    "version": __version__,
    "description": "ML system for transport analytics",
    "author": __author__,
    "email": __email__,
    "features": [
        "Linear regression forecasting",
        "Clustering analysis", 
        "Time series prediction",
        "Peak hours detection",
        "Real-time monitoring",
        "Model optimization",
        "Data quality validation",
        "Automated training pipelines"
    ]
}