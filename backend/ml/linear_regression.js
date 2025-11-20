/**
 * Regresión Lineal - Algoritmo Completo
 * Implementa regresión lineal con gradiente descendente y regularización
 */

class LinearRegression {
  constructor(options = {}) {
    this.learningRate = options.learningRate || 0.01;
    this.iterations = options.iterations || 1000;
    this.regularization = options.regularization || 0; // L2 regularization
    this.tolerance = options.tolerance || 1e-6;
    this.featureScaling = options.featureScaling !== false; // Normalización por defecto
    this.weights = null;
    this.bias = null;
    this.featureMeans = null;
    this.featureStds = null;
    this.trainingHistory = [];
  }

  /**
   * Normaliza características (feature scaling)
   */
  normalizeFeatures(X) {
    if (!this.featureMeans || !this.featureStds) {
      // Calcular media y desviación estándar
      const n = X.length;
      const m = X[0].length;
      
      this.featureMeans = [];
      this.featureStds = [];
      
      for (let j = 0; j < m; j++) {
        const column = X.map(row => row[j]);
        const mean = column.reduce((sum, val) => sum + val, 0) / n;
        const std = Math.sqrt(
          column.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / n
        );
        
        this.featureMeans.push(mean);
        this.featureStds.push(std === 0 ? 1 : std); // Evitar división por cero
      }
    }

    // Normalizar
    return X.map(row =>
      row.map((val, j) => (val - this.featureMeans[j]) / this.featureStds[j])
    );
  }

  /**
   * Entrena el modelo de regresión lineal
   */
  fit(X, y) {
    if (!Array.isArray(X) || !Array.isArray(y) || X.length !== y.length) {
      throw new Error('X e y deben ser arrays de la misma longitud');
    }

    if (X.length === 0) {
      throw new Error('Dataset no puede estar vacío');
    }

    // Normalizar características si está habilitado
    const X_normalized = this.featureScaling 
      ? this.normalizeFeatures(X)
      : X;

    const n = X_normalized.length;
    const m = X_normalized[0].length;

    // Inicializar pesos y bias
    this.weights = new Array(m).fill(0);
    this.bias = 0;

    // Entrenar con gradiente descendente
    for (let iter = 0; iter < this.iterations; iter++) {
      const predictions = this.predictBatch(X_normalized);
      
      // Calcular errores
      const errors = predictions.map((pred, i) => pred - y[i]);
      
      // Calcular gradientes
      const weightGradients = new Array(m).fill(0);
      for (let j = 0; j < m; j++) {
        weightGradients[j] = X_normalized.reduce((sum, row, i) => 
          sum + row[j] * errors[i], 0) / n;
        
        // Agregar regularización L2
        if (this.regularization > 0) {
          weightGradients[j] += this.regularization * this.weights[j];
        }
      }

      const biasGradient = errors.reduce((sum, e) => sum + e, 0) / n;

      // Actualizar pesos y bias
      let maxChange = 0;
      for (let j = 0; j < m; j++) {
        const oldWeight = this.weights[j];
        this.weights[j] -= this.learningRate * weightGradients[j];
        maxChange = Math.max(maxChange, Math.abs(this.weights[j] - oldWeight));
      }

      const oldBias = this.bias;
      this.bias -= this.learningRate * biasGradient;
      maxChange = Math.max(maxChange, Math.abs(this.bias - oldBias));

      // Guardar historial de entrenamiento
      const mse = this.calculateMSE(predictions, y);
      this.trainingHistory.push({
        iteration: iter,
        mse,
        rmse: Math.sqrt(mse),
        maxWeightChange: maxChange
      });

      // Detener si convergencia
      if (maxChange < this.tolerance) {
        break;
      }
    }

    return {
      weights: this.weights,
      bias: this.bias,
      iterations: this.trainingHistory.length,
      finalMSE: this.trainingHistory[this.trainingHistory.length - 1].mse,
      converged: this.trainingHistory.length < this.iterations
    };
  }

  /**
   * Predice valores para un conjunto de características
   */
  predict(X) {
    if (!this.weights || !this.bias) {
      throw new Error('Modelo no entrenado. Llame a fit() primero.');
    }

    if (!Array.isArray(X[0])) {
      // Una sola muestra
      return this.predictSingle(X);
    }

    return this.predictBatch(X);
  }

  /**
   * Predice una sola muestra
   */
  predictSingle(x) {
    const x_normalized = this.featureScaling
      ? x.map((val, j) => (val - this.featureMeans[j]) / this.featureStds[j])
      : x;

    return this.weights.reduce((sum, w, j) => sum + w * x_normalized[j], 0) + this.bias;
  }

  /**
   * Predice múltiples muestras
   */
  predictBatch(X) {
    const X_normalized = this.featureScaling
      ? this.normalizeFeatures(X)
      : X;

    return X_normalized.map(row =>
      this.weights.reduce((sum, w, j) => sum + w * row[j], 0) + this.bias
    );
  }

  /**
   * Calcula Mean Squared Error
   */
  calculateMSE(predictions, actual) {
    if (predictions.length !== actual.length) {
      throw new Error('Arrays deben tener la misma longitud');
    }

    const squaredErrors = predictions.map((pred, i) => 
      Math.pow(pred - actual[i], 2)
    );

    return squaredErrors.reduce((sum, se) => sum + se, 0) / predictions.length;
  }

  /**
   * Calcula Root Mean Squared Error
   */
  calculateRMSE(predictions, actual) {
    return Math.sqrt(this.calculateMSE(predictions, actual));
  }

  /**
   * Calcula Mean Absolute Error
   */
  calculateMAE(predictions, actual) {
    if (predictions.length !== actual.length) {
      throw new Error('Arrays deben tener la misma longitud');
    }

    const absoluteErrors = predictions.map((pred, i) => 
      Math.abs(pred - actual[i])
    );

    return absoluteErrors.reduce((sum, ae) => sum + ae, 0) / predictions.length;
  }

  /**
   * Calcula R² (coeficiente de determinación)
   */
  calculateR2(predictions, actual) {
    if (predictions.length !== actual.length) {
      throw new Error('Arrays deben tener la misma longitud');
    }

    const actualMean = actual.reduce((sum, val) => sum + val, 0) / actual.length;
    const ssRes = predictions.reduce((sum, pred, i) => 
      sum + Math.pow(actual[i] - pred, 2), 0);
    const ssTot = actual.reduce((sum, val) => 
      sum + Math.pow(val - actualMean, 2), 0);

    if (ssTot === 0) return 1; // Perfect fit si no hay variación

    return 1 - (ssRes / ssTot);
  }

  /**
   * Evalúa el modelo con métricas completas
   */
  evaluate(X, y) {
    const predictions = this.predict(X);

    return {
      mse: this.calculateMSE(predictions, y),
      rmse: this.calculateRMSE(predictions, y),
      mae: this.calculateMAE(predictions, y),
      r2: this.calculateR2(predictions, y),
      predictions: predictions.slice(0, 100) // Primeras 100 como muestra
    };
  }

  /**
   * Obtiene parámetros del modelo
   */
  getParams() {
    return {
      weights: this.weights,
      bias: this.bias,
      featureMeans: this.featureMeans,
      featureStds: this.featureStds,
      featureScaling: this.featureScaling,
      learningRate: this.learningRate,
      regularization: this.regularization
    };
  }

  /**
   * Carga parámetros del modelo
   */
  setParams(params) {
    this.weights = params.weights;
    this.bias = params.bias;
    this.featureMeans = params.featureMeans;
    this.featureStds = params.featureStds;
    this.featureScaling = params.featureScaling !== false;
    this.learningRate = params.learningRate || this.learningRate;
    this.regularization = params.regularization || this.regularization;
  }

  /**
   * Guarda el modelo entrenado
   */
  save() {
    return {
      type: 'linear_regression',
      params: this.getParams(),
      trainingHistory: this.trainingHistory,
      timestamp: new Date().toISOString()
    };
  }
}

module.exports = LinearRegression;

