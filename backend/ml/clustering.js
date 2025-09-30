'use strict';

function trainKMeans1D(values, k = 3, maxIters = 100) {
  if (!Array.isArray(values) || values.length < k) {
    throw new Error('Datos insuficientes para k-means');
  }
  const sorted = [...values].sort((a, b) => a - b);
  const centroids = [];
  for (let i = 1; i <= k; i++) {
    const idx = Math.floor((i * sorted.length) / (k + 1));
    centroids.push(sorted[idx]);
  }
  let assignments = new Array(values.length).fill(0);
  for (let iter = 0; iter < maxIters; iter++) {
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
    const sums = new Array(k).fill(0);
    const counts = new Array(k).fill(0);
    for (let i = 0; i < values.length; i++) {
      sums[assignments[i]] += values[i];
      counts[assignments[i]] += 1;
    }
    for (let c = 0; c < k; c++) {
      if (counts[c] > 0) centroids[c] = sums[c] / counts[c];
    }
    if (!changed) break;
  }
  const indexed = centroids.map((v, i) => ({ v, i })).sort((a, b) => a.v - b.v);
  const labels = ['low', 'medium', 'high'];
  const clusterLabels = new Array(k);
  indexed.forEach((item, rank) => {
    clusterLabels[item.i] = labels[Math.min(rank, labels.length - 1)];
  });
  return { centroids, clusterLabels, assignments };
}

module.exports = { trainKMeans1D };


