/**
 * Servicio de Métricas ML
 * Calcula métricas de precisión, recall, F1-score y otras métricas de calidad
 */

class MLMetricsService {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
  }

  /**
   * Calcula métricas completas de precisión, recall, F1-score
   */
  calculateMetrics(predicted, actual, threshold = 0.5) {
    // Convertir predicciones a binarias si es necesario
    const binaryPredicted = predicted.map(p => 
      typeof p === 'number' && p <= 1 ? (p >= threshold ? 1 : 0) : p
    );
    const binaryActual = actual.map(a => a >= threshold ? 1 : 0);

    // Calcular matriz de confusión
    const confusionMatrix = this.calculateConfusionMatrix(binaryPredicted, binaryActual);

    // Calcular métricas básicas
    const precision = this.calculatePrecision(confusionMatrix);
    const recall = this.calculateRecall(confusionMatrix);
    const f1Score = this.calculateF1Score(precision, recall);
    const accuracy = this.calculateAccuracy(confusionMatrix);
    const specificity = this.calculateSpecificity(confusionMatrix);

    // Calcular métricas adicionales
    const support = this.calculateSupport(confusionMatrix);
    const balancedAccuracy = this.calculateBalancedAccuracy(precision, recall);
    const mcc = this.calculateMCC(confusionMatrix); // Matthews Correlation Coefficient

    return {
      confusionMatrix,
      metrics: {
        accuracy: parseFloat(accuracy.toFixed(4)),
        precision: parseFloat(precision.toFixed(4)),
        recall: parseFloat(recall.toFixed(4)),
        f1Score: parseFloat(f1Score.toFixed(4)),
        specificity: parseFloat(specificity.toFixed(4)),
        balancedAccuracy: parseFloat(balancedAccuracy.toFixed(4)),
        mcc: parseFloat(mcc.toFixed(4))
      },
      support,
      threshold,
      timestamp: new Date().toISOString()
    };
  }

  /**
   * Calcula matriz de confusión
   */
  calculateConfusionMatrix(predicted, actual) {
    let truePositives = 0;
    let trueNegatives = 0;
    let falsePositives = 0;
    let falseNegatives = 0;

    for (let i = 0; i < predicted.length; i++) {
      const pred = predicted[i];
      const act = actual[i];

      if (pred === 1 && act === 1) truePositives++;
      else if (pred === 0 && act === 0) trueNegatives++;
      else if (pred === 1 && act === 0) falsePositives++;
      else if (pred === 0 && act === 1) falseNegatives++;
    }

    return {
      truePositives,
      trueNegatives,
      falsePositives,
      falseNegatives,
      total: predicted.length
    };
  }

  /**
   * Calcula precisión
   */
  calculatePrecision(confusionMatrix) {
    const { truePositives, falsePositives } = confusionMatrix;
    const denominator = truePositives + falsePositives;
    return denominator === 0 ? 0 : truePositives / denominator;
  }

  /**
   * Calcula recall (sensibilidad)
   */
  calculateRecall(confusionMatrix) {
    const { truePositives, falseNegatives } = confusionMatrix;
    const denominator = truePositives + falseNegatives;
    return denominator === 0 ? 0 : truePositives / denominator;
  }

  /**
   * Calcula F1-score
   */
  calculateF1Score(precision, recall) {
    const denominator = precision + recall;
    return denominator === 0 ? 0 : 2 * (precision * recall) / denominator;
  }

  /**
   * Calcula accuracy
   */
  calculateAccuracy(confusionMatrix) {
    const { truePositives, trueNegatives, total } = confusionMatrix;
    return total === 0 ? 0 : (truePositives + trueNegatives) / total;
  }

  /**
   * Calcula especificidad
   */
  calculateSpecificity(confusionMatrix) {
    const { trueNegatives, falsePositives } = confusionMatrix;
    const denominator = trueNegatives + falsePositives;
    return denominator === 0 ? 0 : trueNegatives / denominator;
  }

  /**
   * Calcula soporte (cantidad de ejemplos por clase)
   */
  calculateSupport(confusionMatrix) {
    return {
      positive: confusionMatrix.truePositives + confusionMatrix.falseNegatives,
      negative: confusionMatrix.trueNegatives + confusionMatrix.falsePositives,
      total: confusionMatrix.total
    };
  }

  /**
   * Calcula balanced accuracy
   */
  calculateBalancedAccuracy(precision, recall) {
    return (precision + recall) / 2;
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
   * Calcula métricas desde comparación ML vs Real
   */
  calculateMetricsFromComparison(comparison) {
    const predicted = [];
    const actual = [];

    comparison.comparison.forEach(day => {
      day.hourlyComparison.forEach(hour => {
        // Normalizar valores para clasificación binaria (pico vs no pico)
        const isPeakHour = (hour.hora >= 7 && hour.hora <= 9) || (hour.hora >= 17 && hour.hora <= 19);
        const predictedPeak = hour.predicted >= 50; // Threshold de 50 accesos
        const actualPeak = hour.real >= 50;

        predicted.push(predictedPeak ? 1 : 0);
        actual.push(actualPeak ? 1 : 0);
      });
    });

    return this.calculateMetrics(predicted, actual);
  }

  /**
   * Calcula métricas por categoría (por hora, por día, etc.)
   */
  calculateMetricsByCategory(comparison, category = 'hour') {
    const categories = {};

    comparison.comparison.forEach(day => {
      day.hourlyComparison.forEach(hour => {
        const key = category === 'hour' ? hour.hora : day.dia_semana;
        
        if (!categories[key]) {
          categories[key] = {
            predicted: [],
            actual: []
          };
        }

        const predictedPeak = hour.predicted >= 50;
        const actualPeak = hour.real >= 50;

        categories[key].predicted.push(predictedPeak ? 1 : 0);
        categories[key].actual.push(actualPeak ? 1 : 0);
      });
    });

    const metricsByCategory = {};
    Object.keys(categories).forEach(key => {
      metricsByCategory[key] = this.calculateMetrics(
        categories[key].predicted,
        categories[key].actual
      );
    });

    return metricsByCategory;
  }

  /**
   * Genera reporte de métricas completo
   */
  generateMetricsReport(comparison) {
    const overallMetrics = this.calculateMetricsFromComparison(comparison);
    const metricsByHour = this.calculateMetricsByCategory(comparison, 'hour');
    const metricsByDay = this.calculateMetricsByCategory(comparison, 'day');

    return {
      overall: overallMetrics,
      byHour: metricsByHour,
      byDay: metricsByDay,
      summary: {
        accuracy: overallMetrics.metrics.accuracy,
        precision: overallMetrics.metrics.precision,
        recall: overallMetrics.metrics.recall,
        f1Score: overallMetrics.metrics.f1Score,
        bestHour: this.findBestCategory(metricsByHour, 'f1Score'),
        worstHour: this.findWorstCategory(metricsByHour, 'f1Score'),
        bestDay: this.findBestCategory(metricsByDay, 'f1Score'),
        worstDay: this.findWorstCategory(metricsByDay, 'f1Score')
      },
      timestamp: new Date().toISOString()
    };
  }

  /**
   * Encuentra mejor categoría por métrica
   */
  findBestCategory(metricsByCategory, metric) {
    let bestKey = null;
    let bestValue = -1;

    Object.keys(metricsByCategory).forEach(key => {
      const value = metricsByCategory[key].metrics[metric];
      if (value > bestValue) {
        bestValue = value;
        bestKey = key;
      }
    });

    return bestKey ? {
      category: bestKey,
      value: bestValue,
      metrics: metricsByCategory[bestKey].metrics
    } : null;
  }

  /**
   * Encuentra peor categoría por métrica
   */
  findWorstCategory(metricsByCategory, metric) {
    let worstKey = null;
    let worstValue = Infinity;

    Object.keys(metricsByCategory).forEach(key => {
      const value = metricsByCategory[key].metrics[metric];
      if (value < worstValue) {
        worstValue = value;
        worstKey = key;
      }
    });

    return worstKey ? {
      category: worstKey,
      value: worstValue,
      metrics: metricsByCategory[worstKey].metrics
    } : null;
  }
}

module.exports = MLMetricsService;

