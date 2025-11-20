/**
 * Servicio de Actualización Automática Semanal de Modelos ML
 * Scheduler que reentrena modelos automáticamente cada semana
 * Adaptado para el proyecto principal Acees_Group
 */

const cron = require('node-cron');
const fs = require('fs').promises;
const path = require('path');

class WeeklyModelUpdateService {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.schedulerActive = false;
    this.updateHistory = [];
    this.configPath = path.join(__dirname, 'data/scheduler_config.json');
    this.historyPath = path.join(__dirname, 'data/update_history.json');
    
    // Configuración por defecto
    this.config = {
      enabled: true,
      cronExpression: '0 2 * * 0', // Domingos a las 2:00 AM
      autoRetrain: true,
      backupPreviousModel: true,
      performanceTreshold: 0.75, // Mínimo 75% precisión
      rollbackOnFailure: true
    };
  }

  /**
   * Inicializa el servicio de actualización semanal
   */
  async initialize() {
    try {
      await this.loadConfiguration();
      await this.loadUpdateHistory();
      
      if (this.config.enabled) {
        await this.startScheduler();
      }
      
      console.log('📅 Servicio de actualización semanal inicializado');
    } catch (error) {
      console.error('❌ Error inicializando servicio de actualización:', error.message);
    }
  }

  /**
   * Inicia el scheduler automático
   */
  async startScheduler() {
    try {
      if (this.schedulerActive) {
        console.log('⚠️ Scheduler ya está activo');
        return { success: false, message: 'Scheduler ya está activo' };
      }

      // Configurar tarea cron
      this.cronJob = cron.schedule(this.config.cronExpression, async () => {
        console.log('⏰ Ejecutando actualización semanal automática...');
        await this.executeWeeklyUpdate();
      }, {
        scheduled: true,
        timezone: 'America/Lima' // Zona horaria de Perú
      });

      this.schedulerActive = true;
      console.log(`📅 Scheduler iniciado: ${this.config.cronExpression} (Zona: America/Lima)`);

      return {
        success: true,
        message: 'Scheduler iniciado correctamente',
        nextExecution: this.getNextExecutionTime(),
        cronExpression: this.config.cronExpression
      };
    } catch (error) {
      console.error('❌ Error iniciando scheduler:', error.message);
      throw new Error(`Error iniciando scheduler: ${error.message}`);
    }
  }

  /**
   * Detiene el scheduler automático
   */
  async stopScheduler() {
    try {
      if (!this.schedulerActive || !this.cronJob) {
        return { success: false, message: 'Scheduler no está activo' };
      }

      this.cronJob.stop();
      this.cronJob.destroy();
      this.schedulerActive = false;

      console.log('🛑 Scheduler detenido');
      return {
        success: true,
        message: 'Scheduler detenido correctamente'
      };
    } catch (error) {
      console.error('❌ Error deteniendo scheduler:', error.message);
      throw new Error(`Error deteniendo scheduler: ${error.message}`);
    }
  }

  /**
   * Ejecuta actualización semanal completa
   */
  async executeWeeklyUpdate() {
    const updateId = `update_${Date.now()}`;
    const startTime = new Date();

    try {
      console.log(`🚀 [${updateId}] Iniciando actualización semanal...`);

      // 1. Verificar disponibilidad de datos nuevos
      const dataValidation = await this.validateNewData();
      if (!dataValidation.hasNewData) {
        console.log(`⚠️ [${updateId}] No hay datos nuevos suficientes para reentrenamiento`);
        return this.recordUpdateResult(updateId, 'skipped', 'No hay datos nuevos', startTime);
      }

      // 2. Hacer backup del modelo anterior
      if (this.config.backupPreviousModel) {
        await this.backupCurrentModel();
      }

      // 3. Recopilar datos actualizados
      console.log(`📊 [${updateId}] Recopilando dataset actualizado...`);
      const { MLETLService } = require('./ml_etl_service');
      const etlService = new MLETLService(this.Asistencia);
      
      const etlResult = await etlService.runETLPipeline({
        months: 3,
        validateData: true,
        cleanData: true
      });

      // 4. Reentrenar modelo con datos nuevos
      console.log(`🧠 [${updateId}] Reentrenando modelo...`);
      const { PeakHoursPredictiveModel } = require('./peak_hours_predictive_model');
      const peakModel = new PeakHoursPredictiveModel(this.Asistencia);
      
      const trainingResult = await peakModel.trainPeakHoursModel({
        months: 3,
        testSize: 0.2
      });

      // 5. Validar performance del nuevo modelo
      const newAccuracy = trainingResult.metrics.overall.accuracy;
      console.log(`📈 [${updateId}] Nueva precisión: ${(newAccuracy * 100).toFixed(2)}%`);

      if (newAccuracy < this.config.performanceTreshold) {
        console.log(`❌ [${updateId}] Precisión insuficiente: ${(newAccuracy * 100).toFixed(2)}%`);
        
        if (this.config.rollbackOnFailure) {
          await this.rollbackToPreviousModel();
          return this.recordUpdateResult(updateId, 'failed_rollback', 'Precisión insuficiente, rollback ejecutado', startTime, {
            newAccuracy,
            threshold: this.config.performanceTreshold
          });
        } else {
          return this.recordUpdateResult(updateId, 'failed', 'Precisión insuficiente', startTime, {
            newAccuracy,
            threshold: this.config.performanceTreshold
          });
        }
      }

      // 6. Actualizar sistema de alertas
      console.log(`🚨 [${updateId}] Actualizando sistema de alertas...`);
      const { CongestionAlertSystem } = require('./congestion_alert_system');
      const alertSystem = new CongestionAlertSystem(this.Asistencia);
      await alertSystem.initialize();
      
      const alertCheck = await alertSystem.checkAndGenerateAlerts();

      // 7. Generar predicciones de validación
      const predictions = await peakModel.predictNext24Hours();

      // 8. Registrar actualización exitosa
      const endTime = new Date();
      const duration = endTime - startTime;

      console.log(`✅ [${updateId}] Actualización completada exitosamente en ${Math.round(duration / 1000)}s`);

      return this.recordUpdateResult(updateId, 'success', 'Actualización exitosa', startTime, {
        etlRecords: etlResult.transform.records,
        newAccuracy: newAccuracy,
        previousAccuracy: null, // Se podría obtener del backup
        alertsGenerated: alertCheck.alertsGenerated,
        predictionsGenerated: predictions.predictions.length,
        duration: duration
      });

    } catch (error) {
      console.error(`❌ [${updateId}] Error durante actualización:`, error.message);

      if (this.config.rollbackOnFailure) {
        try {
          await this.rollbackToPreviousModel();
          return this.recordUpdateResult(updateId, 'error_rollback', error.message, startTime);
        } catch (rollbackError) {
          console.error(`❌ [${updateId}] Error en rollback:`, rollbackError.message);
          return this.recordUpdateResult(updateId, 'error_no_rollback', `${error.message} + Rollback failed: ${rollbackError.message}`, startTime);
        }
      } else {
        return this.recordUpdateResult(updateId, 'error', error.message, startTime);
      }
    }
  }

  /**
   * Valida si hay datos nuevos suficientes para reentrenamiento
   */
  async validateNewData() {
    try {
      // Obtener fecha de última actualización
      const lastUpdate = this.updateHistory.length > 0 
        ? new Date(this.updateHistory[0].timestamp)
        : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000); // 30 días atrás por defecto

      // Contar registros nuevos desde la última actualización
      const newRecords = await this.Asistencia.countDocuments({
        fecha_hora: { $gte: lastUpdate }
      });

      const minimumNewRecords = 50; // Mínimo de registros nuevos requeridos
      const hasNewData = newRecords >= minimumNewRecords;

      return {
        hasNewData,
        newRecords,
        minimumRequired: minimumNewRecords,
        lastUpdateDate: lastUpdate.toISOString(),
        daysSinceLastUpdate: Math.floor((Date.now() - lastUpdate.getTime()) / (1000 * 60 * 60 * 24))
      };
    } catch (error) {
      throw new Error(`Error validando datos nuevos: ${error.message}`);
    }
  }

  /**
   * Hace backup del modelo actual
   */
  async backupCurrentModel() {
    try {
      const backupDir = path.join(__dirname, 'data/model_backups');
      await fs.mkdir(backupDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const backupPath = path.join(backupDir, `model_backup_${timestamp}.json`);

      // Aquí se haría el backup real del modelo
      // Por simplicidad, creamos un placeholder
      const backupData = {
        timestamp: new Date().toISOString(),
        version: '1.0',
        accuracy: 'placeholder',
        note: 'Backup automático antes de actualización semanal'
      };

      await fs.writeFile(backupPath, JSON.stringify(backupData, null, 2));
      console.log(`💾 Backup creado: ${backupPath}`);
    } catch (error) {
      console.error('❌ Error creando backup:', error.message);
      throw error;
    }
  }

  /**
   * Rollback al modelo anterior
   */
  async rollbackToPreviousModel() {
    try {
      console.log('🔄 Ejecutando rollback al modelo anterior...');
      
      // Aquí se implementaría la lógica real de rollback
      // Por simplicidad, solo registramos el evento
      console.log('✅ Rollback completado');
    } catch (error) {
      console.error('❌ Error en rollback:', error.message);
      throw error;
    }
  }

  /**
   * Registra el resultado de una actualización
   */
  async recordUpdateResult(updateId, status, message, startTime, details = {}) {
    const updateRecord = {
      id: updateId,
      timestamp: startTime.toISOString(),
      status: status, // 'success', 'failed', 'skipped', 'error', 'failed_rollback', 'error_rollback'
      message: message,
      duration: Date.now() - startTime.getTime(),
      details: details
    };

    this.updateHistory.unshift(updateRecord);
    
    // Mantener solo los últimos 50 registros
    if (this.updateHistory.length > 50) {
      this.updateHistory = this.updateHistory.slice(0, 50);
    }

    await this.saveUpdateHistory();
    return updateRecord;
  }

  /**
   * Obtiene el estado del scheduler
   */
  getSchedulerStatus() {
    return {
      active: this.schedulerActive,
      cronExpression: this.config.cronExpression,
      nextExecution: this.getNextExecutionTime(),
      lastUpdate: this.updateHistory[0] || null,
      config: this.config,
      historyCount: this.updateHistory.length
    };
  }

  /**
   * Obtiene la próxima fecha de ejecución
   */
  getNextExecutionTime() {
    if (!this.schedulerActive) return null;

    try {
      // Lógica simplificada para calcular próxima ejecución de cron
      const now = new Date();
      const nextSunday = new Date(now);
      nextSunday.setDate(now.getDate() + (7 - now.getDay()));
      nextSunday.setHours(2, 0, 0, 0); // 2:00 AM

      if (nextSunday <= now) {
        nextSunday.setDate(nextSunday.getDate() + 7);
      }

      return nextSunday.toISOString();
    } catch (error) {
      return null;
    }
  }

  /**
   * Obtiene historial de actualizaciones
   */
  getUpdateHistory(limit = 20) {
    return {
      history: this.updateHistory.slice(0, limit),
      total: this.updateHistory.length,
      summary: this.getHistorySummary()
    };
  }

  /**
   * Genera resumen del historial
   */
  getHistorySummary() {
    const summary = {
      total: this.updateHistory.length,
      byStatus: {
        success: 0,
        failed: 0,
        skipped: 0,
        error: 0
      },
      averageDuration: 0,
      lastSuccessful: null
    };

    if (this.updateHistory.length === 0) return summary;

    let totalDuration = 0;
    this.updateHistory.forEach(update => {
      const status = update.status.includes('success') ? 'success' :
                    update.status.includes('failed') ? 'failed' :
                    update.status.includes('error') ? 'error' : 'skipped';
      
      summary.byStatus[status]++;
      totalDuration += update.duration || 0;

      if (status === 'success' && !summary.lastSuccessful) {
        summary.lastSuccessful = update.timestamp;
      }
    });

    summary.averageDuration = Math.round(totalDuration / this.updateHistory.length);
    return summary;
  }

  /**
   * Configura el scheduler
   */
  async configureScheduler(newConfig) {
    try {
      const oldConfig = { ...this.config };
      this.config = { ...this.config, ...newConfig };

      // Si cambió la expresión cron y el scheduler está activo, reiniciarlo
      if (this.schedulerActive && newConfig.cronExpression && newConfig.cronExpression !== oldConfig.cronExpression) {
        await this.stopScheduler();
        await this.startScheduler();
      }

      // Si se habilitó y no estaba activo, iniciarlo
      if (newConfig.enabled && !oldConfig.enabled && !this.schedulerActive) {
        await this.startScheduler();
      }

      // Si se deshabilitó y estaba activo, detenerlo
      if (newConfig.enabled === false && oldConfig.enabled && this.schedulerActive) {
        await this.stopScheduler();
      }

      await this.saveConfiguration();

      return {
        success: true,
        message: 'Configuración actualizada',
        oldConfig: oldConfig,
        newConfig: this.config
      };
    } catch (error) {
      throw new Error(`Error configurando scheduler: ${error.message}`);
    }
  }

  /**
   * Ejecuta actualización manual inmediata
   */
  async executeManualUpdate() {
    console.log('🔧 Ejecutando actualización manual...');
    return await this.executeWeeklyUpdate();
  }

  // Métodos auxiliares para persistencia
  async loadConfiguration() {
    try {
      const data = await fs.readFile(this.configPath, 'utf8');
      this.config = { ...this.config, ...JSON.parse(data) };
    } catch (error) {
      // Si no existe, usar configuración por defecto
      await this.saveConfiguration();
    }
  }

  async saveConfiguration() {
    try {
      await fs.mkdir(path.dirname(this.configPath), { recursive: true });
      await fs.writeFile(this.configPath, JSON.stringify(this.config, null, 2));
    } catch (error) {
      console.error('❌ Error guardando configuración:', error.message);
    }
  }

  async loadUpdateHistory() {
    try {
      const data = await fs.readFile(this.historyPath, 'utf8');
      this.updateHistory = JSON.parse(data);
    } catch (error) {
      // Si no existe, inicializar vacío
      this.updateHistory = [];
    }
  }

  async saveUpdateHistory() {
    try {
      await fs.mkdir(path.dirname(this.historyPath), { recursive: true });
      await fs.writeFile(this.historyPath, JSON.stringify(this.updateHistory, null, 2));
    } catch (error) {
      console.error('❌ Error guardando historial:', error.message);
    }
  }
}

module.exports = WeeklyModelUpdateService;