/**
 * Pipeline de Entrenamiento del Modelo
 * Orquesta el proceso completo de entrenamiento
 */

const DatasetCollector = require('./dataset_collector');
const TrainTestSplit = require('./train_test_split');
const ModelTrainer = require('./model_trainer');
const ModelValidator = require('./model_validator');
const fs = require('fs').promises;
const path = require('path');

class TrainingPipeline {
  constructor(options = {}) {
    this.collector = options.collector || null;
    this.splitter = new TrainTestSplit({
      testSize: options.testSize || 0.2,
      randomState: options.randomState || 42
    });
    this.trainer = new ModelTrainer();
    this.validator = new ModelValidator();
    this.outputDir = path.join(__dirname, '../data/models');
    this.logsDir = path.join(__dirname, '../data/logs');
  }

  /**
   * Ejecuta el pipeline completo de entrenamiento
   */
  async executePipeline(options = {}) {
    const {
      months = 3,
      testSize = 0.2,
      modelType = 'logistic_regression',
      stratify = 'target',
      collector = null
    } = options;

    // Usar collector pasado como parámetro o instancia propia
    const datasetCollector = collector || this.collector;
    
    if (!datasetCollector) {
      throw new Error('DatasetCollector no disponible. Debe pasarse como parámetro o en constructor.');
    }

    console.log('🚀 Iniciando pipeline de entrenamiento...');
    console.log(`📊 Configuración: ${months} meses, testSize=${testSize}, modelo=${modelType}`);

    try {
      // Paso 1: Validar disponibilidad de datos
      console.log('\n📋 Paso 1: Validando disponibilidad de datos...');
      const validation = await datasetCollector.validateDatasetAvailability();
      
      if (!validation.available) {
        throw new Error(`Dataset insuficiente. Se requieren ≥3 meses de datos históricos.`);
      }

      console.log(`✅ Dataset disponible: ${validation.recordsInPeriod} registros en ${validation.monthsAvailable} meses`);

      // Paso 2: Recopilar dataset histórico
      console.log('\n📥 Paso 2: Recopilando dataset histórico...');
      const collectionResult = await datasetCollector.collectHistoricalDataset({
        months,
        includeFeatures: true,
        outputFormat: 'json'
      });

      console.log(`✅ Dataset recopilado: ${collectionResult.records} registros`);
      console.log(`📁 Archivo: ${collectionResult.filename}`);

      // Cargar dataset
      const datasetContent = await fs.readFile(collectionResult.filepath, 'utf8');
      const dataset = JSON.parse(datasetContent);

      // Paso 3: Train/Test Split
      console.log('\n✂️ Paso 3: Dividiendo dataset (train/test split)...');
      const split = await this.splitter.split(dataset, {
        testSize,
        stratify: stratify
      });

      console.log(`✅ Split completado:`);
      console.log(`   - Train: ${split.trainSize} registros (${(split.trainSize / dataset.length * 100).toFixed(1)}%)`);
      console.log(`   - Test: ${split.testSize} registros (${(split.testSize / dataset.length * 100).toFixed(1)}%)`);

      // Guardar split
      const splitFiles = await this.splitter.saveSplit(
        split.train,
        split.test,
        path.join(__dirname, '../data/splits'),
        'pipeline'
      );

      // Paso 4: Entrenar modelo
      console.log('\n🧠 Paso 4: Entrenando modelo...');
      const trainingResult = await this.trainer.train(split.train, {
        modelType,
        features: this.getFeatureColumns(),
        target: 'target'
      });

      console.log(`✅ Modelo entrenado:`);
      console.log(`   - Tipo: ${trainingResult.modelType}`);
      console.log(`   - Parámetros: ${JSON.stringify(trainingResult.params)}`);
      console.log(`   - Tiempo: ${trainingResult.trainingTime}ms`);

      // Paso 5: Validar modelo
      console.log('\n📊 Paso 5: Validando modelo...');
      const validationResult = await this.validator.validate(
        trainingResult.model,
        split.test,
        {
          features: this.getFeatureColumns(),
          target: 'target'
        }
      );

      console.log(`✅ Validación completada:`);
      console.log(`   - Accuracy: ${(validationResult.accuracy * 100).toFixed(2)}%`);
      console.log(`   - Precision: ${(validationResult.precision * 100).toFixed(2)}%`);
      console.log(`   - Recall: ${(validationResult.recall * 100).toFixed(2)}%`);
      console.log(`   - F1-Score: ${(validationResult.f1Score * 100).toFixed(2)}%`);

      // Paso 6: Guardar modelo
      console.log('\n💾 Paso 6: Guardando modelo...');
      const modelPath = await this.saveModel(trainingResult, validationResult);

      // Paso 7: Generar reporte
      console.log('\n📝 Paso 7: Generando reporte...');
      const report = this.generateReport({
        validation,
        collectionResult,
        split,
        trainingResult,
        validationResult,
        modelPath
      });

      const reportPath = await this.saveReport(report);

      console.log('\n✅ Pipeline completado exitosamente!');
      console.log(`📁 Modelo guardado: ${modelPath}`);
      console.log(`📊 Reporte: ${reportPath}`);

      return {
        success: true,
        model: trainingResult.model,
        validation: validationResult,
        modelPath,
        reportPath,
        report
      };
    } catch (error) {
      console.error('\n❌ Error en pipeline:', error.message);
      throw error;
    }
  }

  /**
   * Obtiene las columnas de características
   */
  getFeatureColumns() {
    return [
      'hora',
      'minuto',
      'dia_semana',
      'dia_mes',
      'mes',
      'semana_anio',
      'es_fin_semana',
      'es_feriado',
      'siglas_facultad',
      'siglas_escuela',
      'tipo',
      'entrada_tipo',
      'puerta',
      'guardia_id'
    ];
  }

  /**
   * Guarda el modelo entrenado
   */
  async saveModel(trainingResult, validationResult) {
    try {
      await fs.mkdir(this.outputDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const modelData = {
        model: trainingResult.model,
        modelType: trainingResult.modelType,
        params: trainingResult.params,
        features: trainingResult.features,
        target: trainingResult.target,
        validation: validationResult,
        createdAt: new Date().toISOString(),
        version: '1.0.0'
      };

      const modelPath = path.join(this.outputDir, `model_${timestamp}.json`);
      await fs.writeFile(modelPath, JSON.stringify(modelData, null, 2));

      return modelPath;
    } catch (error) {
      throw new Error(`Error guardando modelo: ${error.message}`);
    }
  }

  /**
   * Genera reporte del entrenamiento
   */
  generateReport(data) {
    return {
      timestamp: new Date().toISOString(),
      dataset: {
        records: data.collectionResult.records,
        months: data.collectionResult.months,
        dateRange: data.collectionResult.dateRange
      },
      split: {
        trainSize: data.split.trainSize,
        testSize: data.split.testSize,
        ratio: data.split.splitRatio
      },
      model: {
        type: data.trainingResult.modelType,
        params: data.trainingResult.params,
        trainingTime: data.trainingResult.trainingTime
      },
      metrics: {
        accuracy: data.validationResult.accuracy,
        precision: data.validationResult.precision,
        recall: data.validationResult.recall,
        f1Score: data.validationResult.f1Score,
        confusionMatrix: data.validationResult.confusionMatrix
      },
      status: 'completed'
    };
  }

  /**
   * Guarda el reporte
   */
  async saveReport(report) {
    try {
      await fs.mkdir(this.logsDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const reportPath = path.join(this.logsDir, `training_report_${timestamp}.json`);
      await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

      return reportPath;
    } catch (error) {
      throw new Error(`Error guardando reporte: ${error.message}`);
    }
  }
}

module.exports = TrainingPipeline;

