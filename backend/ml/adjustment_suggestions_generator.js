/**
 * Generador de Ajustes Sugeridos
 * Genera recomendaciones basadas en diferencias entre ML y datos reales
 */

class AdjustmentSuggestionsGenerator {
  /**
   * Genera sugerencias de ajuste basadas en comparación ML vs Real
   */
  generateSuggestions(comparison, summary) {
    const suggestions = [];

    // 1. Ajustes por precisión general
    const overallAccuracy = parseFloat(summary.accuracy || 0);
    if (overallAccuracy < 70) {
      suggestions.push({
        type: 'MODEL_RETRAINING',
        priority: 'HIGH',
        title: 'Reentrenar Modelo',
        description: `La precisión general del modelo es ${overallAccuracy}%, lo cual es bajo. Se recomienda reentrenar con más datos históricos o ajustar parámetros.`,
        impact: 'high',
        effort: 'medium'
      });
    }

    // 2. Ajustes por horarios con baja precisión
    const worstHours = summary.worstPredictedHours || [];
    if (worstHours.length > 0) {
      worstHours.forEach(hour => {
        if (hour.avgAccuracy < 60) {
          suggestions.push({
            type: 'HOUR_ADJUSTMENT',
            priority: 'MEDIUM',
            title: `Ajustar Predicciones para Hora ${hour.hora}:00`,
            description: `La hora ${hour.hora}:00 tiene una precisión promedio de ${hour.avgAccuracy}% con un error promedio de ${hour.avgError} accesos. Se recomienda revisar factores específicos de esta hora.`,
            hour: hour.hora,
            impact: 'medium',
            effort: 'low'
          });
        }
      });
    }

    // 3. Ajustes por horarios pico
    const peakHoursAccuracy = parseFloat(summary.peakHoursAccuracy || 0);
    if (peakHoursAccuracy < 50) {
      suggestions.push({
        type: 'PEAK_HOURS_DETECTION',
        priority: 'HIGH',
        title: 'Mejorar Detección de Horarios Pico',
        description: `La precisión en la detección de horarios pico es ${peakHoursAccuracy}%. El modelo no está identificando correctamente los horarios de mayor actividad.`,
        impact: 'high',
        effort: 'medium'
      });
    }

    // 4. Ajustes por diferencia total
    const totalDifference = summary.totalDifference || 0;
    const totalReal = summary.totalReal || 1;
    const differencePercentage = Math.abs(totalDifference / totalReal * 100);

    if (differencePercentage > 20) {
      const direction = totalDifference > 0 ? 'sobreestimando' : 'subestimando';
      suggestions.push({
        type: 'VOLUME_CALIBRATION',
        priority: 'MEDIUM',
        title: 'Ajustar Calibración de Volumen',
        description: `El modelo está ${direction} el volumen total de accesos en un ${differencePercentage.toFixed(1)}%. Se recomienda ajustar los factores de escala en la estimación de volumen.`,
        impact: 'medium',
        effort: 'low'
      });
    }

    // 5. Ajustes por días específicos
    const lowAccuracyDays = comparison.filter(day => {
      const dayAccuracy = day.hourlyComparison.reduce((sum, h) => sum + h.accuracy, 0) / day.hourlyComparison.length;
      return dayAccuracy < 60;
    });

    if (lowAccuracyDays.length > 0) {
      const days = lowAccuracyDays.map(d => d.dia_semana).join(', ');
      suggestions.push({
        type: 'DAY_SPECIFIC_ADJUSTMENT',
        priority: 'LOW',
        title: 'Ajustar Predicciones para Días Específicos',
        description: `Los días ${days} muestran menor precisión. Se recomienda considerar factores específicos de estos días (eventos, feriados, etc.)`,
        impact: 'low',
        effort: 'medium'
      });
    }

    // 6. Sugerencias de recopilación de datos
    if (summary.totalDays < 7) {
      suggestions.push({
        type: 'DATA_COLLECTION',
        priority: 'MEDIUM',
        title: 'Recopilar Más Datos para Validación',
        description: `Solo se están comparando ${summary.totalDays} días. Se recomienda comparar con al menos 7 días para obtener resultados más confiables.`,
        impact: 'medium',
        effort: 'low'
      });
    }

    // 7. Sugerencias de features
    const featuresToConsider = this.suggestFeatureImprovements(comparison);
    if (featuresToConsider.length > 0) {
      suggestions.push({
        type: 'FEATURE_ENGINEERING',
        priority: 'LOW',
        title: 'Mejorar Características del Modelo',
        description: `Considerar agregar las siguientes características al modelo: ${featuresToConsider.join(', ')}`,
        suggestedFeatures: featuresToConsider,
        impact: 'low',
        effort: 'high'
      });
    }

    // Ordenar sugerencias por prioridad
    const priorityOrder = { HIGH: 1, MEDIUM: 2, LOW: 3 };
    suggestions.sort((a, b) => priorityOrder[a.priority] - priorityOrder[b.priority]);

    return {
      totalSuggestions: suggestions.length,
      byPriority: {
        high: suggestions.filter(s => s.priority === 'HIGH'),
        medium: suggestions.filter(s => s.priority === 'MEDIUM'),
        low: suggestions.filter(s => s.priority === 'LOW')
      },
      suggestions
    };
  }

  /**
   * Sugiere mejoras en características basándose en análisis
   */
  suggestFeatureImprovements(comparison) {
    const features = [];

    // Analizar si hay patrones por puerta
    const doorsImpact = this.analyzeDoorImpact(comparison);
    if (doorsImpact > 0.3) {
      features.push('distribución_por_puerta');
    }

    // Analizar si hay patrones por facultad
    const facultyImpact = this.analyzeFacultyImpact(comparison);
    if (facultyImpact > 0.3) {
      features.push('distribución_por_facultad');
    }

    // Analizar si hay patrones por día de la semana
    const weekdayImpact = this.analyzeWeekdayImpact(comparison);
    if (weekdayImpact > 0.4) {
      features.push('patrones_por_día_semana');
    }

    return features;
  }

  /**
   * Analiza impacto de puertas en precisión
   */
  analyzeDoorImpact(comparison) {
    // Implementación simplificada
    // En producción, analizar correlación entre puertas y errores
    return 0.2; // Placeholder
  }

  /**
   * Analiza impacto de facultades en precisión
   */
  analyzeFacultyImpact(comparison) {
    // Implementación simplificada
    return 0.25; // Placeholder
  }

  /**
   * Analiza impacto de día de semana en precisión
   */
  analyzeWeekdayImpact(comparison) {
    // Implementación simplificada
    return 0.35; // Placeholder
  }

  /**
   * Genera acciones específicas basadas en sugerencias
   */
  generateActionPlan(suggestions) {
    const actions = [];

    suggestions.suggestions.forEach((suggestion, index) => {
      actions.push({
        id: index + 1,
        suggestion: suggestion.title,
        type: suggestion.type,
        priority: suggestion.priority,
        steps: this.getActionSteps(suggestion),
        estimatedTime: this.estimateTime(suggestion.effort),
        expectedImpact: suggestion.impact
      });
    });

    return {
      totalActions: actions.length,
      actions,
      timeline: this.generateTimeline(actions)
    };
  }

  /**
   * Obtiene pasos de acción específicos
   */
  getActionSteps(suggestion) {
    const stepsMap = {
      'MODEL_RETRAINING': [
        'Recopilar dataset actualizado (≥3 meses)',
        'Ejecutar pipeline de entrenamiento',
        'Validar métricas del nuevo modelo',
        'Desplegar nuevo modelo en producción'
      ],
      'HOUR_ADJUSTMENT': [
        `Analizar factores específicos de la hora ${suggestion.hour}:00`,
        'Ajustar factores de escala para esta hora',
        'Validar predicciones ajustadas',
        'Actualizar modelo con nuevos parámetros'
      ],
      'PEAK_HOURS_DETECTION': [
        'Analizar patrones históricos de horarios pico',
        'Ajustar algoritmo de identificación',
        'Validar con datos históricos',
        'Reentrenar modelo si es necesario'
      ],
      'VOLUME_CALIBRATION': [
        'Analizar distribución de errores',
        'Ajustar factores de escala globales',
        'Validar predicciones calibradas',
        'Actualizar modelo'
      ],
      'DATA_COLLECTION': [
        'Extender período de validación',
        'Recopilar datos adicionales',
        'Reejecutar comparación',
        'Actualizar métricas'
      ],
      'FEATURE_ENGINEERING': [
        'Implementar nuevas características',
        'Recopilar datos con nuevas features',
        'Reentrenar modelo',
        'Validar mejora en métricas'
      ]
    };

    return stepsMap[suggestion.type] || ['Revisar sugerencia específica'];
  }

  /**
   * Estima tiempo de implementación
   */
  estimateTime(effort) {
    const timeMap = {
      'low': '1-2 horas',
      'medium': '4-8 horas',
      'high': '1-2 días'
    };
    return timeMap[effort] || 'Por determinar';
  }

  /**
   * Genera timeline de acciones
   */
  generateTimeline(actions) {
    const highPriority = actions.filter(a => a.priority === 'HIGH');
    const mediumPriority = actions.filter(a => a.priority === 'MEDIUM');
    const lowPriority = actions.filter(a => a.priority === 'LOW');

    return {
      immediate: highPriority.map(a => a.id),
      shortTerm: mediumPriority.map(a => a.id),
      longTerm: lowPriority.map(a => a.id)
    };
  }
}

module.exports = AdjustmentSuggestionsGenerator;

