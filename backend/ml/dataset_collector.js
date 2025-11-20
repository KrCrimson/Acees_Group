/**
 * Servicio de Recopilación de Dataset Histórico
 * Recopila datos de mínimo 3 meses para entrenamiento del modelo
 */

const mongoose = require('mongoose');
const fs = require('fs').promises;
const path = require('path');

class DatasetCollector {
  constructor(AsistenciaModel) {
    this.minMonths = 3;
    this.datasetPath = path.join(__dirname, '../data/datasets');
    this.Asistencia = AsistenciaModel;
    
    if (!AsistenciaModel) {
      throw new Error('DatasetCollector requiere el modelo Asistencia como parámetro');
    }
  }

  /**
   * Verifica si hay suficientes datos históricos (≥3 meses)
   */
  async validateDatasetAvailability() {
    try {
      const fechaLimite = new Date();
      fechaLimite.setMonth(fechaLimite.getMonth() - this.minMonths);
      
      const count = await this.Asistencia.countDocuments({
        fecha_hora: { $gte: fechaLimite }
      });

      const totalRecords = await this.Asistencia.countDocuments();
      
      return {
        available: count >= 100, // Mínimo 100 registros en 3 meses
        recordsInPeriod: count,
        totalRecords: totalRecords,
        dateRange: {
          desde: fechaLimite.toISOString(),
          hasta: new Date().toISOString()
        },
        monthsAvailable: this.calculateMonthsAvailable(fechaLimite)
      };
    } catch (error) {
      throw new Error(`Error validando disponibilidad de dataset: ${error.message}`);
    }
  }

  /**
   * Calcula los meses disponibles en el dataset
   */
  calculateMonthsAvailable(fechaInicio) {
    const ahora = new Date();
    const diffTime = Math.abs(ahora - fechaInicio);
    const diffMonths = Math.floor(diffTime / (1000 * 60 * 60 * 24 * 30));
    return diffMonths;
  }

  /**
   * Recopila dataset histórico completo con características para ML
   */
  async collectHistoricalDataset(options = {}) {
    const {
      months = this.minMonths,
      includeFeatures = true,
      outputFormat = 'json'
    } = options;

    try {
      // Validar disponibilidad
      const validation = await this.validateDatasetAvailability();
      if (!validation.available) {
        throw new Error(`Dataset insuficiente. Se requieren ≥${this.minMonths} meses de datos.`);
      }

      // Calcular rango de fechas
      const fechaInicio = new Date();
      fechaInicio.setMonth(fechaInicio.getMonth() - months);
      const fechaFin = new Date();

      // Obtener datos históricos
      const asistencias = await this.Asistencia.find({
        fecha_hora: { $gte: fechaInicio, $lte: fechaFin }
      }).sort({ fecha_hora: 1 });

      console.log(`Recopilando ${asistencias.length} registros de ${months} meses...`);

      // Extraer características para ML
      const dataset = includeFeatures 
        ? this.extractFeatures(asistencias)
        : asistencias.map(a => a.toObject());

      // Crear directorio si no existe
      await fs.mkdir(this.datasetPath, { recursive: true });

      // Guardar dataset
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `dataset_${months}meses_${timestamp}.${outputFormat}`;
      const filepath = path.join(this.datasetPath, filename);

      if (outputFormat === 'json') {
        await fs.writeFile(filepath, JSON.stringify(dataset, null, 2));
      } else if (outputFormat === 'csv') {
        const csv = this.convertToCSV(dataset);
        await fs.writeFile(filepath, csv);
      }

      return {
        success: true,
        records: dataset.length,
        months: months,
        dateRange: {
          desde: fechaInicio.toISOString(),
          hasta: fechaFin.toISOString()
        },
        filepath: filepath,
        filename: filename,
        features: includeFeatures ? Object.keys(dataset[0] || {}).length : 0
      };
    } catch (error) {
      throw new Error(`Error recopilando dataset: ${error.message}`);
    }
  }

  /**
   * Extrae características relevantes para entrenamiento del modelo
   */
  extractFeatures(asistencias) {
    return asistencias.map(asistencia => {
      const fechaHora = new Date(asistencia.fecha_hora);
      
      return {
        // Características temporales
        hora: fechaHora.getHours(),
        minuto: fechaHora.getMinutes(),
        dia_semana: fechaHora.getDay(), // 0=Domingo, 6=Sábado
        dia_mes: fechaHora.getDate(),
        mes: fechaHora.getMonth() + 1,
        semana_anio: this.getWeekOfYear(fechaHora),
        es_fin_semana: fechaHora.getDay() === 0 || fechaHora.getDay() === 6 ? 1 : 0,
        es_feriado: this.isHoliday(fechaHora) ? 1 : 0,
        
        // Características del estudiante
        codigo_universitario: asistencia.codigo_universitario,
        siglas_facultad: asistencia.siglas_facultad,
        siglas_escuela: asistencia.siglas_escuela,
        
        // Características del acceso
        tipo: asistencia.tipo === 'entrada' ? 1 : 0, // 1=entrada, 0=salida
        entrada_tipo: asistencia.entrada_tipo,
        puerta: asistencia.puerta,
        
        // Características del guardia
        guardia_id: asistencia.guardia_id || 'sin_guardia',
        autorizacion_manual: asistencia.autorizacion_manual ? 1 : 0,
        
        // Target/Variable objetivo (para predicción)
        // Puede ser: probabilidad de autorización manual, tipo de acceso, etc.
        target: asistencia.autorizacion_manual ? 1 : 0,
        
        // Metadata
        fecha_hora: asistencia.fecha_hora,
        id: asistencia._id
      };
    });
  }

  /**
   * Calcula la semana del año
   */
  getWeekOfYear(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  }

  /**
   * Verifica si es día feriado (puede extenderse con calendario oficial)
   */
  isHoliday(date) {
    // Implementar lógica de feriados si es necesario
    // Por ahora retorna false
    return false;
  }

  /**
   * Convierte dataset a formato CSV
   */
  convertToCSV(dataset) {
    if (dataset.length === 0) return '';
    
    const headers = Object.keys(dataset[0]);
    const csvRows = [
      headers.join(',')
    ];

    dataset.forEach(row => {
      const values = headers.map(header => {
        const value = row[header];
        return typeof value === 'string' ? `"${value}"` : value;
      });
      csvRows.push(values.join(','));
    });

    return csvRows.join('\n');
  }

  /**
   * Obtiene estadísticas del dataset
   */
  async getDatasetStatistics() {
    try {
      const fechaLimite = new Date();
      fechaLimite.setMonth(fechaLimite.getMonth() - this.minMonths);

      const stats = await this.Asistencia.aggregate([
        {
          $match: {
            fecha_hora: { $gte: fechaLimite }
          }
        },
        {
          $group: {
            _id: null,
            total: { $sum: 1 },
            entradas: {
              $sum: { $cond: [{ $eq: ['$tipo', 'entrada'] }, 1, 0] }
            },
            salidas: {
              $sum: { $cond: [{ $eq: ['$tipo', 'salida'] }, 1, 0] }
            },
            autorizaciones_manuales: {
              $sum: { $cond: ['$autorizacion_manual', 1, 0] }
            },
            puertas_unicas: { $addToSet: '$puerta' },
            facultades_unicas: { $addToSet: '$siglas_facultad' },
            estudiantes_unicos: { $addToSet: '$codigo_universitario' }
          }
        }
      ]);

      if (stats.length === 0) {
        return {
          total: 0,
          mensaje: 'No hay datos suficientes'
        };
      }

      const stat = stats[0];
      return {
        total: stat.total,
        entradas: stat.entradas,
        salidas: stat.salidas,
        autorizaciones_manuales: stat.autorizaciones_manuales,
        puertas_unicas: stat.puertas_unicas.length,
        facultades_unicas: stat.facultades_unicas.length,
        estudiantes_unicos: stat.estudiantes_unicos.length,
        periodo: {
          desde: fechaLimite.toISOString(),
          hasta: new Date().toISOString()
        },
        promedio_diario: (stat.total / (this.minMonths * 30)).toFixed(2)
      };
    } catch (error) {
      throw new Error(`Error obteniendo estadísticas: ${error.message}`);
    }
  }
}

module.exports = DatasetCollector;

