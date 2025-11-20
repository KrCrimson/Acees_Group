/**
 * Análisis Estadístico Avanzado para Métricas ML
 * Mejora las métricas con análisis estadístico más robusto
 */

class AdvancedMetricsAnalyzer {
  /**
   * Calcula métricas estadísticas avanzadas
   */
  calculateAdvancedMetrics(predicted, real) {
    if (predicted.length !== real.length) {
      throw new Error('Arrays deben tener la misma longitud');
    }

    const n = predicted.length;
    if (n === 0) {
      return this.getEmptyMetrics();
    }

    // Métricas básicas mejoradas
    const mae = this.calculateMAE(predicted, real);
    const rmse = this.calculateRMSE(predicted, real);
    const mape = this.calculateMAPE(predicted, real);
    const bias = this.calculateBias(predicted, real);
    const r2 = this.calculateR2(predicted, real);

    // Análisis de distribución de errores
    const errors = predicted.map((p, i) => p - real[i]);
    const errorDistribution = this.analyzeErrorDistribution(errors);

    // Identificación de outliers
    const outliers = this.detectOutliers(predicted, real);

    // Análisis de correlación
    const correlation = this.calculateCorrelation(predicted, real);

    // Intervalos de confianza
    const confidenceIntervals = this.calculateConfidenceIntervals(errors);

    return {
      basicMetrics: {
        mae: parseFloat(mae.toFixed(2)),
        rmse: parseFloat(rmse.toFixed(2)),
        mape: parseFloat(mape.toFixed(2)),
        bias: parseFloat(bias.toFixed(2)),
        r2: parseFloat(r2.toFixed(3)),
        correlation: parseFloat(correlation.toFixed(3))
      },
      errorDistribution,
      outliers,
      confidenceIntervals,
      accuracy: this.calculateOverallAccuracy(predicted, real, mae),
      reliability: this.calculateReliability(predicted, real, r2, correlation)
    };
  }

  /**
   * Calcula Mean Absolute Error
   */
  calculateMAE(predicted, real) {
    const errors = predicted.map((p, i) => Math.abs(p - real[i]));
    return errors.reduce((sum, e) => sum + e, 0) / errors.length;
  }

  /**
   * Calcula Root Mean Square Error
   */
  calculateRMSE(predicted, real) {
    const squaredErrors = predicted.map((p, i) => Math.pow(p - real[i], 2));
    const mse = squaredErrors.reduce((sum, se) => sum + se, 0) / squaredErrors.length;
    return Math.sqrt(mse);
  }

  /**
   * Calcula Mean Absolute Percentage Error
   */
  calculateMAPE(predicted, real) {
    const percentages = predicted.map((p, i) => {
      if (real[i] === 0) return p === 0 ? 0 : 100;
      return Math.abs((p - real[i]) / real[i]) * 100;
    });
    return percentages.reduce((sum, p) => sum + p, 0) / percentages.length;
  }

  /**
   * Calcula Bias (sesgo promedio)
   */
  calculateBias(predicted, real) {
    const errors = predicted.map((p, i) => p - real[i]);
    return errors.reduce((sum, e) => sum + e, 0) / errors.length;
  }

  /**
   * Calcula R² (coeficiente de determinación)
   */
  calculateR2(predicted, real) {
    const realMean = real.reduce((sum, r) => sum + r, 0) / real.length;
    const ssRes = predicted.reduce((sum, p, i) => sum + Math.pow(real[i] - p, 2), 0);
    const ssTot = real.reduce((sum, r) => sum + Math.pow(r - realMean, 2), 0);
    
    if (ssTot === 0) return 1; // Perfect fit si no hay variación
    return 1 - (ssRes / ssTot);
  }

  /**
   * Analiza distribución de errores
   */
  analyzeErrorDistribution(errors) {
    const sorted = [...errors].sort((a, b) => a - b);
    const n = errors.length;

    return {
      mean: parseFloat((errors.reduce((sum, e) => sum + e, 0) / n).toFixed(2)),
      median: parseFloat(this.calculateMedian(sorted).toFixed(2)),
      stdDeviation: parseFloat(this.calculateStdDeviation(errors).toFixed(2)),
      min: Math.min(...errors),
      max: Math.max(...errors),
      q1: parseFloat(sorted[Math.floor(n * 0.25)].toFixed(2)),
      q3: parseFloat(sorted[Math.floor(n * 0.75)].toFixed(2)),
      iqr: parseFloat((sorted[Math.floor(n * 0.75)] - sorted[Math.floor(n * 0.25)]).toFixed(2)),
      skewness: parseFloat(this.calculateSkewness(errors).toFixed(3)),
      kurtosis: parseFloat(this.calculateKurtosis(errors).toFixed(3))
    };
  }

  /**
   * Detecta outliers usando método IQR
   */
  detectOutliers(predicted, real) {
    const errors = predicted.map((p, i) => Math.abs(p - real[i]));
    const sorted = [...errors].sort((a, b) => a - b);
    const n = sorted.length;

    const q1 = sorted[Math.floor(n * 0.25)];
    const q3 = sorted[Math.floor(n * 0.75)];
    const iqr = q3 - q1;
    const lowerBound = q1 - 1.5 * iqr;
    const upperBound = q3 + 1.5 * iqr;

    const outliers = errors
      .map((error, index) => ({ error, index, predicted: predicted[index], real: real[index] }))
      .filter(item => item.error < lowerBound || item.error > upperBound);

    return {
      count: outliers.length,
      percentage: parseFloat((outliers.length / n * 100).toFixed(2)),
      outliers: outliers.slice(0, 10) // Primeros 10 como muestra
    };
  }

  /**
   * Calcula correlación de Pearson
   */
  calculateCorrelation(predicted, real) {
    const n = predicted.length;
    const predMean = predicted.reduce((sum, p) => sum + p, 0) / n;
    const realMean = real.reduce((sum, r) => sum + r, 0) / n;

    let numerator = 0;
    let predVariance = 0;
    let realVariance = 0;

    for (let i = 0; i < n; i++) {
      const predDiff = predicted[i] - predMean;
      const realDiff = real[i] - realMean;
      numerator += predDiff * realDiff;
      predVariance += predDiff * predDiff;
      realVariance += realDiff * realDiff;
    }

    const denominator = Math.sqrt(predVariance * realVariance);
    return denominator === 0 ? 0 : numerator / denominator;
  }

  /**
   * Calcula intervalos de confianza
   */
  calculateConfidenceIntervals(errors, confidenceLevel = 0.95) {
    const n = errors.length;
    const mean = errors.reduce((sum, e) => sum + e, 0) / n;
    const stdDev = this.calculateStdDeviation(errors);
    
    // Aproximación usando distribución t (simplificado)
    const tValue = 1.96; // Para 95% de confianza con n grande
    const margin = tValue * (stdDev / Math.sqrt(n));

    return {
      level: confidenceLevel,
      lower: parseFloat((mean - margin).toFixed(2)),
      upper: parseFloat((mean + margin).toFixed(2)),
      mean: parseFloat(mean.toFixed(2))
    };
  }

  /**
   * Calcula precisión general mejorada
   */
  calculateOverallAccuracy(predicted, real, mae) {
    const realMean = real.reduce((sum, r) => sum + r, 0) / real.length;
    if (realMean === 0) return 0;
    
    // Accuracy basada en error relativo
    const relativeError = mae / realMean;
    const accuracy = Math.max(0, 100 - (relativeError * 100));
    
    return parseFloat(accuracy.toFixed(2));
  }

  /**
   * Calcula confiabilidad del modelo
   */
  calculateReliability(predicted, real, r2, correlation) {
    // Combinación de R² y correlación
    const reliability = (r2 * 0.6 + Math.abs(correlation) * 0.4) * 100;
    return parseFloat(reliability.toFixed(2));
  }

  /**
   * Calcula mediana
   */
  calculateMedian(sorted) {
    const n = sorted.length;
    const mid = Math.floor(n / 2);
    return n % 2 === 0
      ? (sorted[mid - 1] + sorted[mid]) / 2
      : sorted[mid];
  }

  /**
   * Calcula desviación estándar
   */
  calculateStdDeviation(values) {
    const n = values.length;
    const mean = values.reduce((sum, v) => sum + v, 0) / n;
    const variance = values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / n;
    return Math.sqrt(variance);
  }

  /**
   * Calcula sesgo (skewness)
   */
  calculateSkewness(values) {
    const n = values.length;
    const mean = values.reduce((sum, v) => sum + v, 0) / n;
    const stdDev = this.calculateStdDeviation(values);
    
    if (stdDev === 0) return 0;

    const skewness = values.reduce((sum, v) => {
      return sum + Math.pow((v - mean) / stdDev, 3);
    }, 0) / n;

    return skewness;
  }

  /**
   * Calcula curtosis
   */
  calculateKurtosis(values) {
    const n = values.length;
    const mean = values.reduce((sum, v) => sum + v, 0) / n;
    const stdDev = this.calculateStdDeviation(values);
    
    if (stdDev === 0) return 0;

    const kurtosis = values.reduce((sum, v) => {
      return sum + Math.pow((v - mean) / stdDev, 4);
    }, 0) / n - 3; // -3 para obtener exceso de curtosis

    return kurtosis;
  }

  /**
   * Retorna métricas vacías
   */
  getEmptyMetrics() {
    return {
      basicMetrics: { mae: 0, rmse: 0, mape: 0, bias: 0, r2: 0, correlation: 0 },
      errorDistribution: {},
      outliers: { count: 0, percentage: 0, outliers: [] },
      confidenceIntervals: { level: 0.95, lower: 0, upper: 0, mean: 0 },
      accuracy: 0,
      reliability: 0
    };
  }
}

module.exports = AdvancedMetricsAnalyzer;

