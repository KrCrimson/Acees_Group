/**
 * Estructura de Datos ML - Definición y Validación
 * Define estructura estándar para datos de ML
 */

class MLDataStructure {
  constructor() {
    this.schema = {
      features: {
        temporal: ['hora', 'minuto', 'dia_semana', 'dia_mes', 'mes', 'semana_anio', 'es_fin_semana', 'es_feriado'],
        estudiante: ['codigo_universitario', 'siglas_facultad', 'siglas_escuela'],
        acceso: ['tipo', 'entrada_tipo', 'puerta'],
        guardia: ['guardia_id', 'autorizacion_manual']
      },
      target: ['target', 'is_peak_hour', 'count'],
      metadata: ['id', 'fecha', 'fecha_hora', 'timestamp']
    };
  }

  /**
   * Define estructura base para datos ML
   */
  defineMLStructure() {
    return {
      version: '1.0.0',
      schema: {
        features: {
          temporal: {
            hora: { type: 'numeric', range: [0, 23], required: true },
            minuto: { type: 'numeric', range: [0, 59], required: false },
            dia_semana: { type: 'numeric', range: [0, 6], required: true },
            dia_mes: { type: 'numeric', range: [1, 31], required: false },
            mes: { type: 'numeric', range: [1, 12], required: true },
            semana_anio: { type: 'numeric', range: [1, 52], required: false },
            es_fin_semana: { type: 'binary', values: [0, 1], required: true },
            es_feriado: { type: 'binary', values: [0, 1], required: true }
          },
          estudiante: {
            codigo_universitario: { type: 'string', required: false },
            siglas_facultad: { type: 'string', required: true },
            siglas_escuela: { type: 'string', required: true }
          },
          acceso: {
            tipo: { type: 'categorical', values: ['entrada', 'salida'], required: true },
            entrada_tipo: { type: 'string', required: false },
            puerta: { type: 'string', required: true }
          },
          guardia: {
            guardia_id: { type: 'string', required: false },
            autorizacion_manual: { type: 'binary', values: [0, 1], required: true }
          }
        },
        target: {
          target: { type: 'numeric', required: true },
          is_peak_hour: { type: 'binary', values: [0, 1], required: false },
          count: { type: 'numeric', required: false }
        },
        metadata: {
          id: { type: 'string', required: true },
          fecha: { type: 'date', required: true },
          fecha_hora: { type: 'datetime', required: true },
          timestamp: { type: 'numeric', required: false }
        }
      },
      constraints: {
        minRecords: 100,
        maxRecords: 1000000,
        requiredFields: ['fecha_hora', 'tipo', 'siglas_facultad'],
        dateRange: {
          min: '2020-01-01',
          max: null // Sin límite máximo
        }
      }
    };
  }

  /**
   * Valida estructura de datos ML
   */
  validateStructure(data, structure = null) {
    const schema = structure || this.defineMLStructure();
    const errors = [];
    const warnings = [];

    if (!Array.isArray(data) || data.length === 0) {
      return {
        isValid: false,
        errors: ['Dataset debe ser un array no vacío']
      };
    }

    // Validar estructura de cada registro
    data.forEach((record, index) => {
      // Validar campos requeridos
      schema.schema.metadata.id.required && !record.id && errors.push(`Registro ${index}: falta campo 'id'`);
      schema.schema.features.temporal.hora.required && (record.hora === undefined || record.hora === null) && 
        errors.push(`Registro ${index}: falta campo 'hora'`);
      schema.schema.features.acceso.tipo.required && !record.tipo && 
        errors.push(`Registro ${index}: falta campo 'tipo'`);

      // Validar tipos y rangos
      if (record.hora !== undefined && (record.hora < 0 || record.hora > 23)) {
        errors.push(`Registro ${index}: hora fuera de rango [0-23]`);
      }

      if (record.dia_semana !== undefined && (record.dia_semana < 0 || record.dia_semana > 6)) {
        errors.push(`Registro ${index}: dia_semana fuera de rango [0-6]`);
      }

      if (record.mes !== undefined && (record.mes < 1 || record.mes > 12)) {
        errors.push(`Registro ${index}: mes fuera de rango [1-12]`);
      }

      // Validar valores categóricos
      if (record.tipo && !['entrada', 'salida'].includes(record.tipo)) {
        errors.push(`Registro ${index}: tipo inválido '${record.tipo}'`);
      }

      // Warnings para campos opcionales faltantes
      if (!record.codigo_universitario) {
        warnings.push(`Registro ${index}: campo opcional 'codigo_universitario' faltante`);
      }
    });

    // Validar cantidad de registros
    if (data.length < schema.constraints.minRecords) {
      warnings.push(`Dataset pequeño: ${data.length} registros (mínimo recomendado: ${schema.constraints.minRecords})`);
    }

    if (data.length > schema.constraints.maxRecords) {
      warnings.push(`Dataset grande: ${data.length} registros (máximo recomendado: ${schema.constraints.maxRecords})`);
    }

    return {
      isValid: errors.length === 0,
      errors: errors.slice(0, 50), // Limitar a 50 errores
      warnings: warnings.slice(0, 20), // Limitar a 20 warnings
      totalRecords: data.length,
      validRecords: data.length - errors.length
    };
  }

  /**
   * Normaliza datos a estructura ML estándar
   */
  normalizeToMLStructure(data) {
    return data.map(record => {
      const fecha = record.fecha_hora ? new Date(record.fecha_hora) : 
                    record.fecha ? new Date(record.fecha) : new Date();

      return {
        // Metadata
        id: record.id || `record_${Date.now()}_${Math.random()}`,
        fecha: fecha.toISOString().split('T')[0],
        fecha_hora: fecha.toISOString(),
        timestamp: fecha.getTime(),

        // Features temporales
        hora: record.hora !== undefined ? record.hora : fecha.getHours(),
        minuto: record.minuto !== undefined ? record.minuto : fecha.getMinutes(),
        dia_semana: record.dia_semana !== undefined ? record.dia_semana : fecha.getDay(),
        dia_mes: record.dia_mes !== undefined ? record.dia_mes : fecha.getDate(),
        mes: record.mes !== undefined ? record.mes : fecha.getMonth() + 1,
        semana_anio: record.semana_anio !== undefined ? record.semana_anio : this.getWeekOfYear(fecha),
        es_fin_semana: record.es_fin_semana !== undefined ? record.es_fin_semana : 
                      (fecha.getDay() === 0 || fecha.getDay() === 6 ? 1 : 0),
        es_feriado: record.es_feriado !== undefined ? record.es_feriado : 0,

        // Features estudiante
        codigo_universitario: record.codigo_universitario || null,
        siglas_facultad: record.siglas_facultad || 'GEN',
        siglas_escuela: record.siglas_escuela || 'GEN',

        // Features acceso
        tipo: record.tipo || 'entrada',
        entrada_tipo: record.entrada_tipo || 'NFC',
        puerta: record.puerta || 'PRINCIPAL',

        // Features guardia
        guardia_id: record.guardia_id || null,
        autorizacion_manual: record.autorizacion_manual ? 1 : 0,

        // Target
        target: record.target !== undefined ? record.target : (record.autorizacion_manual ? 1 : 0),
        is_peak_hour: record.is_peak_hour !== undefined ? record.is_peak_hour : 
                     this.isPeakHour(fecha.getHours(), fecha.getDay()),
        count: record.count !== undefined ? record.count : 1
      };
    });
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
   * Verifica si es horario pico
   */
  isPeakHour(hora, diaSemana) {
    const peakHours = [7, 8, 9, 17, 18, 19];
    const isWeekend = diaSemana === 0 || diaSemana === 6;
    return peakHours.includes(hora) && !isWeekend ? 1 : 0;
  }

  /**
   * Genera documento de estructura ML
   */
  generateSchemaDocumentation() {
    const schema = this.defineMLStructure();
    
    return {
      version: schema.version,
      description: 'Estructura estándar para datos de Machine Learning',
      schema: schema.schema,
      constraints: schema.constraints,
      examples: {
        record: {
          id: 'record_123',
          fecha: '2024-01-15',
          fecha_hora: '2024-01-15T08:30:00Z',
          hora: 8,
          dia_semana: 1,
          mes: 1,
          tipo: 'entrada',
          siglas_facultad: 'FIIS',
          target: 0,
          is_peak_hour: 1
        }
      }
    };
  }
}

module.exports = MLDataStructure;

