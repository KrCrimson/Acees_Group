/**
 * Servicio de Predicción de Horarios Pico usando ML
 * Predice horarios de mayor actividad basándose en modelo entrenado
 */

const fs = require('fs').promises;
const path = require('path');
const HistoricalTrendAnalyzer = require('./historical_trend_analyzer');

class PeakHoursPredictor {
  constructor(modelPath = null, AsistenciaModel = null) {
    this.model = null;
    this.modelPath = modelPath;
    this.trendAnalyzer = AsistenciaModel ? new HistoricalTrendAnalyzer(AsistenciaModel) : null;
    this.features = [
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
    this.historicalBaseline = null;
  }

  /**
   * Carga el modelo más reciente entrenado
   */
  async loadLatestModel() {
    try {
      const modelsDir = path.join(__dirname, '../data/models');
      const files = await fs.readdir(modelsDir);
      
      if (files.length === 0) {
        throw new Error('No hay modelos entrenados disponibles');
      }

      // Obtener el modelo más reciente
      const jsonFiles = files.filter(f => f.endsWith('.json'));
      if (jsonFiles.length === 0) {
        throw new Error('No se encontraron modelos JSON');
      }

      // Ordenar por fecha de creación (del nombre del archivo)
      jsonFiles.sort().reverse();
      const latestModelPath = path.join(modelsDir, jsonFiles[0]);
      
      const modelContent = await fs.readFile(latestModelPath, 'utf8');
      const modelData = JSON.parse(modelContent);
      
      this.model = modelData.model;
      this.modelPath = latestModelPath;
      this.modelType = modelData.modelType;
      this.features = modelData.features || this.features;
      
      return {
        success: true,
        modelType: modelData.modelType,
        createdAt: modelData.createdAt,
        validation: modelData.validation
      };
    } catch (error) {
      throw new Error(`Error cargando modelo: ${error.message}`);
    }
  }

  /**
   * Predice horarios pico para un rango de fechas
   */
  async predictPeakHours(dateRange, options = {}) {
    const {
      granularity = 'hour', // 'hour', 'day', 'week'
      includePredictions = true
    } = options;

    if (!this.model) {
      await this.loadLatestModel();
    }

    const predictions = [];
    const { startDate, endDate } = this.normalizeDateRange(dateRange);

    // Generar predicciones para cada hora en el rango
    let currentDate = new Date(startDate);
    
    while (currentDate <= endDate) {
      const hourPredictions = [];
      
      // Predecir para cada hora del día
      for (let hora = 0; hora < 24; hora++) {
        const prediction = await this.predictForHour(currentDate, hora);
        hourPredictions.push({
          hora,
          fecha: new Date(currentDate),
          predictedCount: prediction.count,
          predictedProbability: prediction.probability,
          confidence: prediction.confidence
        });
      }

      // Identificar horarios pico (top 3 horas)
      const peakHours = this.identifyPeakHours(hourPredictions);

      predictions.push({
        fecha: new Date(currentDate),
        dia_semana: this.getDayName(currentDate.getDay()),
        predictions: hourPredictions,
        peakHours,
        totalPredicted: hourPredictions.reduce((sum, p) => sum + p.predictedCount, 0)
      });

      // Avanzar al siguiente día
      currentDate.setDate(currentDate.getDate() + 1);
    }

    return {
      dateRange: { startDate, endDate },
      granularity,
      predictions,
      summary: this.generateSummary(predictions)
    };
  }

  /**
   * Predice actividad para una hora específica (mejorado con tendencias)
   */
  async predictForHour(date, hour) {
    const features = this.extractFeaturesForHour(date, hour);
    const prediction = this.predictWithModel(features);
    
    // Obtener análisis de tendencias históricas si está disponible
    let trendAdjustment = 1.0;
    let historicalBaseline = null;
    let confidenceBoost = 0;

    if (this.trendAnalyzer) {
      try {
        const trends = await this.trendAnalyzer.analyzeHistoricalTrends(date, hour);
        historicalBaseline = trends.averageCount;
        
        // Ajustar predicción basándose en tendencias
        if (trends.trend === 'increasing') {
          trendAdjustment = 1.15; // 15% más
        } else if (trends.trend === 'decreasing') {
          trendAdjustment = 0.85; // 15% menos
        }

        // Aumentar confianza si hay datos históricos sólidos
        confidenceBoost = trends.confidence * 0.3;
        
        // Ajustar según probabilidad de horario pico
        if (trends.peakLikelihood > 0.5) {
          trendAdjustment *= 1.1;
        }
      } catch (error) {
        console.warn(`Error obteniendo tendencias históricas: ${error.message}`);
      }
    }
    
    // Estimar cantidad de accesos (mejorado)
    const estimatedCount = this.estimateAccessCountImproved(
      prediction.probability, 
      date, 
      hour,
      historicalBaseline,
      trendAdjustment
    );
    
    return {
      ...prediction,
      count: estimatedCount,
      confidence: Math.min(1.0, prediction.confidence + confidenceBoost),
      historicalBaseline,
      trendAdjustment,
      hasHistoricalData: historicalBaseline !== null
    };
  }

  /**
   * Extrae características para una hora específica
   */
  extractFeaturesForHour(date, hour) {
    const diaSemana = date.getDay();
    const mes = date.getMonth() + 1;
    const diaMes = date.getDate();
    
    // Calcular semana del año
    const semanaAnio = this.getWeekOfYear(date);
    
    return {
      hora: hour,
      minuto: 0, // Usar 0 como referencia
      dia_semana: diaSemana,
      dia_mes: diaMes,
      mes: mes,
      semana_anio: semanaAnio,
      es_fin_semana: (diaSemana === 0 || diaSemana === 6) ? 1 : 0,
      es_feriado: this.isHoliday(date) ? 1 : 0,
      siglas_facultad: 'GEN', // Valor promedio
      siglas_escuela: 'GEN',
      tipo: 1, // Entrada
      entrada_tipo: 'NFC',
      puerta: 'PRINCIPAL',
      guardia_id: 'AVG'
    };
  }

  /**
   * Realiza predicción con el modelo
   */
  predictWithModel(features) {
    const featureVector = this.features.map(name => {
      const value = features[name];
      if (typeof value === 'string') {
        return this.hashString(value);
      }
      return value || 0;
    });

    if (this.model.type === 'logistic_regression' || this.model.weights) {
      const linearCombination = featureVector.reduce((sum, val, i) => 
        sum + val * (this.model.weights[i] || 0), 0) + (this.model.bias || 0);
      const probability = 1 / (1 + Math.exp(-Math.max(-500, Math.min(500, linearCombination))));
      
      return {
        probability,
        prediction: probability >= 0.5 ? 1 : 0,
        confidence: Math.abs(probability - 0.5) * 2
      };
    }

    // Para árboles de decisión y random forest
    if (this.model.type === 'decision_tree' || this.model.trees) {
      const trees = this.model.trees || [this.model];
      const predictions = trees.map(tree => this.traverseTree(tree, featureVector));
      
      // Promedio de probabilidades
      const avgProbability = predictions.reduce((sum, p) => sum + p, 0) / predictions.length;
      
      return {
        probability: avgProbability,
        prediction: avgProbability >= 0.5 ? 1 : 0,
        confidence: Math.abs(avgProbability - 0.5) * 2
      };
    }

    return { probability: 0.5, prediction: 0, confidence: 0 };
  }

  /**
   * Recorre árbol de decisión
   */
  traverseTree(node, featureVector) {
    if (node.type === 'leaf') {
      return node.prediction === 1 ? 0.8 : 0.2; // Probabilidad estimada
    }

    const featureValue = featureVector[node.featureIndex];
    
    if (featureValue <= node.threshold) {
      return this.traverseTree(node.left, featureVector);
    } else {
      return this.traverseTree(node.right, featureVector);
    }
  }

  /**
   * Estima cantidad de accesos mejorado (usa datos históricos cuando están disponibles)
   */
  estimateAccessCountImproved(probability, date, hour, historicalBaseline = null, trendAdjustment = 1.0) {
    let baseCount;

    // Si hay baseline histórico, usarlo como base más confiable
    if (historicalBaseline !== null && historicalBaseline > 0) {
      baseCount = historicalBaseline;
      
      // Ajustar según probabilidad del modelo ML
      const mlAdjustment = (probability - 0.5) * 0.4; // ±20% basado en probabilidad
      baseCount *= (1 + mlAdjustment);
    } else {
      // Fallback al método original
      baseCount = this.estimateAccessCount(probability, date, hour);
    }

    // Aplicar ajuste de tendencia
    baseCount *= trendAdjustment;

    // Factores de ajuste contextuales
    const diaSemana = date.getDay();
    const isWeekend = diaSemana === 0 || diaSemana === 6;
    const isPeakHour = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);
    
    if (isWeekend) {
      baseCount *= 0.3;
    }
    
    if (isPeakHour && !isWeekend) {
      baseCount *= 1.2; // Boost adicional para horarios pico en días laborables
    }
    
    // Ajuste por hora del día (curva de actividad normal)
    const hourFactor = this.getHourFactor(hour);
    baseCount *= hourFactor;
    
    return Math.round(Math.max(0, baseCount));
  }

  /**
   * Estima cantidad de accesos basándose en probabilidad y contexto (método original)
   */
  estimateAccessCount(probability, date, hour) {
    // Factores de ajuste
    const diaSemana = date.getDay();
    const isWeekend = diaSemana === 0 || diaSemana === 6;
    const isPeakHour = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);
    
    // Factor base
    let baseCount = probability * 100; // Escalar probabilidad
    
    // Ajustes por contexto
    if (isWeekend) {
      baseCount *= 0.3; // Menos actividad en fines de semana
    }
    
    if (isPeakHour) {
      baseCount *= 2.5; // Más actividad en horarios pico
    }
    
    // Ajuste por hora del día (curva de actividad normal)
    const hourFactor = this.getHourFactor(hour);
    baseCount *= hourFactor;
    
    return Math.round(Math.max(0, baseCount));
  }

  /**
   * Factor de actividad por hora (curva normalizada)
   */
  getHourFactor(hour) {
    // Curva de actividad típica (pico en horas laborables)
    const factors = {
      0: 0.1, 1: 0.05, 2: 0.05, 3: 0.05, 4: 0.05,
      5: 0.2, 6: 0.5, 7: 1.5, 8: 2.0, 9: 1.8,
      10: 1.2, 11: 1.0, 12: 1.3, 13: 1.5, 14: 1.2,
      15: 1.0, 16: 1.2, 17: 1.8, 18: 1.5, 19: 1.0,
      20: 0.5, 21: 0.3, 22: 0.2, 23: 0.1
    };
    
    return factors[hour] || 0.5;
  }

  /**
   * Identifica horarios pico mejorado (considera múltiples factores)
   */
  identifyPeakHours(hourPredictions) {
    // Ordenar por cantidad predicha
    const sorted = [...hourPredictions].sort((a, b) => 
      b.predictedCount - a.predictedCount
    );
    
    // Identificar top 3
    const top3 = sorted.slice(0, 3);
    
    // Calcular score combinado (cantidad + confianza + datos históricos)
    const scored = top3.map(p => ({
      hora: p.hora,
      predictedCount: p.predictedCount,
      probability: p.predictedProbability,
      confidence: p.confidence,
      score: this.calculatePeakScore(p),
      hasHistoricalData: p.hasHistoricalData || false
    })).sort((a, b) => b.score - a.score);
    
    return scored.slice(0, 3);
  }

  /**
   * Calcula score para identificar horarios pico
   */
  calculatePeakScore(prediction) {
    let score = prediction.predictedCount;
    
    // Boost por confianza alta
    score *= (1 + prediction.confidence * 0.2);
    
    // Boost si tiene datos históricos
    if (prediction.hasHistoricalData) {
      score *= 1.15;
    }
    
    // Boost por probabilidad alta del modelo
    score *= (1 + prediction.predictedProbability * 0.1);
    
    return score;
  }

  /**
   * Genera resumen mejorado de predicciones
   */
  generateSummary(predictions) {
    const allPeakHours = [];
    let totalHistoricalData = 0;
    let totalWithHistoricalData = 0;
    
    predictions.forEach(p => {
      p.peakHours.forEach(ph => {
        allPeakHours.push({ ...ph, fecha: p.fecha });
        if (ph.hasHistoricalData) {
          totalHistoricalData++;
        }
      });
      if (p.predictions.some(pr => pr.hasHistoricalData)) {
        totalWithHistoricalData++;
      }
    });

    // Horarios más frecuentes como pico
    const hourFrequency = {};
    allPeakHours.forEach(ph => {
      hourFrequency[ph.hora] = (hourFrequency[ph.hora] || 0) + 1;
    });

    const topPeakHours = Object.entries(hourFrequency)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([hora, count]) => ({
        hora: parseInt(hora),
        frequency: count,
        percentage: (count / predictions.length * 100).toFixed(1),
        avgScore: this.calculateAvgScoreForHour(allPeakHours, parseInt(hora))
      }));

    // Calcular confianza promedio
    const avgConfidence = allPeakHours.length > 0
      ? allPeakHours.reduce((sum, ph) => sum + ph.confidence, 0) / allPeakHours.length
      : 0;

    return {
      totalDays: predictions.length,
      averageDailyPredicted: (
        predictions.reduce((sum, p) => sum + p.totalPredicted, 0) / predictions.length
      ).toFixed(0),
      topPeakHours,
      averageConfidence: parseFloat(avgConfidence.toFixed(2)),
      historicalDataCoverage: {
        percentage: (totalWithHistoricalData / predictions.length * 100).toFixed(1),
        daysWithData: totalWithHistoricalData,
        totalDays: predictions.length
      },
      peakHoursByDay: predictions.map(p => ({
        fecha: p.fecha,
        peakHours: p.peakHours.map(ph => ({
          hora: ph.hora,
          score: ph.score || ph.predictedCount,
          confidence: ph.confidence
        }))
      }))
    };
  }

  /**
   * Calcula score promedio para una hora específica
   */
  calculateAvgScoreForHour(allPeakHours, hora) {
    const hours = allPeakHours.filter(ph => ph.hora === hora);
    if (hours.length === 0) return 0;
    
    const avgScore = hours.reduce((sum, ph) => sum + (ph.score || ph.predictedCount), 0) / hours.length;
    return parseFloat(avgScore.toFixed(2));
  }

  /**
   * Normaliza rango de fechas
   */
  normalizeDateRange(dateRange) {
    let startDate, endDate;

    if (dateRange.startDate && dateRange.endDate) {
      startDate = new Date(dateRange.startDate);
      endDate = new Date(dateRange.endDate);
    } else if (dateRange.days) {
      endDate = new Date();
      startDate = new Date();
      startDate.setDate(startDate.getDate() - dateRange.days);
    } else {
      endDate = new Date();
      startDate = new Date();
      startDate.setDate(startDate.getDate() - 7); // Última semana por defecto
    }

    return { startDate, endDate };
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
    // Implementar lógica de feriados si es necesario
    return false;
  }

  /**
   * Obtiene nombre del día
   */
  getDayName(dayIndex) {
    const days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    return days[dayIndex];
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
}

module.exports = PeakHoursPredictor;

