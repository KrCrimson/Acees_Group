"""
Hyperparameter tuning utilities.
"""
from typing import Dict, Any

from sklearn.model_selection import GridSearchCV


class HyperparameterTuner:
    """Run deterministic hyperparameter tuning using GridSearchCV."""

    def tune(self, estimator, param_grid: Dict[str, Any], X, y, cv: int = 5, scoring: str = "r2") -> Dict[str, Any]:
        search = GridSearchCV(estimator=estimator, param_grid=param_grid, cv=cv, scoring=scoring, n_jobs=-1)
        search.fit(X, y)
        return {
            "best_params": search.best_params_,
            "best_score": float(search.best_score_),
            "cv": cv,
            "scoring": scoring,
        }
