/**
 * Servicio de Recopilación de Dataset Histórico
 * Recopila datos de mínimo 3 meses para entrenamiento del modelo
 * Adaptado para el proyecto principal Acees_Group
 */

const mongoose = require('mongoose');
const fs = require('fs').promises;
const path = require('path');
const MLDataStructure = require('./ml_data_structure');

class DatasetCollector {
  constructor(AsistenciaModel) {
    this.minMonths = 3;
    this.datasetPath = path.join(__dirname, 'data/datasets');
    this.Asistencia = AsistenciaModel;
    this.mlStructure = new MLDataStructure();
    
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

      // Obtener datos históricos - adaptado para nuestro esquema
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
   * Adaptado para los campos del proyecto principal
   */
  extractFeatures(asistencias) {
    return asistencias.map(asistencia => {
      const fechaHora = new Date(asistencia.fecha_hora);
      
      return {
        // ID y metadata
        id: asistencia._id.toString(),
        fecha_hora: asistencia.fecha_hora,
        timestamp_creacion: asistencia.timestamp_creacion || null,
        
        // Características temporales
        hora: fechaHora.getHours(),
        minuto: fechaHora.getMinutes(),
        dia_semana: fechaHora.getDay(), // 0=Domingo, 6=Sábado
        dia_mes: fechaHora.getDate(),
        mes: fechaHora.getMonth() + 1,
        semana_anio: this.getWeekOfYear(fechaHora),
        es_fin_semana: fechaHora.getDay() === 0 || fechaHora.getDay() === 6 ? 1 : 0,
        es_feriado: this.isHoliday(fechaHora) ? 1 : 0,
        
        // Características del estudiante - campos del proyecto principal
        nombre: asistencia.nombre,
        apellido: asistencia.apellido,
        dni: asistencia.dni,
        codigo_universitario: asistencia.codigo_universitario,
        siglas_facultad: asistencia.siglas_facultad,
        siglas_escuela: asistencia.siglas_escuela,
        
        // Características del acceso - campos del proyecto principal
        tipo: asistencia.tipo === 'entrada' ? 1 : 0, // 1=entrada, 0=salida
        entrada_tipo: asistencia.entrada_tipo,
        puerta: asistencia.puerta,
        
        // Características de la guardia - campos del proyecto principal
        guardia_id: asistencia.guardia_id,
        guardia_nombre: asistencia.guardia_nombre,
        autorizacion_manual: asistencia.autorizacion_manual ? 1 : 0,
        
        // Campos específicos del proyecto principal
        estado: asistencia.estado,
        razon_decision: asistencia.razon_decision,
        timestamp_decision: asistencia.timestamp_decision,
        coordenadas: asistencia.coordenadas,
        descripcion_ubicacion: asistencia.descripcion_ubicacion,
        version_registro: asistencia.version_registro,
        
        // Target variables para ML
        is_peak_hour: this.isPeakHour(fechaHora.getHours(), fechaHora.getDay()) ? 1 : 0,
        is_authorized: asistencia.estado === 'autorizado' ? 1 : 0,
        is_manual: asistencia.autorizacion_manual ? 1 : 0,
        
        // Características derivadas
        is_entrance: asistencia.tipo === 'entrada' ? 1 : 0,
        is_weekend: fechaHora.getDay() === 0 || fechaHora.getDay() === 6 ? 1 : 0,
        hour_category: this.categorizeHour(fechaHora.getHours()),
        access_frequency: 1 // Placeholder para frecuencia de acceso
      };
    });
  }

  /**
   * Categoriza las horas en grupos
   */
  categorizeHour(hora) {
    if (hora >= 6 && hora < 12) return 'mañana';
    if (hora >= 12 && hora < 18) return 'tarde';
    if (hora >= 18 && hora < 22) return 'noche';
    return 'madrugada';
  }

  /**
   * Verifica si es horario pico
   */
  isPeakHour(hora, diaSemana) {
    const peakHours = [7, 8, 9, 17, 18, 19];
    const isWeekend = diaSemana === 0 || diaSemana === 6;
    return peakHours.includes(hora) && !isWeekend;
  }

  /**
   * Calcula semana del año
   */
  getWeekOfYear(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  }

  /**
   * Verifica si es día feriado (simplificado)
   */
  isHoliday(date) {
    // Lista básica de feriados peruanos (simplificada)
    const holidays = [
      '01-01', // Año Nuevo
      '05-01', // Día del Trabajo
      '07-28', // Fiestas Patrias
      '07-29', // Fiestas Patrias
      '08-30', // Santa Rosa de Lima
      '10-08', // Combate de Angamos
      '11-01', // Todos los Santos
      '12-08', // Inmaculada Concepción
      '12-25'  // Navidad
    ];
    
    const monthDay = String(date.getMonth() + 1).padStart(2, '0') + '-' + 
                    String(date.getDate()).padStart(2, '0');
    return holidays.includes(monthDay);
  }

  /**
   * Convierte dataset a formato CSV
   */
  convertToCSV(data) {
    if (!data || data.length === 0) return '';
    
    const headers = Object.keys(data[0]);
    const csvContent = [
      headers.join(','),
      ...data.map(row => 
        headers.map(header => {
          const value = row[header];
          // Escapar valores que contienen comas o comillas
          if (typeof value === 'string' && (value.includes(',') || value.includes('"'))) {
            return `"${value.replace(/"/g, '""')}"`;
          }
          return value;
        }).join(',')
      )
    ].join('\n');
    
    return csvContent;
  }

  /**
   * Obtiene estadísticas del dataset
   */
  async getDatasetStatistics() {
    try {
      const totalRecords = await this.Asistencia.countDocuments();
      
      // Estadísticas por tipo
      const typeStats = await this.Asistencia.aggregate([
        { $group: { _id: '$tipo', count: { $sum: 1 } } }
      ]);

      // Estadísticas por facultad
      const facultyStats = await this.Asistencia.aggregate([
        { $group: { _id: '$siglas_facultad', count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $limit: 10 }
      ]);

      // Estadísticas por mes
      const monthlyStats = await this.Asistencia.aggregate([
        {
          $group: {
            _id: {
              year: { $year: '$fecha_hora' },
              month: { $month: '$fecha_hora' }
            },
            count: { $sum: 1 }
          }
        },
        { $sort: { '_id.year': -1, '_id.month': -1 } },
        { $limit: 12 }
      ]);

      return {
        totalRecords,
        typeDistribution: typeStats,
        topFaculties: facultyStats,
        monthlyTrend: monthlyStats,
        lastUpdated: new Date().toISOString()
      };
    } catch (error) {
      throw new Error(`Error obteniendo estadísticas: ${error.message}`);
    }
  }
}

module.exports = DatasetCollector;