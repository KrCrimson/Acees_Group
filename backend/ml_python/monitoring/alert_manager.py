"""
Alert manager for monitoring events.
"""
from datetime import datetime
from typing import Dict, Any


class AlertManager:
    """Generate normalized alert payloads."""

    def build_alert(self, severity: str, message: str, context: Dict[str, Any] | None = None) -> Dict[str, Any]:
        return {
            "timestamp": datetime.utcnow().isoformat(),
            "severity": severity,
            "message": message,
            "context": context or {},
        }
