/**
 * Validador de Modelos - Calcula Métricas de Validación
 * Implementa métricas estándar para evaluación de modelos
 */

class ModelValidator {
  constructor() {
    this.metrics = {};
  }

  /**
   * Valida modelo con conjunto de prueba
   */
  async validate(model, testSet, options = {}) {
    const {
      features = [],
      target = 'target'
    } = options;

    if (!testSet || testSet.length === 0) {
      throw new Error('Conjunto de prueba no puede estar vacío');
    }

    // Preparar datos
    const { X, y } = this.prepareData(testSet, features, target);

    // Realizar predicciones
    const predictions = this.predict(model, X, features);

    // Calcular métricas
    const metrics = this.calculateMetrics(y, predictions);

    return {
      ...metrics,
      predictions: predictions.slice(0, 100), // Primeras 100 predicciones como muestra
      actual: y.slice(0, 100),
      sampleSize: testSet.length
    };
  }

  /**
   * Prepara datos para validación
   */
  prepareData(dataset, features, target) {
    const X = [];
    const y = [];

    dataset.forEach(row => {
      const featuresVector = this.extractFeatures(row, features);
      X.push(featuresVector);
      y.push(row[target] || 0);
    });

    return { X, y };
  }

  /**
   * Extrae características de una fila
   */
  extractFeatures(row, featureNames) {
    return featureNames.map(name => {
      const value = row[name];
      
      if (typeof value === 'string') {
        return this.hashString(value);
      }
      
      if (typeof value === 'number') {
        return isNaN(value) ? 0 : value;
      }
      
      return value || 0;
    });
  }

  /**
   * Hash simple para convertir strings a números
   */
  hashString(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash) % 1000;
  }

  /**
   * Realiza predicciones con el modelo
   */
  predict(model, X, features) {
    if (model.type === 'logistic_regression' || model.weights) {
      return this.predictLogisticRegression(model, X);
    } else if (model.type === 'decision_tree' || model.trees) {
      if (model.trees) {
        // Random Forest
        return this.predictRandomForest(model, X, features);
      } else {
        // Decision Tree
        return this.predictDecisionTree(model, X, features);
      }
    } else {
      throw new Error('Tipo de modelo no reconocido');
    }
  }

  /**
   * Predicción con Regresión Logística
   */
  predictLogisticRegression(model, X) {
    const predictions = [];

    X.forEach(sample => {
      const linearCombination = this.dotProduct(sample, model.weights) + model.bias;
      const probability = this.sigmoid(linearCombination);
      predictions.push(probability >= 0.5 ? 1 : 0);
    });

    return predictions;
  }

  /**
   * Predicción con Árbol de Decisión
   */
  predictDecisionTree(model, X, features) {
    const predictions = [];

    X.forEach(sample => {
      const prediction = this.traverseTree(model, sample);
      predictions.push(prediction);
    });

    return predictions;
  }

  /**
   * Predicción con Random Forest
   */
  predictRandomForest(model, X, features) {
    const predictions = [];

    X.forEach(sample => {
      const treePredictions = [];
      
      model.trees.forEach(tree => {
        const prediction = this.traverseTree(tree, sample);
        treePredictions.push(prediction);
      });

      // Votación mayoritaria
      const counts = {};
      treePredictions.forEach(pred => {
        counts[pred] = (counts[pred] || 0) + 1;
      });

      let maxCount = 0;
      let majority = 0;

      Object.keys(counts).forEach(pred => {
        if (counts[pred] > maxCount) {
          maxCount = counts[pred];
          majority = parseInt(pred);
        }
      });

      predictions.push(majority);
    });

    return predictions;
  }

  /**
   * Recorre árbol para hacer predicción
   */
  traverseTree(node, sample) {
    if (node.type === 'leaf') {
      return node.prediction;
    }

    const featureValue = sample[node.featureIndex];
    
    if (featureValue <= node.threshold) {
      return this.traverseTree(node.left, sample);
    } else {
      return this.traverseTree(node.right, sample);
    }
  }

  /**
   * Calcula todas las métricas de validación
   */
  calculateMetrics(actual, predicted) {
    const confusionMatrix = this.calculateConfusionMatrix(actual, predicted);
    
    const tp = confusionMatrix.truePositives;
    const tn = confusionMatrix.trueNegatives;
    const fp = confusionMatrix.falsePositives;
    const fn = confusionMatrix.falseNegatives;

    // Accuracy
    const accuracy = (tp + tn) / (tp + tn + fp + fn) || 0;

    // Precision
    const precision = tp / (tp + fp) || 0;

    // Recall (Sensitivity)
    const recall = tp / (tp + fn) || 0;

    // F1-Score
    const f1Score = 2 * (precision * recall) / (precision + recall) || 0;

    // Specificity
    const specificity = tn / (tn + fp) || 0;

    // Error Rate
    const errorRate = (fp + fn) / (tp + tn + fp + fn) || 0;

    return {
      accuracy,
      precision,
      recall,
      f1Score,
      specificity,
      errorRate,
      confusionMatrix: {
        ...confusionMatrix,
        matrix: [
          [tn, fp],
          [fn, tp]
        ]
      },
      support: {
        positive: tp + fn,
        negative: tn + fp
      }
    };
  }

  /**
   * Calcula matriz de confusión
   */
  calculateConfusionMatrix(actual, predicted) {
    let truePositives = 0;
    let trueNegatives = 0;
    let falsePositives = 0;
    let falseNegatives = 0;

    for (let i = 0; i < actual.length; i++) {
      const a = actual[i];
      const p = predicted[i];

      if (a === 1 && p === 1) truePositives++;
      else if (a === 0 && p === 0) trueNegatives++;
      else if (a === 0 && p === 1) falsePositives++;
      else if (a === 1 && p === 0) falseNegatives++;
    }

    return {
      truePositives,
      trueNegatives,
      falsePositives,
      falseNegatives,
      total: actual.length
    };
  }

  /**
   * Función sigmoide
   */
  sigmoid(x) {
    return 1 / (1 + Math.exp(-Math.max(-500, Math.min(500, x))));
  }

  /**
   * Producto punto
   */
  dotProduct(a, b) {
    return a.reduce((sum, val, i) => sum + val * b[i], 0);
  }

  /**
   * Genera reporte de métricas en formato legible
   */
  generateMetricsReport(metrics) {
    return {
      resumen: {
        accuracy: `${(metrics.accuracy * 100).toFixed(2)}%`,
        precision: `${(metrics.precision * 100).toFixed(2)}%`,
        recall: `${(metrics.recall * 100).toFixed(2)}%`,
        f1Score: `${(metrics.f1Score * 100).toFixed(2)}%`,
        specificity: `${(metrics.specificity * 100).toFixed(2)}%`,
        errorRate: `${(metrics.errorRate * 100).toFixed(2)}%`
      },
      confusionMatrix: {
        'Verdaderos Negativos': metrics.confusionMatrix.trueNegatives,
        'Falsos Positivos': metrics.confusionMatrix.falsePositives,
        'Falsos Negativos': metrics.confusionMatrix.falseNegatives,
        'Verdaderos Positivos': metrics.confusionMatrix.truePositives
      },
      interpretacion: this.interpretMetrics(metrics)
    };
  }

  /**
   * Interpreta las métricas
   */
  interpretMetrics(metrics) {
    const interpretations = [];

    if (metrics.accuracy >= 0.9) {
      interpretations.push('Excelente precisión general (>90%)');
    } else if (metrics.accuracy >= 0.7) {
      interpretations.push('Buena precisión general (70-90%)');
    } else {
      interpretations.push('Precisión general mejorable (<70%)');
    }

    if (metrics.precision >= 0.8) {
      interpretations.push('El modelo tiene baja tasa de falsos positivos');
    }

    if (metrics.recall >= 0.8) {
      interpretations.push('El modelo detecta bien los casos positivos');
    }

    if (metrics.f1Score >= 0.8) {
      interpretations.push('Balance adecuado entre precisión y recall');
    }

    return interpretations;
  }
}

module.exports = ModelValidator;

