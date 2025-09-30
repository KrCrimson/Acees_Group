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

function predictLinear(model, x) {
  return model.slope * x + model.intercept;
}

module.exports = { trainLinearRegression1D, predictLinear };


