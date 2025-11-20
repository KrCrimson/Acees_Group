/**
 * Servicio de Actualización Automática Semanal del Modelo
 * Reentrenamiento incremental y validación de performance
 */

const LinearRegression = require('./linear_regression');
const CrossValidation = require('./cross_validation');
const ParameterOptimizer = require('./parameter_optimizer');
const DatasetCollector = require('./dataset_collector');
const fs = require('fs').promises;
const path = require('path');

class WeeklyModelUpdateService {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.collector = new DatasetCollector(AsistenciaModel);
    this.modelsDir = path.join(__dirname, '../data/linear_regression_models');
    this.updateHistoryDir = path.join(__dirname, '../data/model_updates');
    this.scheduleConfig = {
      enabled: false,
      dayOfWeek: 0, // Domingo (0-6)
      hour: 2, // 2 AM
      interval: 7 // días
    };
  }

  /**
   * Ejecuta actualización semanal del modelo
   */
  async executeWeeklyUpdate(options = {}) {
    const {
      incremental = true,
      validatePerformance = true,
      checkDrift = true,
      targetR2 = 0.7
    } = options;

    try {
      console.log('🔄 Iniciando actualización semanal del modelo...');

      // 1. Cargar modelo actual
      const currentModel = await this.loadCurrentModel();
      if (!currentModel) {
        throw new Error('No hay modelo actual para actualizar');
      }

      console.log(`✅ Modelo actual cargado: ${currentModel.filepath}`);

      // 2. Recopilar datos nuevos (última semana)
      const newData = await this.collectNewData(7); // Últimos 7 días
      console.log(`✅ Datos nuevos recopilados: ${newData.length} registros`);

      if (newData.length < 10) {
        throw new Error('Datos insuficientes para actualización (mínimo 10 registros)');
      }

      // 3. Verificar drift del modelo
      let driftDetected = false;
      if (checkDrift) {
        driftDetected = await this.checkModelDrift(currentModel, newData);
        console.log(`📊 Drift detectado: ${driftDetected ? 'SÍ' : 'NO'}`);
      }

      // 4. Reentrenamiento incremental o completo
      let updatedModel;
      if (incremental && !driftDetected) {
        console.log('🔄 Reentrenamiento incremental...');
        updatedModel = await this.incrementalRetrain(currentModel, newData, targetR2);
      } else {
        console.log('🔄 Reentrenamiento completo...');
        updatedModel = await this.fullRetrain(currentModel, newData, targetR2);
      }

      // 5. Validar performance
      let performanceValidation = null;
      if (validatePerformance) {
        console.log('✅ Validando performance...');
        performanceValidation = await this.validatePerformance(
          updatedModel,
          currentModel,
          newData
        );

        // Si el nuevo modelo es peor, mantener el anterior
        if (performanceValidation.degradation > 0.1) {
          console.warn('⚠️ Degradación detectada. Manteniendo modelo anterior.');
          return {
            success: false,
            reason: 'performance_degradation',
            currentModel: currentModel.modelData,
            performanceComparison: performanceValidation
          };
        }
      }

      // 6. Guardar modelo actualizado
      const updatedModelPath = await this.saveUpdatedModel(updatedModel, {
        previousModel: currentModel.modelData,
        incremental,
        driftDetected,
        performanceValidation
      });

      // 7. Registrar actualización
      await this.recordUpdate({
        previousModel: currentModel.filepath,
        newModel: updatedModelPath,
        incremental,
        driftDetected,
        performanceValidation,
        newDataSize: newData.length
      });

      console.log('✅ Actualización semanal completada exitosamente');

      return {
        success: true,
        previousModel: currentModel.filepath,
        updatedModel: updatedModelPath,
        incremental,
        driftDetected,
        performanceValidation,
        newDataSize: newData.length,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      throw new Error(`Error en actualización semanal: ${error.message}`);
    }
  }

  /**
   * Reentrenamiento incremental
   */
  async incrementalRetrain(currentModel, newData, targetR2) {
    try {
      // Preparar datos nuevos
      const features = currentModel.modelData.features;
      const { X, y } = this.prepareDataForTraining(newData, features, currentModel.modelData.targetColumn);

      // Obtener datos de entrenamiento anteriores (muestra)
      const oldX = currentModel.modelData.trainingData?.lastX || [];
      const oldY = currentModel.modelData.trainingData?.lastY || [];

      // Combinar datos antiguos y nuevos (peso mayor a datos nuevos)
      const combinedX = [...oldX.slice(-1000), ...X]; // Últimos 1000 del anterior + nuevos
      const combinedY = [...oldY.slice(-1000), ...y];

      // Usar parámetros del modelo actual como punto de partida
      const currentParams = currentModel.modelData.params;
      
      // Entrenar con learning rate más bajo para ajuste fino
      const model = new LinearRegression({
        ...currentParams,
        learningRate: currentParams.learningRate * 0.5, // Learning rate más bajo
        iterations: 500 // Menos iteraciones para ajuste fino
      });

      // Inicializar con pesos del modelo anterior
      model.setParams(currentParams);
      
      // Ajuste fino con nuevos datos
      const trainingResult = model.fit(combinedX, combinedY);

      // Validación cruzada
      const cvValidator = new CrossValidation({ k: 5 });
      const cvResults = cvValidator.crossValidateMultipleMetrics(combinedX, combinedY, {
        learningRate: currentParams.learningRate * 0.5,
        iterations: 500,
        regularization: currentParams.regularization,
        featureScaling: currentParams.featureScaling
      });

      // Evaluar en nuevos datos
      const newEvaluation = model.evaluate(X, y);

      return {
        model: model.save(),
        features,
        targetColumn: currentModel.modelData.targetColumn,
        trainingData: {
          trainSize: combinedX.length,
          oldDataSize: oldX.length,
          newDataSize: X.length,
          lastX: combinedX.slice(-500), // Guardar últimos para próxima actualización
          lastY: combinedY.slice(-500)
        },
        metrics: {
          training: trainingResult,
          crossValidation: cvResults.summary,
          newData: newEvaluation
        },
        incremental: true,
        meetsR2Threshold: newEvaluation.r2 >= targetR2
      };
    } catch (error) {
      throw new Error(`Error en reentrenamiento incremental: ${error.message}`);
    }
  }

  /**
   * Reentrenamiento completo
   */
  async fullRetrain(currentModel, newData, targetR2) {
    try {
      // Recopilar todos los datos históricos (últimos 3 meses + nuevos)
      const allData = await this.collector.collectHistoricalDataset({
        months: 3,
        includeFeatures: true,
        outputFormat: 'json'
      });

      const datasetContent = await fs.readFile(allData.filepath, 'utf8');
      const dataset = JSON.parse(datasetContent);

      // Combinar con datos nuevos
      const combinedDataset = [...dataset, ...newData];

      // Preparar datos
      const features = currentModel.modelData.features;
      const { X, y } = this.prepareDataForTraining(
        combinedDataset,
        features,
        currentModel.modelData.targetColumn
      );

      // Optimizar parámetros
      const optimizer = new ParameterOptimizer();
      const optimizationResult = optimizer.optimizeForR2(X, y, targetR2, 5);

      // Entrenar modelo completo
      const model = new LinearRegression(optimizationResult.bestParams);
      const trainingResult = model.fit(X, y);

      // Validación cruzada
      const cvValidator = new CrossValidation({ k: 5 });
      const cvResults = cvValidator.crossValidateMultipleMetrics(X, y, optimizationResult.bestParams);

      // Split train/test
      const splitIndex = Math.floor(X.length * 0.8);
      const X_test = X.slice(splitIndex);
      const y_test = y.slice(splitIndex);
      const testEvaluation = model.evaluate(X_test, y_test);

      return {
        model: model.save(),
        features,
        targetColumn: currentModel.modelData.targetColumn,
        trainingData: {
          trainSize: X.length,
          testSize: X_test.length,
          lastX: X.slice(-500),
          lastY: y.slice(-500)
        },
        metrics: {
          training: trainingResult,
          crossValidation: cvResults.summary,
          test: testEvaluation
        },
        optimization: optimizationResult,
        incremental: false,
        meetsR2Threshold: testEvaluation.r2 >= targetR2
      };
    } catch (error) {
      throw new Error(`Error en reentrenamiento completo: ${error.message}`);
    }
  }

  /**
   * Prepara datos para entrenamiento
   */
  prepareDataForTraining(dataset, featureColumns, targetColumn) {
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
   * Recopila datos nuevos
   */
  async collectNewData(days = 7) {
    const endDate = new Date();
    const startDate = new Date(endDate.getTime() - days * 24 * 60 * 60 * 1000);

    const query = {
      fecha_hora: {
        $gte: startDate,
        $lte: endDate
      }
    };

    const asistencias = await this.Asistencia.find(query)
      .sort({ fecha_hora: 1 })
      .lean();

    return asistencias;
  }

  /**
   * Carga modelo actual
   */
  async loadCurrentModel() {
    try {
      const files = await fs.readdir(this.modelsDir);
      const jsonFiles = files.filter(f => f.endsWith('.json')).sort().reverse();

      if (jsonFiles.length === 0) {
        return null;
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
      throw new Error(`Error cargando modelo actual: ${error.message}`);
    }
  }

  /**
   * Verifica drift del modelo
   */
  async checkModelDrift(currentModel, newData) {
    try {
      // Calcular estadísticas de datos nuevos
      const newStats = this.calculateDataStats(newData);
      
      // Obtener estadísticas del modelo anterior (si están guardadas)
      const oldStats = currentModel.modelData.dataStats || null;

      if (!oldStats) {
        // Si no hay estadísticas anteriores, calcular drift básico
        return this.basicDriftCheck(newStats);
      }

      // Comparar estadísticas
      const driftScore = this.compareStats(oldStats, newStats);

      // Considerar drift si el score es > 0.3
      return driftScore > 0.3;
    } catch (error) {
      console.warn('Error verificando drift:', error.message);
      return false;
    }
  }

  /**
   * Calcula estadísticas de datos
   */
  calculateDataStats(data) {
    const horas = data.map(r => {
      const fecha = new Date(r.fecha_hora);
      return fecha.getHours();
    });

    const tipos = data.map(r => r.tipo || 'entrada');

    return {
      meanHour: horas.reduce((sum, h) => sum + h, 0) / horas.length,
      stdHour: this.calculateStd(horas),
      tipoDistribution: {
        entrada: tipos.filter(t => t === 'entrada').length / tipos.length,
        salida: tipos.filter(t => t === 'salida').length / tipos.length
      },
      dataSize: data.length
    };
  }

  /**
   * Calcula desviación estándar
   */
  calculateStd(values) {
    const mean = values.reduce((sum, v) => sum + v, 0) / values.length;
    const variance = values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length;
    return Math.sqrt(variance);
  }

  /**
   * Compara estadísticas
   */
  compareStats(oldStats, newStats) {
    // Comparar media de horas
    const hourDiff = Math.abs(oldStats.meanHour - newStats.meanHour) / 24;
    
    // Comparar distribución de tipos
    const tipoDiff = Math.abs(
      oldStats.tipoDistribution.entrada - newStats.tipoDistribution.entrada
    );

    // Score combinado
    const driftScore = (hourDiff + tipoDiff) / 2;

    return driftScore;
  }

  /**
   * Verificación básica de drift
   */
  basicDriftCheck(stats) {
    // Verificar si hay cambios significativos en distribución
    return stats.tipoDistribution.entrada < 0.3 || stats.tipoDistribution.entrada > 0.7;
  }

  /**
   * Valida performance del modelo
   */
  async validatePerformance(newModel, oldModel, testData) {
    try {
      const features = newModel.features;
      const { X, y } = this.prepareDataForTraining(testData, features, newModel.targetColumn);

      // Evaluar nuevo modelo
      const newModelInstance = new LinearRegression();
      newModelInstance.setParams(newModel.model.params);
      const newEvaluation = newModelInstance.evaluate(X, y);

      // Evaluar modelo anterior
      const oldModelInstance = new LinearRegression();
      oldModelInstance.setParams(oldModel.modelData.params);
      const oldEvaluation = oldModelInstance.evaluate(X, y);

      // Comparar métricas
      const r2Improvement = newEvaluation.r2 - oldEvaluation.r2;
      const rmseImprovement = oldEvaluation.rmse - newEvaluation.rmse;
      const maeImprovement = oldEvaluation.mae - newEvaluation.mae;

      const degradation = Math.max(
        oldEvaluation.r2 - newEvaluation.r2,
        (newEvaluation.rmse - oldEvaluation.rmse) / oldEvaluation.rmse,
        (newEvaluation.mae - oldEvaluation.mae) / oldEvaluation.mae
      );

      return {
        newModel: newEvaluation,
        oldModel: oldEvaluation,
        r2Improvement: parseFloat(r2Improvement.toFixed(4)),
        rmseImprovement: parseFloat(rmseImprovement.toFixed(4)),
        maeImprovement: parseFloat(maeImprovement.toFixed(4)),
        degradation: Math.max(0, parseFloat(degradation.toFixed(4))),
        isImproved: r2Improvement > 0 && rmseImprovement > 0
      };
    } catch (error) {
      throw new Error(`Error validando performance: ${error.message}`);
    }
  }

  /**
   * Guarda modelo actualizado
   */
  async saveUpdatedModel(modelData, metadata) {
    try {
      await fs.mkdir(this.modelsDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `linear_regression_${timestamp}.json`;
      const filepath = path.join(this.modelsDir, filename);

      const fullModelData = {
        ...modelData,
        metadata: {
          ...metadata,
          updateType: modelData.incremental ? 'incremental' : 'full',
          timestamp: new Date().toISOString()
        },
        dataStats: this.calculateDataStats(metadata.newData || [])
      };

      await fs.writeFile(filepath, JSON.stringify(fullModelData, null, 2));

      return filepath;
    } catch (error) {
      throw new Error(`Error guardando modelo actualizado: ${error.message}`);
    }
  }

  /**
   * Registra actualización
   */
  async recordUpdate(updateInfo) {
    try {
      await fs.mkdir(this.updateHistoryDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `update_${timestamp}.json`;
      const filepath = path.join(this.updateHistoryDir, filename);

      const updateRecord = {
        ...updateInfo,
        timestamp: new Date().toISOString()
      };

      await fs.writeFile(filepath, JSON.stringify(updateRecord, null, 2));

      return filepath;
    } catch (error) {
      console.warn('Error registrando actualización:', error.message);
      return null;
    }
  }

  /**
   * Configura schedule de actualización semanal
   */
  configureSchedule(config) {
    this.scheduleConfig = {
      ...this.scheduleConfig,
      ...config
    };

    return this.scheduleConfig;
  }

  /**
   * Obtiene configuración del schedule
   */
  getScheduleConfig() {
    return this.scheduleConfig;
  }

  /**
   * Obtiene historial de actualizaciones
   */
  async getUpdateHistory(limit = 10) {
    try {
      const files = await fs.readdir(this.updateHistoryDir);
      const jsonFiles = files.filter(f => f.endsWith('.json')).sort().reverse().slice(0, limit);

      const updates = await Promise.all(
        jsonFiles.map(async (file) => {
          const content = await fs.readFile(
            path.join(this.updateHistoryDir, file),
            'utf8'
          );
          return JSON.parse(content);
        })
      );

      return updates;
    } catch (error) {
      return [];
    }
  }
}

module.exports = WeeklyModelUpdateService;

