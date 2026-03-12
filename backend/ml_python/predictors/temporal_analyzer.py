"""
Temporal analyzer for short-term temporal effects.
"""
from typing import Dict, Any

import pandas as pd


class TemporalAnalyzer:
    """Analyze temporal volatility and moving averages."""

    def summarize(self, df: pd.DataFrame, value_col: str = "count") -> Dict[str, Any]:
        if "fecha_hora" not in df.columns or value_col not in df.columns:
            raise ValueError("Required columns not found")

        data = df.copy()
        data["fecha_hora"] = pd.to_datetime(data["fecha_hora"])
        data = data.sort_values("fecha_hora")
        data["ma_24"] = data[value_col].rolling(24, min_periods=1).mean()
        data["volatility_24"] = data[value_col].rolling(24, min_periods=1).std().fillna(0)

        return {
            "latest_moving_average": float(data["ma_24"].iloc[-1]),
            "latest_volatility": float(data["volatility_24"].iloc[-1]),
            "rows": int(len(data)),
        }
