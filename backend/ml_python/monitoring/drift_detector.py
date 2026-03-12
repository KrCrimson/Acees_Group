"""
Drift detector for distribution changes.
"""
from typing import Dict, Any

import numpy as np


class DriftDetector:
    """Compute a lightweight PSI-like drift signal."""

    def detect(self, reference: np.ndarray, current: np.ndarray, threshold: float = 0.1) -> Dict[str, Any]:
        ref = np.asarray(reference)
        cur = np.asarray(current)
        bins = np.histogram_bin_edges(ref, bins=10)
        ref_hist, _ = np.histogram(ref, bins=bins)
        cur_hist, _ = np.histogram(cur, bins=bins)
        ref_p = np.where(ref_hist == 0, 1e-8, ref_hist / max(ref_hist.sum(), 1))
        cur_p = np.where(cur_hist == 0, 1e-8, cur_hist / max(cur_hist.sum(), 1))
        psi = float(np.sum((cur_p - ref_p) * np.log(cur_p / ref_p)))
        return {
            "drift_score": psi,
            "threshold": threshold,
            "is_drift": psi > threshold,
        }
