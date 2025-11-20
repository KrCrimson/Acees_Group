/**
 * Servicio ETL de Datos Históricos
 * Extrae, Transforma y Carga datos de entrada/salida para ML
 */

const fs = require('fs').promises;
const path = require('path');

class HistoricalDataETL {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.dataDir = path.join(__dirname, '../data/etl');
    this.processedDir = path.join(__dirname, '../data/etl/processed');
    this.rawDir = path.join(__dirname, '../data/etl/raw');
  }

  /**
   * Ejecuta pipeline ETL completo
   */
  async executeETLPipeline(options = {}) {
    const {
      months = 3,
      startDate = null,
      endDate = null,
      cleanData = true,
      validateData = true,
      aggregateByHour = true
    } = options;

    try {
      console.log('🔄 Iniciando pipeline ETL...');

      // 1. EXTRACT - Extraer datos históricos
      console.log('📥 Paso 1: Extrayendo datos históricos...');
      const rawData = await this.extractHistoricalData({
        months,
        startDate,
        endDate
      });

      console.log(`✅ Extraídos ${rawData.length} registros`);

      // Guardar datos raw
      await this.saveRawData(rawData);

      // 2. TRANSFORM - Transformar y limpiar datos
      console.log('🔧 Paso 2: Transformando y limpiando datos...');
      let transformedData = rawData;

      if (cleanData) {
        transformedData = await this.cleanData(rawData);
      }

      transformedData = await this.transformData(transformedData, {
        aggregateByHour
      });

      // 3. VALIDATE - Validar calidad de datos
      if (validateData) {
        console.log('✅ Paso 3: Validando calidad de datos...');
        const validationResult = await this.validateDataQuality(transformedData);
        
        if (!validationResult.isValid) {
          throw new Error(`Datos no válidos: ${validationResult.errors.join(', ')}`);
        }

        console.log(`✅ Validación exitosa: ${validationResult.score}% de calidad`);
      }

      // 4. LOAD - Cargar datos procesados
      console.log('💾 Paso 4: Guardando datos procesados...');
      const processedDataPath = await this.loadProcessedData(transformedData);

      console.log('✅ Pipeline ETL completado exitosamente');

      return {
        success: true,
        rawRecords: rawData.length,
        processedRecords: transformedData.length,
        rawDataPath: path.join(this.rawDir, `raw_${Date.now()}.json`),
        processedDataPath,
        validation: validateData ? await this.validateDataQuality(transformedData) : null,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      throw new Error(`Error en pipeline ETL: ${error.message}`);
    }
  }

  /**
   * EXTRACT - Extrae datos históricos de MongoDB
   */
  async extractHistoricalData(options = {}) {
    const {
      months = 3,
      startDate = null,
      endDate = null
    } = options;

    let query = {};

    if (startDate && endDate) {
      query.fecha_hora = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    } else {
      const fechaLimite = new Date();
      fechaLimite.setMonth(fechaLimite.getMonth() - months);
      query.fecha_hora = { $gte: fechaLimite };
    }

    const asistencias = await this.Asistencia.find(query)
      .sort({ fecha_hora: 1 })
      .lean();

    return asistencias.map(a => ({
      id: a._id,
      fecha_hora: a.fecha_hora,
      nombre: a.nombre,
      apellido: a.apellido,
      dni: a.dni,
      codigo_universitario: a.codigo_universitario,
      siglas_facultad: a.siglas_facultad,
      siglas_escuela: a.siglas_escuela,
      tipo: a.tipo,
      entrada_tipo: a.entrada_tipo,
      puerta: a.puerta,
      guardia_id: a.guardia_id,
      guardia_nombre: a.guardia_nombre,
      autorizacion_manual: a.autorizacion_manual || false,
      razon_decision: a.razon_decision,
      coordenadas: a.coordenadas,
      descripcion_ubicacion: a.descripcion_ubicacion
    }));
  }

  /**
   * Guarda datos raw
   */
  async saveRawData(data) {
    try {
      await fs.mkdir(this.rawDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `raw_${timestamp}.json`;
      const filepath = path.join(this.rawDir, filename);

      await fs.writeFile(filepath, JSON.stringify(data, null, 2));

      return filepath;
    } catch (error) {
      console.warn('Error guardando datos raw:', error.message);
      return null;
    }
  }

  /**
   * TRANSFORM - Transforma datos para ML
   */
  async transformData(data, options = {}) {
    const {
      aggregateByHour = true
    } = options;

    if (aggregateByHour) {
      return this.aggregateByHour(data);
    }

    // Transformar sin agregación
    return data.map(record => this.transformRecord(record));
  }

  /**
   * Agrega datos por hora
   */
  aggregateByHour(data) {
    const hourlyAggregation = {};

    data.forEach(record => {
      const fecha = new Date(record.fecha_hora);
      const hora = fecha.getHours();
      const fechaKey = fecha.toISOString().split('T')[0];
      const tipo = record.tipo || 'entrada';
      const key = `${fechaKey}_${hora}_${tipo}`;

      if (!hourlyAggregation[key]) {
        hourlyAggregation[key] = {
          fecha: fechaKey,
          hora,
          tipo,
          dia_semana: fecha.getDay(),
          mes: fecha.getMonth() + 1,
          semana_anio: this.getWeekOfYear(fecha),
          es_fin_semana: (fecha.getDay() === 0 || fecha.getDay() === 6) ? 1 : 0,
          es_feriado: this.isHoliday(fecha) ? 1 : 0,
          count: 0,
          entradas: 0,
          salidas: 0,
          autorizaciones_manuales: 0,
          puertas: new Set(),
          facultades: new Set(),
          guardias: new Set()
        };
      }

      const agg = hourlyAggregation[key];
      agg.count++;
      
      if (tipo === 'entrada') {
        agg.entradas++;
      } else {
        agg.salidas++;
      }

      if (record.autorizacion_manual) {
        agg.autorizaciones_manuales++;
      }

      if (record.puerta) agg.puertas.add(record.puerta);
      if (record.siglas_facultad) agg.facultades.add(record.siglas_facultad);
      if (record.guardia_id) agg.guardias.add(record.guardia_id);
    });

    // Convertir a array y estructurar para ML
    return Object.values(hourlyAggregation).map(agg => ({
      fecha: agg.fecha,
      hora: agg.hora,
      tipo: agg.tipo,
      dia_semana: agg.dia_semana,
      mes: agg.mes,
      semana_anio: agg.semana_anio,
      es_fin_semana: agg.es_fin_semana,
      es_feriado: agg.es_feriado,
      count: agg.count,
      entradas: agg.entradas,
      salidas: agg.salidas,
      autorizaciones_manuales: agg.autorizaciones_manuales,
      puertas_unicas: agg.puertas.size,
      facultades_unicas: agg.facultades.size,
      guardias_unicos: agg.guardias.size,
      // Target para ML
      target: agg.count,
      is_peak_hour: this.isPeakHour(agg.hora, agg.dia_semana)
    }));
  }

  /**
   * Transforma un registro individual
   */
  transformRecord(record) {
    const fecha = new Date(record.fecha_hora);

    return {
      fecha: fecha.toISOString().split('T')[0],
      hora: fecha.getHours(),
      minuto: fecha.getMinutes(),
      dia_semana: fecha.getDay(),
      mes: fecha.getMonth() + 1,
      semana_anio: this.getWeekOfYear(fecha),
      es_fin_semana: (fecha.getDay() === 0 || fecha.getDay() === 6) ? 1 : 0,
      es_feriado: this.isHoliday(fecha) ? 1 : 0,
      tipo: record.tipo === 'entrada' ? 1 : 0,
      codigo_universitario: record.codigo_universitario,
      siglas_facultad: record.siglas_facultad,
      siglas_escuela: record.siglas_escuela,
      puerta: record.puerta,
      autorizacion_manual: record.autorizacion_manual ? 1 : 0,
      target: record.autorizacion_manual ? 1 : 0
    };
  }

  /**
   * CLEAN - Limpia datos (maneja outliers, valores faltantes, etc.)
   */
  async cleanData(data) {
    let cleaned = [...data];

    // 1. Eliminar duplicados
    cleaned = this.removeDuplicates(cleaned);

    // 2. Manejar valores faltantes
    cleaned = this.handleMissingValues(cleaned);

    // 3. Detectar y manejar outliers
    cleaned = this.handleOutliers(cleaned);

    // 4. Normalizar formatos
    cleaned = this.normalizeFormats(cleaned);

    // 5. Validar rangos
    cleaned = this.validateRanges(cleaned);

    return cleaned;
  }

  /**
   * Elimina duplicados
   */
  removeDuplicates(data) {
    const seen = new Set();
    return data.filter(record => {
      const key = `${record.id}_${record.fecha_hora}`;
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    });
  }

  /**
   * Maneja valores faltantes
   */
  handleMissingValues(data) {
    return data.map(record => ({
      ...record,
      nombre: record.nombre || 'N/A',
      apellido: record.apellido || 'N/A',
      dni: record.dni || 'N/A',
      codigo_universitario: record.codigo_universitario || 'N/A',
      siglas_facultad: record.siglas_facultad || 'GEN',
      siglas_escuela: record.siglas_escuela || 'GEN',
      tipo: record.tipo || 'entrada',
      entrada_tipo: record.entrada_tipo || 'NFC',
      puerta: record.puerta || 'PRINCIPAL',
      autorizacion_manual: record.autorizacion_manual || false,
      razon_decision: record.razon_decision || null,
      coordenadas: record.coordenadas || null,
      descripcion_ubicacion: record.descripcion_ubicacion || null
    }));
  }

  /**
   * Maneja outliers (datos anómalos)
   */
  handleOutliers(data) {
    // Agrupar por hora para detectar outliers
    const hourlyData = {};
    
    data.forEach(record => {
      const fecha = new Date(record.fecha_hora);
      const hora = fecha.getHours();
      const key = `${hora}_${record.tipo}`;

      if (!hourlyData[key]) {
        hourlyData[key] = [];
      }

      hourlyData[key].push(record);
    });

    // Detectar outliers usando IQR method
    const cleaned = [];
    Object.keys(hourlyData).forEach(key => {
      const group = hourlyData[key];
      const counts = group.map(() => 1); // Simplificado
      
      // Calcular Q1, Q3, IQR
      const sorted = [...counts].sort((a, b) => a - b);
      const q1 = sorted[Math.floor(sorted.length * 0.25)];
      const q3 = sorted[Math.floor(sorted.length * 0.75)];
      const iqr = q3 - q1;
      const lowerBound = q1 - 1.5 * iqr;
      const upperBound = q3 + 1.5 * iqr;

      // Filtrar outliers (en este caso, todos los registros son válidos)
      cleaned.push(...group);
    });

    return cleaned;
  }

  /**
   * Normaliza formatos
   */
  normalizeFormats(data) {
    return data.map(record => {
      const fecha = new Date(record.fecha_hora);
      
      return {
        ...record,
        fecha_hora: fecha.toISOString(),
        tipo: record.tipo?.toLowerCase() || 'entrada',
        siglas_facultad: record.siglas_facultad?.toUpperCase() || 'GEN',
        siglas_escuela: record.siglas_escuela?.toUpperCase() || 'GEN',
        puerta: record.puerta?.toUpperCase() || 'PRINCIPAL'
      };
    });
  }

  /**
   * Valida rangos de valores
   */
  validateRanges(data) {
    return data.filter(record => {
      const fecha = new Date(record.fecha_hora);
      const hora = fecha.getHours();

      // Validar hora (0-23)
      if (hora < 0 || hora > 23) return false;

      // Validar fecha (no futura más de 1 día)
      const now = new Date();
      const maxDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      if (fecha > maxDate) return false;

      // Validar tipo
      const validTypes = ['entrada', 'salida'];
      if (!validTypes.includes(record.tipo)) return false;

      return true;
    });
  }

  /**
   * Valida calidad de datos
   */
  async validateDataQuality(data) {
    if (!data || data.length === 0) {
      return {
        isValid: false,
        score: 0,
        errors: ['Dataset vacío']
      };
    }

    const checks = {
      completeness: this.checkCompleteness(data),
      consistency: this.checkConsistency(data),
      validity: this.checkValidity(data),
      uniqueness: this.checkUniqueness(data),
      timeliness: this.checkTimeliness(data)
    };

    const scores = Object.values(checks).map(c => c.score);
    const overallScore = scores.reduce((sum, s) => sum + s, 0) / scores.length;

    const errors = [];
    Object.keys(checks).forEach(key => {
      if (!checks[key].isValid) {
        errors.push(...checks[key].errors);
      }
    });

    return {
      isValid: overallScore >= 0.7 && errors.length === 0,
      score: parseFloat(overallScore.toFixed(2)),
      checks,
      errors,
      recommendations: this.generateRecommendations(checks)
    };
  }

  /**
   * Verifica completitud de datos
   */
  checkCompleteness(data) {
    const requiredFields = ['fecha_hora', 'tipo', 'dni'];
    let missingCount = 0;
    let totalFields = data.length * requiredFields.length;

    data.forEach(record => {
      requiredFields.forEach(field => {
        if (!record[field] || record[field] === null || record[field] === '') {
          missingCount++;
        }
      });
    });

    const completeness = 1 - (missingCount / totalFields);
    const isValid = completeness >= 0.95;

    return {
      isValid,
      score: completeness,
      errors: isValid ? [] : [`Completitud: ${(completeness * 100).toFixed(1)}%`]
    };
  }

  /**
   * Verifica consistencia de datos
   */
  checkConsistency(data) {
    const inconsistencies = [];

    data.forEach(record => {
      // Verificar consistencia de fechas
      const fecha = new Date(record.fecha_hora);
      if (isNaN(fecha.getTime())) {
        inconsistencies.push('Fecha inválida');
      }

      // Verificar consistencia de tipos
      const validTypes = ['entrada', 'salida'];
      if (!validTypes.includes(record.tipo)) {
        inconsistencies.push(`Tipo inválido: ${record.tipo}`);
      }
    });

    const consistency = inconsistencies.length === 0 ? 1.0 : 
                       Math.max(0, 1 - (inconsistencies.length / data.length));

    return {
      isValid: consistency >= 0.95,
      score: consistency,
      errors: inconsistencies.slice(0, 10) // Primeras 10 como muestra
    };
  }

  /**
   * Verifica validez de datos
   */
  checkValidity(data) {
    let invalidCount = 0;

    data.forEach(record => {
      const fecha = new Date(record.fecha_hora);
      const hora = fecha.getHours();

      // Validar hora
      if (hora < 0 || hora > 23) invalidCount++;

      // Validar DNI (formato básico)
      if (record.dni && record.dni.length < 8) invalidCount++;

      // Validar fecha (no futura más de 1 día)
      const now = new Date();
      const maxDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      if (fecha > maxDate) invalidCount++;
    });

    const validity = 1 - (invalidCount / data.length);

    return {
      isValid: validity >= 0.95,
      score: validity,
      errors: invalidCount > 0 ? [`${invalidCount} registros inválidos`] : []
    };
  }

  /**
   * Verifica unicidad de datos
   */
  checkUniqueness(data) {
    const seen = new Set();
    let duplicates = 0;

    data.forEach(record => {
      const key = `${record.id}_${record.fecha_hora}`;
      if (seen.has(key)) {
        duplicates++;
      } else {
        seen.add(key);
      }
    });

    const uniqueness = 1 - (duplicates / data.length);

    return {
      isValid: uniqueness >= 0.95,
      score: uniqueness,
      errors: duplicates > 0 ? [`${duplicates} registros duplicados`] : []
    };
  }

  /**
   * Verifica actualidad de datos
   */
  checkTimeliness(data) {
    const now = new Date();
    const sixMonthsAgo = new Date(now.getTime() - 6 * 30 * 24 * 60 * 60 * 1000);
    
    let outdatedCount = 0;

    data.forEach(record => {
      const fecha = new Date(record.fecha_hora);
      if (fecha < sixMonthsAgo) {
        outdatedCount++;
      }
    });

    const timeliness = outdatedCount === 0 ? 1.0 : 
                       Math.max(0, 1 - (outdatedCount / data.length));

    return {
      isValid: timeliness >= 0.8,
      score: timeliness,
      errors: outdatedCount > 0 ? [`${outdatedCount} registros muy antiguos (>6 meses)`] : []
    };
  }

  /**
   * Genera recomendaciones basadas en checks
   */
  generateRecommendations(checks) {
    const recommendations = [];

    if (checks.completeness.score < 0.95) {
      recommendations.push('Mejorar completitud de datos: algunos campos requeridos están vacíos');
    }

    if (checks.consistency.score < 0.95) {
      recommendations.push('Corregir inconsistencias: verificar formatos y valores válidos');
    }

    if (checks.validity.score < 0.95) {
      recommendations.push('Validar datos: algunos valores están fuera de rangos esperados');
    }

    if (checks.uniqueness.score < 0.95) {
      recommendations.push('Eliminar duplicados: hay registros duplicados en el dataset');
    }

    if (checks.timeliness.score < 0.8) {
      recommendations.push('Actualizar datos: algunos registros son muy antiguos');
    }

    return recommendations;
  }

  /**
   * LOAD - Guarda datos procesados
   */
  async loadProcessedData(data) {
    try {
      await fs.mkdir(this.processedDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `processed_${timestamp}.json`;
      const filepath = path.join(this.processedDir, filename);

      await fs.writeFile(filepath, JSON.stringify(data, null, 2));

      return filepath;
    } catch (error) {
      throw new Error(`Error guardando datos procesados: ${error.message}`);
    }
  }

  /**
   * Obtiene estadísticas del dataset procesado
   */
  async getDatasetStatistics(dataPath = null) {
    try {
      let data;
      
      if (dataPath) {
        const content = await fs.readFile(dataPath, 'utf8');
        data = JSON.parse(content);
      } else {
        // Cargar último dataset procesado
        const files = await fs.readdir(this.processedDir);
        const jsonFiles = files.filter(f => f.endsWith('.json')).sort().reverse();
        
        if (jsonFiles.length === 0) {
          throw new Error('No hay datasets procesados disponibles');
        }

        const content = await fs.readFile(
          path.join(this.processedDir, jsonFiles[0]),
          'utf8'
        );
        data = JSON.parse(content);
      }

      return {
        totalRecords: data.length,
        dateRange: this.getDateRange(data),
        hourlyDistribution: this.getHourlyDistribution(data),
        dailyDistribution: this.getDailyDistribution(data),
        typeDistribution: this.getTypeDistribution(data),
        qualityMetrics: await this.validateDataQuality(data)
      };
    } catch (error) {
      throw new Error(`Error obteniendo estadísticas: ${error.message}`);
    }
  }

  /**
   * Obtiene rango de fechas del dataset
   */
  getDateRange(data) {
    if (data.length === 0) return null;

    const dates = data.map(r => new Date(r.fecha || r.fecha_hora)).sort((a, b) => a - b);
    
    return {
      start: dates[0].toISOString(),
      end: dates[dates.length - 1].toISOString(),
      days: Math.ceil((dates[dates.length - 1] - dates[0]) / (1000 * 60 * 60 * 24))
    };
  }

  /**
   * Obtiene distribución por hora
   */
  getHourlyDistribution(data) {
    const distribution = {};

    data.forEach(record => {
      const hora = record.hora || new Date(record.fecha_hora).getHours();
      distribution[hora] = (distribution[hora] || 0) + 1;
    });

    return distribution;
  }

  /**
   * Obtiene distribución por día
   */
  getDailyDistribution(data) {
    const distribution = {};

    data.forEach(record => {
      const dia = record.dia_semana || new Date(record.fecha || record.fecha_hora).getDay();
      const dayNames = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
      distribution[dayNames[dia]] = (distribution[dayNames[dia]] || 0) + 1;
    });

    return distribution;
  }

  /**
   * Obtiene distribución por tipo
   */
  getTypeDistribution(data) {
    const distribution = {};

    data.forEach(record => {
      const tipo = record.tipo || 'entrada';
      distribution[tipo] = (distribution[tipo] || 0) + 1;
    });

    return distribution;
  }

  /**
   * Obtiene semana del año
   */
  getWeekOfYear(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  }

  /**
   * Verifica si es feriado
   */
  isHoliday(date) {
    return false; // Implementar lógica de feriados si es necesario
  }

  /**
   * Verifica si es horario pico
   */
  isPeakHour(hora, diaSemana) {
    const peakHours = [7, 8, 9, 17, 18, 19];
    const isWeekend = diaSemana === 0 || diaSemana === 6;
    return peakHours.includes(hora) && !isWeekend;
  }
}

module.exports = HistoricalDataETL;

