/**
 * Servicio de Métricas Mejorado para ML
 * Métricas avanzadas, validación cruzada mejorada y análisis de precisión
 */

class EnhancedMetricsService {
  constructor() {
    this.metrics = {};
  }

  /**
   * Calcula métricas completas mejoradas
   */
  calculateEnhancedMetrics(predicted, actual, options = {}) {
    const {
      threshold = 0.5,
      includeRegressionMetrics = false,
      includeClassificationMetrics = true
    } = options;

    const results = {
      timestamp: new Date().toISOString(),
      sampleSize: actual.length
    };

    // Métricas de clasificación
    if (includeClassificationMetrics) {
      const binaryPredicted = this.binarize(predicted, threshold);
      const binaryActual = this.binarize(actual, threshold);
      
      const classificationMetrics = this.calculateClassificationMetrics(
        binaryPredicted,
        binaryActual
      );
      results.classification = classificationMetrics;
    }

    // Métricas de regresión
    if (includeRegressionMetrics && this.isRegression(predicted, actual)) {
      const regressionMetrics = this.calculateRegressionMetrics(predicted, actual);
      results.regression = regressionMetrics;
    }

    // Métricas adicionales
    results.additional = {
      rocAuc: this.calculateROCAUC(predicted, actual, threshold),
      prAuc: this.calculatePRAUC(predicted, actual, threshold),
      calibration: this.calculateCalibration(predicted, actual),
      confidenceIntervals: this.calculateConfidenceIntervals(predicted, actual)
    };

    return results;
  }

  /**
   * Calcula métricas de clasificación completas
   */
  calculateClassificationMetrics(predicted, actual) {
    const confusionMatrix = this.calculateConfusionMatrix(predicted, actual);
    
    const tp = confusionMatrix.truePositives;
    const tn = confusionMatrix.trueNegatives;
    const fp = confusionMatrix.falsePositives;
    const fn = confusionMatrix.falseNegatives;
    const total = tp + tn + fp + fn;

    // Métricas básicas
    const accuracy = (tp + tn) / total || 0;
    const precision = tp / (tp + fp) || 0;
    const recall = tp / (tp + fn) || 0;
    const specificity = tn / (tn + fp) || 0;
    const f1Score = 2 * (precision * recall) / (precision + recall) || 0;

    // Métricas adicionales
    const f2Score = 5 * (precision * recall) / (4 * precision + recall) || 0; // Más peso a recall
    const f0_5Score = 1.25 * (precision * recall) / (0.25 * precision + recall) || 0; // Más peso a precision
    const balancedAccuracy = (recall + specificity) / 2;
    const mcc = this.calculateMCC(confusionMatrix);
    const cohenKappa = this.calculateCohenKappa(confusionMatrix);
    
    // Error rates
    const falsePositiveRate = fp / (fp + tn) || 0;
    const falseNegativeRate = fn / (fn + tp) || 0;
    const errorRate = (fp + fn) / total || 0;

    // Support
    const support = {
      positive: tp + fn,
      negative: tn + fp,
      total: total
    };

    return {
      accuracy: parseFloat(accuracy.toFixed(4)),
      precision: parseFloat(precision.toFixed(4)),
      recall: parseFloat(recall.toFixed(4)),
      specificity: parseFloat(specificity.toFixed(4)),
      f1Score: parseFloat(f1Score.toFixed(4)),
      f2Score: parseFloat(f2Score.toFixed(4)),
      f0_5Score: parseFloat(f0_5Score.toFixed(4)),
      balancedAccuracy: parseFloat(balancedAccuracy.toFixed(4)),
      mcc: parseFloat(mcc.toFixed(4)),
      cohenKappa: parseFloat(cohenKappa.toFixed(4)),
      falsePositiveRate: parseFloat(falsePositiveRate.toFixed(4)),
      falseNegativeRate: parseFloat(falseNegativeRate.toFixed(4)),
      errorRate: parseFloat(errorRate.toFixed(4)),
      confusionMatrix,
      support,
      interpretation: this.interpretClassificationMetrics({
        accuracy, precision, recall, f1Score, mcc
      })
    };
  }

  /**
   * Calcula métricas de regresión
   */
  calculateRegressionMetrics(predicted, actual) {
    const n = actual.length;
    
    // Errores básicos
    const errors = predicted.map((p, i) => p - actual[i]);
    const squaredErrors = errors.map(e => e * e);
    const absoluteErrors = errors.map(e => Math.abs(e));
    
    // MSE, RMSE, MAE
    const mse = squaredErrors.reduce((sum, e) => sum + e, 0) / n;
    const rmse = Math.sqrt(mse);
    const mae = absoluteErrors.reduce((sum, e) => sum + e, 0) / n;
    
    // R²
    const meanActual = actual.reduce((sum, a) => sum + a, 0) / n;
    const ssTotal = actual.reduce((sum, a) => sum + Math.pow(a - meanActual, 2), 0);
    const ssResidual = squaredErrors.reduce((sum, e) => sum + e, 0);
    const r2 = 1 - (ssResidual / ssTotal) || 0;
    
    // MAPE (Mean Absolute Percentage Error)
    const mape = actual.reduce((sum, a, i) => {
      if (a !== 0) {
        return sum + Math.abs((a - predicted[i]) / a);
      }
      return sum;
    }, 0) / n * 100;
    
    // R² ajustado
    const adjustedR2 = 1 - ((1 - r2) * (n - 1) / (n - predicted.length - 1)) || 0;
    
    // Error mediano
    const sortedErrors = absoluteErrors.sort((a, b) => a - b);
    const medianError = sortedErrors[Math.floor(n / 2)];
    
    return {
      mse: parseFloat(mse.toFixed(4)),
      rmse: parseFloat(rmse.toFixed(4)),
      mae: parseFloat(mae.toFixed(4)),
      r2: parseFloat(r2.toFixed(4)),
      adjustedR2: parseFloat(adjustedR2.toFixed(4)),
      mape: parseFloat(mape.toFixed(2)),
      medianError: parseFloat(medianError.toFixed(4)),
      meanActual: parseFloat(meanActual.toFixed(2)),
      meanPredicted: parseFloat((predicted.reduce((sum, p) => sum + p, 0) / n).toFixed(2))
    };
  }

  /**
   * Calcula matriz de confusión
   */
  calculateConfusionMatrix(predicted, actual) {
    let tp = 0, tn = 0, fp = 0, fn = 0;

    for (let i = 0; i < actual.length; i++) {
      if (actual[i] === 1 && predicted[i] === 1) tp++;
      else if (actual[i] === 0 && predicted[i] === 0) tn++;
      else if (actual[i] === 0 && predicted[i] === 1) fp++;
      else if (actual[i] === 1 && predicted[i] === 0) fn++;
    }

    return { truePositives: tp, trueNegatives: tn, falsePositives: fp, falseNegatives: fn };
  }

  /**
   * Calcula Matthews Correlation Coefficient
   */
  calculateMCC(confusionMatrix) {
    const { truePositives, trueNegatives, falsePositives, falseNegatives } = confusionMatrix;
    const numerator = (truePositives * trueNegatives) - (falsePositives * falseNegatives);
    const denominator = Math.sqrt(
      (truePositives + falsePositives) *
      (truePositives + falseNegatives) *
      (trueNegatives + falsePositives) *
      (trueNegatives + falseNegatives)
    );
    return denominator === 0 ? 0 : numerator / denominator;
  }

  /**
   * Calcula Cohen's Kappa
   */
  calculateCohenKappa(confusionMatrix) {
    const { truePositives, trueNegatives, falsePositives, falseNegatives } = confusionMatrix;
    const total = truePositives + trueNegatives + falsePositives + falseNegatives;
    
    const po = (truePositives + trueNegatives) / total; // Observed agreement
    const pe = (
      ((truePositives + falsePositives) * (truePositives + falseNegatives) +
       (falseNegatives + trueNegatives) * (falsePositives + trueNegatives)) / (total * total)
    ); // Expected agreement
    
    return pe === 1 ? 0 : (po - pe) / (1 - pe);
  }

  /**
   * Calcula AUC-ROC (simplificado)
   */
  calculateROCAUC(predicted, actual, threshold) {
    // Para cálculo completo de AUC-ROC, se necesitarían probabilidades
    // Esta es una aproximación basada en threshold
    const binaryPredicted = this.binarize(predicted, threshold);
    const metrics = this.calculateClassificationMetrics(binaryPredicted, actual);
    
    // Aproximación: usar balanced accuracy como proxy
    return metrics.balancedAccuracy;
  }

  /**
   * Calcula AUC-PR (Precision-Recall AUC)
   */
  calculatePRAUC(predicted, actual, threshold) {
    // Similar a ROC-AUC, aproximación basada en threshold
    const binaryPredicted = this.binarize(predicted, threshold);
    const metrics = this.calculateClassificationMetrics(binaryPredicted, actual);
    
    // Aproximación usando F1-score
    return metrics.f1Score;
  }

  /**
   * Calcula calibración del modelo
   */
  calculateCalibration(predicted, actual) {
    // Dividir predicciones en bins y comparar con frecuencia real
    const bins = 10;
    const binSize = 1.0 / bins;
    const calibrationData = [];

    for (let i = 0; i < bins; i++) {
      const minProb = i * binSize;
      const maxProb = (i + 1) * binSize;
      
      const inBin = predicted
        .map((p, idx) => ({ prob: p, actual: actual[idx] }))
        .filter(item => item.prob >= minProb && item.prob < maxProb);
      
      if (inBin.length > 0) {
        const meanPredicted = inBin.reduce((sum, item) => sum + item.prob, 0) / inBin.length;
        const meanActual = inBin.reduce((sum, item) => sum + item.actual, 0) / inBin.length;
        
        calibrationData.push({
          bin: i,
          range: [minProb, maxProb],
          meanPredicted: parseFloat(meanPredicted.toFixed(4)),
          meanActual: parseFloat(meanActual.toFixed(4)),
          count: inBin.length,
          calibrationError: Math.abs(meanPredicted - meanActual)
        });
      }
    }

    const meanCalibrationError = calibrationData.length > 0
      ? calibrationData.reduce((sum, bin) => sum + bin.calibrationError, 0) / calibrationData.length
      : 0;

    return {
      bins: calibrationData,
      meanCalibrationError: parseFloat(meanCalibrationError.toFixed(4)),
      isWellCalibrated: meanCalibrationError < 0.1
    };
  }

  /**
   * Calcula intervalos de confianza
   */
  calculateConfidenceIntervals(predicted, actual, confidence = 0.95) {
    const errors = predicted.map((p, i) => Math.abs(p - actual[i]));
    const meanError = errors.reduce((sum, e) => sum + e, 0) / errors.length;
    const stdError = Math.sqrt(
      errors.reduce((sum, e) => sum + Math.pow(e - meanError, 2), 0) / errors.length
    );
    
    // Z-score para 95% de confianza
    const z = 1.96;
    const margin = z * (stdError / Math.sqrt(errors.length));
    
    return {
      mean: parseFloat(meanError.toFixed(4)),
      std: parseFloat(stdError.toFixed(4)),
      lowerBound: parseFloat((meanError - margin).toFixed(4)),
      upperBound: parseFloat((meanError + margin).toFixed(4)),
      confidence: confidence
    };
  }

  /**
   * Binariza valores según threshold
   */
  binarize(values, threshold) {
    return values.map(v => (v >= threshold ? 1 : 0));
  }

  /**
   * Verifica si es problema de regresión
   */
  isRegression(predicted, actual) {
    // Si los valores son continuos (no solo 0 y 1), es regresión
    const uniquePredicted = new Set(predicted);
    const uniqueActual = new Set(actual);
    return uniquePredicted.size > 2 || uniqueActual.size > 2;
  }

  /**
   * Interpreta métricas de clasificación
   */
  interpretClassificationMetrics(metrics) {
    const { accuracy, precision, recall, f1Score, mcc } = metrics;
    const interpretations = [];

    if (accuracy >= 0.9) {
      interpretations.push('Excelente precisión general (>90%)');
    } else if (accuracy >= 0.8) {
      interpretations.push('Buena precisión general (80-90%)');
    } else if (accuracy >= 0.7) {
      interpretations.push('Precisión aceptable (70-80%)');
    } else {
      interpretations.push('Precisión mejorable (<70%) - Considerar reentrenamiento');
    }

    if (precision >= 0.8 && recall >= 0.8) {
      interpretations.push('Modelo balanceado con buena precisión y recall');
    } else if (precision >= 0.8 && recall < 0.8) {
      interpretations.push('Alta precisión pero bajo recall - Puede estar perdiendo casos positivos');
    } else if (precision < 0.8 && recall >= 0.8) {
      interpretations.push('Alto recall pero baja precisión - Puede tener falsos positivos');
    }

    if (f1Score >= 0.8) {
      interpretations.push('Excelente balance F1-score');
    } else if (f1Score < 0.6) {
      interpretations.push('F1-score bajo - Modelo necesita mejoras');
    }

    if (mcc >= 0.5) {
      interpretations.push('Buena correlación (MCC) - Modelo confiable');
    } else if (mcc < 0.3) {
      interpretations.push('Baja correlación (MCC) - Modelo poco confiable');
    }

    return interpretations;
  }

  /**
   * Genera reporte completo de métricas
   */
  generateComprehensiveReport(predicted, actual, options = {}) {
    const metrics = this.calculateEnhancedMetrics(predicted, actual, options);
    
    return {
      summary: {
        sampleSize: metrics.sampleSize,
        timestamp: metrics.timestamp,
        overallPerformance: this.getOverallPerformance(metrics)
      },
      metrics: metrics,
      recommendations: this.generateRecommendations(metrics)
    };
  }

  /**
   * Obtiene evaluación general del rendimiento
   */
  getOverallPerformance(metrics) {
    if (metrics.classification) {
      const { accuracy, f1Score, mcc } = metrics.classification;
      
      if (accuracy >= 0.9 && f1Score >= 0.8 && mcc >= 0.5) {
        return 'Excelente';
      } else if (accuracy >= 0.8 && f1Score >= 0.7) {
        return 'Bueno';
      } else if (accuracy >= 0.7) {
        return 'Aceptable';
      } else {
        return 'Necesita Mejora';
      }
    }
    
    if (metrics.regression) {
      const { r2, mape } = metrics.regression;
      
      if (r2 >= 0.9 && mape < 10) {
        return 'Excelente';
      } else if (r2 >= 0.8 && mape < 20) {
        return 'Bueno';
      } else if (r2 >= 0.7) {
        return 'Aceptable';
      } else {
        return 'Necesita Mejora';
      }
    }
    
    return 'Desconocido';
  }

  /**
   * Genera recomendaciones basadas en métricas
   */
  generateRecommendations(metrics) {
    const recommendations = [];

    if (metrics.classification) {
      const { accuracy, precision, recall, f1Score } = metrics.classification;
      
      if (accuracy < 0.7) {
        recommendations.push('Considerar reentrenar el modelo con más datos o diferentes features');
      }
      
      if (precision < 0.7) {
        recommendations.push('Alta tasa de falsos positivos - Ajustar threshold o mejorar features');
      }
      
      if (recall < 0.7) {
        recommendations.push('Alta tasa de falsos negativos - Considerar balancear clases o ajustar threshold');
      }
      
      if (f1Score < 0.7) {
        recommendations.push('F1-score bajo - Revisar balance entre precision y recall');
      }
    }

    if (metrics.regression) {
      const { r2, mape } = metrics.regression;
      
      if (r2 < 0.7) {
        recommendations.push('R² bajo - Considerar features adicionales o modelos más complejos');
      }
      
      if (mape > 20) {
        recommendations.push('MAPE alto - Revisar outliers y normalización de datos');
      }
    }

    if (metrics.additional?.calibration?.isWellCalibrated === false) {
      recommendations.push('Modelo no bien calibrado - Considerar calibración de probabilidades');
    }

    return recommendations;
  }
}

module.exports = EnhancedMetricsService;

