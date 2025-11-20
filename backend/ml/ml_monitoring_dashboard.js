/**
 * Dashboard de Monitoreo ML
 * Integra métricas, evolución temporal y visualizaciones
 */

const MLMetricsService = require('./ml_metrics_service');
const TemporalMetricsEvolution = require('./temporal_metrics_evolution');
const MLRealComparison = require('./ml_real_comparison');

class MLMonitoringDashboard {
  constructor(AsistenciaModel) {
    this.metricsService = new MLMetricsService(AsistenciaModel);
    this.temporalEvolution = new TemporalMetricsEvolution();
    this.comparison = new MLRealComparison(AsistenciaModel);
  }

  /**
   * Genera dashboard completo de monitoreo ML
   */
  async generateDashboard(dateRange, options = {}) {
    const {
      includeEvolution = true,
      evolutionDays = 30,
      includeComparison = true,
      includeDetailedMetrics = true
    } = options;

    try {
      // 1. Obtener comparación ML vs Real
      let comparison = null;
      let metrics = null;
      let evolution = null;

      if (includeComparison) {
        const PeakHoursPredictor = require('./peak_hours_predictor');
        const predictor = new PeakHoursPredictor(null, this.comparison.Asistencia);
        await predictor.loadLatestModel();
        
        const predictions = await predictor.predictPeakHours(dateRange);
        comparison = await this.comparison.compareMLvsReal(
          predictions.predictions,
          predictions.dateRange
        );
      }

      // 2. Calcular métricas
      if (includeDetailedMetrics && comparison) {
        metrics = this.metricsService.generateMetricsReport(comparison);
        
        // Guardar métricas para evolución temporal
        try {
          await this.temporalEvolution.saveMetrics(metrics, comparison.dateRange, {
            modelType: 'logistic_regression',
            version: '1.0.0'
          });
        } catch (error) {
          console.warn('Error guardando métricas para evolución:', error.message);
        }
      }

      // 3. Obtener evolución temporal
      if (includeEvolution) {
        evolution = await this.temporalEvolution.generateEvolutionReport(evolutionDays);
      }

      // 4. Comparar con historial si hay métricas actuales
      let historicalComparison = null;
      if (metrics && evolution) {
        historicalComparison = await this.temporalEvolution.compareWithHistory(
          metrics,
          evolutionDays
        );
      }

      return {
        dateRange,
        currentMetrics: metrics,
        evolution,
        historicalComparison,
        comparison: comparison ? {
          overallAccuracy: comparison.accuracy,
          summary: comparison.summary
        } : null,
        dashboard: {
          currentStatus: this.generateCurrentStatus(metrics),
          trends: this.generateTrends(evolution),
          alerts: this.generateAlerts(metrics, evolution, historicalComparison),
          recommendations: this.generateRecommendations(metrics, evolution)
        },
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      throw new Error(`Error generando dashboard: ${error.message}`);
    }
  }

  /**
   * Genera estado actual del modelo
   */
  generateCurrentStatus(metrics) {
    if (!metrics) {
      return {
        status: 'unknown',
        message: 'No hay métricas disponibles'
      };
    }

    const { accuracy, precision, recall, f1Score } = metrics.summary;

    // Determinar estado general
    let status = 'good';
    let message = 'Modelo funcionando correctamente';

    if (f1Score < 0.6) {
      status = 'poor';
      message = 'Modelo requiere mejoras significativas';
    } else if (f1Score < 0.75) {
      status = 'fair';
      message = 'Modelo funcionando pero puede mejorarse';
    }

    return {
      status,
      message,
      metrics: {
        accuracy: parseFloat((accuracy * 100).toFixed(2)),
        precision: parseFloat((precision * 100).toFixed(2)),
        recall: parseFloat((recall * 100).toFixed(2)),
        f1Score: parseFloat((f1Score * 100).toFixed(2))
      },
      grade: this.calculateGrade(f1Score)
    };
  }

  /**
   * Calcula calificación del modelo
   */
  calculateGrade(f1Score) {
    if (f1Score >= 0.9) return 'A';
    if (f1Score >= 0.8) return 'B';
    if (f1Score >= 0.7) return 'C';
    if (f1Score >= 0.6) return 'D';
    return 'F';
  }

  /**
   * Genera tendencias
   */
  generateTrends(evolution) {
    if (!evolution) {
      return null;
    }

    return {
      accuracy: evolution.evolutions.accuracy?.statistics.trend || 'stable',
      precision: evolution.evolutions.precision?.statistics.trend || 'stable',
      recall: evolution.evolutions.recall?.statistics.trend || 'stable',
      f1Score: evolution.evolutions.f1Score?.statistics.trend || 'stable',
      overallTrend: this.calculateOverallTrend(evolution)
    };
  }

  /**
   * Calcula tendencia general
   */
  calculateOverallTrend(evolution) {
    const trends = [
      evolution.evolutions.accuracy?.statistics.trend,
      evolution.evolutions.precision?.statistics.trend,
      evolution.evolutions.recall?.statistics.trend,
      evolution.evolutions.f1Score?.statistics.trend
    ].filter(t => t);

    if (trends.length === 0) return 'stable';

    const improving = trends.filter(t => t === 'improving').length;
    const degrading = trends.filter(t => t === 'degrading').length;

    if (improving > degrading) return 'improving';
    if (degrading > improving) return 'degrading';
    return 'stable';
  }

  /**
   * Genera alertas basadas en métricas
   */
  generateAlerts(metrics, evolution, historicalComparison) {
    const alerts = [];

    if (!metrics) return alerts;

    // Alertas de métricas bajas
    if (metrics.summary.f1Score < 0.6) {
      alerts.push({
        level: 'critical',
        type: 'low_performance',
        message: `F1-Score bajo (${(metrics.summary.f1Score * 100).toFixed(1)}%). Se recomienda reentrenar el modelo.`,
        metric: 'f1Score',
        value: metrics.summary.f1Score
      });
    }

    if (metrics.summary.accuracy < 0.7) {
      alerts.push({
        level: 'warning',
        type: 'low_accuracy',
        message: `Accuracy bajo (${(metrics.summary.accuracy * 100).toFixed(1)}%). Revisar calidad del modelo.`,
        metric: 'accuracy',
        value: metrics.summary.accuracy
      });
    }

    // Alertas de degradación
    if (historicalComparison) {
      Object.keys(historicalComparison).forEach(metricName => {
        const comp = historicalComparison[metricName];
        if (comp.changePercentage < -10) {
          alerts.push({
            level: 'warning',
            type: 'degradation',
            message: `${metricName} ha disminuido ${Math.abs(comp.changePercentage).toFixed(1)}% comparado con el promedio histórico.`,
            metric: metricName,
            change: comp.changePercentage
          });
        }
      });
    }

    // Alertas de desbalance
    if (metrics.summary) {
      const precisionRecallDiff = Math.abs(metrics.summary.precision - metrics.summary.recall);
      if (precisionRecallDiff > 0.2) {
        alerts.push({
          level: 'info',
          type: 'imbalance',
          message: `Hay desbalance entre precisión y recall (diferencia: ${(precisionRecallDiff * 100).toFixed(1)}%).`,
          metric: 'precision_recall',
          difference: precisionRecallDiff
        });
      }
    }

    return alerts.sort((a, b) => {
      const levelOrder = { critical: 1, warning: 2, info: 3 };
      return levelOrder[a.level] - levelOrder[b.level];
    });
  }

  /**
   * Genera recomendaciones
   */
  generateRecommendations(metrics, evolution) {
    const recommendations = [];

    if (!metrics) return recommendations;

    // Recomendaciones basadas en métricas actuales
    if (metrics.summary.f1Score < 0.7) {
      recommendations.push({
        priority: 'high',
        category: 'model_improvement',
        title: 'Mejorar Modelo',
        description: 'El F1-Score está por debajo del umbral recomendado. Considerar reentrenar con más datos o ajustar hiperparámetros.',
        action: 'Reentrenar modelo con dataset actualizado'
      });
    }

    if (metrics.summary.precision < metrics.summary.recall) {
      recommendations.push({
        priority: 'medium',
        category: 'tuning',
        title: 'Reducir Falsos Positivos',
        description: 'La precisión es menor que el recall. El modelo está generando muchos falsos positivos.',
        action: 'Ajustar threshold o mejorar características del modelo'
      });
    }

    if (metrics.summary.recall < metrics.summary.precision) {
      recommendations.push({
        priority: 'medium',
        category: 'tuning',
        title: 'Reducir Falsos Negativos',
        description: 'El recall es menor que la precisión. El modelo está perdiendo casos positivos.',
        action: 'Reducir threshold o mejorar capacidad de detección del modelo'
      });
    }

    // Recomendaciones basadas en evolución
    if (evolution) {
      const f1Trend = evolution.evolutions.f1Score?.statistics.trend;
      if (f1Trend === 'degrading') {
        recommendations.push({
          priority: 'high',
          category: 'monitoring',
          title: 'Tendencia Degradante Detectada',
          description: 'El F1-Score muestra una tendencia a la baja. Investigar causas y considerar reentrenamiento.',
          action: 'Analizar datos recientes y retrainar modelo'
        });
      }
    }

    return recommendations.sort((a, b) => {
      const priorityOrder = { high: 1, medium: 2, low: 3 };
      return priorityOrder[a.priority] - priorityOrder[b.priority];
    });
  }

  /**
   * Obtiene resumen rápido del dashboard
   */
  async getQuickSummary(days = 7) {
    try {
      const dateRange = { days };
      const dashboard = await this.generateDashboard(dateRange, {
        includeEvolution: true,
        evolutionDays: 30,
        includeComparison: true,
        includeDetailedMetrics: true
      });

      return {
        status: dashboard.dashboard.currentStatus,
        keyMetrics: dashboard.currentMetrics?.summary || {},
        trends: dashboard.dashboard.trends,
        alertsCount: dashboard.dashboard.alerts.length,
        recommendationsCount: dashboard.dashboard.recommendations.length,
        timestamp: dashboard.timestamp
      };
    } catch (error) {
      throw new Error(`Error obteniendo resumen rápido: ${error.message}`);
    }
  }
}

module.exports = MLMonitoringDashboard;

