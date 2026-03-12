"""
Resource optimization helper.
"""
from typing import Dict, Any


class ResourceOptimizer:
    """Simple CPU/memory recommendation engine."""

    def evaluate(self, cpu_pct: float, memory_pct: float) -> Dict[str, Any]:
        status = "healthy"
        if cpu_pct > 85 or memory_pct > 85:
            status = "critical"
        elif cpu_pct > 70 or memory_pct > 70:
            status = "warning"

        return {
            "status": status,
            "cpu_pct": cpu_pct,
            "memory_pct": memory_pct,
            "scale_up": status in {"warning", "critical"},
        }
