/**
 * Servicio de Evolución Temporal de Métricas ML
 * Almacena y recupera métricas históricas para análisis temporal
 */

const fs = require('fs').promises;
const path = require('path');

class TemporalMetricsEvolution {
  constructor() {
    this.metricsDir = path.join(__dirname, '../data/metrics_history');
    this.ensureMetricsDir();
  }

  /**
   * Asegura que el directorio de métricas existe
   */
  async ensureMetricsDir() {
    try {
      await fs.mkdir(this.metricsDir, { recursive: true });
    } catch (error) {
      console.error('Error creando directorio de métricas:', error);
    }
  }

  /**
   * Guarda métricas para un período específico
   */
  async saveMetrics(metrics, dateRange, modelInfo = {}) {
    try {
      const metricRecord = {
        id: `metrics_${Date.now()}`,
        timestamp: new Date().toISOString(),
        dateRange: {
          startDate: dateRange.startDate,
          endDate: dateRange.endDate
        },
        modelInfo: {
          modelType: modelInfo.modelType || 'unknown',
          modelVersion: modelInfo.version || '1.0.0',
          modelPath: modelInfo.modelPath || null
        },
        metrics: {
          overall: metrics.overall || metrics,
          byHour: metrics.byHour || {},
          byDay: metrics.byDay || {}
        },
        summary: metrics.summary || this.extractSummary(metrics)
      };

      const filename = `metrics_${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
      const filepath = path.join(this.metricsDir, filename);

      await fs.writeFile(filepath, JSON.stringify(metricRecord, null, 2));

      return {
        success: true,
        filepath,
        id: metricRecord.id
      };
    } catch (error) {
      throw new Error(`Error guardando métricas: ${error.message}`);
    }
  }

  /**
   * Extrae resumen de métricas
   */
  extractSummary(metrics) {
    const overall = metrics.overall || metrics;
    return {
      accuracy: overall.metrics?.accuracy || overall.accuracy || 0,
      precision: overall.metrics?.precision || overall.precision || 0,
      recall: overall.metrics?.recall || overall.recall || 0,
      f1Score: overall.metrics?.f1Score || overall.f1Score || 0
    };
  }

  /**
   * Obtiene todas las métricas históricas
   */
  async getAllMetricsHistory(limit = 100) {
    try {
      const files = await fs.readdir(this.metricsDir);
      const jsonFiles = files.filter(f => f.endsWith('.json')).sort().reverse();

      const metricsHistory = [];
      for (const file of jsonFiles.slice(0, limit)) {
        try {
          const filepath = path.join(this.metricsDir, file);
          const content = await fs.readFile(filepath, 'utf8');
          const metricData = JSON.parse(content);
          metricsHistory.push(metricData);
        } catch (error) {
          console.warn(`Error leyendo archivo ${file}:`, error.message);
        }
      }

      return metricsHistory.sort((a, b) => 
        new Date(b.timestamp) - new Date(a.timestamp)
      );
    } catch (error) {
      if (error.code === 'ENOENT') {
        return [];
      }
      throw new Error(`Error obteniendo historial de métricas: ${error.message}`);
    }
  }

  /**
   * Obtiene evolución temporal de una métrica específica
   */
  async getMetricEvolution(metricName = 'f1Score', days = 30) {
    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - days);

      const allMetrics = await this.getAllMetricsHistory(1000);
      
      const evolution = allMetrics
        .filter(m => new Date(m.timestamp) >= cutoffDate)
        .map(m => {
          const summary = m.summary || this.extractSummary(m.metrics);
          return {
            timestamp: m.timestamp,
            date: m.dateRange?.startDate || m.timestamp,
            value: summary[metricName] || 0,
            metrics: summary
          };
        })
        .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

      return {
        metricName,
        period: days,
        dataPoints: evolution.length,
        evolution,
        statistics: this.calculateEvolutionStatistics(evolution.map(e => e.value))
      };
    } catch (error) {
      throw new Error(`Error obteniendo evolución de métrica: ${error.message}`);
    }
  }

  /**
   * Calcula estadísticas de evolución
   */
  calculateEvolutionStatistics(values) {
    if (values.length === 0) {
      return {
        mean: 0,
        median: 0,
        stdDeviation: 0,
        min: 0,
        max: 0,
        trend: 'stable'
      };
    }

    const mean = values.reduce((sum, v) => sum + v, 0) / values.length;
    const sorted = [...values].sort((a, b) => a - b);
    const median = sorted.length % 2 === 0
      ? (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2
      : sorted[Math.floor(sorted.length / 2)];

    const variance = values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length;
    const stdDeviation = Math.sqrt(variance);

    // Determinar tendencia
    const firstHalf = values.slice(0, Math.floor(values.length / 2));
    const secondHalf = values.slice(Math.floor(values.length / 2));
    const firstHalfMean = firstHalf.reduce((sum, v) => sum + v, 0) / firstHalf.length;
    const secondHalfMean = secondHalf.reduce((sum, v) => sum + v, 0) / secondHalf.length;
    
    const change = ((secondHalfMean - firstHalfMean) / firstHalfMean) * 100;
    let trend = 'stable';
    if (change > 5) trend = 'improving';
    else if (change < -5) trend = 'degrading';

    return {
      mean: parseFloat(mean.toFixed(4)),
      median: parseFloat(median.toFixed(4)),
      stdDeviation: parseFloat(stdDeviation.toFixed(4)),
      min: Math.min(...values),
      max: Math.max(...values),
      trend,
      changePercentage: parseFloat(change.toFixed(2))
    };
  }

  /**
   * Obtiene evolución de múltiples métricas
   */
  async getMultipleMetricsEvolution(metricNames = ['accuracy', 'precision', 'recall', 'f1Score'], days = 30) {
    const evolutions = {};

    for (const metricName of metricNames) {
      try {
        evolutions[metricName] = await this.getMetricEvolution(metricName, days);
      } catch (error) {
        console.warn(`Error obteniendo evolución de ${metricName}:`, error.message);
        evolutions[metricName] = null;
      }
    }

    return evolutions;
  }

  /**
   * Obtiene última métrica guardada
   */
  async getLatestMetrics() {
    try {
      const history = await this.getAllMetricsHistory(1);
      return history.length > 0 ? history[0] : null;
    } catch (error) {
      throw new Error(`Error obteniendo última métrica: ${error.message}`);
    }
  }

  /**
   * Compara métricas actuales con históricas
   */
  async compareWithHistory(currentMetrics, days = 30) {
    try {
      const historicalMetrics = await this.getMultipleMetricsEvolution(
        ['accuracy', 'precision', 'recall', 'f1Score'],
        days
      );

      const currentSummary = currentMetrics.summary || this.extractSummary(currentMetrics);

      const comparison = {};
      Object.keys(historicalMetrics).forEach(metricName => {
        const evolution = historicalMetrics[metricName];
        if (evolution && evolution.evolution.length > 0) {
          const historicalAvg = evolution.statistics.mean;
          const currentValue = currentSummary[metricName] || 0;
          const change = currentValue - historicalAvg;
          const changePercentage = historicalAvg > 0 
            ? (change / historicalAvg) * 100 
            : 0;

          comparison[metricName] = {
            current: currentValue,
            historicalAverage: historicalAvg,
            change: parseFloat(change.toFixed(4)),
            changePercentage: parseFloat(changePercentage.toFixed(2)),
            trend: change > 0 ? 'improving' : change < 0 ? 'degrading' : 'stable'
          };
        }
      });

      return comparison;
    } catch (error) {
      throw new Error(`Error comparando con historial: ${error.message}`);
    }
  }

  /**
   * Genera reporte de evolución temporal
   */
  async generateEvolutionReport(days = 30) {
    try {
      const evolutions = await this.getMultipleMetricsEvolution(
        ['accuracy', 'precision', 'recall', 'f1Score'],
        days
      );

      const latest = await this.getLatestMetrics();

      return {
        period: days,
        evolutions,
        latestMetrics: latest,
        summary: {
          averageAccuracy: evolutions.accuracy?.statistics.mean || 0,
          averagePrecision: evolutions.precision?.statistics.mean || 0,
          averageRecall: evolutions.recall?.statistics.mean || 0,
          averageF1Score: evolutions.f1Score?.statistics.mean || 0,
          trends: {
            accuracy: evolutions.accuracy?.statistics.trend || 'stable',
            precision: evolutions.precision?.statistics.trend || 'stable',
            recall: evolutions.recall?.statistics.trend || 'stable',
            f1Score: evolutions.f1Score?.statistics.trend || 'stable'
          }
        },
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      throw new Error(`Error generando reporte de evolución: ${error.message}`);
    }
  }
}

module.exports = TemporalMetricsEvolution;

