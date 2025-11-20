/**
 * Sistema de Alertas de Congestión
 * Detecta y alerta sobre congestión prevista basándose en predicciones ML
 * US040 - Alertas congestión
 */

const PeakHoursPredictor = require('./peak_hours_predictor');

class CongestionAlertSystem {
  constructor(AsistenciaModel) {
    this.predictor = new PeakHoursPredictor(null, AsistenciaModel);
    this.thresholds = {
      low: 50,      // Alerta baja: >50 accesos/hora
      medium: 100,  // Alerta media: >100 accesos/hora
      high: 150,    // Alerta alta: >150 accesos/hora
      critical: 200 // Alerta crítica: >200 accesos/hora
    };
    this.config = {
      enabled: true,
      notificationChannels: ['dashboard', 'email'], // dashboard, email, sms, push
      alertWindow: 24, // horas de anticipación
      checkInterval: 60 // minutos entre checks
    };
    this.alertHistory = [];
  }

  /**
   * Configura thresholds personalizados
   */
  configureThresholds(thresholds) {
    this.thresholds = { ...this.thresholds, ...thresholds };
    return {
      success: true,
      thresholds: this.thresholds
    };
  }

  /**
   * Configura sistema de alertas
   */
  configure(config) {
    this.config = { ...this.config, ...config };
    return {
      success: true,
      config: this.config
    };
  }

  /**
   * Verifica y genera alertas de congestión
   */
  async checkCongestionAlerts(dateRange = null, options = {}) {
    const {
      lookAheadHours = this.config.alertWindow,
      includeHistorical = true
    } = options;

    try {
      // Obtener predicciones
      await this.predictor.loadLatestModel();
      
      if (!dateRange) {
        const now = new Date();
        const endDate = new Date(now);
        endDate.setHours(endDate.getHours() + lookAheadHours);
        dateRange = {
          startDate: now.toISOString(),
          endDate: endDate.toISOString()
        };
      }

      const predictions = await this.predictor.predictPeakHours(dateRange);

      // Analizar predicciones y generar alertas
      const alerts = this.analyzePredictions(predictions.predictions);

      // Agregar contexto histórico si está habilitado
      if (includeHistorical) {
        alerts.forEach(alert => {
          alert.historicalContext = this.getHistoricalContext(alert);
        });
      }

      // Filtrar alertas según configuración
      const activeAlerts = alerts.filter(alert => 
        this.shouldTriggerAlert(alert)
      );

      // Guardar en historial
      if (activeAlerts.length > 0) {
        this.alertHistory.push({
          timestamp: new Date(),
          alerts: activeAlerts,
          totalAlerts: activeAlerts.length
        });
      }

      return {
        success: true,
        dateRange: predictions.dateRange,
        alerts: activeAlerts,
        summary: this.generateAlertSummary(activeAlerts),
        thresholds: this.thresholds,
        timestamp: new Date()
      };
    } catch (error) {
      throw new Error(`Error verificando alertas de congestión: ${error.message}`);
    }
  }

  /**
   * Analiza predicciones y genera alertas
   */
  analyzePredictions(predictions) {
    const alerts = [];

    predictions.forEach(prediction => {
      const level = this.getAlertLevel(prediction.predictedTotal);
      
      if (level !== 'none') {
        alerts.push({
          id: `alert_${Date.now()}_${prediction.hora}`,
          level: level,
          timestamp: prediction.timestamp,
          fecha: prediction.fecha,
          hora: prediction.hora,
          predictedTotal: prediction.predictedTotal,
          predictedEntrance: prediction.predictedEntrance,
          predictedExit: prediction.predictedExit,
          confidence: prediction.confidence,
          threshold: this.thresholds[level],
          message: this.generateAlertMessage(prediction, level),
          recommendations: this.generateRecommendations(prediction, level)
        });
      }
    });

    return alerts.sort((a, b) => {
      const levelOrder = { critical: 4, high: 3, medium: 2, low: 1, none: 0 };
      return levelOrder[b.level] - levelOrder[a.level];
    });
  }

  /**
   * Determina nivel de alerta basado en predicción
   */
  getAlertLevel(predictedTotal) {
    if (predictedTotal >= this.thresholds.critical) return 'critical';
    if (predictedTotal >= this.thresholds.high) return 'high';
    if (predictedTotal >= this.thresholds.medium) return 'medium';
    if (predictedTotal >= this.thresholds.low) return 'low';
    return 'none';
  }

  /**
   * Genera mensaje de alerta
   */
  generateAlertMessage(prediction, level) {
    const levelMessages = {
      critical: 'CONGESTIÓN CRÍTICA',
      high: 'ALTA CONGESTIÓN',
      medium: 'CONGESTIÓN MODERADA',
      low: 'CONGESTIÓN LEVE'
    };

    return `${levelMessages[level]} prevista para ${prediction.fecha} a las ${prediction.hora}:00. ` +
           `Se esperan ${prediction.predictedTotal} accesos (${prediction.predictedEntrance} entradas, ${prediction.predictedExit} salidas). ` +
           `Confianza: ${(prediction.confidence * 100).toFixed(1)}%`;
  }

  /**
   * Genera recomendaciones basadas en alerta
   */
  generateRecommendations(prediction, level) {
    const recommendations = [];

    if (level === 'critical' || level === 'high') {
      recommendations.push({
        type: 'RESOURCE_ALLOCATION',
        priority: 'HIGH',
        action: 'Aumentar personal de guardias en puntos de control',
        description: 'Asignar guardias adicionales para manejar la alta demanda'
      });

      recommendations.push({
        type: 'SCHEDULE_OPTIMIZATION',
        priority: 'HIGH',
        action: 'Optimizar horarios de buses',
        description: 'Ajustar frecuencia de buses para reducir congestión'
      });
    }

    if (level === 'medium') {
      recommendations.push({
        type: 'MONITORING',
        priority: 'MEDIUM',
        action: 'Monitorear de cerca la situación',
        description: 'Estar preparado para escalar recursos si es necesario'
      });
    }

    recommendations.push({
      type: 'NOTIFICATION',
      priority: 'LOW',
      action: 'Notificar a estudiantes sobre horarios pico',
      description: 'Comunicar horarios pico esperados para distribuir carga'
    });

    return recommendations;
  }

  /**
   * Obtiene contexto histórico para una alerta
   */
  getHistoricalContext(alert) {
    // Buscar alertas similares en el historial
    const similarAlerts = this.alertHistory
      .flatMap(entry => entry.alerts)
      .filter(a => 
        a.hora === alert.hora && 
        a.level === alert.level &&
        new Date(a.timestamp) > new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) // Últimos 7 días
      );

    return {
      similarAlertsCount: similarAlerts.length,
      lastSimilarAlert: similarAlerts.length > 0 
        ? similarAlerts[similarAlerts.length - 1].timestamp 
        : null,
      frequency: similarAlerts.length > 0 
        ? `${similarAlerts.length} veces en los últimos 7 días`
        : 'Primera vez'
    };
  }

  /**
   * Determina si una alerta debe ser activada
   */
  shouldTriggerAlert(alert) {
    // Filtrar según configuración
    if (!this.config.enabled) return false;
    
    // Solo alertas de nivel medio o superior por defecto
    const levelOrder = { critical: 4, high: 3, medium: 2, low: 1 };
    return levelOrder[alert.level] >= 2;
  }

  /**
   * Genera resumen de alertas
   */
  generateAlertSummary(alerts) {
    const summary = {
      total: alerts.length,
      byLevel: {
        critical: alerts.filter(a => a.level === 'critical').length,
        high: alerts.filter(a => a.level === 'high').length,
        medium: alerts.filter(a => a.level === 'medium').length,
        low: alerts.filter(a => a.level === 'low').length
      },
      nextAlert: alerts.length > 0 ? alerts[0] : null,
      peakTime: this.findPeakTime(alerts)
    };

    return summary;
  }

  /**
   * Encuentra hora pico de las alertas
   */
  findPeakTime(alerts) {
    if (alerts.length === 0) return null;

    const hourCounts = {};
    alerts.forEach(alert => {
      hourCounts[alert.hora] = (hourCounts[alert.hora] || 0) + alert.predictedTotal;
    });

    const peakHour = Object.entries(hourCounts)
      .sort((a, b) => b[1] - a[1])[0];

    return peakHour 
      ? { hour: parseInt(peakHour[0]), totalAccess: peakHour[1] }
      : null;
  }

  /**
   * Obtiene historial de alertas
   */
  getAlertHistory(limit = 50) {
    return {
      history: this.alertHistory.slice(-limit),
      total: this.alertHistory.length,
      recentAlerts: this.alertHistory
        .flatMap(entry => entry.alerts)
        .slice(-limit)
    };
  }

  /**
   * Limpia historial de alertas
   */
  clearAlertHistory(daysToKeep = 30) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);

    this.alertHistory = this.alertHistory.filter(
      entry => new Date(entry.timestamp) > cutoffDate
    );

    return {
      success: true,
      remainingEntries: this.alertHistory.length
    };
  }
}

module.exports = CongestionAlertSystem;

