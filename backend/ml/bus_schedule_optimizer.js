/**
 * Optimizador de Horarios de Buses
 * Genera sugerencias de horarios óptimos de buses basándose en predicciones ML
 * US039 - Sugerir horarios buses
 */

const PeakHoursPredictor = require('./peak_hours_predictor');

class BusScheduleOptimizer {
  constructor(AsistenciaModel) {
    this.predictor = new PeakHoursPredictor(null, AsistenciaModel);
    this.busCapacity = 50; // Capacidad promedio de un bus
    this.minInterval = 15; // Intervalo mínimo entre buses (minutos)
    this.maxWaitTime = 30; // Tiempo máximo de espera deseado (minutos)
  }

  /**
   * Genera sugerencias de horarios de buses optimizados
   */
  async generateBusScheduleSuggestions(dateRange, options = {}) {
    const {
      busCapacity = this.busCapacity,
      minInterval = this.minInterval,
      maxWaitTime = this.maxWaitTime,
      includeReturn = true,
      optimizeForCost = false
    } = options;

    try {
      // 1. Obtener predicciones de horarios pico
      await this.predictor.loadLatestModel();
      const predictions = await this.predictor.predictPeakHours(dateRange);

      // 2. Identificar horarios pico
      const peakHours = this.identifyPeakHours(predictions.predictions);

      // 3. Optimizar horarios de ida
      const outboundSchedule = this.optimizeOutboundSchedule(
        peakHours,
        busCapacity,
        minInterval,
        maxWaitTime
      );

      // 4. Optimizar horarios de retorno (si aplica)
      let returnSchedule = null;
      if (includeReturn) {
        returnSchedule = this.optimizeReturnSchedule(
          peakHours,
          busCapacity,
          minInterval,
          maxWaitTime
        );
      }

      // 5. Calcular métricas de eficiencia
      const efficiencyMetrics = this.calculateEfficiencyMetrics(
        predictions,
        outboundSchedule,
        returnSchedule,
        busCapacity
      );

      // 6. Generar recomendaciones
      const recommendations = this.generateRecommendations(
        efficiencyMetrics,
        outboundSchedule,
        returnSchedule
      );

      return {
        dateRange: predictions.dateRange,
        outboundSchedule,
        returnSchedule,
        efficiencyMetrics,
        recommendations,
        optimizationParams: {
          busCapacity,
          minInterval,
          maxWaitTime,
          optimizeForCost
        }
      };
    } catch (error) {
      throw new Error(`Error generando sugerencias de horarios de buses: ${error.message}`);
    }
  }

  /**
   * Identifica horarios pico de las predicciones
   */
  identifyPeakHours(predictions) {
    const peakHours = [];
    const threshold = this.calculatePeakThreshold(predictions);

    predictions.forEach(pred => {
      if (pred.isPeakHour && pred.predictedTotal >= threshold) {
        peakHours.push({
          timestamp: pred.timestamp,
          fecha: pred.fecha,
          hora: pred.hora,
          predictedEntrance: pred.predictedEntrance,
          predictedExit: pred.predictedExit,
          predictedTotal: pred.predictedTotal,
          confidence: pred.confidence
        });
      }
    });

    return peakHours.sort((a, b) => a.hora - b.hora);
  }

  /**
   * Calcula threshold para identificar horarios pico
   */
  calculatePeakThreshold(predictions) {
    const totals = predictions.map(p => p.predictedTotal);
    const mean = totals.reduce((a, b) => a + b, 0) / totals.length;
    const std = Math.sqrt(
      totals.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / totals.length
    );
    return mean + std * 0.5; // Media + 0.5 desviaciones estándar
  }

  /**
   * Optimiza horarios de ida (hacia la universidad)
   */
  optimizeOutboundSchedule(peakHours, busCapacity, minInterval, maxWaitTime) {
    const schedule = [];
    const entranceHours = peakHours.filter(h => h.predictedEntrance > 0);

    // Agrupar por horas consecutivas
    const hourGroups = this.groupConsecutiveHours(entranceHours);

    hourGroups.forEach(group => {
      const totalPassengers = group.reduce((sum, h) => sum + h.predictedEntrance, 0);
      const busesNeeded = Math.ceil(totalPassengers / busCapacity);
      const startHour = group[0].hora;
      const endHour = group[group.length - 1].hora;
      const duration = endHour - startHour + 1;

      // Calcular intervalos óptimos
      const optimalInterval = this.calculateOptimalInterval(
        duration,
        busesNeeded,
        minInterval,
        maxWaitTime
      );

      // Generar horarios
      const times = this.generateScheduleTimes(startHour, endHour, optimalInterval);

      schedule.push({
        route: 'OUTBOUND',
        period: `${startHour}:00 - ${endHour}:00`,
        totalPassengers: totalPassengers,
        busesNeeded: busesNeeded,
        interval: optimalInterval,
        times: times,
        efficiency: this.calculateScheduleEfficiency(group, times, busCapacity)
      });
    });

    return schedule;
  }

  /**
   * Optimiza horarios de retorno (desde la universidad)
   */
  optimizeReturnSchedule(peakHours, busCapacity, minInterval, maxWaitTime) {
    const schedule = [];
    const exitHours = peakHours.filter(h => h.predictedExit > 0);

    // Agrupar por horas consecutivas
    const hourGroups = this.groupConsecutiveHours(exitHours);

    hourGroups.forEach(group => {
      const totalPassengers = group.reduce((sum, h) => sum + h.predictedExit, 0);
      const busesNeeded = Math.ceil(totalPassengers / busCapacity);
      const startHour = group[0].hora;
      const endHour = group[group.length - 1].hora;
      const duration = endHour - startHour + 1;

      // Calcular intervalos óptimos
      const optimalInterval = this.calculateOptimalInterval(
        duration,
        busesNeeded,
        minInterval,
        maxWaitTime
      );

      // Generar horarios
      const times = this.generateScheduleTimes(startHour, endHour, optimalInterval);

      schedule.push({
        route: 'RETURN',
        period: `${startHour}:00 - ${endHour}:00`,
        totalPassengers: totalPassengers,
        busesNeeded: busesNeeded,
        interval: optimalInterval,
        times: times,
        efficiency: this.calculateScheduleEfficiency(group, times, busCapacity)
      });
    });

    return schedule;
  }

  /**
   * Agrupa horas consecutivas
   */
  groupConsecutiveHours(hours) {
    if (hours.length === 0) return [];
    
    const groups = [];
    let currentGroup = [hours[0]];

    for (let i = 1; i < hours.length; i++) {
      if (hours[i].hora === hours[i - 1].hora + 1) {
        currentGroup.push(hours[i]);
      } else {
        groups.push(currentGroup);
        currentGroup = [hours[i]];
      }
    }
    groups.push(currentGroup);

    return groups;
  }

  /**
   * Calcula intervalo óptimo entre buses
   */
  calculateOptimalInterval(duration, busesNeeded, minInterval, maxWaitTime) {
    const maxInterval = Math.min(maxWaitTime, duration * 60 / busesNeeded);
    const optimalInterval = Math.max(minInterval, Math.round(maxInterval));

    return optimalInterval;
  }

  /**
   * Genera horarios específicos
   */
  generateScheduleTimes(startHour, endHour, interval) {
    const times = [];
    const startMinutes = startHour * 60;
    const endMinutes = endHour * 60 + 59;

    for (let min = startMinutes; min <= endMinutes; min += interval) {
      const hour = Math.floor(min / 60);
      const minute = min % 60;
      times.push({
        hour: hour,
        minute: minute,
        time: `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`
      });
    }

    return times;
  }

  /**
   * Calcula eficiencia de un horario
   */
  calculateScheduleEfficiency(hourGroup, scheduleTimes, busCapacity) {
    const totalPassengers = hourGroup.reduce((sum, h) => sum + h.predictedEntrance, 0);
    const totalCapacity = scheduleTimes.length * busCapacity;
    const utilization = totalCapacity > 0 ? (totalPassengers / totalCapacity) * 100 : 0;
    
    // Penalizar sobrecapacidad o subutilización
    const efficiency = utilization > 100 
      ? 100 - (utilization - 100) * 0.5 // Penalizar sobrecapacidad
      : utilization;

    return {
      utilization: Math.round(utilization * 100) / 100,
      efficiency: Math.round(efficiency * 100) / 100,
      totalCapacity: totalCapacity,
      totalPassengers: totalPassengers
    };
  }

  /**
   * Calcula métricas de eficiencia generales
   */
  calculateEfficiencyMetrics(predictions, outboundSchedule, returnSchedule, busCapacity) {
    const totalOutboundBuses = outboundSchedule.reduce((sum, s) => sum + s.busesNeeded, 0);
    const totalReturnBuses = returnSchedule 
      ? returnSchedule.reduce((sum, s) => sum + s.busesNeeded, 0)
      : 0;

    const totalOutboundPassengers = outboundSchedule.reduce((sum, s) => sum + s.totalPassengers, 0);
    const totalReturnPassengers = returnSchedule
      ? returnSchedule.reduce((sum, s) => sum + s.totalPassengers, 0)
      : 0;

    const avgOutboundEfficiency = outboundSchedule.length > 0
      ? outboundSchedule.reduce((sum, s) => sum + s.efficiency.efficiency, 0) / outboundSchedule.length
      : 0;

    const avgReturnEfficiency = returnSchedule && returnSchedule.length > 0
      ? returnSchedule.reduce((sum, s) => sum + s.efficiency.efficiency, 0) / returnSchedule.length
      : 0;

    return {
      totalBuses: totalOutboundBuses + totalReturnBuses,
      totalPassengers: totalOutboundPassengers + totalReturnPassengers,
      averageEfficiency: (avgOutboundEfficiency + avgReturnEfficiency) / 2,
      outbound: {
        buses: totalOutboundBuses,
        passengers: totalOutboundPassengers,
        efficiency: avgOutboundEfficiency
      },
      return: {
        buses: totalReturnBuses,
        passengers: totalReturnPassengers,
        efficiency: avgReturnEfficiency
      }
    };
  }

  /**
   * Genera recomendaciones basadas en métricas
   */
  generateRecommendations(efficiencyMetrics, outboundSchedule, returnSchedule) {
    const recommendations = [];

    // Eficiencia general
    if (efficiencyMetrics.averageEfficiency < 60) {
      recommendations.push({
        type: 'EFFICIENCY_IMPROVEMENT',
        priority: 'HIGH',
        title: 'Mejorar Eficiencia de Horarios',
        description: `La eficiencia promedio es ${efficiencyMetrics.averageEfficiency.toFixed(1)}%. Considerar ajustar intervalos o capacidad de buses.`,
        action: 'Revisar horarios y ajustar intervalos entre buses'
      });
    }

    // Utilización de capacidad
    outboundSchedule.forEach(schedule => {
      if (schedule.efficiency.utilization < 50) {
        recommendations.push({
          type: 'CAPACITY_OPTIMIZATION',
          priority: 'MEDIUM',
          title: `Optimizar Capacidad en ${schedule.period}`,
          description: `La utilización de capacidad es ${schedule.efficiency.utilization.toFixed(1)}%. Considerar reducir frecuencia de buses.`,
          period: schedule.period,
          action: `Reducir frecuencia o usar buses más pequeños en ${schedule.period}`
        });
      } else if (schedule.efficiency.utilization > 120) {
        recommendations.push({
          type: 'CAPACITY_INCREASE',
          priority: 'HIGH',
          title: `Aumentar Capacidad en ${schedule.period}`,
          description: `La demanda excede la capacidad en ${schedule.efficiency.utilization.toFixed(1)}%. Se requiere más buses.`,
          period: schedule.period,
          action: `Aumentar frecuencia o capacidad de buses en ${schedule.period}`
        });
      }
    });

    // Balance entre ida y retorno
    if (returnSchedule && efficiencyMetrics.outbound.buses !== efficiencyMetrics.return.buses) {
      recommendations.push({
        type: 'ROUTE_BALANCE',
        priority: 'LOW',
        title: 'Balancear Rutas de Ida y Retorno',
        description: `Diferencia en número de buses entre ida (${efficiencyMetrics.outbound.buses}) y retorno (${efficiencyMetrics.return.buses}).`,
        action: 'Considerar balancear recursos entre rutas'
      });
    }

    return recommendations;
  }
}

module.exports = BusScheduleOptimizer;

