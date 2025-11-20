/**
 * Sistema de Alertas de Congestión
 * Sistema automático de alertas con thresholds configurables
 * Adaptado para el proyecto principal Acees_Group
 */

const fs = require('fs').promises;
const path = require('path');

class CongestionAlertSystem {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.alertsDir = path.join(__dirname, 'data/alerts');
    this.configPath = path.join(this.alertsDir, 'alert_config.json');
    this.historyPath = path.join(this.alertsDir, 'alert_history.json');
    
    // Configuración por defecto de thresholds
    this.defaultConfig = {
      thresholds: {
        low: 50,      // >50 accesos/hora
        medium: 100,  // >100 accesos/hora
        high: 150,    // >150 accesos/hora
        critical: 200 // >200 accesos/hora
      },
      notifications: {
        dashboard: true,
        email: false, // Simplificado para este proyecto
        console: true
      },
      monitoring: {
        enabled: true,
        checkIntervalMinutes: 15,
        historicalContextHours: 24
      }
    };
    
    this.currentConfig = { ...this.defaultConfig };
    this.alertHistory = [];
  }

  /**
   * Inicializa el sistema de alertas
   */
  async initialize() {
    try {
      await fs.mkdir(this.alertsDir, { recursive: true });
      await this.loadConfiguration();
      await this.loadAlertHistory();
      console.log('🚨 Sistema de alertas de congestión inicializado');
    } catch (error) {
      console.error('❌ Error inicializando sistema de alertas:', error.message);
    }
  }

  /**
   * Configura thresholds de alerta
   */
  async configureThresholds(newThresholds) {
    try {
      this.currentConfig.thresholds = { ...this.currentConfig.thresholds, ...newThresholds };
      await this.saveConfiguration();
      
      console.log('⚙️ Thresholds actualizados:', this.currentConfig.thresholds);
      
      return {
        success: true,
        message: 'Thresholds configurados correctamente',
        currentThresholds: this.currentConfig.thresholds
      };
    } catch (error) {
      throw new Error(`Error configurando thresholds: ${error.message}`);
    }
  }

  /**
   * Verifica congestión actual y genera alertas si es necesario
   */
  async checkAndGenerateAlerts() {
    try {
      console.log('🔍 Verificando niveles de congestión...');

      const currentHour = new Date().getHours();
      const congestionData = await this.getCurrentCongestionLevels();
      
      const alerts = [];
      
      // Verificar cada puerta y tipo de acceso
      for (const location of congestionData.locations) {
        const alertLevel = this.determineAlertLevel(location.count);
        
        if (alertLevel !== 'normal') {
          const alert = await this.createAlert(location, alertLevel, congestionData.context);
          alerts.push(alert);
          
          // Enviar notificación
          await this.sendNotification(alert);
        }
      }

      // Guardar alertas en historial
      if (alerts.length > 0) {
        await this.saveAlertsToHistory(alerts);
      }

      return {
        success: true,
        alertsGenerated: alerts.length,
        alerts: alerts,
        congestionSummary: {
          totalAccesses: congestionData.total,
          peakLocation: congestionData.peakLocation,
          averagePerHour: congestionData.averagePerHour
        },
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error('❌ Error verificando congestión:', error.message);
      throw new Error(`Error verificando congestión: ${error.message}`);
    }
  }

  /**
   * Obtiene niveles actuales de congestión
   */
  async getCurrentCongestionLevels() {
    try {
      const now = new Date();
      const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
      
      // Congestión por ubicación en la última hora
      const locationCongestion = await this.Asistencia.aggregate([
        {
          $match: {
            fecha_hora: { $gte: oneHourAgo, $lte: now }
          }
        },
        {
          $group: {
            _id: {
              puerta: '$puerta',
              tipo: '$tipo'
            },
            count: { $sum: 1 },
            facultades: { $addToSet: '$siglas_facultad' },
            lastAccess: { $max: '$fecha_hora' }
          }
        },
        {
          $sort: { count: -1 }
        }
      ]);

      // Contexto histórico (últimas 24 horas)
      const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      const historicalData = await this.Asistencia.aggregate([
        {
          $match: {
            fecha_hora: { $gte: oneDayAgo, $lte: now }
          }
        },
        {
          $group: {
            _id: {
              hour: { $hour: '$fecha_hora' },
              tipo: '$tipo'
            },
            avgCount: { $avg: 1 },
            totalCount: { $sum: 1 }
          }
        }
      ]);

      const totalAccesses = locationCongestion.reduce((sum, loc) => sum + loc.count, 0);
      const peakLocation = locationCongestion[0] || null;
      
      return {
        total: totalAccesses,
        locations: locationCongestion.map(loc => ({
          puerta: loc._id.puerta,
          tipo: loc._id.tipo,
          count: loc.count,
          facultades: loc.facultades,
          lastAccess: loc.lastAccess,
          location: `${loc._id.puerta}_${loc._id.tipo}`
        })),
        peakLocation: peakLocation,
        averagePerHour: totalAccesses,
        context: {
          historical: historicalData,
          timeRange: { from: oneHourAgo, to: now }
        }
      };
    } catch (error) {
      throw new Error(`Error obteniendo datos de congestión: ${error.message}`);
    }
  }

  /**
   * Determina nivel de alerta basado en el conteo
   */
  determineAlertLevel(count) {
    const thresholds = this.currentConfig.thresholds;
    
    if (count >= thresholds.critical) return 'critical';
    if (count >= thresholds.high) return 'high';
    if (count >= thresholds.medium) return 'medium';
    if (count >= thresholds.low) return 'low';
    
    return 'normal';
  }

  /**
   * Crea objeto de alerta
   */
  async createAlert(location, level, context) {
    const now = new Date();
    
    return {
      id: `alert_${now.getTime()}_${Math.random().toString(36).substr(2, 9)}`,
      timestamp: now.toISOString(),
      level: level,
      location: {
        puerta: location.puerta,
        tipo: location.tipo,
        description: `${location.puerta} - ${location.tipo}`
      },
      metrics: {
        currentCount: location.count,
        threshold: this.currentConfig.thresholds[level],
        facultadesInvolucradas: location.facultades,
        lastAccess: location.lastAccess
      },
      message: this.generateAlertMessage(location, level),
      severity: this.getSeverityScore(level),
      recommendations: this.generateRecommendations(location, level),
      context: {
        timeWindow: '1 hora',
        historicalComparison: await this.getHistoricalComparison(location, context)
      }
    };
  }

  /**
   * Genera mensaje de alerta
   */
  generateAlertMessage(location, level) {
    const messages = {
      low: `Congestión moderada detectada en ${location.puerta} (${location.tipo}): ${location.count} accesos en la última hora`,
      medium: `Congestión significativa en ${location.puerta} (${location.tipo}): ${location.count} accesos/hora - Monitorear de cerca`,
      high: `¡ALTA congestión en ${location.puerta} (${location.tipo})! ${location.count} accesos/hora - Considerar medidas preventivas`,
      critical: `🚨 CONGESTIÓN CRÍTICA en ${location.puerta} (${location.tipo}): ${location.count} accesos/hora - ¡ACCIÓN INMEDIATA REQUERIDA!`
    };
    
    return messages[level] || 'Nivel de congestión desconocido';
  }

  /**
   * Obtiene puntuación de severidad
   */
  getSeverityScore(level) {
    const scores = { low: 1, medium: 2, high: 3, critical: 4 };
    return scores[level] || 0;
  }

  /**
   * Genera recomendaciones basadas en el nivel de alerta
   */
  generateRecommendations(location, level) {
    const baseRecommendations = {
      low: [
        'Monitorear tendencia en las próximas horas',
        'Preparar personal adicional si es necesario'
      ],
      medium: [
        'Aumentar frecuencia de monitoreo',
        'Considerar apertura de puertas adicionales',
        'Notificar a personal de seguridad'
      ],
      high: [
        'Implementar control de flujo',
        'Abrir todas las puertas disponibles',
        'Asignar personal adicional de inmediato',
        'Comunicar a estudiantes sobre congestión'
      ],
      critical: [
        '🚨 ACTIVAR PROTOCOLO DE EMERGENCIA',
        'Abrir todas las salidas de emergencia si es necesario',
        'Coordinar con seguridad universitaria',
        'Implementar desvío de tráfico estudiantil',
        'Comunicación masiva inmediata'
      ]
    };

    const recommendations = [...baseRecommendations[level]];
    
    // Recomendaciones específicas por ubicación
    if (location.puerta === 'fafing' && level >= 'medium') {
      recommendations.push('Considerar usar entrada principal como alternativa');
    }
    
    if (location.tipo === 'entrada' && level >= 'high') {
      recommendations.push('Implementar sistema de citas o horarios escalonados');
    }

    return recommendations;
  }

  /**
   * Obtiene comparación histórica
   */
  async getHistoricalComparison(location, context) {
    try {
      const currentHour = new Date().getHours();
      const currentDay = new Date().getDay();
      
      // Buscar datos históricos de la misma hora y día de la semana
      const historicalAvg = context.historical.find(h => 
        h._id.hour === currentHour && h._id.tipo === location.tipo
      );

      if (historicalAvg) {
        const comparison = location.count / historicalAvg.avgCount;
        return {
          historicalAverage: Math.round(historicalAvg.avgCount),
          currentVsHistorical: `${(comparison * 100).toFixed(0)}%`,
          trend: comparison > 1.5 ? 'Muy por encima del promedio' :
                comparison > 1.2 ? 'Por encima del promedio' :
                comparison < 0.8 ? 'Por debajo del promedio' : 'Normal'
        };
      }

      return {
        historicalAverage: 'No disponible',
        currentVsHistorical: 'N/A',
        trend: 'Sin datos históricos suficientes'
      };
    } catch (error) {
      return {
        historicalAverage: 'Error',
        currentVsHistorical: 'N/A',
        trend: 'Error obteniendo comparación'
      };
    }
  }

  /**
   * Envía notificación de alerta
   */
  async sendNotification(alert) {
    try {
      if (this.currentConfig.notifications.console) {
        this.logAlertToConsole(alert);
      }

      if (this.currentConfig.notifications.dashboard) {
        // Placeholder para integración con dashboard
        console.log(`📊 [DASHBOARD] Alerta enviada: ${alert.level.toUpperCase()}`);
      }

      // Aquí se pueden agregar más canales de notificación (email, SMS, etc.)
      
    } catch (error) {
      console.error('❌ Error enviando notificación:', error.message);
    }
  }

  /**
   * Registra alerta en consola
   */
  logAlertToConsole(alert) {
    const emoji = {
      low: '🟡',
      medium: '🟠', 
      high: '🔴',
      critical: '🚨'
    };

    console.log(`\\n${emoji[alert.level]} ===== ALERTA DE CONGESTIÓN =====`);
    console.log(`Nivel: ${alert.level.toUpperCase()}`);
    console.log(`Ubicación: ${alert.location.description}`);
    console.log(`Mensaje: ${alert.message}`);
    console.log(`Hora: ${alert.timestamp}`);
    console.log(`Recomendaciones:`);
    alert.recommendations.forEach(rec => console.log(`  • ${rec}`));
    console.log(`=====================================\\n`);
  }

  /**
   * Guarda alertas en historial
   */
  async saveAlertsToHistory(alerts) {
    try {
      this.alertHistory.push(...alerts);
      
      // Mantener solo las últimas 1000 alertas
      if (this.alertHistory.length > 1000) {
        this.alertHistory = this.alertHistory.slice(-1000);
      }
      
      await fs.writeFile(this.historyPath, JSON.stringify(this.alertHistory, null, 2));
    } catch (error) {
      console.error('❌ Error guardando historial de alertas:', error.message);
    }
  }

  /**
   * Obtiene historial de alertas
   */
  async getAlertHistory(options = {}) {
    const { limit = 50, level = null, hours = 24 } = options;
    
    try {
      let filteredHistory = [...this.alertHistory];
      
      // Filtrar por nivel si se especifica
      if (level) {
        filteredHistory = filteredHistory.filter(alert => alert.level === level);
      }
      
      // Filtrar por tiempo
      const cutoffTime = new Date(Date.now() - hours * 60 * 60 * 1000);
      filteredHistory = filteredHistory.filter(alert => 
        new Date(alert.timestamp) >= cutoffTime
      );
      
      // Ordenar por timestamp descendente y limitar
      filteredHistory.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
      filteredHistory = filteredHistory.slice(0, limit);
      
      return {
        success: true,
        alerts: filteredHistory,
        total: filteredHistory.length,
        summary: this.generateHistorySummary(filteredHistory)
      };
    } catch (error) {
      throw new Error(`Error obteniendo historial: ${error.message}`);
    }
  }

  /**
   * Genera resumen del historial
   */
  generateHistorySummary(history) {
    const summary = {
      total: history.length,
      byLevel: { low: 0, medium: 0, high: 0, critical: 0 },
      byLocation: {},
      lastAlert: history[0]?.timestamp || null
    };
    
    history.forEach(alert => {
      summary.byLevel[alert.level]++;
      
      const location = alert.location.description;
      summary.byLocation[location] = (summary.byLocation[location] || 0) + 1;
    });
    
    return summary;
  }

  /**
   * Limpia historial de alertas
   */
  async clearAlertHistory() {
    try {
      this.alertHistory = [];
      await fs.writeFile(this.historyPath, JSON.stringify([], null, 2));
      
      return {
        success: true,
        message: 'Historial de alertas limpiado correctamente'
      };
    } catch (error) {
      throw new Error(`Error limpiando historial: ${error.message}`);
    }
  }

  /**
   * Carga configuración guardada
   */
  async loadConfiguration() {
    try {
      const data = await fs.readFile(this.configPath, 'utf8');
      this.currentConfig = JSON.parse(data);
    } catch (error) {
      // Si no existe, usar configuración por defecto
      this.currentConfig = { ...this.defaultConfig };
      await this.saveConfiguration();
    }
  }

  /**
   * Guarda configuración actual
   */
  async saveConfiguration() {
    try {
      await fs.writeFile(this.configPath, JSON.stringify(this.currentConfig, null, 2));
    } catch (error) {
      console.error('❌ Error guardando configuración:', error.message);
    }
  }

  /**
   * Carga historial de alertas guardado
   */
  async loadAlertHistory() {
    try {
      const data = await fs.readFile(this.historyPath, 'utf8');
      this.alertHistory = JSON.parse(data);
    } catch (error) {
      // Si no existe, inicializar vacío
      this.alertHistory = [];
    }
  }
}

module.exports = CongestionAlertSystem;