/**
 * Servicio de Regresión Lineal Completo
 * Integra regresión lineal, validación cruzada y optimización
 */

const LinearRegression = require('./linear_regression');
const CrossValidation = require('./cross_validation');
const ParameterOptimizer = require('./parameter_optimizer');
const DatasetCollector = require('./dataset_collector');
const fs = require('fs').promises;
const path = require('path');

class LinearRegressionService {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.collector = new DatasetCollector(AsistenciaModel);
    this.modelsDir = path.join(__dirname, '../data/linear_regression_models');
  }

  /**
   * Prepara datos para regresión lineal
   */
  prepareRegressionData(dataset, featureColumns, targetColumn) {
    const X = [];
    const y = [];

    dataset.forEach(row => {
      const features = featureColumns.map(col => {
        const value = row[col];
        if (typeof value === 'string') {
          return this.hashString(value);
        }
        return typeof value === 'number' && !isNaN(value) ? value : 0;
      });

      const target = row[targetColumn];
      if (target !== undefined && target !== null) {
        X.push(features);
        y.push(typeof target === 'number' ? target : parseFloat(target) || 0);
      }
    });

    return { X, y };
  }

  /**
   * Hash string a número
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
   * Entrena modelo de regresión lineal con validación cruzada
   */
  async trainRegressionModel(options = {}) {
    const {
      months = 3,
      featureColumns = null,
      targetColumn = 'target',
      testSize = 0.2,
      optimizeParams = true,
      cvFolds = 5,
      targetR2 = 0.7
    } = options;

    try {
      // 1. Recopilar dataset
      const collectionResult = await this.collector.collectHistoricalDataset({
        months,
        includeFeatures: true,
        outputFormat: 'json'
      });

      const datasetContent = await fs.readFile(collectionResult.filepath, 'utf8');
      const dataset = JSON.parse(datasetContent);

      // 2. Detectar características si no se proporcionan
      const features = featureColumns || this.detectFeatureColumns(dataset);

      // 3. Preparar datos
      const { X, y } = this.prepareRegressionData(dataset, features, targetColumn);

      if (X.length < cvFolds) {
        throw new Error(`Dataset insuficiente. Se requieren al menos ${cvFolds} muestras.`);
      }

      // 4. Split train/test
      const splitIndex = Math.floor(X.length * (1 - testSize));
      const X_train = X.slice(0, splitIndex);
      const y_train = y.slice(0, splitIndex);
      const X_test = X.slice(splitIndex);
      const y_test = y.slice(splitIndex);

      // 5. Optimizar parámetros si está habilitado
      let bestParams = {
        learningRate: 0.01,
        iterations: 1000,
        regularization: 0,
        featureScaling: true
      };

      let optimizationResult = null;

      if (optimizeParams) {
        const optimizer = new ParameterOptimizer();
        optimizationResult = optimizer.optimizeForR2(X_train, y_train, targetR2, cvFolds);
        bestParams = optimizationResult.bestParams;
      }

      // 6. Entrenar modelo final con mejores parámetros
      const model = new LinearRegression(bestParams);
      const trainingResult = model.fit(X_train, y_train);

      // 7. Validación cruzada completa
      const cvValidator = new CrossValidation({ k: cvFolds });
      const cvResults = cvValidator.crossValidateMultipleMetrics(X_train, y_train, bestParams);

      // 8. Evaluar en conjunto de prueba
      const testEvaluation = model.evaluate(X_test, y_test);

      // 9. Guardar modelo
      const modelData = {
        ...model.save(),
        features,
        targetColumn,
        trainingData: {
          trainSize: X_train.length,
          testSize: X_test.length,
          cvFolds
        },
        metrics: {
          training: trainingResult,
          crossValidation: cvResults,
          test: testEvaluation
        },
        optimization: optimizationResult,
        meetsR2Threshold: testEvaluation.r2 >= targetR2
      };

      await this.saveModel(modelData);

      return {
        success: true,
        model: modelData,
        metrics: {
          training: trainingResult,
          crossValidation: cvResults.summary,
          test: testEvaluation
        },
        optimization: optimizationResult,
        meetsR2Threshold: testEvaluation.r2 >= targetR2,
        modelPath: modelData.modelPath
      };
    } catch (error) {
      throw new Error(`Error entrenando modelo de regresión: ${error.message}`);
    }
  }

  /**
   * Detecta columnas de características automáticamente
   */
  detectFeatureColumns(dataset) {
    if (dataset.length === 0) return [];

    const excluded = ['id', 'fecha_hora', 'target', 'codigo_universitario'];
    const features = Object.keys(dataset[0]).filter(key => 
      !excluded.includes(key) && 
      dataset[0][key] !== undefined &&
      dataset[0][key] !== null
    );

    return features;
  }

  /**
   * Guarda modelo entrenado
   */
  async saveModel(modelData) {
    try {
      await fs.mkdir(this.modelsDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `linear_regression_${timestamp}.json`;
      const filepath = path.join(this.modelsDir, filename);

      modelData.modelPath = filepath;
      await fs.writeFile(filepath, JSON.stringify(modelData, null, 2));

      return filepath;
    } catch (error) {
      throw new Error(`Error guardando modelo: ${error.message}`);
    }
  }

  /**
   * Carga modelo más reciente
   */
  async loadLatestModel() {
    try {
      const files = await fs.readdir(this.modelsDir);
      const jsonFiles = files.filter(f => f.endsWith('.json')).sort().reverse();

      if (jsonFiles.length === 0) {
        throw new Error('No hay modelos de regresión entrenados');
      }

      const filepath = path.join(this.modelsDir, jsonFiles[0]);
      const content = await fs.readFile(filepath, 'utf8');
      const modelData = JSON.parse(content);

      const model = new LinearRegression();
      model.setParams(modelData.params);

      return {
        model,
        modelData,
        filepath
      };
    } catch (error) {
      throw new Error(`Error cargando modelo: ${error.message}`);
    }
  }

  /**
   * Predice con modelo cargado
   */
  async predict(features) {
    try {
      const { model } = await this.loadLatestModel();
      return model.predict(features);
    } catch (error) {
      throw new Error(`Error en predicción: ${error.message}`);
    }
  }

  /**
   * Evalúa modelo con métricas completas
   */
  async evaluateModel(testData) {
    try {
      const { model, modelData } = await this.loadLatestModel();
      
      const { X, y } = this.prepareRegressionData(
        testData,
        modelData.features,
        modelData.targetColumn
      );

      return model.evaluate(X, y);
    } catch (error) {
      throw new Error(`Error evaluando modelo: ${error.message}`);
    }
  }

  /**
   * Obtiene resumen de métricas del modelo
   */
  async getModelMetrics() {
    try {
      const { modelData } = await this.loadLatestModel();
      
      return {
        modelType: 'linear_regression',
        features: modelData.features,
        metrics: {
          training: modelData.metrics.training,
          crossValidation: modelData.metrics.crossValidation,
          test: modelData.metrics.test
        },
        meetsR2Threshold: modelData.meetsR2Threshold,
        createdAt: modelData.timestamp
      };
    } catch (error) {
      throw new Error(`Error obteniendo métricas: ${error.message}`);
    }
  }
}

module.exports = LinearRegressionService;

