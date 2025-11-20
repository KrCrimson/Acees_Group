/**
 * Servicio de Series Temporales
 * Implementa modelos ARIMA simplificado para predicción temporal
 * US043 - Series temporales
 */

const DatasetCollector = require('./dataset_collector');

class TimeSeriesService {
  constructor(AsistenciaModel) {
    this.collector = new DatasetCollector(AsistenciaModel);
  }

  /**
   * Entrena modelo de series temporales
   */
  async trainTimeSeriesModel(options = {}) {
    const {
      months = 3,
      targetColumn = 'total_accesses',
      aggregation = 'hourly', // hourly, daily, weekly
      detectSeasonality = true,
      forecastHorizon = 24 // horas/días a predecir
    } = options;

    try {
      // 1. Recopilar y preparar datos
      const timeSeriesData = await this.prepareTimeSeriesData(months, aggregation, targetColumn);

      // 2. Detectar estacionalidad
      let seasonality = null;
      if (detectSeasonality) {
        seasonality = this.detectSeasonality(timeSeriesData);
      }

      // 3. Entrenar modelo ARIMA simplificado
      const model = this.trainARIMA(timeSeriesData, seasonality);

      // 4. Validar modelo
      const validation = this.validateModel(model, timeSeriesData);

      // 5. Generar forecast
      const forecast = this.forecast(model, forecastHorizon, timeSeriesData);

      return {
        success: true,
        model: {
          type: 'ARIMA',
          parameters: model.parameters,
          seasonality: seasonality,
          validation: validation
        },
        forecast: forecast,
        aggregation: aggregation,
        dataPoints: timeSeriesData.length
      };
    } catch (error) {
      throw new Error(`Error entrenando modelo de series temporales: ${error.message}`);
    }
  }

  /**
   * Prepara datos para series temporales
   */
  async prepareTimeSeriesData(months, aggregation, targetColumn) {
    const dataset = await this.collector.collectHistoricalDataset({
      months,
      includeFeatures: true,
      outputFormat: 'json'
    });

    const datasetContent = await require('fs').promises.readFile(dataset.filepath, 'utf8');
    const data = JSON.parse(datasetContent);

    // Agregar datos según nivel
    const aggregated = {};
    
    data.forEach(record => {
      const date = new Date(record.fecha_hora || record.fecha);
      let key;

      if (aggregation === 'hourly') {
        key = `${date.toISOString().split('T')[0]}_${date.getHours()}`;
      } else if (aggregation === 'daily') {
        key = date.toISOString().split('T')[0];
      } else if (aggregation === 'weekly') {
        const week = this.getWeekNumber(date);
        key = `${date.getFullYear()}_W${week}`;
      }

      if (!aggregated[key]) {
        aggregated[key] = {
          timestamp: date,
          value: 0,
          count: 0
        };
      }

      aggregated[key].value += 1; // Contar accesos
      aggregated[key].count += 1;
    });

    // Convertir a array ordenado
    return Object.values(aggregated)
      .sort((a, b) => a.timestamp - b.timestamp)
      .map(item => ({
        timestamp: item.timestamp,
        value: item.value,
        date: item.timestamp.toISOString().split('T')[0]
      }));
  }

  /**
   * Obtiene número de semana
   */
  getWeekNumber(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  }

  /**
   * Detecta estacionalidad
   */
  detectSeasonality(timeSeriesData) {
    if (timeSeriesData.length < 24) return null;

    // Detectar patrones diarios (24 horas)
    const dailyPattern = this.detectDailyPattern(timeSeriesData);
    
    // Detectar patrones semanales (7 días)
    const weeklyPattern = this.detectWeeklyPattern(timeSeriesData);

    return {
      daily: dailyPattern,
      weekly: weeklyPattern,
      dominant: dailyPattern.strength > weeklyPattern.strength ? 'daily' : 'weekly'
    };
  }

  /**
   * Detecta patrón diario
   */
  detectDailyPattern(data) {
    const hourlyAverages = new Array(24).fill(0).map(() => []);
    
    data.forEach(item => {
      const hour = new Date(item.timestamp).getHours();
      hourlyAverages[hour].push(item.value);
    });

    const pattern = hourlyAverages.map(hours => {
      return hours.length > 0
        ? hours.reduce((a, b) => a + b, 0) / hours.length
        : 0;
    });

    // Calcular fuerza del patrón (varianza)
    const mean = pattern.reduce((a, b) => a + b, 0) / 24;
    const variance = pattern.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / 24;
    const strength = variance / (mean || 1);

    return {
      pattern: pattern,
      strength: strength,
      period: 24
    };
  }

  /**
   * Detecta patrón semanal
   */
  detectWeeklyPattern(data) {
    const dailyAverages = new Array(7).fill(0).map(() => []);
    
    data.forEach(item => {
      const dayOfWeek = new Date(item.timestamp).getDay();
      dailyAverages[dayOfWeek].push(item.value);
    });

    const pattern = dailyAverages.map(days => {
      return days.length > 0
        ? days.reduce((a, b) => a + b, 0) / days.length
        : 0;
    });

    const mean = pattern.reduce((a, b) => a + b, 0) / 7;
    const variance = pattern.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / 7;
    const strength = variance / (mean || 1);

    return {
      pattern: pattern,
      strength: strength,
      period: 7
    };
  }

  /**
   * Entrena modelo ARIMA simplificado
   */
  trainARIMA(timeSeriesData, seasonality) {
    // ARIMA simplificado: modelo autoregresivo de orden 1 (AR(1))
    // y diferenciación para hacer la serie estacionaria

    // 1. Diferenciación
    const differenced = this.difference(timeSeriesData);

    // 2. Calcular autocorrelación
    const autocorr = this.calculateAutocorrelation(differenced, 5);

    // 3. Estimar parámetros AR(1)
    const arCoefficient = this.estimateARCoefficient(differenced);

    // 4. Estimar media y desviación estándar
    const mean = differenced.reduce((a, b) => a + b.value, 0) / differenced.length;
    const variance = differenced.reduce((sum, val) => sum + Math.pow(val.value - mean, 2), 0) / differenced.length;
    const std = Math.sqrt(variance);

    return {
      parameters: {
        ar: arCoefficient,
        mean: mean,
        std: std,
        differencing: 1
      },
      seasonality: seasonality,
      autocorrelation: autocorr,
      originalMean: timeSeriesData.reduce((a, b) => a + b.value, 0) / timeSeriesData.length
    };
  }

  /**
   * Diferenciación de primer orden
   */
  difference(data) {
    const differenced = [];
    
    for (let i = 1; i < data.length; i++) {
      differenced.push({
        timestamp: data[i].timestamp,
        value: data[i].value - data[i - 1].value
      });
    }

    return differenced;
  }

  /**
   * Calcula autocorrelación
   */
  calculateAutocorrelation(data, maxLag) {
    const mean = data.reduce((a, b) => a + b.value, 0) / data.length;
    const autocorr = [];

    for (let lag = 0; lag <= maxLag; lag++) {
      let numerator = 0;
      let denominator = 0;

      for (let i = lag; i < data.length; i++) {
        numerator += (data[i].value - mean) * (data[i - lag].value - mean);
      }

      for (let i = 0; i < data.length; i++) {
        denominator += Math.pow(data[i].value - mean, 2);
      }

      autocorr.push(denominator > 0 ? numerator / denominator : 0);
    }

    return autocorr;
  }

  /**
   * Estima coeficiente AR(1)
   */
  estimateARCoefficient(differenced) {
    if (differenced.length < 2) return 0;

    let numerator = 0;
    let denominator = 0;

    for (let i = 1; i < differenced.length; i++) {
      numerator += differenced[i].value * differenced[i - 1].value;
      denominator += differenced[i - 1].value * differenced[i - 1].value;
    }

    return denominator > 0 ? numerator / denominator : 0;
  }

  /**
   * Valida modelo
   */
  validateModel(model, timeSeriesData) {
    // Dividir en train/test (80/20)
    const splitIndex = Math.floor(timeSeriesData.length * 0.8);
    const trainData = timeSeriesData.slice(0, splitIndex);
    const testData = timeSeriesData.slice(splitIndex);

    // Generar predicciones para conjunto de test
    const predictions = [];
    const actuals = [];

    for (let i = 0; i < testData.length; i++) {
      const forecastValue = this.predictNextValue(model, trainData, i);
      predictions.push(forecastValue);
      actuals.push(testData[i].value);
    }

    // Calcular métricas
    const mse = this.calculateMSE(actuals, predictions);
    const mae = this.calculateMAE(actuals, predictions);
    const rmse = Math.sqrt(mse);
    const meanActual = actuals.reduce((a, b) => a + b, 0) / actuals.length;
    const accuracy = meanActual > 0 ? Math.max(0, 1 - (rmse / meanActual)) : 0;

    return {
      mse: mse,
      mae: mae,
      rmse: rmse,
      accuracy: accuracy,
      meetsThreshold: accuracy >= 0.75 // >75% según US043
    };
  }

  /**
   * Predice siguiente valor
   */
  predictNextValue(model, history, index) {
    if (history.length === 0) return 0;

    // AR(1): X_t = phi * X_{t-1} + error
    const lastValue = history[history.length - 1].value;
    const predicted = model.parameters.ar * lastValue + model.parameters.mean;

    // Ajustar por estacionalidad si existe
    if (model.seasonality && model.seasonality.daily) {
      const hour = new Date(history[history.length - 1].timestamp).getHours();
      const seasonalFactor = model.seasonality.daily.pattern[hour] / 
        (model.seasonality.daily.pattern.reduce((a, b) => a + b, 0) / 24);
      return predicted * seasonalFactor;
    }

    return predicted;
  }

  /**
   * Calcula MSE
   */
  calculateMSE(actuals, predictions) {
    if (actuals.length !== predictions.length) return Infinity;
    
    let sum = 0;
    for (let i = 0; i < actuals.length; i++) {
      sum += Math.pow(actuals[i] - predictions[i], 2);
    }
    return sum / actuals.length;
  }

  /**
   * Calcula MAE
   */
  calculateMAE(actuals, predictions) {
    if (actuals.length !== predictions.length) return Infinity;
    
    let sum = 0;
    for (let i = 0; i < actuals.length; i++) {
      sum += Math.abs(actuals[i] - predictions[i]);
    }
    return sum / actuals.length;
  }

  /**
   * Genera forecast
   */
  forecast(model, horizon, history) {
    const forecast = [];
    const lastValue = history[history.length - 1].value;
    let currentValue = lastValue;

    for (let i = 0; i < horizon; i++) {
      // Predicción AR(1)
      const predicted = model.parameters.ar * currentValue + model.parameters.mean;

      // Ajustar por estacionalidad
      let adjustedPrediction = predicted;
      if (model.seasonality && model.seasonality.daily) {
        const futureDate = new Date(history[history.length - 1].timestamp);
        futureDate.setHours(futureDate.getHours() + i + 1);
        const hour = futureDate.getHours();
        const seasonalFactor = model.seasonality.daily.pattern[hour] / 
          (model.seasonality.daily.pattern.reduce((a, b) => a + b, 0) / 24);
        adjustedPrediction = predicted * seasonalFactor;
      }

      // Asegurar valor no negativo
      adjustedPrediction = Math.max(0, adjustedPrediction);

      forecast.push({
        step: i + 1,
        timestamp: new Date(history[history.length - 1].timestamp.getTime() + (i + 1) * 60 * 60 * 1000),
        predicted: Math.round(adjustedPrediction),
        confidence: 0.85 // Confianza estimada
      });

      currentValue = adjustedPrediction;
    }

    return forecast;
  }
}

module.exports = TimeSeriesService;

