/**
 * Servicio de Visualización de Predicciones ML
 * Genera datos estructurados para gráficos de predicción vs real
 */

const PeakHoursPredictor = require('./peak_hours_predictor');
const MLRealComparison = require('./ml_real_comparison');

class PredictionVisualizationService {
  constructor(AsistenciaModel) {
    this.predictor = new PeakHoursPredictor(null, AsistenciaModel);
    this.comparison = new MLRealComparison(AsistenciaModel);
    this.Asistencia = AsistenciaModel;
  }

  /**
   * Genera datos para gráficos de predicción vs real
   */
  async generateVisualizationData(dateRange, options = {}) {
    const {
      granularity = 'hour', // 'hour', 'day', 'week'
      includeConfidenceIntervals = true,
      includeRealData = true
    } = options;

    try {
      // 1. Generar predicciones ML
      await this.predictor.loadLatestModel();
      const predictions = await this.predictor.predictPeakHours(dateRange);

      // 2. Obtener datos reales si está disponible
      let realData = null;
      let comparison = null;

      if (includeRealData) {
        comparison = await this.comparison.compareMLvsReal(
          predictions.predictions,
          predictions.dateRange
        );
        realData = this.extractRealDataForVisualization(comparison, granularity);
      }

      // 3. Estructurar datos de predicción para gráficos
      const predictionData = this.structurePredictionData(predictions, granularity);

      // 4. Calcular intervalos de confianza si está habilitado
      let confidenceIntervals = null;
      if (includeConfidenceIntervals) {
        confidenceIntervals = this.calculateConfidenceIntervals(
          predictionData,
          realData
        );
      }

      // 5. Generar datos combinados para gráficos
      const chartData = this.combineChartData(
        predictionData,
        realData,
        confidenceIntervals,
        granularity
      );

      return {
        dateRange: predictions.dateRange,
        granularity,
        chartData,
        predictionData,
        realData,
        confidenceIntervals,
        summary: this.generateVisualizationSummary(chartData),
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      throw new Error(`Error generando datos de visualización: ${error.message}`);
    }
  }

  /**
   * Estructura datos de predicción para gráficos
   */
  structurePredictionData(predictions, granularity) {
    if (granularity === 'hour') {
      return this.structureByHour(predictions);
    } else if (granularity === 'day') {
      return this.structureByDay(predictions);
    } else {
      return this.structureByWeek(predictions);
    }
  }

  /**
   * Estructura datos por hora
   */
  structureByHour(predictions) {
    const data = [];

    predictions.predictions.forEach(day => {
      day.predictions.forEach(hour => {
        data.push({
          timestamp: new Date(day.fecha).setHours(hour.hora, 0, 0, 0),
          date: day.fecha.toISOString().split('T')[0],
          hour: hour.hora,
          predicted: hour.predictedCount,
          confidence: hour.confidence,
          probability: hour.predictedProbability,
          hasHistoricalData: hour.hasHistoricalData || false
        });
      });
    });

    return data.sort((a, b) => a.timestamp - b.timestamp);
  }

  /**
   * Estructura datos por día
   */
  structureByDay(predictions) {
    return predictions.predictions.map(day => ({
      timestamp: new Date(day.fecha).setHours(0, 0, 0, 0),
      date: day.fecha.toISOString().split('T')[0],
      dayOfWeek: day.dia_semana,
      predicted: day.totalPredicted,
      peakHours: day.peakHours.map(ph => ph.hora),
      averageConfidence: day.predictions.length > 0
        ? day.predictions.reduce((sum, p) => sum + p.confidence, 0) / day.predictions.length
        : 0
    }));
  }

  /**
   * Estructura datos por semana
   */
  structureByWeek(predictions) {
    const weeks = {};
    
    predictions.predictions.forEach(day => {
      const weekStart = this.getWeekStart(day.fecha);
      const weekKey = weekStart.toISOString().split('T')[0];

      if (!weeks[weekKey]) {
        weeks[weekKey] = {
          timestamp: weekStart.getTime(),
          weekStart: weekKey,
          predicted: 0,
          days: 0
        };
      }

      weeks[weekKey].predicted += day.totalPredicted;
      weeks[weekKey].days++;
    });

    return Object.values(weeks).map(week => ({
      ...week,
      averageDaily: week.predicted / week.days
    }));
  }

  /**
   * Obtiene inicio de semana
   */
  getWeekStart(date) {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1); // Lunes
    return new Date(d.setDate(diff));
  }

  /**
   * Extrae datos reales para visualización
   */
  extractRealDataForVisualization(comparison, granularity) {
    if (granularity === 'hour') {
      return comparison.comparison.flatMap(day =>
        day.hourlyComparison.map(hour => ({
          timestamp: new Date(day.fecha).setHours(hour.hora, 0, 0, 0),
          date: day.fecha.toISOString().split('T')[0],
          hour: hour.hora,
          real: hour.real,
          predicted: hour.predicted,
          error: hour.error,
          accuracy: hour.accuracy
        }))
      ).sort((a, b) => a.timestamp - b.timestamp);
    } else if (granularity === 'day') {
      return comparison.comparison.map(day => ({
        timestamp: new Date(day.fecha).setHours(0, 0, 0, 0),
        date: day.fecha.toISOString().split('T')[0],
        dayOfWeek: day.dia_semana,
        real: day.totalReal,
        predicted: day.totalPredicted,
        difference: day.totalPredicted - day.totalReal,
        peakHoursMatch: parseFloat(day.peakHoursComparison.match.matchPercentage)
      }));
    } else {
      // Por semana
      const weeks = {};
      comparison.comparison.forEach(day => {
        const weekStart = this.getWeekStart(day.fecha);
        const weekKey = weekStart.toISOString().split('T')[0];

        if (!weeks[weekKey]) {
          weeks[weekKey] = {
            timestamp: weekStart.getTime(),
            weekStart: weekKey,
            real: 0,
            predicted: 0,
            days: 0
          };
        }

        weeks[weekKey].real += day.totalReal;
        weeks[weekKey].predicted += day.totalPredicted;
        weeks[weekKey].days++;
      });

      return Object.values(weeks).map(week => ({
        ...week,
        averageDailyReal: week.real / week.days,
        averageDailyPredicted: week.predicted / week.days
      }));
    }
  }

  /**
   * Calcula intervalos de confianza para predicciones
   */
  calculateConfidenceIntervals(predictionData, realData = null) {
    const intervals = [];

    if (realData && realData.length > 0) {
      // Calcular intervalos basados en errores históricos
      const errors = realData.map(d => Math.abs(d.predicted - d.real));
      const meanError = errors.reduce((sum, e) => sum + e, 0) / errors.length;
      const stdError = this.calculateStdDeviation(errors);

      // Intervalo de confianza del 95%
      const zScore = 1.96;
      const margin = zScore * stdError;

      predictionData.forEach((pred, index) => {
        const correspondingReal = realData.find(r => 
          Math.abs(r.timestamp - pred.timestamp) < 3600000 // 1 hora
        );

        if (correspondingReal) {
          const predictionError = Math.abs(pred.predicted - correspondingReal.real);
          const adjustedMargin = margin * (1 + predictionError / meanError);
        }

        intervals.push({
          timestamp: pred.timestamp,
          predicted: pred.predicted,
          confidenceLevel: 0.95,
          lowerBound: Math.max(0, pred.predicted - margin),
          upperBound: pred.predicted + margin,
          confidence: pred.confidence || 0.5
        });
      });
    } else {
      // Intervalos basados solo en confianza del modelo
      predictionData.forEach(pred => {
        const margin = pred.predicted * (1 - pred.confidence) * 0.5;
        intervals.push({
          timestamp: pred.timestamp,
          predicted: pred.predicted,
          confidenceLevel: pred.confidence,
          lowerBound: Math.max(0, pred.predicted - margin),
          upperBound: pred.predicted + margin,
          confidence: pred.confidence
        });
      });
    }

    return intervals;
  }

  /**
   * Calcula desviación estándar
   */
  calculateStdDeviation(values) {
    if (values.length === 0) return 0;
    const mean = values.reduce((sum, v) => sum + v, 0) / values.length;
    const variance = values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length;
    return Math.sqrt(variance);
  }

  /**
   * Combina datos para gráficos
   */
  combineChartData(predictionData, realData, confidenceIntervals, granularity) {
    const combined = [];

    if (realData && realData.length > 0) {
      // Combinar predicciones con datos reales
      predictionData.forEach((pred, index) => {
        const real = realData.find(r => 
          Math.abs(r.timestamp - pred.timestamp) < 3600000
        );

        const interval = confidenceIntervals 
          ? confidenceIntervals.find(i => i.timestamp === pred.timestamp)
          : null;

        combined.push({
          timestamp: pred.timestamp,
          date: pred.date || new Date(pred.timestamp).toISOString().split('T')[0],
          hour: pred.hour,
          predicted: pred.predicted,
          real: real ? real.real : null,
          error: real ? Math.abs(pred.predicted - real.real) : null,
          accuracy: real ? real.accuracy : null,
          confidenceInterval: interval ? {
            lower: interval.lowerBound,
            upper: interval.upperBound,
            confidence: interval.confidence
          } : null,
          confidence: pred.confidence || 0.5
        });
      });
    } else {
      // Solo predicciones con intervalos de confianza
      predictionData.forEach((pred, index) => {
        const interval = confidenceIntervals 
          ? confidenceIntervals[index]
          : null;

        combined.push({
          timestamp: pred.timestamp,
          date: pred.date || new Date(pred.timestamp).toISOString().split('T')[0],
          hour: pred.hour,
          predicted: pred.predicted,
          real: null,
          confidenceInterval: interval ? {
            lower: interval.lowerBound,
            upper: interval.upperBound,
            confidence: interval.confidence
          } : null,
          confidence: pred.confidence || 0.5
        });
      });
    }

    return combined.sort((a, b) => a.timestamp - b.timestamp);
  }

  /**
   * Genera resumen para visualización
   */
  generateVisualizationSummary(chartData) {
    const withRealData = chartData.filter(d => d.real !== null);
    
    if (withRealData.length === 0) {
      return {
        totalPredictions: chartData.length,
        averagePredicted: chartData.reduce((sum, d) => sum + d.predicted, 0) / chartData.length,
        averageConfidence: chartData.reduce((sum, d) => sum + d.confidence, 0) / chartData.length
      };
    }

    const totalError = withRealData.reduce((sum, d) => sum + (d.error || 0), 0);
    const avgAccuracy = withRealData.reduce((sum, d) => sum + (d.accuracy || 0), 0) / withRealData.length;

    return {
      totalPredictions: chartData.length,
      totalRealData: withRealData.length,
      averagePredicted: chartData.reduce((sum, d) => sum + d.predicted, 0) / chartData.length,
      averageReal: withRealData.reduce((sum, d) => sum + (d.real || 0), 0) / withRealData.length,
      averageError: totalError / withRealData.length,
      averageAccuracy: avgAccuracy,
      averageConfidence: chartData.reduce((sum, d) => sum + d.confidence, 0) / chartData.length
    };
  }

  /**
   * Genera datos para gráfico de líneas (predicción vs real)
   */
  async generateLineChartData(dateRange) {
    const data = await this.generateVisualizationData(dateRange, {
      granularity: 'hour',
      includeConfidenceIntervals: true,
      includeRealData: true
    });

    return {
      labels: data.chartData.map(d => {
        const date = new Date(d.timestamp);
        return `${date.getDate()}/${date.getMonth() + 1} ${date.getHours()}:00`;
      }),
      datasets: [
        {
          label: 'Predicción ML',
          data: data.chartData.map(d => d.predicted),
          borderColor: 'rgb(75, 192, 192)',
          backgroundColor: 'rgba(75, 192, 192, 0.2)',
          tension: 0.1
        },
        {
          label: 'Datos Reales',
          data: data.chartData.map(d => d.real).filter(d => d !== null),
          borderColor: 'rgb(255, 99, 132)',
          backgroundColor: 'rgba(255, 99, 132, 0.2)',
          tension: 0.1
        },
        {
          label: 'Intervalo Confianza Superior',
          data: data.chartData.map(d => d.confidenceInterval?.upper || null).filter(d => d !== null),
          borderColor: 'rgba(75, 192, 192, 0.3)',
          backgroundColor: 'rgba(75, 192, 192, 0.1)',
          borderDash: [5, 5],
          fill: false
        },
        {
          label: 'Intervalo Confianza Inferior',
          data: data.chartData.map(d => d.confidenceInterval?.lower || null).filter(d => d !== null),
          borderColor: 'rgba(75, 192, 192, 0.3)',
          backgroundColor: 'rgba(75, 192, 192, 0.1)',
          borderDash: [5, 5],
          fill: true
        }
      ],
      summary: data.summary
    };
  }

  /**
   * Genera datos para gráfico de barras (comparación diaria)
   */
  async generateBarChartData(dateRange) {
    const data = await this.generateVisualizationData(dateRange, {
      granularity: 'day',
      includeConfidenceIntervals: false,
      includeRealData: true
    });

    return {
      labels: data.chartData.map(d => {
        const date = new Date(d.timestamp);
        return `${date.getDate()}/${date.getMonth() + 1}`;
      }),
      datasets: [
        {
          label: 'Predicción ML',
          data: data.chartData.map(d => d.predicted),
          backgroundColor: 'rgba(75, 192, 192, 0.6)'
        },
        {
          label: 'Datos Reales',
          data: data.chartData.map(d => d.real).filter(d => d !== null),
          backgroundColor: 'rgba(255, 99, 132, 0.6)'
        }
      ],
      summary: data.summary
    };
  }
}

module.exports = PredictionVisualizationService;

