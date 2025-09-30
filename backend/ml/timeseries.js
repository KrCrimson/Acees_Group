'use strict';

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

module.exports = { movingAverage };


