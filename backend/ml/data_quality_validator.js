/**
 * Servicio de Validación de Calidad de Datos
 * Valida calidad, completitud y consistencia de datos para ML
 */

class DataQualityValidator {
  constructor() {
    this.qualityThresholds = {
      completeness: 0.95,
      consistency: 0.95,
      validity: 0.95,
      uniqueness: 0.95,
      timeliness: 0.8,
      overall: 0.85
    };
  }

  /**
   * Valida calidad completa de datos
   */
  async validateDataQuality(data, options = {}) {
    const {
      checkCompleteness = true,
      checkConsistency = true,
      checkValidity = true,
      checkUniqueness = true,
      checkTimeliness = true,
      generateReport = true
    } = options;

    const checks = {};

    // 1. Completitud
    if (checkCompleteness) {
      checks.completeness = this.validateCompleteness(data);
    }

    // 2. Consistencia
    if (checkConsistency) {
      checks.consistency = this.validateConsistency(data);
    }

    // 3. Validez
    if (checkValidity) {
      checks.validity = this.validateValidity(data);
    }

    // 4. Unicidad
    if (checkUniqueness) {
      checks.uniqueness = this.validateUniqueness(data);
    }

    // 5. Actualidad
    if (checkTimeliness) {
      checks.timeliness = this.validateTimeliness(data);
    }

    // Calcular score general
    const scores = Object.values(checks).map(c => c.score || 0);
    const overallScore = scores.length > 0 
      ? scores.reduce((sum, s) => sum + s, 0) / scores.length
      : 0;

    // Determinar si cumple umbrales
    const meetsThresholds = overallScore >= this.qualityThresholds.overall &&
      Object.keys(checks).every(key => 
        checks[key].score >= (this.qualityThresholds[key] || 0)
      );

    const result = {
      isValid: meetsThresholds,
      overallScore: parseFloat(overallScore.toFixed(4)),
      meetsThresholds,
      checks,
      timestamp: new Date().toISOString()
    };

    if (generateReport) {
      result.report = this.generateQualityReport(result, data);
    }

    return result;
  }

  /**
   * Valida completitud de datos
   */
  validateCompleteness(data) {
    if (data.length === 0) {
      return {
        isValid: false,
        score: 0,
        errors: ['Dataset vacío'],
        details: {}
      };
    }

    const requiredFields = ['fecha_hora', 'tipo'];
    const optionalFields = ['hora', 'dia_semana', 'siglas_facultad', 'puerta'];
    
    const fieldCompleteness = {};
    let totalMissing = 0;
    let totalFields = 0;

    // Completitud de campos requeridos
    requiredFields.forEach(field => {
      const missing = data.filter(r => !r[field] && r[field] !== 0).length;
      const completeness = 1 - (missing / data.length);
      fieldCompleteness[field] = {
        missing,
        completeness: parseFloat(completeness.toFixed(4)),
        isRequired: true
      };
      totalMissing += missing;
      totalFields += data.length;
    });

    // Completitud de campos opcionales
    optionalFields.forEach(field => {
      const missing = data.filter(r => !r[field] && r[field] !== 0).length;
      const completeness = 1 - (missing / data.length);
      fieldCompleteness[field] = {
        missing,
        completeness: parseFloat(completeness.toFixed(4)),
        isRequired: false
      };
      totalMissing += missing;
      totalFields += data.length;
    });

    const overallCompleteness = totalFields > 0 
      ? 1 - (totalMissing / totalFields)
      : 0;

    return {
      isValid: overallCompleteness >= this.qualityThresholds.completeness,
      score: parseFloat(overallCompleteness.toFixed(4)),
      details: fieldCompleteness,
      totalMissing,
      totalFields,
      errors: overallCompleteness < this.qualityThresholds.completeness
        ? [`Completitud ${(overallCompleteness * 100).toFixed(1)}% por debajo del umbral ${(this.qualityThresholds.completeness * 100)}%`]
        : []
    };
  }

  /**
   * Valida consistencia de datos
   */
  validateConsistency(data) {
    const inconsistencies = [];
    const consistencyChecks = {
      dateFormat: 0,
      typeFormat: 0,
      hourRange: 0,
      logicalConsistency: 0
    };

    data.forEach((record, index) => {
      // Verificar formato de fecha
      try {
        const fecha = new Date(record.fecha_hora);
        if (isNaN(fecha.getTime())) {
          inconsistencies.push(`Registro ${index}: fecha inválida`);
          consistencyChecks.dateFormat++;
        }
      } catch (e) {
        inconsistencies.push(`Registro ${index}: fecha inválida`);
        consistencyChecks.dateFormat++;
      }

      // Verificar formato de tipo
      const validTypes = ['entrada', 'salida'];
      if (!validTypes.includes(record.tipo)) {
        inconsistencies.push(`Registro ${index}: tipo inválido '${record.tipo}'`);
        consistencyChecks.typeFormat++;
      }

      // Verificar rango de hora
      const hora = record.hora !== undefined ? record.hora : 
                  record.fecha_hora ? new Date(record.fecha_hora).getHours() : null;
      if (hora !== null && (hora < 0 || hora > 23)) {
        inconsistencies.push(`Registro ${index}: hora fuera de rango [0-23]`);
        consistencyChecks.hourRange++;
      }

      // Verificar consistencia lógica
      if (record.fecha_hora && record.hora !== undefined) {
        const fechaHora = new Date(record.fecha_hora).getHours();
        if (Math.abs(fechaHora - record.hora) > 1) {
          inconsistencies.push(`Registro ${index}: inconsistencia entre fecha_hora y hora`);
          consistencyChecks.logicalConsistency++;
        }
      }
    });

    const totalInconsistencies = Object.values(consistencyChecks)
      .reduce((sum, count) => sum + count, 0);
    const consistency = 1 - (totalInconsistencies / data.length);

    return {
      isValid: consistency >= this.qualityThresholds.consistency,
      score: parseFloat(Math.max(0, consistency).toFixed(4)),
      details: consistencyChecks,
      inconsistencies: inconsistencies.slice(0, 20),
      totalInconsistencies,
      errors: consistency < this.qualityThresholds.consistency
        ? [`${totalInconsistencies} inconsistencias detectadas`]
        : []
    };
  }

  /**
   * Valida validez de datos
   */
  validateValidity(data) {
    let invalidCount = 0;
    const validityChecks = {
      invalidDates: 0,
      invalidHours: 0,
      invalidTypes: 0,
      invalidValues: 0
    };

    const now = new Date();
    const maxFutureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    data.forEach((record, index) => {
      // Validar fecha (no futura más de 1 día)
      try {
        const fecha = new Date(record.fecha_hora);
        if (fecha > maxFutureDate) {
          invalidCount++;
          validityChecks.invalidDates++;
        }
      } catch (e) {
        invalidCount++;
        validityChecks.invalidDates++;
      }

      // Validar hora
      const hora = record.hora !== undefined ? record.hora : 
                  record.fecha_hora ? new Date(record.fecha_hora).getHours() : null;
      if (hora !== null && (hora < 0 || hora > 23)) {
        invalidCount++;
        validityChecks.invalidHours++;
      }

      // Validar tipo
      const validTypes = ['entrada', 'salida'];
      if (!validTypes.includes(record.tipo)) {
        invalidCount++;
        validityChecks.invalidTypes++;
      }

      // Validar valores numéricos
      if (record.dia_semana !== undefined && (record.dia_semana < 0 || record.dia_semana > 6)) {
        invalidCount++;
        validityChecks.invalidValues++;
      }
    });

    const validity = 1 - (invalidCount / data.length);

    return {
      isValid: validity >= this.qualityThresholds.validity,
      score: parseFloat(Math.max(0, validity).toFixed(4)),
      details: validityChecks,
      invalidCount,
      errors: validity < this.qualityThresholds.validity
        ? [`${invalidCount} registros inválidos`]
        : []
    };
  }

  /**
   * Valida unicidad de datos
   */
  validateUniqueness(data) {
    const seen = new Set();
    let duplicates = 0;
    const duplicateDetails = [];

    data.forEach((record, index) => {
      const key = `${record.id || index}_${record.fecha_hora}`;
      if (seen.has(key)) {
        duplicates++;
        duplicateDetails.push(index);
      } else {
        seen.add(key);
      }
    });

    const uniqueness = 1 - (duplicates / data.length);

    return {
      isValid: uniqueness >= this.qualityThresholds.uniqueness,
      score: parseFloat(Math.max(0, uniqueness).toFixed(4)),
      duplicates,
      duplicateIndices: duplicateDetails.slice(0, 50),
      errors: uniqueness < this.qualityThresholds.uniqueness
        ? [`${duplicates} registros duplicados`]
        : []
    };
  }

  /**
   * Valida actualidad de datos
   */
  validateTimeliness(data) {
    const now = new Date();
    const sixMonthsAgo = new Date(now.getTime() - 6 * 30 * 24 * 60 * 60 * 1000);
    const oneYearAgo = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);

    let outdatedCount = 0;
    let veryOldCount = 0;

    data.forEach(record => {
      try {
        const fecha = new Date(record.fecha_hora);
        if (fecha < oneYearAgo) {
          veryOldCount++;
        } else if (fecha < sixMonthsAgo) {
          outdatedCount++;
        }
      } catch (e) {
        outdatedCount++;
      }
    });

    const timeliness = 1 - ((outdatedCount + veryOldCount) / data.length);

    return {
      isValid: timeliness >= this.qualityThresholds.timeliness,
      score: parseFloat(Math.max(0, timeliness).toFixed(4)),
      outdatedCount,
      veryOldCount,
      errors: timeliness < this.qualityThresholds.timeliness
        ? [`${outdatedCount + veryOldCount} registros muy antiguos`]
        : []
    };
  }

  /**
   * Genera reporte de calidad
   */
  generateQualityReport(validationResult, data) {
    const report = {
      summary: {
        isValid: validationResult.isValid,
        overallScore: validationResult.overallScore,
        meetsThresholds: validationResult.meetsThresholds,
        totalRecords: data.length
      },
      checks: {},
      recommendations: [],
      metrics: this.calculateQualityMetrics(data)
    };

    Object.keys(validationResult.checks).forEach(key => {
      const check = validationResult.checks[key];
      report.checks[key] = {
        isValid: check.isValid,
        score: check.score,
        status: check.isValid ? 'PASS' : 'FAIL',
        threshold: this.qualityThresholds[key] || 0
      };

      if (!check.isValid) {
        report.recommendations.push(
          ...this.generateRecommendations(key, check)
        );
      }
    });

    return report;
  }

  /**
   * Calcula métricas de calidad
   */
  calculateQualityMetrics(data) {
    if (data.length === 0) {
      return {
        totalRecords: 0,
        dateRange: null,
        fieldDistribution: {}
      };
    }

    const dates = data.map(r => new Date(r.fecha_hora))
      .filter(d => !isNaN(d.getTime()))
      .sort((a, b) => a - b);

    return {
      totalRecords: data.length,
      dateRange: dates.length > 0 ? {
        start: dates[0].toISOString(),
        end: dates[dates.length - 1].toISOString(),
        days: Math.ceil((dates[dates.length - 1] - dates[0]) / (1000 * 60 * 60 * 24))
      } : null,
      fieldDistribution: {
        tipos: this.countValues(data, 'tipo'),
        facultades: this.countValues(data, 'siglas_facultad'),
        puertas: this.countValues(data, 'puerta')
      }
    };
  }

  /**
   * Cuenta valores únicos
   */
  countValues(data, field) {
    const counts = {};
    data.forEach(record => {
      const value = record[field] || 'N/A';
      counts[value] = (counts[value] || 0) + 1;
    });
    return counts;
  }

  /**
   * Genera recomendaciones
   */
  generateRecommendations(checkType, checkResult) {
    const recommendations = {
      completeness: [
        'Completar campos faltantes usando imputación o datos históricos',
        'Revisar origen de datos para campos con alta tasa de valores faltantes'
      ],
      consistency: [
        'Corregir formatos inconsistentes en fechas y tipos',
        'Validar rangos de valores antes de cargar datos'
      ],
      validity: [
        'Eliminar o corregir registros con valores fuera de rangos válidos',
        'Implementar validación en tiempo de inserción'
      ],
      uniqueness: [
        'Eliminar registros duplicados',
        'Implementar constraints de unicidad en base de datos'
      ],
      timeliness: [
        'Actualizar datos históricos',
        'Considerar recopilar datos más recientes'
      ]
    };

    return recommendations[checkType] || ['Revisar datos para este criterio'];
  }

  /**
   * Valida datos para ML específicamente
   */
  async validateForML(data) {
    const mlValidation = {
      minRecords: data.length >= 100,
      hasTarget: data.some(r => r.target !== undefined),
      hasFeatures: this.hasRequiredFeatures(data),
      dateRange: this.validateDateRange(data),
      distribution: this.validateDistribution(data)
    };

    const isValid = Object.values(mlValidation).every(v => 
      typeof v === 'boolean' ? v : v.isValid !== false
    );

    return {
      isValid,
      mlValidation,
      readyForML: isValid && data.length >= 100
    };
  }

  /**
   * Verifica si tiene características requeridas
   */
  hasRequiredFeatures(data) {
    const requiredFeatures = ['hora', 'dia_semana', 'tipo'];
    return requiredFeatures.every(feature => 
      data.some(r => r[feature] !== undefined)
    );
  }

  /**
   * Valida rango de fechas
   */
  validateDateRange(data) {
    if (data.length === 0) {
      return { isValid: false, error: 'Dataset vacío' };
    }

    const dates = data.map(r => new Date(r.fecha_hora))
      .filter(d => !isNaN(d.getTime()))
      .sort((a, b) => a - b);

    if (dates.length === 0) {
      return { isValid: false, error: 'No hay fechas válidas' };
    }

    const days = Math.ceil((dates[dates.length - 1] - dates[0]) / (1000 * 60 * 60 * 24));

    return {
      isValid: days >= 7, // Mínimo 7 días
      days,
      start: dates[0].toISOString(),
      end: dates[dates.length - 1].toISOString()
    };
  }

  /**
   * Valida distribución de datos
   */
  validateDistribution(data) {
    const types = this.countValues(data, 'tipo');
    const hasBothTypes = types['entrada'] > 0 && types['salida'] > 0;

    return {
      isValid: hasBothTypes,
      distribution: types,
      balanced: Math.abs((types['entrada'] || 0) - (types['salida'] || 0)) / data.length < 0.5
    };
  }
}

module.exports = DataQualityValidator;

