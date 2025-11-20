/**
 * Servicio de Reportes de Horarios Pico con ML
 * Integra predicciones, comparación y sugerencias
 */

const PeakHoursPredictor = require('./peak_hours_predictor');
const MLRealComparison = require('./ml_real_comparison');
const AdjustmentSuggestionsGenerator = require('./adjustment_suggestions_generator');
const AdvancedMetricsAnalyzer = require('./advanced_metrics_analyzer');

class PeakHoursReportService {
  constructor(AsistenciaModel) {
    this.predictor = new PeakHoursPredictor(null, AsistenciaModel);
    this.comparison = new MLRealComparison(AsistenciaModel);
    this.suggestionsGenerator = new AdjustmentSuggestionsGenerator();
    this.metricsAnalyzer = new AdvancedMetricsAnalyzer();
  }

  /**
   * Genera reporte completo de horarios pico con ML
   */
  async generatePeakHoursReport(dateRange, options = {}) {
    const {
      includeComparison = true,
      includeSuggestions = true,
      includeHourlyMetrics = true
    } = options;

    try {
      // 1. Generar predicciones ML
      console.log('📊 Generando predicciones ML...');
      const predictions = await this.predictor.predictPeakHours(dateRange);
      
      let comparison = null;
      let comparisonSummary = null;
      let suggestions = null;
      let hourlyMetrics = null;

      // 2. Comparar con datos reales si está disponible
      if (includeComparison) {
        console.log('📈 Comparando con datos reales...');
        comparison = await this.comparison.compareMLvsReal(
          predictions.predictions,
          predictions.dateRange
        );
        comparisonSummary = comparison.summary;
      }

      // 3. Calcular métricas por horario
      if (includeHourlyMetrics && comparison) {
        console.log('📉 Calculando métricas por horario...');
        hourlyMetrics = this.calculateHourlyMetrics(comparison);
      }

      // 4. Generar sugerencias de ajuste
      if (includeSuggestions && comparison) {
        console.log('💡 Generando sugerencias de ajuste...');
        suggestions = this.suggestionsGenerator.generateSuggestions(
          comparison.comparison,
          comparisonSummary
        );
      }

      return {
        dateRange: predictions.dateRange,
        predictions: {
          summary: predictions.summary,
          dailyPredictions: predictions.predictions.map(p => ({
            fecha: p.fecha,
            dia_semana: p.dia_semana,
            peakHours: p.peakHours,
            totalPredicted: p.totalPredicted
          }))
        },
        comparison: comparison ? {
          overallAccuracy: comparison.accuracy,
          summary: comparisonSummary,
          dailyComparison: comparison.comparison.map(c => ({
            fecha: c.fecha,
            dia_semana: c.dia_semana,
            totalPredicted: c.totalPredicted,
            totalReal: c.totalReal,
            difference: c.totalPredicted - c.totalReal,
            peakHoursMatch: c.peakHoursComparison.match.matchPercentage
          }))
        } : null,
        hourlyMetrics: hourlyMetrics,
        suggestions: suggestions ? {
          totalSuggestions: suggestions.totalSuggestions,
          byPriority: suggestions.byPriority,
          suggestions: suggestions.suggestions.map(s => ({
            type: s.type,
            priority: s.priority,
            title: s.title,
            description: s.description,
            impact: s.impact,
            effort: s.effort
          })),
          actionPlan: this.suggestionsGenerator.generateActionPlan(suggestions)
        } : null,
        timestamp: new Date()
      };
    } catch (error) {
      throw new Error(`Error generando reporte de horarios pico: ${error.message}`);
    }
  }

  /**
   * Calcula métricas detalladas por horario (mejorado con análisis estadístico avanzado)
   */
  calculateHourlyMetrics(comparison) {
    const hourlyStats = {};

    comparison.comparison.forEach(day => {
      day.hourlyComparison.forEach(hour => {
        if (!hourlyStats[hour.hora]) {
          hourlyStats[hour.hora] = {
            hora: hour.hora,
            totalPredicted: 0,
            totalReal: 0,
            totalError: 0,
            accuracySum: 0,
            count: 0,
            maxError: 0,
            minError: Infinity,
            confidenceSum: 0,
            predictedValues: [],
            realValues: []
          };
        }

        const stats = hourlyStats[hour.hora];
        stats.totalPredicted += hour.predicted;
        stats.totalReal += hour.real;
        stats.totalError += hour.error;
        stats.accuracySum += hour.accuracy;
        stats.confidenceSum += hour.confidence;
        stats.count++;
        stats.maxError = Math.max(stats.maxError, hour.error);
        stats.minError = Math.min(stats.minError, hour.error);
        stats.predictedValues.push(hour.predicted);
        stats.realValues.push(hour.real);
      });
    });

    // Calcular promedios y métricas básicas
    const metrics = Object.values(hourlyStats).map(stats => {
      const avgAccuracy = stats.count > 0 ? stats.accuracySum / stats.count : 0;
      const avgError = stats.count > 0 ? stats.totalError / stats.count : 0;
      const avgConfidence = stats.count > 0 ? stats.confidenceSum / stats.count : 0;
      const avgPredicted = stats.count > 0 ? stats.totalPredicted / stats.count : 0;
      const avgReal = stats.count > 0 ? stats.totalReal / stats.count : 0;
      const bias = avgPredicted - avgReal;

      // Calcular métricas estadísticas avanzadas
      const advancedMetrics = this.metricsAnalyzer.calculateAdvancedMetrics(
        stats.predictedValues,
        stats.realValues
      );

      return {
        hora: stats.hora,
        samples: stats.count,
        averagePredicted: parseFloat(avgPredicted.toFixed(2)),
        averageReal: parseFloat(avgReal.toFixed(2)),
        averageAccuracy: parseFloat(avgAccuracy.toFixed(2)),
        averageError: parseFloat(avgError.toFixed(2)),
        maxError: stats.maxError,
        minError: stats.minError === Infinity ? 0 : stats.minError,
        bias: parseFloat(bias.toFixed(2)),
        mae: advancedMetrics.basicMetrics.mae,
        rmse: advancedMetrics.basicMetrics.rmse,
        mape: advancedMetrics.basicMetrics.mape,
        r2: advancedMetrics.basicMetrics.r2,
        correlation: advancedMetrics.basicMetrics.correlation,
        averageConfidence: parseFloat(avgConfidence.toFixed(2)),
        performance: this.categorizePerformance(avgAccuracy),
        advancedMetrics: {
          errorDistribution: advancedMetrics.errorDistribution,
          outliers: advancedMetrics.outliers,
          confidenceIntervals: advancedMetrics.confidenceIntervals,
          reliability: advancedMetrics.reliability
        }
      };
    });

    // Ordenar por hora
    metrics.sort((a, b) => a.hora - b.hora);

    return {
      metrics,
      summary: {
        bestHours: metrics.filter(m => m.performance === 'excellent').slice(0, 5),
        worstHours: metrics.filter(m => m.performance === 'poor').slice(0, 5),
        averageAccuracy: parseFloat((
          metrics.reduce((sum, m) => sum + m.averageAccuracy, 0) / metrics.length
        ).toFixed(2)),
        averageR2: parseFloat((
          metrics.reduce((sum, m) => sum + m.r2, 0) / metrics.length
        ).toFixed(3)),
        averageCorrelation: parseFloat((
          metrics.reduce((sum, m) => sum + m.correlation, 0) / metrics.length
        ).toFixed(3)),
        peakHoursAccuracy: this.calculatePeakHoursAccuracy(metrics),
        modelBias: parseFloat((
          metrics.reduce((sum, m) => sum + m.bias, 0) / metrics.length
        ).toFixed(2)),
        overallReliability: parseFloat((
          metrics.reduce((sum, m) => sum + m.advancedMetrics.reliability, 0) / metrics.length
        ).toFixed(2))
      }
    };
  }

  /**
   * Categoriza rendimiento por precisión
   */
  categorizePerformance(accuracy) {
    if (accuracy >= 90) return 'excellent';
    if (accuracy >= 80) return 'very_good';
    if (accuracy >= 70) return 'good';
    if (accuracy >= 60) return 'fair';
    return 'poor';
  }

  /**
   * Calcula precisión específica para horarios pico (7-9 y 17-19)
   */
  calculatePeakHoursAccuracy(metrics) {
    const peakHours = [7, 8, 9, 17, 18, 19];
    const peakMetrics = metrics.filter(m => peakHours.includes(m.hora));
    
    if (peakMetrics.length === 0) return 0;
    
    const avgAccuracy = peakMetrics.reduce((sum, m) => sum + m.averageAccuracy, 0) / peakMetrics.length;
    return parseFloat(avgAccuracy.toFixed(2));
  }

  /**
   * Obtiene reporte resumido para dashboard
   */
  async getDashboardSummary(dateRange) {
    try {
      const report = await this.generatePeakHoursReport(dateRange, {
        includeComparison: true,
        includeSuggestions: true,
        includeHourlyMetrics: true
      });

      return {
        dateRange: report.dateRange,
        predictions: {
          totalDays: report.predictions.summary.totalDays,
          averageDailyPredicted: report.predictions.summary.averageDailyPredicted,
          topPeakHours: report.predictions.summary.topPeakHours
        },
        comparison: report.comparison ? {
          overallAccuracy: report.comparison.overallAccuracy,
          totalPredicted: report.comparison.summary.totalPredicted,
          totalReal: report.comparison.summary.totalReal,
          difference: report.comparison.summary.totalDifference,
          peakHoursAccuracy: report.comparison.summary.peakHoursAccuracy
        } : null,
        hourlyMetrics: report.hourlyMetrics ? {
          averageAccuracy: report.hourlyMetrics.summary.averageAccuracy,
          peakHoursAccuracy: report.hourlyMetrics.summary.peakHoursAccuracy,
          bestHours: report.hourlyMetrics.summary.bestHours,
          worstHours: report.hourlyMetrics.summary.worstHours
        } : null,
        suggestions: report.suggestions ? {
          total: report.suggestions.totalSuggestions,
          highPriority: report.suggestions.byPriority.high.length,
          mediumPriority: report.suggestions.byPriority.medium.length,
          lowPriority: report.suggestions.byPriority.low.length
        } : null,
        timestamp: report.timestamp
      };
    } catch (error) {
      throw new Error(`Error obteniendo resumen: ${error.message}`);
    }
  }
}

module.exports = PeakHoursReportService;

