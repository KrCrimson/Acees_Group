"""
Peak hours predictor (US037).
"""
from typing import Dict, Any, List

import pandas as pd


class PeakHoursPredictor:
    """Predict peak hours based on historical counts."""

    def predict_peak_hours(self, df: pd.DataFrame, count_col: str = "count") -> Dict[str, Any]:
        if "hour" not in df.columns:
            raise ValueError("Input dataframe requires 'hour' column")
        if count_col not in df.columns:
            raise ValueError(f"Input dataframe requires '{count_col}' column")

        hourly = df.groupby("hour", as_index=False)[count_col].mean().sort_values(count_col, ascending=False)
        peak_hours: List[int] = hourly.head(3)["hour"].astype(int).tolist()

        return {
            "peak_hours": peak_hours,
            "hourly_profile": hourly.to_dict(orient="records"),
            "target_accuracy": 0.8,
            "user_story": "US037",
        }
