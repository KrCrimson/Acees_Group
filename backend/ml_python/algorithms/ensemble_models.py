"""
Ensemble models for transport analytics.
"""
from typing import Dict, Any, List, Optional

import numpy as np
import pandas as pd
from sklearn.ensemble import VotingRegressor, RandomForestRegressor, GradientBoostingRegressor
from sklearn.linear_model import Ridge
from sklearn.metrics import r2_score


class EnsembleModels:
    """Build and evaluate simple ensemble regressors."""

    def __init__(self) -> None:
        self.model: Optional[VotingRegressor] = None
        self.metrics: Dict[str, Any] = {}

    def build_default_ensemble(self) -> VotingRegressor:
        estimators = [
            ("ridge", Ridge(alpha=1.0)),
            ("rf", RandomForestRegressor(n_estimators=200, random_state=42)),
            ("gbr", GradientBoostingRegressor(random_state=42)),
        ]
        self.model = VotingRegressor(estimators=estimators)
        return self.model

    def train(self, X_train: pd.DataFrame, y_train: pd.Series) -> Dict[str, Any]:
        if self.model is None:
            self.build_default_ensemble()
        self.model.fit(X_train, y_train)
        return {"status": "trained", "n_samples": int(len(X_train))}

    def predict(self, X: pd.DataFrame) -> np.ndarray:
        if self.model is None:
            raise RuntimeError("Ensemble model is not trained")
        return self.model.predict(X)

    def evaluate(self, X_val: pd.DataFrame, y_val: pd.Series) -> Dict[str, Any]:
        y_pred = self.predict(X_val)
        score = float(r2_score(y_val, y_pred))
        self.metrics = {
            "r2_score": score,
            "meets_rf009_1": score >= 0.7,
            "n_samples": int(len(y_val)),
        }
        return self.metrics
