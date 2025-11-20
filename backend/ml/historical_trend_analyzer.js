/**
 * Análisis Avanzado de Tendencias Históricas
 * Analiza patrones históricos para mejorar predicciones
 */

class HistoricalTrendAnalyzer {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.cache = new Map();
    this.cacheTTL = 3600000; // 1 hora
  }

  /**
   * Analiza tendencias históricas para un horario específico
   */
  async analyzeHistoricalTrends(date, hour, lookbackDays = 30) {
    const cacheKey = `${date.toDateString()}-${hour}`;
    
    // Verificar cache
    if (this.cache.has(cacheKey)) {
      const cached = this.cache.get(cacheKey);
      if (Date.now() - cached.timestamp < this.cacheTTL) {
        return cached.data;
      }
    }

    const startDate = new Date(date);
    startDate.setDate(startDate.getDate() - lookbackDays);
    const endDate = new Date(date);

    // Obtener datos históricos para la misma hora y día de semana
    const historicalData = await this.getHistoricalHourData(startDate, endDate, date.getDay(), hour);

    const trends = {
      averageCount: this.calculateAverage(historicalData),
      medianCount: this.calculateMedian(historicalData),
      stdDeviation: this.calculateStdDeviation(historicalData),
      trend: this.calculateTrend(historicalData),
      seasonality: this.detectSeasonality(historicalData),
      confidence: this.calculateConfidence(historicalData),
      peakLikelihood: this.calculatePeakLikelihood(historicalData, hour)
    };

    // Guardar en cache
    this.cache.set(cacheKey, {
      data: trends,
      timestamp: Date.now()
    });

    return trends;
  }

  /**
   * Obtiene datos históricos para una hora específica y día de semana
   */
  async getHistoricalHourData(startDate, endDate, dayOfWeek, hour) {
    const startOfDay = new Date(startDate);
    startOfDay.setHours(hour, 0, 0, 0);
    
    const endOfDay = new Date(endDate);
    endOfDay.setHours(hour, 59, 59, 999);

    const asistencias = await this.Asistencia.find({
      fecha_hora: {
        $gte: startOfDay,
        $lte: endOfDay
      }
    });

    // Filtrar por día de semana y agrupar por fecha
    const groupedByDate = {};
    asistencias.forEach(a => {
      const fecha = new Date(a.fecha_hora);
      if (fecha.getDay() === dayOfWeek && fecha.getHours() === hour) {
        const dateKey = fecha.toDateString();
        if (!groupedByDate[dateKey]) {
          groupedByDate[dateKey] = 0;
        }
        groupedByDate[dateKey]++;
      }
    });

    return Object.values(groupedByDate);
  }

  /**
   * Calcula promedio
   */
  calculateAverage(data) {
    if (data.length === 0) return 0;
    return data.reduce((sum, val) => sum + val, 0) / data.length;
  }

  /**
   * Calcula mediana
   */
  calculateMedian(data) {
    if (data.length === 0) return 0;
    const sorted = [...data].sort((a, b) => a - b);
    const mid = Math.floor(sorted.length / 2);
    return sorted.length % 2 === 0
      ? (sorted[mid - 1] + sorted[mid]) / 2
      : sorted[mid];
  }

  /**
   * Calcula desviación estándar
   */
  calculateStdDeviation(data) {
    if (data.length === 0) return 0;
    const avg = this.calculateAverage(data);
    const squareDiffs = data.map(value => Math.pow(value - avg, 2));
    const avgSquareDiff = this.calculateAverage(squareDiffs);
    return Math.sqrt(avgSquareDiff);
  }

  /**
   * Calcula tendencia (creciente/decreciente/estable)
   */
  calculateTrend(data) {
    if (data.length < 2) return 'stable';

    // Dividir datos en dos mitades
    const mid = Math.floor(data.length / 2);
    const firstHalf = data.slice(0, mid);
    const secondHalf = data.slice(mid);

    const avgFirst = this.calculateAverage(firstHalf);
    const avgSecond = this.calculateAverage(secondHalf);

    const change = ((avgSecond - avgFirst) / avgFirst) * 100;

    if (change > 5) return 'increasing';
    if (change < -5) return 'decreasing';
    return 'stable';
  }

  /**
   * Detecta estacionalidad
   */
  detectSeasonality(data) {
    if (data.length < 7) return 'none';

    // Analizar patrones semanales
    const weeklyPattern = this.detectWeeklyPattern(data);
    
    return {
      weekly: weeklyPattern,
      strength: this.calculateSeasonalityStrength(data)
    };
  }

  /**
   * Detecta patrón semanal
   */
  detectWeeklyPattern(data) {
    // Simplificado: detecta si hay diferencia significativa entre días
    const variance = this.calculateStdDeviation(data) / this.calculateAverage(data);
    return variance > 0.3 ? 'strong' : variance > 0.15 ? 'moderate' : 'weak';
  }

  /**
   * Calcula fuerza de estacionalidad
   */
  calculateSeasonalityStrength(data) {
    const cv = this.calculateStdDeviation(data) / this.calculateAverage(data); // Coefficient of Variation
    return Math.min(100, cv * 100);
  }

  /**
   * Calcula confianza basada en cantidad de datos
   */
  calculateConfidence(data) {
    const sampleSize = data.length;
    // Más datos = mayor confianza
    if (sampleSize >= 20) return 0.9;
    if (sampleSize >= 10) return 0.7;
    if (sampleSize >= 5) return 0.5;
    return 0.3;
  }

  /**
   * Calcula probabilidad de ser horario pico
   */
  calculatePeakLikelihood(data, hour) {
    if (data.length === 0) return 0;

    const avg = this.calculateAverage(data);
    const overallAvg = this.estimateOverallAverage();
    
    // Si el promedio es significativamente mayor que el promedio general
    const ratio = avg / overallAvg;
    
    // Horarios conocidos como pico (7-9, 17-19)
    const knownPeakHours = [7, 8, 9, 17, 18, 19];
    const isKnownPeak = knownPeakHours.includes(hour);
    
    let likelihood = 0;
    if (ratio > 1.5) likelihood += 0.4;
    if (ratio > 2.0) likelihood += 0.3;
    if (isKnownPeak) likelihood += 0.2;
    if (data.length >= 10) likelihood += 0.1;

    return Math.min(1.0, likelihood);
  }

  /**
   * Estima promedio general (simplificado)
   */
  estimateOverallAverage() {
    // Valor por defecto, en producción se calcularía desde BD
    return 50;
  }

  /**
   * Analiza múltiples horarios simultáneamente
   */
  async analyzeMultipleHours(date, hours = []) {
    const analyses = await Promise.all(
      hours.map(hour => this.analyzeHistoricalTrends(date, hour))
    );

    return analyses.reduce((acc, analysis, index) => {
      acc[hours[index]] = analysis;
      return acc;
    }, {});
  }
}

module.exports = HistoricalTrendAnalyzer;

