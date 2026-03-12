"""
Performance tracker for model metrics over time.
"""
from datetime import datetime
from typing import Dict, Any, List


class PerformanceTracker:
    """Track metric points for trend analysis."""

    def __init__(self) -> None:
        self.history: List[Dict[str, Any]] = []

    def track(self, model_name: str, metrics: Dict[str, Any]) -> Dict[str, Any]:
        item = {
            "timestamp": datetime.utcnow().isoformat(),
            "model_name": model_name,
            "metrics": metrics,
        }
        self.history.append(item)
        return item

    def latest(self) -> Dict[str, Any]:
        return self.history[-1] if self.history else {}
