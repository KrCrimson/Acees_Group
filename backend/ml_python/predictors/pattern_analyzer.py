"""
Pattern analyzer for attendance behavior (US036 support).
"""
from typing import Dict, Any

import pandas as pd


class PatternAnalyzer:
    """Extract trend and seasonality-like patterns from aggregated data."""

    def analyze(self, df: pd.DataFrame, date_col: str = "fecha_hora", value_col: str = "count") -> Dict[str, Any]:
        if date_col not in df.columns or value_col not in df.columns:
            raise ValueError("Required columns not found")

        data = df.copy()
        data[date_col] = pd.to_datetime(data[date_col])
        data["day_of_week"] = data[date_col].dt.dayofweek
        data["hour"] = data[date_col].dt.hour

        by_day = data.groupby("day_of_week", as_index=False)[value_col].mean()
        by_hour = data.groupby("hour", as_index=False)[value_col].mean()

        return {
            "weekly_pattern": by_day.to_dict(orient="records"),
            "hourly_pattern": by_hour.to_dict(orient="records"),
            "user_story": "US036",
        }
