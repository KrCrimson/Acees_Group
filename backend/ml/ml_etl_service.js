/**
 * Servicio ETL para Machine Learning
 * Extrae, transforma y carga datos para entrenamiento de modelos
 * Adaptado para el proyecto principal Acees_Group
 */

const DatasetCollector = require('./dataset_collector');
const MLDataStructure = require('./ml_data_structure');

class MLETLService {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.datasetCollector = new DatasetCollector(AsistenciaModel);
    this.mlStructure = new MLDataStructure();
  }

  /**
   * Pipeline ETL completo para datos ML
   */
  async runETLPipeline(options = {}) {
    const {
      months = 3,
      validateData = true,
      cleanData = true,
      outputFormat = 'json'
    } = options;

    try {
      console.log('🚀 Iniciando pipeline ETL para ML...');

      // 1. EXTRACT - Extraer datos históricos
      console.log('📥 Extrayendo datos históricos...');
      const extractResult = await this.extractHistoricalData(months);

      // 2. TRANSFORM - Transformar y limpiar datos
      console.log('🔄 Transformando datos...');
      let transformedData = await this.transformData(extractResult.data);

      if (cleanData) {
        console.log('🧹 Limpiando datos...');
        transformedData = await this.cleanData(transformedData);
      }

      // 3. VALIDATE - Validar estructura de datos
      if (validateData) {
        console.log('✅ Validando estructura de datos...');
        const validation = this.mlStructure.validateStructure(transformedData);
        if (!validation.isValid) {
          throw new Error(`Datos inválidos: ${validation.errors.join(', ')}`);
        }
      }

      // 4. LOAD - Guardar datos procesados
      console.log('💾 Guardando datos procesados...');
      const loadResult = await this.loadProcessedData(transformedData, outputFormat);

      console.log('✅ Pipeline ETL completado exitosamente');

      return {
        success: true,
        extract: extractResult,
        transform: {
          records: transformedData.length,
          features: Object.keys(transformedData[0] || {}).length
        },
        load: loadResult,
        pipeline: {
          startTime: new Date().toISOString(),
          duration: Date.now() - extractResult.startTime,
          totalRecords: transformedData.length
        }
      };
    } catch (error) {
      console.error('❌ Error en pipeline ETL:', error.message);
      throw new Error(`Pipeline ETL falló: ${error.message}`);
    }
  }

  /**
   * Extrae datos históricos de la base de datos
   */
  async extractHistoricalData(months) {
    const startTime = Date.now();
    
    try {
      const fechaInicio = new Date();
      fechaInicio.setMonth(fechaInicio.getMonth() - months);

      const data = await this.Asistencia.find({
        fecha_hora: { $gte: fechaInicio }
      }).sort({ fecha_hora: 1 });

      return {
        success: true,
        data: data,
        records: data.length,
        dateRange: {
          desde: fechaInicio.toISOString(),
          hasta: new Date().toISOString()
        },
        startTime: startTime
      };
    } catch (error) {
      throw new Error(`Error extrayendo datos: ${error.message}`);
    }
  }

  /**
   * Transforma datos raw a formato ML
   */
  async transformData(rawData) {
    try {
      const transformed = rawData.map(record => {
        const fechaHora = new Date(record.fecha_hora);
        
        return {
          // IDs y metadatos
          id: record._id.toString(),
          fecha_hora: record.fecha_hora,
          fecha: fechaHora.toISOString().split('T')[0],
          timestamp: fechaHora.getTime(),

          // Features temporales
          hora: fechaHora.getHours(),
          minuto: fechaHora.getMinutes(),
          dia_semana: fechaHora.getDay(),
          dia_mes: fechaHora.getDate(),
          mes: fechaHora.getMonth() + 1,
          año: fechaHora.getFullYear(),
          semana_anio: this.getWeekOfYear(fechaHora),
          
          // Features binarias temporales
          es_fin_semana: fechaHora.getDay() === 0 || fechaHora.getDay() === 6 ? 1 : 0,
          es_feriado: this.isHoliday(fechaHora) ? 1 : 0,
          es_horario_pico: this.isPeakHour(fechaHora.getHours(), fechaHora.getDay()) ? 1 : 0,
          
          // Features categóricas de horario
          periodo_dia: this.getPeriodOfDay(fechaHora.getHours()),
          categoria_hora: this.categorizeHour(fechaHora.getHours()),
          
          // Features del estudiante
          nombre: record.nombre || null,
          apellido: record.apellido || null,
          dni: record.dni || null,
          codigo_universitario: record.codigo_universitario || null,
          siglas_facultad: record.siglas_facultad || 'GEN',
          siglas_escuela: record.siglas_escuela || 'GEN',
          
          // Features del acceso
          tipo: record.tipo || 'salida',
          es_entrada: record.tipo === 'entrada' ? 1 : 0,
          entrada_tipo: record.entrada_tipo || 'nfc',
          puerta: record.puerta || 'fafing',
          
          // Features de la guardia
          guardia_id: record.guardia_id || null,
          guardia_nombre: record.guardia_nombre || null,
          autorizacion_manual: record.autorizacion_manual ? 1 : 0,
          
          // Features del estado y decisión
          estado: record.estado || 'autorizado',
          es_autorizado: record.estado === 'autorizado' ? 1 : 0,
          razon_decision: record.razon_decision || null,
          tiene_coordenadas: record.coordenadas ? 1 : 0,
          
          // Features derivadas
          facultad_encoded: this.encodeFacultad(record.siglas_facultad),
          escuela_encoded: this.encodeEscuela(record.siglas_escuela),
          puerta_encoded: this.encodePuerta(record.puerta),
          
          // Target variables
          target_autorizado: record.estado === 'autorizado' ? 1 : 0,
          target_manual: record.autorizacion_manual ? 1 : 0,
          target_pico: this.isPeakHour(fechaHora.getHours(), fechaHora.getDay()) ? 1 : 0
        };
      });

      return transformed;
    } catch (error) {
      throw new Error(`Error transformando datos: ${error.message}`);
    }
  }

  /**
   * Limpia y filtra datos
   */
  async cleanData(data) {
    try {
      const cleaned = data.filter(record => {
        // Filtrar registros con campos críticos faltantes
        return record.fecha_hora && 
               record.siglas_facultad && 
               record.tipo &&
               record.hora !== null && 
               record.hora !== undefined;
      });

      // Remover outliers de hora
      const cleanedHours = cleaned.filter(record => 
        record.hora >= 0 && record.hora <= 23
      );

      // Llenar valores faltantes
      const filled = cleanedHours.map(record => ({
        ...record,
        codigo_universitario: record.codigo_universitario || 'SIN_CODIGO',
        dni: record.dni || 'SIN_DNI',
        guardia_nombre: record.guardia_nombre || 'sin_guardia',
        entrada_tipo: record.entrada_tipo || 'nfc',
        puerta: record.puerta || 'fafing'
      }));

      console.log(`🧹 Limpieza completada: ${data.length} → ${filled.length} registros`);
      
      return filled;
    } catch (error) {
      throw new Error(`Error limpiando datos: ${error.message}`);
    }
  }

  /**
   * Guarda datos procesados
   */
  async loadProcessedData(data, format = 'json') {
    try {
      const result = await this.datasetCollector.collectHistoricalDataset({
        months: 3,
        includeFeatures: false, // Ya están procesados
        outputFormat: format
      });

      // Sobrescribir con nuestros datos procesados
      const fs = require('fs').promises;
      const filepath = result.filepath;
      
      if (format === 'json') {
        await fs.writeFile(filepath, JSON.stringify(data, null, 2));
      } else if (format === 'csv') {
        const csv = this.convertToCSV(data);
        await fs.writeFile(filepath, csv);
      }

      return {
        success: true,
        records: data.length,
        filepath: filepath,
        format: format
      };
    } catch (error) {
      throw new Error(`Error guardando datos: ${error.message}`);
    }
  }

  /**
   * Genera reporte de calidad de datos
   */
  async generateDataQualityReport(data) {
    try {
      const report = {
        totalRecords: data.length,
        completeness: {},
        distribution: {},
        quality: {
          duplicates: 0,
          outliers: 0,
          inconsistencies: []
        },
        recommendations: []
      };

      // Análisis de completitud
      const fields = Object.keys(data[0] || {});
      fields.forEach(field => {
        const nonNullCount = data.filter(record => 
          record[field] !== null && 
          record[field] !== undefined && 
          record[field] !== ''
        ).length;
        
        report.completeness[field] = {
          nonNull: nonNullCount,
          percentage: (nonNullCount / data.length * 100).toFixed(2)
        };
      });

      // Análisis de distribución
      report.distribution.tipoAcceso = this.getDistribution(data, 'tipo');
      report.distribution.facultades = this.getDistribution(data, 'siglas_facultad');
      report.distribution.horas = this.getDistribution(data, 'hora');

      // Detectar duplicados
      const ids = data.map(r => r.id);
      report.quality.duplicates = ids.length - new Set(ids).size;

      // Recomendaciones
      if (report.completeness.codigo_universitario.percentage < 90) {
        report.recommendations.push('Mejorar captura de códigos universitarios');
      }
      if (report.quality.duplicates > 0) {
        report.recommendations.push('Eliminar registros duplicados');
      }

      return report;
    } catch (error) {
      throw new Error(`Error generando reporte de calidad: ${error.message}`);
    }
  }

  // Métodos auxiliares
  getWeekOfYear(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  }

  isHoliday(date) {
    const holidays = ['01-01', '05-01', '07-28', '07-29', '08-30', '10-08', '11-01', '12-08', '12-25'];
    const monthDay = String(date.getMonth() + 1).padStart(2, '0') + '-' + 
                    String(date.getDate()).padStart(2, '0');
    return holidays.includes(monthDay);
  }

  isPeakHour(hora, diaSemana) {
    const peakHours = [7, 8, 9, 17, 18, 19];
    const isWeekend = diaSemana === 0 || diaSemana === 6;
    return peakHours.includes(hora) && !isWeekend;
  }

  getPeriodOfDay(hora) {
    if (hora >= 6 && hora < 12) return 'mañana';
    if (hora >= 12 && hora < 18) return 'tarde';
    if (hora >= 18 && hora < 22) return 'noche';
    return 'madrugada';
  }

  categorizeHour(hora) {
    if (hora >= 7 && hora <= 9) return 'pico_mañana';
    if (hora >= 17 && hora <= 19) return 'pico_tarde';
    if (hora >= 10 && hora <= 16) return 'regular';
    return 'baja_actividad';
  }

  encodeFacultad(facultad) {
    const mapping = { 'FACEM': 1, 'FAEDU': 2, 'FACSA': 3, 'GEN': 0 };
    return mapping[facultad] || 0;
  }

  encodeEscuela(escuela) {
    const mapping = { 'EPIOL': 1, 'EPIDH': 2, 'EPO': 3, 'GEN': 0 };
    return mapping[escuela] || 0;
  }

  encodePuerta(puerta) {
    const mapping = { 'fafing': 1, 'principal': 2, 'trasera': 3 };
    return mapping[puerta] || 1;
  }

  getDistribution(data, field) {
    const distribution = {};
    data.forEach(record => {
      const value = record[field];
      distribution[value] = (distribution[value] || 0) + 1;
    });
    return distribution;
  }

  convertToCSV(data) {
    if (!data || data.length === 0) return '';
    
    const headers = Object.keys(data[0]);
    const csvContent = [
      headers.join(','),
      ...data.map(row => 
        headers.map(header => {
          const value = row[header];
          if (typeof value === 'string' && (value.includes(',') || value.includes('"'))) {
            return `"${value.replace(/"/g, '""')}"`;
          }
          return value;
        }).join(',')
      )
    ].join('\n');
    
    return csvContent;
  }
}

module.exports = MLETLService;