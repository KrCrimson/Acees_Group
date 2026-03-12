"""
Runtime performance optimizer.
"""
from typing import Dict, Any


class PerformanceOptimizer:
    """Optimize runtime knobs based on latency and throughput targets."""

    def recommend(self, latency_ms: float, throughput_rps: float) -> Dict[str, Any]:
        actions = []
        if latency_ms > 300:
            actions.append("Enable model caching")
            actions.append("Batch prediction requests")
        if throughput_rps < 50:
            actions.append("Increase worker count")
        return {
            "latency_ms": latency_ms,
            "throughput_rps": throughput_rps,
            "actions": actions,
        }
