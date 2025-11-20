/**
 * Modelo Predictivo de Horarios Pico Entrada/Salida
 * Predice horarios de mayor congestión para anticipar carga
 */

const LinearRegression = require('./linear_regression');
const CrossValidation = require('./cross_validation');
const ParameterOptimizer = require('./parameter_optimizer');
const DatasetCollector = require('./dataset_collector');
const fs = require('fs').promises;
const path = require('path');

class PeakHoursPredictiveModel {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.collector = new DatasetCollector(AsistenciaModel);
    this.modelsDir = path.join(__dirname, '../data/peak_hours_models');
    this.entranceModel = null;
    this.exitModel = null;
  }

  /**
   * Prepara datos específicos para predicción de horarios pico
   */
  preparePeakHoursData(dataset) {
    // Agrupar por hora y tipo (entrada/salida)
    const hourlyData = {};

    dataset.forEach(row => {
      const fecha = new Date(row.fecha_hora);
      const hora = fecha.getHours();
      const tipo = row.tipo === 'entrada' ? 'entrance' : 'exit';
      const key = `${hora}_${tipo}_${fecha.toDateString()}`;

      if (!hourlyData[key]) {
        hourlyData[key] = {
          hora,
          tipo,
          fecha: fecha.toDateString(),
          count: 0,
          features: this.extractFeaturesForHour(row, fecha)
        };
      }

      hourlyData[key].count++;
    });

    // Convertir a formato para entrenamiento
    const X_entrance = [];
    const y_entrance = [];
    const X_exit = [];
    const y_exit = [];

    Object.keys(hourlyData).forEach(key => {
      const data = hourlyData[key];
      
      // Features: hora, día_semana, mes, es_fin_semana, es_feriado, semana_anio
      const features = [
        data.hora,
        data.features.dia_semana,
        data.features.mes,
        data.features.es_fin_semana,
        data.features.es_feriado,
        data.features.semana_anio
      ];

      if (data.tipo === 'entrance') {
        X_entrance.push(features);
        y_entrance.push(data.count);
      } else {
        X_exit.push(features);
        y_exit.push(data.count);
      }
    });

    return {
      X_entrance,
      y_entrance,
      X_exit,
      y_exit,
      featureNames: ['hora', 'dia_semana', 'mes', 'es_fin_semana', 'es_feriado', 'semana_anio']
    };
  }

  /**
   * Extrae características para una hora específica
   */
  extractFeaturesForHour(row, fecha) {
    return {
      hora: fecha.getHours(),
      dia_semana: fecha.getDay(),
      mes: fecha.getMonth() + 1,
      semana_anio: this.getWeekOfYear(fecha),
      es_fin_semana: (fecha.getDay() === 0 || fecha.getDay() === 6) ? 1 : 0,
      es_feriado: this.isHoliday(fecha) ? 1 : 0
    };
  }

  /**
   * Calcula semana del año
   */
  getWeekOfYear(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  }

  /**
   * Verifica si es feriado
   */
  isHoliday(date) {
    return false; // Implementar lógica de feriados si es necesario
  }

  /**
   * Entrena modelos predictivos para entrada y salida
   */
  async trainPredictiveModels(options = {}) {
    const {
      months = 3,
      testSize = 0.2,
      optimizeParams = true,
      cvFolds = 5,
      targetAccuracy = 0.8
    } = options;

    try {
      // 1. Recopilar dataset histórico
      const collectionResult = await this.collector.collectHistoricalDataset({
        months,
        includeFeatures: true,
        outputFormat: 'json'
      });

      const datasetContent = await fs.readFile(collectionResult.filepath, 'utf8');
      const dataset = JSON.parse(datasetContent);

      // 2. Preparar datos específicos para horarios pico
      const { X_entrance, y_entrance, X_exit, y_exit, featureNames } = 
        this.preparePeakHoursData(dataset);

      if (X_entrance.length < cvFolds || X_exit.length < cvFolds) {
        throw new Error(`Dataset insuficiente. Se requieren al menos ${cvFolds} muestras.`);
      }

      // 3. Entrenar modelo de ENTRADAS
      console.log('🔵 Entrenando modelo de ENTRADAS...');
      const entranceResult = await this.trainModel(
        X_entrance,
        y_entrance,
        'entrance',
        optimizeParams,
        cvFolds,
        targetAccuracy
      );

      // 4. Entrenar modelo de SALIDAS
      console.log('🔴 Entrenando modelo de SALIDAS...');
      const exitResult = await this.trainModel(
        X_exit,
        y_exit,
        'exit',
        optimizeParams,
        cvFolds,
        targetAccuracy
      );

      // 5. Guardar modelos
      const modelData = {
        entrance: entranceResult,
        exit: exitResult,
        featureNames,
        meetsAccuracyThreshold: entranceResult.accuracy >= targetAccuracy && 
                                 exitResult.accuracy >= targetAccuracy,
        createdAt: new Date().toISOString()
      };

      await this.saveModels(modelData);

      return {
        success: true,
        entrance: entranceResult,
        exit: exitResult,
        meetsAccuracyThreshold: modelData.meetsAccuracyThreshold,
        modelPath: modelData.modelPath
      };
    } catch (error) {
      throw new Error(`Error entrenando modelos predictivos: ${error.message}`);
    }
  }

  /**
   * Entrena un modelo específico (entrada o salida) con mejoras
   */
  async trainModel(X, y, type, optimizeParams, cvFolds, targetAccuracy) {
    // Split train/test
    const splitIndex = Math.floor(X.length * (1 - 0.2));
    const X_train = X.slice(0, splitIndex);
    const y_train = y.slice(0, splitIndex);
    const X_test = X.slice(splitIndex);
    const y_test = y.slice(splitIndex);

    // Optimizar parámetros si está habilitado
    let bestParams = {
      learningRate: 0.01,
      iterations: 1000,
      regularization: 0.01,
      featureScaling: true
    };

    let optimizationResult = null;

    if (optimizeParams) {
      const optimizer = new ParameterOptimizer();
      // Optimizar para R² alto (que se traduce en buena precisión)
      optimizationResult = optimizer.optimizeForR2(X_train, y_train, 0.7, cvFolds);
      bestParams = optimizationResult.bestParams;
    }

    // Early stopping
    const EarlyStopping = require('./early_stopping');
    const earlyStopping = new EarlyStopping({
      patience: 20,
      minDelta: 0.001,
      monitor: 'loss',
      mode: 'min',
      restoreBestWeights: true
    });

    // Entrenar modelo con early stopping
    const model = new LinearRegression(bestParams);
    const trainingResult = model.fit(X_train, y_train, {
      validationSplit: 0.2,
      earlyStopping: earlyStopping,
      verbose: false
    });

    // Validación cruzada mejorada
    const cvValidator = new CrossValidation({ k: cvFolds });
    const cvResults = cvValidator.crossValidateMultipleMetrics(X_train, y_train, bestParams);

    // Evaluar en test
    const testEvaluation = model.evaluate(X_test, y_test);

    // Calcular precisión mejorada
    const accuracy = this.calculateAccuracy(testEvaluation, y_test);

    // Métricas mejoradas
    const EnhancedMetricsService = require('./enhanced_metrics_service');
    const enhancedMetrics = new EnhancedMetricsService();
    const testPredictions = model.predictBatch(X_test);
    const enhancedMetricsResult = enhancedMetrics.calculateEnhancedMetrics(
      testPredictions,
      y_test,
      { includeRegressionMetrics: true, includeClassificationMetrics: false }
    );

    return {
      type,
      model: model.save(),
      params: bestParams,
      metrics: {
        training: trainingResult,
        crossValidation: cvResults.summary,
        test: testEvaluation,
        accuracy: accuracy,
        enhanced: enhancedMetricsResult.regression || {}
      },
      optimization: optimizationResult,
      earlyStopping: earlyStopping.getState(),
      meetsAccuracyThreshold: accuracy >= targetAccuracy
    };
  }

  /**
   * Calcula precisión basada en error relativo
   */
  calculateAccuracy(evaluation, y_actual) {
    const meanActual = y_actual.reduce((sum, val) => sum + val, 0) / y_actual.length;
    if (meanActual === 0) return 0;

    // Precisión basada en RMSE relativo
    const relativeRMSE = evaluation.rmse / meanActual;
    const accuracy = Math.max(0, 1 - relativeRMSE);

    return parseFloat(accuracy.toFixed(4));
  }

  /**
   * Guarda modelos entrenados
   */
  async saveModels(modelData) {
    try {
      await fs.mkdir(this.modelsDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `peak_hours_model_${timestamp}.json`;
      const filepath = path.join(this.modelsDir, filename);

      modelData.modelPath = filepath;
      await fs.writeFile(filepath, JSON.stringify(modelData, null, 2));

      return filepath;
    } catch (error) {
      throw new Error(`Error guardando modelos: ${error.message}`);
    }
  }

  /**
   * Carga modelos más recientes
   */
  async loadLatestModels() {
    try {
      const files = await fs.readdir(this.modelsDir);
      const jsonFiles = files.filter(f => f.endsWith('.json')).sort().reverse();

      if (jsonFiles.length === 0) {
        throw new Error('No hay modelos de horarios pico entrenados');
      }

      const filepath = path.join(this.modelsDir, jsonFiles[0]);
      const content = await fs.readFile(filepath, 'utf8');
      const modelData = JSON.parse(content);

      // Cargar modelos
      const entranceModel = new LinearRegression();
      entranceModel.setParams(modelData.entrance.model.params);

      const exitModel = new LinearRegression();
      exitModel.setParams(modelData.exit.model.params);

      this.entranceModel = entranceModel;
      this.exitModel = exitModel;

      return {
        entranceModel,
        exitModel,
        modelData,
        filepath
      };
    } catch (error) {
      throw new Error(`Error cargando modelos: ${error.message}`);
    }
  }

  /**
   * Predice horarios pico para las próximas 24 horas
   */
  async predictNext24Hours(targetDate = null) {
    try {
      // Cargar modelos si no están cargados
      if (!this.entranceModel || !this.exitModel) {
        await this.loadLatestModels();
      }

      const date = targetDate ? new Date(targetDate) : new Date();
      const predictions = [];

      // Predecir para cada hora de las próximas 24 horas
      for (let hourOffset = 0; hourOffset < 24; hourOffset++) {
        const predictionDate = new Date(date);
        predictionDate.setHours(date.getHours() + hourOffset, 0, 0, 0);

        // Predecir ENTRADAS
        const entranceFeatures = this.prepareFeaturesForPrediction(predictionDate);
        const entranceCount = this.entranceModel.predict(entranceFeatures);

        // Predecir SALIDAS
        const exitFeatures = this.prepareFeaturesForPrediction(predictionDate);
        const exitCount = this.exitModel.predict(exitFeatures);

        // Identificar si es horario pico
        const isPeakHour = this.isPeakHourPredicted(entranceCount, exitCount, predictionDate);

        predictions.push({
          timestamp: predictionDate.toISOString(),
          fecha: predictionDate.toISOString().split('T')[0],
          hora: predictionDate.getHours(),
          dia_semana: this.getDayName(predictionDate.getDay()),
          predictedEntrance: Math.round(Math.max(0, entranceCount)),
          predictedExit: Math.round(Math.max(0, exitCount)),
          predictedTotal: Math.round(Math.max(0, entranceCount + exitCount)),
          isPeakHour,
          confidence: this.calculateConfidence(entranceCount, exitCount)
        });
      }

      // Identificar horarios pico principales
      const peakHours = this.identifyPeakHours(predictions);

      return {
        startDate: date.toISOString(),
        predictions,
        peakHours,
        summary: this.generatePredictionSummary(predictions),
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      throw new Error(`Error prediciendo próximas 24 horas: ${error.message}`);
    }
  }

  /**
   * Prepara características para predicción en una fecha específica
   */
  prepareFeaturesForPrediction(date) {
    const diaSemana = date.getDay();
    const mes = date.getMonth() + 1;
    const semanaAnio = this.getWeekOfYear(date);

    return [
      date.getHours(),
      diaSemana,
      mes,
      (diaSemana === 0 || diaSemana === 6) ? 1 : 0,
      this.isHoliday(date) ? 1 : 0,
      semanaAnio
    ];
  }

  /**
   * Determina si es horario pico predicho
   */
  isPeakHourPredicted(entranceCount, exitCount, date) {
    const hour = date.getHours();
    const total = entranceCount + exitCount;

    // Horarios conocidos como pico (7-9, 17-19)
    const knownPeakHours = [7, 8, 9, 17, 18, 19];
    const isKnownPeak = knownPeakHours.includes(hour);

    // Umbral dinámico basado en promedio estimado
    const threshold = 50; // Umbral de accesos para considerar pico

    return isKnownPeak || total >= threshold;
  }

  /**
   * Calcula confianza de la predicción
   */
  calculateConfidence(entranceCount, exitCount) {
    // Confianza basada en valores razonables (no negativos, no extremos)
    const total = entranceCount + exitCount;
    
    if (total < 0) return 0.3;
    if (total > 500) return 0.5; // Valores extremos tienen menos confianza
    
    // Confianza aumenta con valores en rango esperado
    return Math.min(0.95, 0.6 + (total / 500) * 0.35);
  }

  /**
   * Identifica horarios pico principales
   */
  identifyPeakHours(predictions) {
    // Ordenar por total predicho
    const sorted = [...predictions].sort((a, b) => 
      b.predictedTotal - a.predictedTotal
    );

    // Top 5 horarios pico
    return sorted.slice(0, 5).map(p => ({
      hora: p.hora,
      fecha: p.fecha,
      predictedEntrance: p.predictedEntrance,
      predictedExit: p.predictedExit,
      predictedTotal: p.predictedTotal,
      confidence: p.confidence
    }));
  }

  /**
   * Genera resumen de predicción
   */
  generatePredictionSummary(predictions) {
    const peakHours = predictions.filter(p => p.isPeakHour);
    const totalEntrance = predictions.reduce((sum, p) => sum + p.predictedEntrance, 0);
    const totalExit = predictions.reduce((sum, p) => sum + p.predictedExit, 0);
    const avgConfidence = predictions.reduce((sum, p) => sum + p.confidence, 0) / predictions.length;

    return {
      totalHours: predictions.length,
      peakHoursCount: peakHours.length,
      peakHours: peakHours.map(p => p.hora),
      totalPredictedEntrance: Math.round(totalEntrance),
      totalPredictedExit: Math.round(totalExit),
      totalPredicted: Math.round(totalEntrance + totalExit),
      averageConfidence: parseFloat(avgConfidence.toFixed(2)),
      peakHoursDetails: peakHours.map(p => ({
        hora: p.hora,
        total: p.predictedTotal,
        confidence: p.confidence
      }))
    };
  }

  /**
   * Obtiene nombre del día
   */
  getDayName(dayIndex) {
    const days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    return days[dayIndex];
  }

  /**
   * Valida precisión del modelo
   */
  async validateAccuracy(options = {}) {
    const {
      months = 3,
      testSize = 0.2,
      targetAccuracy = 0.8
    } = options;

    try {
      // Recopilar datos
      const collectionResult = await this.collector.collectHistoricalDataset({
        months,
        includeFeatures: true,
        outputFormat: 'json'
      });

      const datasetContent = await fs.readFile(collectionResult.filepath, 'utf8');
      const dataset = JSON.parse(datasetContent);

      // Preparar datos
      const { X_entrance, y_entrance, X_exit, y_exit } = 
        this.preparePeakHoursData(dataset);

      // Cargar modelos
      const { entranceModel, exitModel } = await this.loadLatestModels();

      // Evaluar precisión en datos de prueba
      const splitIndex = Math.floor(X_entrance.length * (1 - testSize));
      
      const X_entrance_test = X_entrance.slice(splitIndex);
      const y_entrance_test = y_entrance.slice(splitIndex);
      const X_exit_test = X_exit.slice(splitIndex);
      const y_exit_test = y_exit.slice(splitIndex);

      const entranceEval = entranceModel.evaluate(X_entrance_test, y_entrance_test);
      const exitEval = exitModel.evaluate(X_exit_test, y_exit_test);

      const entranceAccuracy = this.calculateAccuracy(entranceEval, y_entrance_test);
      const exitAccuracy = this.calculateAccuracy(exitEval, y_exit_test);
      const overallAccuracy = (entranceAccuracy + exitAccuracy) / 2;

      return {
        entrance: {
          accuracy: entranceAccuracy,
          metrics: entranceEval,
          meetsThreshold: entranceAccuracy >= targetAccuracy
        },
        exit: {
          accuracy: exitAccuracy,
          metrics: exitEval,
          meetsThreshold: exitAccuracy >= targetAccuracy
        },
        overall: {
          accuracy: overallAccuracy,
          meetsThreshold: overallAccuracy >= targetAccuracy
        }
      };
    } catch (error) {
      throw new Error(`Error validando precisión: ${error.message}`);
    }
  }

  /**
   * Obtiene métricas del modelo
   */
  async getModelMetrics() {
    try {
      const { modelData } = await this.loadLatestModels();

      return {
        entrance: {
          accuracy: modelData.entrance.metrics.accuracy,
          r2: modelData.entrance.metrics.test.r2,
          rmse: modelData.entrance.metrics.test.rmse,
          meetsThreshold: modelData.entrance.meetsAccuracyThreshold
        },
        exit: {
          accuracy: modelData.exit.metrics.accuracy,
          r2: modelData.exit.metrics.test.r2,
          rmse: modelData.exit.metrics.test.rmse,
          meetsThreshold: modelData.exit.meetsAccuracyThreshold
        },
        overall: {
          accuracy: (modelData.entrance.metrics.accuracy + modelData.exit.metrics.accuracy) / 2,
          meetsThreshold: modelData.meetsAccuracyThreshold
        },
        createdAt: modelData.createdAt
      };
    } catch (error) {
      throw new Error(`Error obteniendo métricas: ${error.message}`);
    }
  }

  /**
   * ALIAS: Método compatible con backend principal
   * Llama a trainPredictiveModels internamente
   */
  async trainPeakHoursModel(options = {}) {
    return await this.trainPredictiveModels(options);
  }

  /**
   * ALIAS: Método compatible con backend principal
   * Predice próximas 24 horas usando el modelo entrenado
   */
  async predictNext24Hours() {
    try {
      // Cargar modelos si no están en memoria
      if (!this.entranceModel || !this.exitModel) {
        const modelData = await this.loadModels();
        this.entranceModel = modelData.entrance;
        this.exitModel = modelData.exit;
      }

      const predictions = [];
      const now = new Date();

      for (let i = 0; i < 24; i++) {
        const futureTime = new Date(now.getTime() + (i * 60 * 60 * 1000));
        const features = this.extractFeaturesForHour({}, futureTime);
        
        const featureArray = [
          features.hora,
          features.dia_semana,
          features.mes,
          features.es_fin_semana,
          features.es_feriado,
          features.semana_anio
        ];

        const entrancePred = this.entranceModel.model.predict([featureArray])[0];
        const exitPred = this.exitModel.model.predict([featureArray])[0];

        predictions.push({
          hora: futureTime.getHours(),
          fecha_hora: futureTime.toISOString(),
          predicciones: {
            entrada: Math.max(0, Math.round(entrancePred)),
            salida: Math.max(0, Math.round(exitPred)),
            total: Math.max(0, Math.round(entrancePred + exitPred))
          },
          es_pico: (entrancePred + exitPred) > 50, // umbral configurable
          confianza: Math.min(
            this.entranceModel.metrics.accuracy,
            this.exitModel.metrics.accuracy
          )
        });
      }

      return {
        success: true,
        generatedAt: new Date().toISOString(),
        predictions,
        modelMetrics: {
          entrance: this.entranceModel.metrics,
          exit: this.exitModel.metrics
        }
      };
    } catch (error) {
      throw new Error(`Error prediciendo próximas 24 horas: ${error.message}`);
    }
  }
}

module.exports = PeakHoursPredictiveModel;

