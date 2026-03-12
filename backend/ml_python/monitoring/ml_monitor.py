"""
Central ML monitor service.
"""
from datetime import datetime
from typing import Dict, Any


class MLMonitor:
    """Aggregate high-level health for ML services."""

    def snapshot(self, components: Dict[str, str]) -> Dict[str, Any]:
        overall = "healthy" if all(v == "healthy" for v in components.values()) else "degraded"
        return {
            "timestamp": datetime.utcnow().isoformat(),
            "overall": overall,
            "components": components,
        }
