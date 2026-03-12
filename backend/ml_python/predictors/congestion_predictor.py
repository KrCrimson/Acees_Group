"""
Congestion predictor for operational alerts.
"""
from typing import Dict, Any

import pandas as pd


class CongestionPredictor:
    """Classify congestion level from attendance volume."""

    def predict(self, df: pd.DataFrame, value_col: str = "count") -> Dict[str, Any]:
        if value_col not in df.columns:
            raise ValueError(f"Missing required column: {value_col}")

        p75 = float(df[value_col].quantile(0.75))
        p90 = float(df[value_col].quantile(0.90))
        current = float(df[value_col].iloc[-1])

        if current >= p90:
            level = "high"
        elif current >= p75:
            level = "medium"
        else:
            level = "low"

        return {
            "congestion_level": level,
            "current_value": current,
            "thresholds": {"medium": p75, "high": p90},
        }
