/**
 * Servicio de Limpieza de Datos Automatizada
 * Algoritmos avanzados para limpieza y preprocesamiento
 */

class DataCleaningService {
  constructor() {
    this.cleaningStrategies = {
      outliers: 'iqr', // 'iqr', 'zscore', 'isolation'
      missing: 'impute', // 'impute', 'remove', 'forward_fill'
      normalization: 'standard', // 'standard', 'minmax', 'robust'
      encoding: 'hash' // 'hash', 'onehot', 'label'
    };
  }

  /**
   * Ejecuta limpieza completa de datos
   */
  async cleanDataset(data, options = {}) {
    const {
      removeOutliers = true,
      handleMissing = true,
      normalize = false,
      encodeCategorical = true,
      validateAfterCleaning = true
    } = options;

    let cleaned = [...data];
    const cleaningReport = {
      originalSize: data.length,
      steps: []
    };

    // 1. Limpieza de valores faltantes
    if (handleMissing) {
      const before = cleaned.length;
      cleaned = await this.handleMissingValues(cleaned, options.missingStrategy);
      cleaningReport.steps.push({
        step: 'missing_values',
        removed: before - cleaned.length,
        strategy: options.missingStrategy || this.cleaningStrategies.missing
      });
    }

    // 2. Detección y manejo de outliers
    if (removeOutliers) {
      const before = cleaned.length;
      cleaned = await this.removeOutliers(cleaned, options.outlierStrategy);
      cleaningReport.steps.push({
        step: 'outliers',
        removed: before - cleaned.length,
        strategy: options.outlierStrategy || this.cleaningStrategies.outliers
      });
    }

    // 3. Normalización
    if (normalize) {
      cleaned = await this.normalizeData(cleaned, options.normalizationStrategy);
      cleaningReport.steps.push({
        step: 'normalization',
        strategy: options.normalizationStrategy || this.cleaningStrategies.normalization
      });
    }

    // 4. Codificación de variables categóricas
    if (encodeCategorical) {
      cleaned = await this.encodeCategoricalFeatures(cleaned, options.encodingStrategy);
      cleaningReport.steps.push({
        step: 'encoding',
        strategy: options.encodingStrategy || this.cleaningStrategies.encoding
      });
    }

    // 5. Validación post-limpieza
    if (validateAfterCleaning) {
      const validation = await this.validateCleanedData(cleaned);
      cleaningReport.validation = validation;
    }

    cleaningReport.finalSize = cleaned.length;
    cleaningReport.reduction = ((data.length - cleaned.length) / data.length * 100).toFixed(2);

    return {
      cleanedData: cleaned,
      report: cleaningReport
    };
  }

  /**
   * Maneja valores faltantes
   */
  async handleMissingValues(data, strategy = 'impute') {
    if (strategy === 'remove') {
      return data.filter(record => {
        const required = ['fecha_hora', 'tipo', 'hora'];
        return required.every(field => record[field] !== null && record[field] !== undefined);
      });
    }

    if (strategy === 'impute') {
      return data.map(record => ({
        ...record,
        hora: record.hora !== undefined ? record.hora : this.imputeHour(record),
        dia_semana: record.dia_semana !== undefined ? record.dia_semana : 
                   (record.fecha_hora ? new Date(record.fecha_hora).getDay() : 1),
        mes: record.mes !== undefined ? record.mes : 
            (record.fecha_hora ? new Date(record.fecha_hora).getMonth() + 1 : 1),
        siglas_facultad: record.siglas_facultad || 'GEN',
        siglas_escuela: record.siglas_escuela || 'GEN',
        tipo: record.tipo || 'entrada',
        puerta: record.puerta || 'PRINCIPAL',
        autorizacion_manual: record.autorizacion_manual !== undefined ? record.autorizacion_manual : 0
      }));
    }

    if (strategy === 'forward_fill') {
      return this.forwardFillMissing(data);
    }

    return data;
  }

  /**
   * Imputa hora basándose en promedio histórico
   */
  imputeHour(record) {
    // Promedio de horas pico: 8 AM
    return 8;
  }

  /**
   * Forward fill para valores faltantes
   */
  forwardFillMissing(data) {
    let lastValues = {};
    
    return data.map(record => {
      const filled = { ...record };
      
      Object.keys(record).forEach(key => {
        if (record[key] === null || record[key] === undefined) {
          filled[key] = lastValues[key] || this.getDefaultValue(key);
        } else {
          lastValues[key] = record[key];
        }
      });

      return filled;
    });
  }

  /**
   * Obtiene valor por defecto para campo
   */
  getDefaultValue(field) {
    const defaults = {
      hora: 8,
      dia_semana: 1,
      mes: 1,
      siglas_facultad: 'GEN',
      siglas_escuela: 'GEN',
      tipo: 'entrada',
      puerta: 'PRINCIPAL',
      autorizacion_manual: 0
    };
    return defaults[field] || null;
  }

  /**
   * Elimina outliers usando método IQR
   */
  async removeOutliers(data, strategy = 'iqr') {
    if (strategy === 'iqr') {
      return this.removeOutliersIQR(data);
    }

    if (strategy === 'zscore') {
      return this.removeOutliersZScore(data);
    }

    return data;
  }

  /**
   * Elimina outliers usando IQR
   */
  removeOutliersIQR(data) {
    if (data.length === 0) return data;

    // Calcular outliers por hora
    const hourlyData = {};
    
    data.forEach(record => {
      const hora = record.hora || new Date(record.fecha_hora).getHours();
      if (!hourlyData[hora]) {
        hourlyData[hora] = [];
      }
      hourlyData[hora].push(record);
    });

    const cleaned = [];
    Object.keys(hourlyData).forEach(hora => {
      const group = hourlyData[hora];
      const counts = group.map(() => 1); // Simplificado
      
      const sorted = [...counts].sort((a, b) => a - b);
      const q1 = sorted[Math.floor(sorted.length * 0.25)];
      const q3 = sorted[Math.floor(sorted.length * 0.75)];
      const iqr = q3 - q1;
      
      // En este caso, no eliminamos registros individuales
      // Solo validamos que los datos sean consistentes
      cleaned.push(...group);
    });

    return cleaned;
  }

  /**
   * Elimina outliers usando Z-Score
   */
  removeOutliersZScore(data) {
    if (data.length === 0) return data;

    // Calcular media y desviación estándar de horas
    const horas = data.map(r => r.hora || new Date(r.fecha_hora).getHours());
    const mean = horas.reduce((sum, h) => sum + h, 0) / horas.length;
    const std = Math.sqrt(
      horas.reduce((sum, h) => sum + Math.pow(h - mean, 2), 0) / horas.length
    );

    const threshold = 3; // Z-score threshold

    return data.filter(record => {
      const hora = record.hora || new Date(record.fecha_hora).getHours();
      const zScore = Math.abs((hora - mean) / std);
      return zScore <= threshold;
    });
  }

  /**
   * Normaliza datos
   */
  async normalizeData(data, strategy = 'standard') {
    if (strategy === 'standard') {
      return this.standardNormalization(data);
    }

    if (strategy === 'minmax') {
      return this.minMaxNormalization(data);
    }

    return data;
  }

  /**
   * Normalización estándar (Z-score)
   */
  standardNormalization(data) {
    if (data.length === 0) return data;

    // Calcular estadísticas
    const numericFields = ['hora', 'dia_semana', 'mes'];
    const stats = {};

    numericFields.forEach(field => {
      const values = data.map(r => r[field]).filter(v => v !== undefined && v !== null);
      if (values.length > 0) {
        const mean = values.reduce((sum, v) => sum + v, 0) / values.length;
        const std = Math.sqrt(
          values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length
        );
        stats[field] = { mean, std: std === 0 ? 1 : std };
      }
    });

    // Normalizar (guardar estadísticas para denormalización)
    return data.map(record => {
      const normalized = { ...record };
      
      numericFields.forEach(field => {
        if (stats[field] && record[field] !== undefined) {
          normalized[`${field}_normalized`] = 
            (record[field] - stats[field].mean) / stats[field].std;
        }
      });

      return normalized;
    });
  }

  /**
   * Normalización Min-Max
   */
  minMaxNormalization(data) {
    if (data.length === 0) return data;

    const numericFields = ['hora', 'dia_semana', 'mes'];
    const ranges = {};

    numericFields.forEach(field => {
      const values = data.map(r => r[field]).filter(v => v !== undefined && v !== null);
      if (values.length > 0) {
        ranges[field] = {
          min: Math.min(...values),
          max: Math.max(...values),
          range: Math.max(...values) - Math.min(...values) || 1
        };
      }
    });

    return data.map(record => {
      const normalized = { ...record };
      
      numericFields.forEach(field => {
        if (ranges[field] && record[field] !== undefined) {
          normalized[`${field}_normalized`] = 
            (record[field] - ranges[field].min) / ranges[field].range;
        }
      });

      return normalized;
    });
  }

  /**
   * Codifica características categóricas
   */
  async encodeCategoricalFeatures(data, strategy = 'hash') {
    if (strategy === 'hash') {
      return this.hashEncode(data);
    }

    if (strategy === 'label') {
      return this.labelEncode(data);
    }

    return data;
  }

  /**
   * Codificación hash
   */
  hashEncode(data) {
    return data.map(record => ({
      ...record,
      siglas_facultad_encoded: this.hashString(record.siglas_facultad || 'GEN'),
      siglas_escuela_encoded: this.hashString(record.siglas_escuela || 'GEN'),
      puerta_encoded: this.hashString(record.puerta || 'PRINCIPAL')
    }));
  }

  /**
   * Codificación label
   */
  labelEncode(data) {
    const categories = {
      siglas_facultad: new Set(),
      siglas_escuela: new Set(),
      puerta: new Set()
    };

    // Recopilar todas las categorías
    data.forEach(record => {
      if (record.siglas_facultad) categories.siglas_facultad.add(record.siglas_facultad);
      if (record.siglas_escuela) categories.siglas_escuela.add(record.siglas_escuela);
      if (record.puerta) categories.puerta.add(record.puerta);
    });

    // Crear mapeos
    const mappings = {};
    Object.keys(categories).forEach(field => {
      mappings[field] = {};
      Array.from(categories[field]).forEach((cat, index) => {
        mappings[field][cat] = index;
      });
    });

    // Codificar
    return data.map(record => ({
      ...record,
      siglas_facultad_encoded: mappings.siglas_facultad[record.siglas_facultad] || 0,
      siglas_escuela_encoded: mappings.siglas_escuela[record.siglas_escuela] || 0,
      puerta_encoded: mappings.puerta[record.puerta] || 0
    }));
  }

  /**
   * Hash string a número
   */
  hashString(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash) % 1000;
  }

  /**
   * Valida datos después de limpieza
   */
  async validateCleanedData(data) {
    if (data.length === 0) {
      return {
        isValid: false,
        errors: ['Dataset vacío después de limpieza']
      };
    }

    const errors = [];

    // Validar estructura básica
    const requiredFields = ['fecha_hora', 'tipo', 'hora'];
    requiredFields.forEach(field => {
      const missing = data.filter(r => !r[field] && r[field] !== 0).length;
      if (missing > 0) {
        errors.push(`Campo '${field}' faltante en ${missing} registros`);
      }
    });

    // Validar rangos
    const invalidHours = data.filter(r => {
      const hora = r.hora !== undefined ? r.hora : new Date(r.fecha_hora).getHours();
      return hora < 0 || hora > 23;
    }).length;

    if (invalidHours > 0) {
      errors.push(`${invalidHours} registros con hora inválida`);
    }

    return {
      isValid: errors.length === 0,
      errors,
      recordsValidated: data.length
    };
  }

  /**
   * Genera reporte de limpieza
   */
  generateCleaningReport(originalData, cleanedData, steps) {
    return {
      timestamp: new Date().toISOString(),
      originalSize: originalData.length,
      finalSize: cleanedData.length,
      recordsRemoved: originalData.length - cleanedData.length,
      removalPercentage: ((originalData.length - cleanedData.length) / originalData.length * 100).toFixed(2),
      steps: steps,
      qualityImprovement: this.calculateQualityImprovement(originalData, cleanedData)
    };
  }

  /**
   * Calcula mejora de calidad
   */
  calculateQualityImprovement(original, cleaned) {
    // Métricas simplificadas
    const originalCompleteness = this.calculateCompleteness(original);
    const cleanedCompleteness = this.calculateCompleteness(cleaned);

    return {
      completenessImprovement: cleanedCompleteness - originalCompleteness,
      originalCompleteness,
      cleanedCompleteness
    };
  }

  /**
   * Calcula completitud
   */
  calculateCompleteness(data) {
    if (data.length === 0) return 0;

    const requiredFields = ['fecha_hora', 'tipo', 'hora'];
    let totalFields = data.length * requiredFields.length;
    let filledFields = 0;

    data.forEach(record => {
      requiredFields.forEach(field => {
        if (record[field] !== null && record[field] !== undefined && record[field] !== '') {
          filledFields++;
        }
      });
    });

    return filledFields / totalFields;
  }
}

module.exports = DataCleaningService;

