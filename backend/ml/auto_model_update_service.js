/**
 * Servicio de Actualización Automática del Modelo ML
 * Programa actualización automática del modelo basado en datos nuevos
 */

const TrainingPipeline = require('./training_pipeline');
const DatasetCollector = require('./dataset_collector');
const fs = require('fs').promises;
const path = require('path');

class AutoModelUpdateService {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.collector = new DatasetCollector(AsistenciaModel);
    this.updateConfig = {
      enabled: false,
      interval: 7, // días
      minNewData: 100, // mínimo de nuevos registros
      autoRetrain: false,
      checkInterval: 24 * 60 * 60 * 1000 // 24 horas en ms
    };
    this.lastCheck = null;
    this.updateHistory = [];
  }

  /**
   * Configura actualización automática
   */
  configureAutoUpdate(config) {
    this.updateConfig = {
      ...this.updateConfig,
      ...config
    };

    return {
      success: true,
      config: this.updateConfig,
      message: 'Configuración de actualización automática guardada'
    };
  }

  /**
   * Obtiene configuración actual
   */
  getConfig() {
    return {
      ...this.updateConfig,
      lastCheck: this.lastCheck,
      updateHistory: this.updateHistory.slice(-10) // Últimas 10 actualizaciones
    };
  }

  /**
   * Verifica si hay suficientes datos nuevos para actualizar modelo
   */
  async checkForNewData(days = null) {
    try {
      const checkDays = days || this.updateConfig.interval;
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - checkDays);

      const newRecords = await this.Asistencia.countDocuments({
        fecha_hora: { $gte: cutoffDate }
      });

      const totalRecords = await this.Asistencia.countDocuments();

      return {
        hasNewData: newRecords >= this.updateConfig.minNewData,
        newRecords,
        totalRecords,
        cutoffDate: cutoffDate.toISOString(),
        daysChecked: checkDays,
        percentage: totalRecords > 0 ? (newRecords / totalRecords * 100).toFixed(2) : 0
      };
    } catch (error) {
      throw new Error(`Error verificando datos nuevos: ${error.message}`);
    }
  }

  /**
   * Ejecuta verificación y actualización automática si es necesario
   */
  async performAutoUpdateCheck() {
    try {
      this.lastCheck = new Date();

      if (!this.updateConfig.enabled) {
        return {
          executed: false,
          reason: 'Actualización automática deshabilitada',
          timestamp: this.lastCheck.toISOString()
        };
      }

      // Verificar datos nuevos
      const dataCheck = await this.checkForNewData();

      if (!dataCheck.hasNewData) {
        return {
          executed: false,
          reason: `Datos insuficientes. Se requieren ${this.updateConfig.minNewData}, disponibles: ${dataCheck.newRecords}`,
          dataCheck,
          timestamp: this.lastCheck.toISOString()
        };
      }

      // Si autoRetrain está habilitado, ejecutar reentrenamiento
      if (this.updateConfig.autoRetrain) {
        return await this.triggerAutoRetrain(dataCheck);
      }

      return {
        executed: false,
        reason: 'Auto-retrain deshabilitado. Datos disponibles pero no se reentrenará automáticamente.',
        dataCheck,
        recommendation: 'Ejecutar reentrenamiento manualmente',
        timestamp: this.lastCheck.toISOString()
      };
    } catch (error) {
      const errorRecord = {
        timestamp: new Date().toISOString(),
        error: error.message,
        type: 'auto_update_check_error'
      };

      this.updateHistory.push(errorRecord);
      throw error;
    }
  }

  /**
   * Dispara reentrenamiento automático
   */
  async triggerAutoRetrain(dataCheck) {
    try {
      const pipeline = new TrainingPipeline({ collector: this.collector });

      const result = await pipeline.executePipeline({
        months: 3,
        testSize: 0.2,
        modelType: 'logistic_regression',
        stratify: 'target',
        collector: this.collector
      });

      const updateRecord = {
        timestamp: new Date().toISOString(),
        type: 'auto_retrain',
        dataCheck,
        result: {
          modelPath: result.modelPath,
          validation: result.validation,
          reportPath: result.reportPath
        },
        success: true
      };

      this.updateHistory.push(updateRecord);
      this.saveUpdateHistory();

      return {
        executed: true,
        type: 'auto_retrain',
        dataCheck,
        result: {
          modelPath: result.modelPath,
          validation: result.validation,
          success: true
        },
        timestamp: updateRecord.timestamp
      };
    } catch (error) {
      const errorRecord = {
        timestamp: new Date().toISOString(),
        type: 'auto_retrain_error',
        error: error.message,
        dataCheck,
        success: false
      };

      this.updateHistory.push(errorRecord);
      this.saveUpdateHistory();

      throw error;
    }
  }

  /**
   * Guarda historial de actualizaciones
   */
  async saveUpdateHistory() {
    try {
      const historyDir = path.join(__dirname, '../data/update_history');
      await fs.mkdir(historyDir, { recursive: true });

      const historyPath = path.join(historyDir, 'update_history.json');
      await fs.writeFile(historyPath, JSON.stringify(this.updateHistory, null, 2));
    } catch (error) {
      console.error('Error guardando historial de actualizaciones:', error);
    }
  }

  /**
   * Carga historial de actualizaciones
   */
  async loadUpdateHistory() {
    try {
      const historyPath = path.join(__dirname, '../data/update_history/update_history.json');
      const content = await fs.readFile(historyPath, 'utf8');
      this.updateHistory = JSON.parse(content);
    } catch (error) {
      if (error.code !== 'ENOENT') {
        console.error('Error cargando historial:', error);
      }
      this.updateHistory = [];
    }
  }

  /**
   * Programa verificación periódica
   */
  scheduleAutoUpdate() {
    if (!this.updateConfig.enabled) {
      return { success: false, message: 'Actualización automática no está habilitada' };
    }

    // En producción, usar un scheduler como node-cron
    // Por ahora, retornamos configuración para scheduler externo
    return {
      success: true,
      schedule: {
        interval: this.updateConfig.checkInterval,
        intervalHours: this.updateConfig.checkInterval / (60 * 60 * 1000),
        nextCheck: new Date(Date.now() + this.updateConfig.checkInterval).toISOString(),
        function: 'performAutoUpdateCheck'
      },
      message: 'Configuración de scheduler generada. Implementar con cron o scheduler externo.'
    };
  }

  /**
   * Obtiene estadísticas de actualizaciones
   */
  getUpdateStatistics() {
    const successful = this.updateHistory.filter(u => u.success === true);
    const failed = this.updateHistory.filter(u => u.success === false);
    const lastUpdate = this.updateHistory.length > 0 
      ? this.updateHistory[this.updateHistory.length - 1]
      : null;

    return {
      totalUpdates: this.updateHistory.length,
      successful: successful.length,
      failed: failed.length,
      successRate: this.updateHistory.length > 0 
        ? (successful.length / this.updateHistory.length * 100).toFixed(2)
        : 0,
      lastUpdate,
      lastCheck: this.lastCheck,
      config: this.updateConfig
    };
  }

  /**
   * Ejecuta actualización manual
   */
  async executeManualUpdate(options = {}) {
    try {
      const {
        months = 3,
        testSize = 0.2,
        modelType = 'logistic_regression'
      } = options;

      const pipeline = new TrainingPipeline({ collector: this.collector });

      const result = await pipeline.executePipeline({
        months,
        testSize,
        modelType,
        stratify: 'target',
        collector: this.collector
      });

      const updateRecord = {
        timestamp: new Date().toISOString(),
        type: 'manual_update',
        options,
        result: {
          modelPath: result.modelPath,
          validation: result.validation
        },
        success: true
      };

      this.updateHistory.push(updateRecord);
      await this.saveUpdateHistory();

      return {
        success: true,
        result,
        timestamp: updateRecord.timestamp
      };
    } catch (error) {
      const errorRecord = {
        timestamp: new Date().toISOString(),
        type: 'manual_update_error',
        error: error.message,
        success: false
      };

      this.updateHistory.push(errorRecord);
      await this.saveUpdateHistory();

      throw error;
    }
  }
}

module.exports = AutoModelUpdateService;

