/**
 * Validación Cruzada K-Fold
 * Implementa validación cruzada para evaluación robusta del modelo
 */

const LinearRegression = require('./linear_regression');

class CrossValidation {
  constructor(options = {}) {
    this.k = options.k || 5; // k-fold por defecto
    this.shuffle = options.shuffle !== false;
    this.randomState = options.randomState || 42;
  }

  /**
   * Divide datos en k folds
   */
  splitKFold(X, y, k) {
    const n = X.length;
    const foldSize = Math.floor(n / k);
    const folds = [];

    // Mezclar datos si está habilitado
    let shuffledData = this.shuffle 
      ? this.shuffleArray([...X.map((x, i) => ({ x, y: y[i] }))], this.randomState)
      : X.map((x, i) => ({ x, y: y[i] }));

    // Crear folds
    for (let i = 0; i < k; i++) {
      const start = i * foldSize;
      const end = i === k - 1 ? n : (i + 1) * foldSize;
      folds.push(shuffledData.slice(start, end));
    }

    return folds;
  }

  /**
   * Ejecuta validación cruzada k-fold
   */
  crossValidate(X, y, modelOptions = {}, metric = 'r2') {
    if (X.length !== y.length) {
      throw new Error('X e y deben tener la misma longitud');
    }

    if (X.length < this.k) {
      throw new Error(`No hay suficientes datos para ${this.k}-fold. Se requieren al menos ${this.k} muestras.`);
    }

    const folds = this.splitKFold(X, y, this.k);
    const scores = [];
    const foldResults = [];

    for (let i = 0; i < this.k; i++) {
      // Preparar datos de entrenamiento y prueba
      const testFold = folds[i];
      const trainFolds = folds.filter((_, idx) => idx !== i);

      const X_train = trainFolds.flatMap(fold => fold.map(d => d.x));
      const y_train = trainFolds.flatMap(fold => fold.map(d => d.y));
      const X_test = testFold.map(d => d.x);
      const y_test = testFold.map(d => d.y);

      // Entrenar modelo
      const model = new LinearRegression(modelOptions);
      model.fit(X_train, y_train);

      // Evaluar modelo
      const evaluation = model.evaluate(X_test, y_test);

      // Obtener métrica solicitada
      const score = evaluation[metric] || evaluation.r2;
      scores.push(score);

      foldResults.push({
        fold: i + 1,
        trainSize: X_train.length,
        testSize: X_test.length,
        metrics: evaluation,
        score: score
      });
    }

    // Calcular estadísticas
    const mean = scores.reduce((sum, s) => sum + s, 0) / scores.length;
    const std = Math.sqrt(
      scores.reduce((sum, s) => sum + Math.pow(s - mean, 2), 0) / scores.length
    );

    return {
      k: this.k,
      metric,
      scores,
      mean: parseFloat(mean.toFixed(4)),
      std: parseFloat(std.toFixed(4)),
      min: Math.min(...scores),
      max: Math.max(...scores),
      foldResults,
      meetsThreshold: metric === 'r2' ? mean >= 0.7 : true
    };
  }

  /**
   * Ejecuta validación cruzada con múltiples métricas
   */
  crossValidateMultipleMetrics(X, y, modelOptions = {}) {
    const metrics = ['mse', 'rmse', 'mae', 'r2'];
    const results = {};

    metrics.forEach(metric => {
      results[metric] = this.crossValidate(X, y, modelOptions, metric);
    });

    return {
      k: this.k,
      metrics: results,
      summary: {
        r2: results.r2.mean,
        rmse: results.rmse.mean,
        mae: results.mae.mean,
        mse: results.mse.mean,
        meetsR2Threshold: results.r2.mean >= 0.7
      }
    };
  }

  /**
   * Mezcla array con semilla
   */
  shuffleArray(array, seed) {
    const shuffled = [...array];
    let random = this.seededRandom(seed);

    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }

    return shuffled;
  }

  /**
   * Generador de números aleatorios con semilla
   */
  seededRandom(seed) {
    let value = seed;
    return function() {
      value = (value * 9301 + 49297) % 233280;
      return value / 233280;
    };
  }

  /**
   * Validación cruzada estratificada (para regresión adaptada)
   */
  stratifiedKFold(X, y, k) {
    // Para regresión, dividir por rangos de valores objetivo
    const n = y.length;
    const sortedIndices = [...Array(n).keys()].sort((a, b) => y[a] - y[b]);
    
    const foldSize = Math.floor(n / k);
    const folds = [];

    for (let i = 0; i < k; i++) {
      const foldIndices = [];
      for (let j = i; j < n; j += k) {
        foldIndices.push(sortedIndices[j]);
      }
      
      folds.push(foldIndices.map(idx => ({
        x: X[idx],
        y: y[idx]
      })));
    }

    return folds;
  }
}

module.exports = CrossValidation;

