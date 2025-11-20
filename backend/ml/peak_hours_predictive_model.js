/**
 * Modelo Predictivo de Horarios Pico Entrada/Salida
 * Predice horarios de mayor congestión para anticipar carga
 * Adaptado para el proyecto principal Acees_Group
 */

const fs = require('fs').promises;
const path = require('path');

class PeakHoursPredictiveModel {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.modelsDir = path.join(__dirname, 'data/peak_hours_models');
    this.entranceModel = null;
    this.exitModel = null;
    this.modelMetrics = {
      entrance: { accuracy: 0, precision: 0, recall: 0, f1Score: 0 },
      exit: { accuracy: 0, precision: 0, recall: 0, f1Score: 0 }
    };
  }

  /**
   * Entrena el modelo de predicción de horarios pico
   */
  async trainPeakHoursModel(options = {}) {
    const { months = 3, testSize = 0.2 } = options;

    try {
      console.log('🚀 Iniciando entrenamiento de modelo de horarios pico...');

      // 1. Recopilar datos históricos
      const dataset = await this.collectTrainingData(months);
      console.log(`📊 Dataset recopilado: ${dataset.length} registros`);

      // 2. Preparar datos para entrenamiento
      const { trainingData, testData } = await this.preparePeakHoursData(dataset, testSize);
      console.log(`🔄 Datos preparados: ${trainingData.length} entrenamiento, ${testData.length} prueba`);

      // 3. Entrenar modelos separados para entrada y salida
      this.entranceModel = await this.trainTypeSpecificModel(trainingData, 'entrada');
      this.exitModel = await this.trainTypeSpecificModel(trainingData, 'salida');

      // 4. Validar modelos
      const entranceMetrics = await this.validateModel(this.entranceModel, testData, 'entrada');
      const exitMetrics = await this.validateModel(this.exitModel, testData, 'salida');

      this.modelMetrics.entrance = entranceMetrics;
      this.modelMetrics.exit = exitMetrics;

      // 5. Guardar modelos
      await this.saveModels();

      const overallAccuracy = (entranceMetrics.accuracy + exitMetrics.accuracy) / 2;

      console.log('✅ Entrenamiento completado exitosamente');
      console.log(`📈 Precisión promedio: ${(overallAccuracy * 100).toFixed(2)}%`);

      return {
        success: true,
        metrics: {
          entrance: entranceMetrics,
          exit: exitMetrics,
          overall: {
            accuracy: overallAccuracy,
            precision: (entranceMetrics.precision + exitMetrics.precision) / 2,
            recall: (entranceMetrics.recall + exitMetrics.recall) / 2,
            f1Score: (entranceMetrics.f1Score + exitMetrics.f1Score) / 2
          }
        },
        trainingData: {
          totalRecords: dataset.length,
          trainingRecords: trainingData.length,
          testRecords: testData.length,
          months: months
        },
        modelSaved: true
      };
    } catch (error) {
      console.error('❌ Error entrenando modelo:', error.message);
      throw new Error(`Error entrenando modelo de horarios pico: ${error.message}`);
    }
  }

  /**
   * Recopila datos históricos para entrenamiento
   */
  async collectTrainingData(months) {
    try {
      const fechaInicio = new Date();
      fechaInicio.setMonth(fechaInicio.getMonth() - months);

      const dataset = await this.Asistencia.find({
        fecha_hora: { $gte: fechaInicio },
        tipo: { $in: ['entrada', 'salida'] }
      }).sort({ fecha_hora: 1 });

      return dataset.map(record => ({
        id: record._id.toString(),
        fecha_hora: record.fecha_hora,
        tipo: record.tipo,
        siglas_facultad: record.siglas_facultad,
        siglas_escuela: record.siglas_escuela,
        puerta: record.puerta,
        entrada_tipo: record.entrada_tipo,
        estado: record.estado
      }));
    } catch (error) {
      throw new Error(`Error recopilando datos: ${error.message}`);
    }
  }

  /**
   * Prepara datos específicos para predicción de horarios pico
   */
  async preparePeakHoursData(dataset, testSize = 0.2) {
    try {
      // Agrupar por hora, día y tipo
      const hourlyData = this.aggregateHourlyData(dataset);

      // Convertir a formato de entrenamiento con features
      const processedData = this.extractFeaturesFromHourlyData(hourlyData);

      // Dividir en entrenamiento y prueba
      const splitIndex = Math.floor(processedData.length * (1 - testSize));
      const trainingData = processedData.slice(0, splitIndex);
      const testData = processedData.slice(splitIndex);

      return { trainingData, testData };
    } catch (error) {
      throw new Error(`Error preparando datos: ${error.message}`);
    }
  }

  /**
   * Agrega datos por hora, día y tipo
   */
  aggregateHourlyData(dataset) {
    const hourlyData = {};

    dataset.forEach(record => {
      const fecha = new Date(record.fecha_hora);
      const hora = fecha.getHours();
      const fechaStr = fecha.toDateString();
      const key = `${fechaStr}_${hora}_${record.tipo}`;

      if (!hourlyData[key]) {
        hourlyData[key] = {
          fecha: fecha,
          hora: hora,
          tipo: record.tipo,
          count: 0,
          facultades: new Set(),
          puertas: new Set()
        };
      }

      hourlyData[key].count++;
      hourlyData[key].facultades.add(record.siglas_facultad);
      hourlyData[key].puertas.add(record.puerta);
    });

    return hourlyData;
  }

  /**
   * Extrae features de datos agregados por hora
   */
  extractFeaturesFromHourlyData(hourlyData) {
    return Object.keys(hourlyData).map(key => {
      const data = hourlyData[key];
      const fecha = data.fecha;

      return {
        // Features temporales
        hora: data.hora,
        dia_semana: fecha.getDay(),
        dia_mes: fecha.getDate(),
        mes: fecha.getMonth() + 1,
        semana_anio: this.getWeekOfYear(fecha),
        
        // Features binarias
        es_fin_semana: (fecha.getDay() === 0 || fecha.getDay() === 6) ? 1 : 0,
        es_feriado: this.isHoliday(fecha) ? 1 : 0,
        es_horario_pico: this.isPeakHour(data.hora, fecha.getDay()) ? 1 : 0,
        
        // Features del acceso
        tipo: data.tipo,
        es_entrada: data.tipo === 'entrada' ? 1 : 0,
        diversidad_facultades: data.facultades.size,
        diversidad_puertas: data.puertas.size,
        
        // Target
        count: data.count,
        is_peak: data.count > this.calculatePeakThreshold(data.tipo) ? 1 : 0
      };
    });
  }

  /**
   * Entrena modelo específico para un tipo (entrada/salida)
   */
  async trainTypeSpecificModel(trainingData, tipo) {
    try {
      const typeData = trainingData.filter(record => record.tipo === tipo);
      
      if (typeData.length < 10) {
        throw new Error(`Datos insuficientes para tipo ${tipo}: ${typeData.length} registros`);
      }

      // Preparar features y targets
      const features = typeData.map(record => [
        record.hora,
        record.dia_semana,
        record.mes,
        record.es_fin_semana,
        record.es_feriado,
        record.diversidad_facultades,
        record.diversidad_puertas
      ]);

      const targets = typeData.map(record => record.count);

      // Modelo simple de regresión lineal implementado manualmente
      const model = this.trainLinearRegression(features, targets);
      
      return {
        type: tipo,
        model: model,
        featureNames: ['hora', 'dia_semana', 'mes', 'es_fin_semana', 'es_feriado', 'diversidad_facultades', 'diversidad_puertas'],
        trainedAt: new Date().toISOString(),
        trainingSize: typeData.length
      };
    } catch (error) {
      throw new Error(`Error entrenando modelo ${tipo}: ${error.message}`);
    }
  }

  /**
   * Implementación simple de regresión lineal
   */
  trainLinearRegression(X, y) {
    const n = X.length;
    const m = X[0].length;
    
    // Inicializar pesos aleatoriamente
    const weights = Array(m + 1).fill(0).map(() => Math.random() * 0.01);
    
    const learningRate = 0.01;
    const epochs = 1000;
    
    // Entrenamiento por gradiente descendente
    for (let epoch = 0; epoch < epochs; epoch++) {
      const gradients = Array(m + 1).fill(0);
      
      for (let i = 0; i < n; i++) {
        // Predicción
        let prediction = weights[0]; // bias
        for (let j = 0; j < m; j++) {
          prediction += weights[j + 1] * X[i][j];
        }
        
        // Error
        const error = prediction - y[i];
        
        // Gradientes
        gradients[0] += error; // bias gradient
        for (let j = 0; j < m; j++) {
          gradients[j + 1] += error * X[i][j];
        }
      }
      
      // Actualizar pesos
      for (let j = 0; j <= m; j++) {
        weights[j] -= learningRate * gradients[j] / n;
      }
    }
    
    return { weights, features: m };
  }

  /**
   * Valida el modelo con datos de prueba
   */
  async validateModel(model, testData, tipo) {
    try {
      const typeTestData = testData.filter(record => record.tipo === tipo);
      
      if (typeTestData.length === 0) {
        return { accuracy: 0, precision: 0, recall: 0, f1Score: 0 };
      }

      let correct = 0;
      let truePositives = 0;
      let falsePositives = 0;
      let falseNegatives = 0;

      for (const record of typeTestData) {
        const features = [
          record.hora,
          record.dia_semana,
          record.mes,
          record.es_fin_semana,
          record.es_feriado,
          record.diversidad_facultades,
          record.diversidad_puertas
        ];

        const prediction = this.predict(model, features);
        const actualIsPeak = record.is_peak;
        const predictedIsPeak = prediction > this.calculatePeakThreshold(tipo) ? 1 : 0;

        if (predictedIsPeak === actualIsPeak) {
          correct++;
        }

        if (actualIsPeak === 1 && predictedIsPeak === 1) truePositives++;
        if (actualIsPeak === 0 && predictedIsPeak === 1) falsePositives++;
        if (actualIsPeak === 1 && predictedIsPeak === 0) falseNegatives++;
      }

      const accuracy = correct / typeTestData.length;
      const precision = truePositives / (truePositives + falsePositives) || 0;
      const recall = truePositives / (truePositives + falseNegatives) || 0;
      const f1Score = 2 * (precision * recall) / (precision + recall) || 0;

      return { accuracy, precision, recall, f1Score };
    } catch (error) {
      throw new Error(`Error validando modelo ${tipo}: ${error.message}`);
    }
  }

  /**
   * Realiza predicción con el modelo
   */
  predict(model, features) {
    let prediction = model.model.weights[0]; // bias
    for (let i = 0; i < features.length; i++) {
      prediction += model.model.weights[i + 1] * features[i];
    }
    return Math.max(0, prediction); // No negativos
  }

  /**
   * Predice horarios pico para las próximas 24 horas
   */
  async predictNext24Hours() {
    try {
      if (!this.entranceModel || !this.exitModel) {
        await this.loadModels();
      }

      const predictions = [];
      const now = new Date();
      
      for (let i = 0; i < 24; i++) {
        const futureTime = new Date(now.getTime() + (i * 60 * 60 * 1000));
        
        const features = [
          futureTime.getHours(),
          futureTime.getDay(),
          futureTime.getMonth() + 1,
          (futureTime.getDay() === 0 || futureTime.getDay() === 6) ? 1 : 0,
          this.isHoliday(futureTime) ? 1 : 0,
          3, // diversidad_facultades promedio
          2  // diversidad_puertas promedio
        ];

        const entrancePrediction = this.predict(this.entranceModel, features);
        const exitPrediction = this.predict(this.exitModel, features);

        predictions.push({
          hora: futureTime.getHours(),
          fecha_hora: futureTime.toISOString(),
          predicciones: {
            entrada: Math.round(entrancePrediction),
            salida: Math.round(exitPrediction),
            total: Math.round(entrancePrediction + exitPrediction)
          },
          es_pico: {
            entrada: entrancePrediction > this.calculatePeakThreshold('entrada'),
            salida: exitPrediction > this.calculatePeakThreshold('salida'),
            general: (entrancePrediction + exitPrediction) > 50
          },
          confianza: this.calculateConfidence(features)
        });
      }

      return {
        success: true,
        predictions: predictions,
        generatedAt: new Date().toISOString(),
        modelMetrics: this.modelMetrics
      };
    } catch (error) {
      throw new Error(`Error prediciendo horarios pico: ${error.message}`);
    }
  }

  /**
   * Calcula umbral para determinar horario pico
   */
  calculatePeakThreshold(tipo) {
    return tipo === 'entrada' ? 30 : 25; // Umbrales ajustables
  }

  /**
   * Calcula confianza de la predicción
   */
  calculateConfidence(features) {
    // Simplificado: basado en si es horario típico de universidad
    const hora = features[0];
    const esFinde = features[3];
    
    if (esFinde) return 0.6;
    if (hora >= 7 && hora <= 19) return 0.85;
    return 0.4;
  }

  /**
   * Guarda modelos entrenados
   */
  async saveModels() {
    try {
      await fs.mkdir(this.modelsDir, { recursive: true });
      
      const modelsData = {
        entrance: this.entranceModel,
        exit: this.exitModel,
        metrics: this.modelMetrics,
        savedAt: new Date().toISOString()
      };

      const filepath = path.join(this.modelsDir, 'peak_hours_models.json');
      await fs.writeFile(filepath, JSON.stringify(modelsData, null, 2));
      
      console.log(`💾 Modelos guardados en: ${filepath}`);
    } catch (error) {
      console.error('❌ Error guardando modelos:', error.message);
    }
  }

  /**
   * Carga modelos guardados
   */
  async loadModels() {
    try {
      const filepath = path.join(this.modelsDir, 'peak_hours_models.json');
      const data = await fs.readFile(filepath, 'utf8');
      const modelsData = JSON.parse(data);
      
      this.entranceModel = modelsData.entrance;
      this.exitModel = modelsData.exit;
      this.modelMetrics = modelsData.metrics;
      
      console.log('📥 Modelos cargados exitosamente');
    } catch (error) {
      throw new Error(`Error cargando modelos: ${error.message}`);
    }
  }

  // Métodos auxiliares
  getWeekOfYear(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  }

  isPeakHour(hora, diaSemana) {
    const peakHours = [7, 8, 9, 17, 18, 19];
    const isWeekend = diaSemana === 0 || diaSemana === 6;
    return peakHours.includes(hora) && !isWeekend;
  }

  isHoliday(date) {
    const holidays = ['01-01', '05-01', '07-28', '07-29', '08-30', '10-08', '11-01', '12-08', '12-25'];
    const monthDay = String(date.getMonth() + 1).padStart(2, '0') + '-' + 
                    String(date.getDate()).padStart(2, '0');
    return holidays.includes(monthDay);
  }
}

module.exports = PeakHoursPredictiveModel;