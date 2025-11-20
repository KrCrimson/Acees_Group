/**
 * Entrenador de Modelos de Machine Learning
 * Implementa diferentes algoritmos de aprendizaje
 */

class ModelTrainer {
  constructor() {
    this.models = {};
  }

  /**
   * Entrena un modelo con el dataset proporcionado
   */
  async train(dataset, options = {}) {
    const {
      modelType = 'logistic_regression',
      features = [],
      target = 'target'
    } = options;

    if (!Array.isArray(dataset) || dataset.length === 0) {
      throw new Error('Dataset debe ser un array no vacío');
    }

    const startTime = Date.now();

    switch (modelType) {
      case 'logistic_regression':
        return this.trainLogisticRegression(dataset, features, target, startTime);
      
      case 'decision_tree':
        return this.trainDecisionTree(dataset, features, target, startTime);
      
      case 'random_forest':
        return this.trainRandomForest(dataset, features, target, startTime);
      
      default:
        throw new Error(`Tipo de modelo no soportado: ${modelType}`);
    }
  }

  /**
   * Entrena modelo de Regresión Logística
   */
  trainLogisticRegression(dataset, features, target, startTime) {
    // Preparar datos
    const { X, y, featureNames } = this.prepareData(dataset, features, target);
    
    // Implementación simplificada de Regresión Logística
    // En producción, usar biblioteca como ml-matrix o llamar a servicio Python
    const model = this.logisticRegressionFit(X, y);

    const trainingTime = Date.now() - startTime;

    return {
      model,
      modelType: 'logistic_regression',
      features: featureNames,
      target,
      params: {
        learningRate: 0.01,
        iterations: 1000,
        regularization: 0.1
      },
      trainingTime
    };
  }

  /**
   * Entrena modelo de Árbol de Decisión
   */
  trainDecisionTree(dataset, features, target, startTime) {
    const { X, y, featureNames } = this.prepareData(dataset, features, target);
    
    // Implementación simplificada de Árbol de Decisión
    const model = this.decisionTreeFit(X, y, featureNames);

    const trainingTime = Date.now() - startTime;

    return {
      model,
      modelType: 'decision_tree',
      features: featureNames,
      target,
      params: {
        maxDepth: 10,
        minSamplesSplit: 5
      },
      trainingTime
    };
  }

  /**
   * Entrena modelo de Random Forest
   */
  trainRandomForest(dataset, features, target, startTime) {
    const { X, y, featureNames } = this.prepareData(dataset, features, target);
    
    // Implementación simplificada de Random Forest
    const nTrees = 10;
    const trees = [];

    for (let i = 0; i < nTrees; i++) {
      // Bootstrap sample
      const bootstrapSample = this.bootstrapSample(X, y);
      const tree = this.decisionTreeFit(
        bootstrapSample.X,
        bootstrapSample.y,
        featureNames
      );
      trees.push(tree);
    }

    const trainingTime = Date.now() - startTime;

    return {
      model: { trees, type: 'random_forest' },
      modelType: 'random_forest',
      features: featureNames,
      target,
      params: {
        nTrees,
        maxDepth: 10,
        minSamplesSplit: 5
      },
      trainingTime
    };
  }

  /**
   * Prepara datos para entrenamiento
   */
  prepareData(dataset, features, target) {
    const X = [];
    const y = [];
    const featureNames = features.length > 0 ? features : this.detectFeatures(dataset);

    dataset.forEach(row => {
      const featuresVector = this.extractFeatures(row, featureNames);
      X.push(featuresVector);
      y.push(row[target] || 0);
    });

    return { X, y, featureNames };
  }

  /**
   * Detecta características automáticamente
   */
  detectFeatures(dataset) {
    if (dataset.length === 0) return [];

    const excluded = ['id', 'fecha_hora', 'target', 'codigo_universitario'];
    const features = Object.keys(dataset[0]).filter(key => !excluded.includes(key));
    return features;
  }

  /**
   * Extrae características de una fila
   */
  extractFeatures(row, featureNames) {
    return featureNames.map(name => {
      const value = row[name];
      
      // Convertir strings a números (encoding simple)
      if (typeof value === 'string') {
        return this.hashString(value);
      }
      
      // Normalizar valores numéricos
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
      hash = hash & hash; // Convert to 32bit integer
    }
    return Math.abs(hash) % 1000; // Normalizar a rango 0-999
  }

  /**
   * Entrenamiento simplificado de Regresión Logística
   */
  logisticRegressionFit(X, y, learningRate = 0.01, iterations = 1000) {
    const nFeatures = X[0].length;
    const weights = new Array(nFeatures).fill(0);
    let bias = 0;

    for (let iter = 0; iter < iterations; iter++) {
      for (let i = 0; i < X.length; i++) {
        const prediction = this.sigmoid(this.dotProduct(X[i], weights) + bias);
        const error = y[i] - prediction;

        // Actualizar pesos
        for (let j = 0; j < weights.length; j++) {
          weights[j] += learningRate * error * X[i][j];
        }
        bias += learningRate * error;
      }
    }

    return { weights, bias, type: 'logistic_regression' };
  }

  /**
   * Entrenamiento simplificado de Árbol de Decisión
   */
  decisionTreeFit(X, y, featureNames, maxDepth = 10, minSamplesSplit = 5) {
    return this.buildTree(X, y, featureNames, 0, maxDepth, minSamplesSplit);
  }

  /**
   * Construye árbol de decisión recursivamente
   */
  buildTree(X, y, featureNames, depth, maxDepth, minSamplesSplit) {
    // Caso base: todos los ejemplos tienen la misma clase
    const uniqueClasses = [...new Set(y)];
    if (uniqueClasses.length === 1 || depth >= maxDepth || X.length < minSamplesSplit) {
      return {
        type: 'leaf',
        prediction: this.majorityClass(y),
        samples: X.length
      };
    }

    // Encontrar mejor split
    const bestSplit = this.findBestSplit(X, y, featureNames);

    if (!bestSplit) {
      return {
        type: 'leaf',
        prediction: this.majorityClass(y),
        samples: X.length
      };
    }

    // Dividir datos
    const { leftX, leftY, rightX, rightY } = this.splitData(
      X, y, bestSplit.featureIndex, bestSplit.threshold
    );

    // Construir subárboles
    return {
      type: 'node',
      featureIndex: bestSplit.featureIndex,
      featureName: featureNames[bestSplit.featureIndex],
      threshold: bestSplit.threshold,
      left: this.buildTree(leftX, leftY, featureNames, depth + 1, maxDepth, minSamplesSplit),
      right: this.buildTree(rightX, rightY, featureNames, depth + 1, maxDepth, minSamplesSplit),
      samples: X.length
    };
  }

  /**
   * Encuentra el mejor split para el árbol
   */
  findBestSplit(X, y, featureNames) {
    let bestGini = Infinity;
    let bestSplit = null;

    for (let featureIndex = 0; featureIndex < X[0].length; featureIndex++) {
      const values = X.map(row => row[featureIndex]).sort((a, b) => a - b);
      const uniqueValues = [...new Set(values)];

      for (let threshold of uniqueValues) {
        const { leftY, rightY } = this.splitByThreshold(X, y, featureIndex, threshold);
        
        if (leftY.length === 0 || rightY.length === 0) continue;

        const gini = this.weightedGini(leftY, rightY);
        
        if (gini < bestGini) {
          bestGini = gini;
          bestSplit = { featureIndex, threshold };
        }
      }
    }

    return bestSplit;
  }

  /**
   * Divide datos por umbral
   */
  splitByThreshold(X, y, featureIndex, threshold) {
    const leftY = [];
    const rightY = [];

    for (let i = 0; i < X.length; i++) {
      if (X[i][featureIndex] <= threshold) {
        leftY.push(y[i]);
      } else {
        rightY.push(y[i]);
      }
    }

    return { leftY, rightY };
  }

  /**
   * Calcula Gini ponderado
   */
  weightedGini(leftY, rightY) {
    const giniLeft = this.giniImpurity(leftY);
    const giniRight = this.giniImpurity(rightY);
    const total = leftY.length + rightY.length;
    
    return (leftY.length / total) * giniLeft + (rightY.length / total) * giniRight;
  }

  /**
   * Calcula impureza de Gini
   */
  giniImpurity(y) {
    if (y.length === 0) return 0;

    const counts = {};
    y.forEach(label => {
      counts[label] = (counts[label] || 0) + 1;
    });

    let gini = 1;
    Object.keys(counts).forEach(label => {
      const p = counts[label] / y.length;
      gini -= p * p;
    });

    return gini;
  }

  /**
   * Divide datos según feature y umbral
   */
  splitData(X, y, featureIndex, threshold) {
    const leftX = [];
    const leftY = [];
    const rightX = [];
    const rightY = [];

    for (let i = 0; i < X.length; i++) {
      if (X[i][featureIndex] <= threshold) {
        leftX.push(X[i]);
        leftY.push(y[i]);
      } else {
        rightX.push(X[i]);
        rightY.push(y[i]);
      }
    }

    return { leftX, leftY, rightX, rightY };
  }

  /**
   * Obtiene la clase mayoritaria
   */
  majorityClass(y) {
    const counts = {};
    y.forEach(label => {
      counts[label] = (counts[label] || 0) + 1;
    });

    let maxCount = 0;
    let majority = 0;

    Object.keys(counts).forEach(label => {
      if (counts[label] > maxCount) {
        maxCount = counts[label];
        majority = parseInt(label);
      }
    });

    return majority;
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
   * Bootstrap sampling
   */
  bootstrapSample(X, y) {
    const n = X.length;
    const sampleX = [];
    const sampleY = [];

    for (let i = 0; i < n; i++) {
      const index = Math.floor(Math.random() * n);
      sampleX.push(X[index]);
      sampleY.push(y[index]);
    }

    return { X: sampleX, y: sampleY };
  }
}

module.exports = ModelTrainer;

