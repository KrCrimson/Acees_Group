// Utilidades de modelos ML ligeros sin dependencias externas
// - Regresión lineal (mínimos cuadrados) 1D
// - K-Means 1D para identificar clústeres de flujo
// - Promedio móvil simple para series temporales

'use strict';

function trainLinearRegression1D(xValues, yValues) {
  if (!Array.isArray(xValues) || !Array.isArray(yValues) || xValues.length !== yValues.length || xValues.length === 0) {
    throw new Error('Datos inválidos para regresión lineal');
  }
  const n = xValues.length;
  const meanX = xValues.reduce((a, b) => a + b, 0) / n;
  const meanY = yValues.reduce((a, b) => a + b, 0) / n;
  let num = 0;
  let den = 0;
  for (let i = 0; i < n; i++) {
    const dx = xValues[i] - meanX;
    num += dx * (yValues[i] - meanY);
    den += dx * dx;
  }
  const slope = den === 0 ? 0 : num / den;
  const intercept = meanY - slope * meanX;
  return { slope, intercept };
}

function predictLinearRegression1D(model, x) {
  return model.slope * x + model.intercept;
}

function trainKMeans1D(values, k = 3, maxIters = 100) {
  if (!Array.isArray(values) || values.length < k) {
    throw new Error('Datos insuficientes para k-means');
  }
  // Inicialización: elegir k percentiles aproximados
  const sorted = [...values].sort((a, b) => a - b);
  const centroids = [];
  for (let i = 1; i <= k; i++) {
    const idx = Math.floor((i * sorted.length) / (k + 1));
    centroids.push(sorted[idx]);
  }
  let assignments = new Array(values.length).fill(0);
  for (let iter = 0; iter < maxIters; iter++) {
    // Asignar
    let changed = false;
    for (let i = 0; i < values.length; i++) {
      let best = 0;
      let bestDist = Infinity;
      for (let c = 0; c < k; c++) {
        const d = Math.abs(values[i] - centroids[c]);
        if (d < bestDist) {
          bestDist = d;
          best = c;
        }
      }
      if (assignments[i] !== best) {
        assignments[i] = best;
        changed = true;
      }
    }
    // Recalcular centroides
    const sums = new Array(k).fill(0);
    const counts = new Array(k).fill(0);
    for (let i = 0; i < values.length; i++) {
      sums[assignments[i]] += values[i];
      counts[assignments[i]] += 1;
    }
    for (let c = 0; c < k; c++) {
      if (counts[c] > 0) {
        centroids[c] = sums[c] / counts[c];
      }
    }
    if (!changed) break;
  }
  // Ordenar centroides para etiquetar Low/Med/High
  const indexed = centroids.map((v, i) => ({ v, i })).sort((a, b) => a.v - b.v);
  const rankToLabel = ['low', 'medium', 'high'];
  const clusterLabels = new Array(k);
  indexed.forEach((item, rank) => {
    clusterLabels[item.i] = rankToLabel[Math.min(rank, rankToLabel.length - 1)];
  });
  return { centroids, clusterLabels };
}

function movingAverage(series, windowSize = 3) {
  if (windowSize <= 1) return [...series];
  const result = [];
  for (let i = 0; i < series.length; i++) {
    const start = Math.max(0, i - windowSize + 1);
    const slice = series.slice(start, i + 1);
    const avg = slice.reduce((a, b) => a + b, 0) / slice.length;
    result.push(avg);
  }
  return result;
}

module.exports = {
  trainLinearRegression1D,
  predictLinearRegression1D,
  trainKMeans1D,
  movingAverage
};


