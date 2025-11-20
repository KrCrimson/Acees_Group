/**
 * Servicio de Comparación ML vs Datos Reales
 * Compara predicciones del modelo con datos históricos reales
 */

class MLRealComparison {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
  }

  /**
   * Compara predicciones ML con datos reales para un rango de fechas
   */
  async compareMLvsReal(predictions, dateRange) {
    try {
      const startDate = new Date(dateRange.startDate);
      const endDate = new Date(dateRange.endDate);
      
      // Obtener datos reales de la base de datos
      const realData = await this.getRealData(startDate, endDate);
      
      // Agrupar datos reales por fecha y hora
      const realDataByHour = this.groupByHour(realData);
      
      // Comparar predicciones con datos reales
      const comparison = this.comparePredictions(predictions, realDataByHour);
      
      return {
        dateRange: { startDate, endDate },
        comparison,
        accuracy: this.calculateOverallAccuracy(comparation),
        summary: this.generateComparisonSummary(comparison)
      };
    } catch (error) {
      throw new Error(`Error comparando ML vs Real: ${error.message}`);
    }
  }

  /**
   * Obtiene datos reales de la base de datos
   */
  async getRealData(startDate, endDate) {
    const asistencias = await this.Asistencia.find({
      fecha_hora: {
        $gte: startDate,
        $lte: endDate
      }
    }).sort({ fecha_hora: 1 });

    return asistencias.map(a => ({
      fecha: new Date(a.fecha_hora),
      hora: new Date(a.fecha_hora).getHours(),
      dia_semana: new Date(a.fecha_hora).getDay(),
      tipo: a.tipo,
      puerta: a.puerta,
      facultad: a.siglas_facultad,
      autorizacion_manual: a.autorizacion_manual || false
    }));
  }

  /**
   * Agrupa datos reales por fecha y hora
   */
  groupByHour(realData) {
    const grouped = {};

    realData.forEach(record => {
      const fechaKey = this.getDateKey(record.fecha);
      const hora = record.hora;

      if (!grouped[fechaKey]) {
        grouped[fechaKey] = {};
      }

      if (!grouped[fechaKey][hora]) {
        grouped[fechaKey][hora] = {
          count: 0,
          entradas: 0,
          salidas: 0,
          autorizaciones_manuales: 0
        };
      }

      grouped[fechaKey][hora].count++;
      if (record.tipo === 'entrada') {
        grouped[fechaKey][hora].entradas++;
      } else {
        grouped[fechaKey][hora].salidas++;
      }
      
      if (record.autorizacion_manual) {
        grouped[fechaKey][hora].autorizaciones_manuales++;
      }
    });

    return grouped;
  }

  /**
   * Compara predicciones con datos reales
   */
  comparePredictions(predictions, realDataByHour) {
    const comparison = [];

    predictions.forEach(prediction => {
      const fechaKey = this.getDateKey(prediction.fecha);
      const realDataForDate = realDataByHour[fechaKey] || {};

      const hourlyComparison = prediction.predictions.map(pred => {
        const real = realDataForDate[pred.hora] || {
          count: 0,
          entradas: 0,
          salidas: 0,
          autorizaciones_manuales: 0
        };

        const difference = pred.predictedCount - real.count;
        const error = Math.abs(difference);
        const errorPercentage = real.count > 0 
          ? (error / real.count * 100).toFixed(2)
          : pred.predictedCount > 0 ? 100 : 0;

        return {
          hora: pred.hora,
          fecha: prediction.fecha,
          predicted: pred.predictedCount,
          real: real.count,
          difference,
          error,
          errorPercentage: parseFloat(errorPercentage),
          accuracy: this.calculateHourAccuracy(pred.predictedCount, real.count),
          confidence: pred.confidence
        };
      });

      // Comparar horarios pico
      const predictedPeakHours = prediction.peakHours.map(ph => ph.hora);
      const realPeakHours = this.getRealPeakHours(realDataForDate);

      comparison.push({
        fecha: prediction.fecha,
        dia_semana: prediction.dia_semana,
        totalPredicted: prediction.totalPredicted,
        totalReal: Object.values(realDataForDate).reduce((sum, h) => sum + h.count, 0),
        hourlyComparison,
        peakHoursComparison: {
          predicted: predictedPeakHours,
          real: realPeakHours,
          match: this.comparePeakHours(predictedPeakHours, realPeakHours)
        }
      });
    });

    return comparison;
  }

  /**
   * Obtiene horarios pico reales (top 3 horas)
   */
  getRealPeakHours(realDataForDate) {
    const hours = Object.entries(realDataForDate)
      .map(([hora, data]) => ({
        hora: parseInt(hora),
        count: data.count
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 3)
      .map(h => h.hora);

    return hours;
  }

  /**
   * Compara horarios pico predichos vs reales
   */
  comparePeakHours(predicted, real) {
    const matches = predicted.filter(h => real.includes(h)).length;
    const totalMatches = Math.max(predicted.length, real.length);
    
    return {
      matches,
      matchPercentage: (matches / totalMatches * 100).toFixed(2),
      predictedOnly: predicted.filter(h => !real.includes(h)),
      realOnly: real.filter(h => !predicted.includes(h))
    };
  }

  /**
   * Calcula precisión por hora
   */
  calculateHourAccuracy(predicted, real) {
    if (real === 0 && predicted === 0) return 100;
    if (real === 0) return 0;
    
    const error = Math.abs(predicted - real);
    const accuracy = Math.max(0, 100 - (error / real * 100));
    return parseFloat(accuracy.toFixed(2));
  }

  /**
   * Calcula precisión general
   */
  calculateOverallAccuracy(comparison) {
    let totalAccuracy = 0;
    let count = 0;

    comparison.forEach(day => {
      day.hourlyComparison.forEach(hour => {
        totalAccuracy += hour.accuracy;
        count++;
      });
    });

    return count > 0 ? (totalAccuracy / count).toFixed(2) : 0;
  }

  /**
   * Genera resumen de comparación
   */
  generateComparisonSummary(comparison) {
    const totalDays = comparison.length;
    let totalPredicted = 0;
    let totalReal = 0;
    const hourAccuracy = {};

    comparison.forEach(day => {
      totalPredicted += day.totalPredicted;
      totalReal += day.totalReal;

      day.hourlyComparison.forEach(hour => {
        if (!hourAccuracy[hour.hora]) {
          hourAccuracy[hour.hora] = {
            totalAccuracy: 0,
            count: 0,
            totalError: 0
          };
        }

        hourAccuracy[hour.hora].totalAccuracy += hour.accuracy;
        hourAccuracy[hour.hora].count++;
        hourAccuracy[hour.hora].totalError += hour.error;
      });
    });

    // Calcular promedio de precisión por hora
    const avgAccuracyByHour = Object.entries(hourAccuracy).map(([hora, stats]) => ({
      hora: parseInt(hora),
      avgAccuracy: parseFloat((stats.totalAccuracy / stats.count).toFixed(2)),
      avgError: parseFloat((stats.totalError / stats.count).toFixed(2)),
      sampleCount: stats.count
    })).sort((a, b) => b.avgAccuracy - a.avgAccuracy);

    // Calcular precisión de horarios pico
    const peakHoursAccuracy = comparison.reduce((acc, day) => {
      const matchPercentage = parseFloat(day.peakHoursComparison.match.matchPercentage);
      return acc + matchPercentage;
    }, 0) / totalDays;

    return {
      totalDays,
      totalPredicted,
      totalReal,
      totalDifference: totalPredicted - totalReal,
      avgAccuracyByHour,
      peakHoursAccuracy: parseFloat(peakHoursAccuracy.toFixed(2)),
      bestPredictedHours: avgAccuracyByHour.slice(0, 5),
      worstPredictedHours: avgAccuracyByHour.slice(-5).reverse()
    };
  }

  /**
   * Obtiene clave de fecha para agrupación
   */
  getDateKey(date) {
    const d = new Date(date);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }
}

module.exports = MLRealComparison;

