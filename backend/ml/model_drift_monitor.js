/**
 * Monitor de Drift del Modelo
 * Detecta cambios en distribución de datos que afectan el modelo
 */

class ModelDriftMonitor {
  constructor() {
    this.driftThresholds = {
      statistical: 0.3, // KS test threshold
      feature: 0.2, // Feature distribution change
      performance: 0.1 // Performance degradation
    };
  }

  /**
   * Monitorea drift completo del modelo
   */
  async monitorDrift(currentModel, newData, historicalData = null) {
    const driftResults = {
      statistical: null,
      feature: null,
      performance: null,
      overall: null
    };

    try {
      // 1. Drift estadístico
      driftResults.statistical = await this.detectStatisticalDrift(
        currentModel,
        newData,
        historicalData
      );

      // 2. Drift de características
      driftResults.feature = await this.detectFeatureDrift(
        currentModel,
        newData,
        historicalData
      );

      // 3. Drift de performance
      driftResults.performance = await this.detectPerformanceDrift(
        currentModel,
        newData
      );

      // Calcular score general
      const scores = [
        driftResults.statistical?.score || 0,
        driftResults.feature?.score || 0,
        driftResults.performance?.score || 0
      ].filter(s => s > 0);

      driftResults.overall = {
        score: scores.length > 0 ? scores.reduce((sum, s) => sum + s, 0) / scores.length : 0,
        detected: scores.some(s => s > this.driftThresholds.statistical),
        severity: this.calculateSeverity(scores)
      };

      return driftResults;
    } catch (error) {
      throw new Error(`Error monitoreando drift: ${error.message}`);
    }
  }

  /**
   * Detecta drift estadístico usando KS test
   */
  async detectStatisticalDrift(currentModel, newData, historicalData) {
    try {
      // Calcular distribución de características en datos nuevos
      const newDistribution = this.calculateFeatureDistribution(newData);

      // Calcular distribución histórica
      let historicalDistribution = null;
      if (historicalData) {
        historicalDistribution = this.calculateFeatureDistribution(historicalData);
      } else if (currentModel.modelData?.dataStats) {
        historicalDistribution = currentModel.modelData.dataStats;
      }

      if (!historicalDistribution) {
        return {
          detected: false,
          score: 0,
          reason: 'No historical data available'
        };
      }

      // Comparar distribuciones usando KS-like test
      const ksScore = this.compareDistributions(historicalDistribution, newDistribution);

      return {
        detected: ksScore > this.driftThresholds.statistical,
        score: ksScore,
        newDistribution,
        historicalDistribution,
        method: 'ks_like'
      };
    } catch (error) {
      return {
        detected: false,
        score: 0,
        error: error.message
      };
    }
  }

  /**
   * Detecta drift en características
   */
  async detectFeatureDrift(currentModel, newData, historicalData) {
    try {
      const features = currentModel.modelData.features || [];
      const featureDrifts = {};

      features.forEach(feature => {
        const newValues = this.extractFeatureValues(newData, feature);
        const historicalValues = historicalData 
          ? this.extractFeatureValues(historicalData, feature)
          : null;

        if (historicalValues && newValues.length > 0) {
          const drift = this.calculateFeatureDrift(newValues, historicalValues);
          featureDrifts[feature] = drift;
        }
      });

      const maxDrift = Math.max(...Object.values(featureDrifts).map(d => d.score || 0));
      const avgDrift = Object.values(featureDrifts).reduce((sum, d) => sum + (d.score || 0), 0) / 
                       Object.keys(featureDrifts).length;

      return {
        detected: maxDrift > this.driftThresholds.feature,
        score: avgDrift,
        maxScore: maxDrift,
        featureDrifts,
        affectedFeatures: Object.keys(featureDrifts).filter(f => 
          featureDrifts[f].score > this.driftThresholds.feature
        )
      };
    } catch (error) {
      return {
        detected: false,
        score: 0,
        error: error.message
      };
    }
  }

  /**
   * Detecta drift en performance
   */
  async detectPerformanceDrift(currentModel, newData) {
    try {
      const LinearRegression = require('./linear_regression');
      const model = new LinearRegression();
      model.setParams(currentModel.modelData.params);

      const features = currentModel.modelData.features;
      const { X, y } = this.prepareDataForPrediction(newData, features);

      if (X.length === 0) {
        return {
          detected: false,
          score: 0,
          reason: 'No prediction data available'
        };
      }

      const predictions = model.predict(X);
      const errors = predictions.map((pred, i) => Math.abs(pred - y[i]));
      const meanError = errors.reduce((sum, e) => sum + e, 0) / errors.length;

      // Comparar con error esperado del modelo
      const expectedError = currentModel.modelData.metrics?.test?.mae || 
                          currentModel.modelData.metrics?.crossValidation?.mae || 10;

      const performanceDrift = Math.abs(meanError - expectedError) / expectedError;

      return {
        detected: performanceDrift > this.driftThresholds.performance,
        score: performanceDrift,
        meanError,
        expectedError,
        degradation: performanceDrift
      };
    } catch (error) {
      return {
        detected: false,
        score: 0,
        error: error.message
      };
    }
  }

  /**
   * Calcula distribución de características
   */
  calculateFeatureDistribution(data) {
    const horas = data.map(r => {
      const fecha = new Date(r.fecha_hora);
      return fecha.getHours();
    });

    const tipos = data.map(r => r.tipo || 'entrada');

    return {
      horas: {
        mean: horas.reduce((sum, h) => sum + h, 0) / horas.length,
        std: this.calculateStd(horas),
        distribution: this.getDistribution(horas, 24)
      },
      tipos: {
        entrada: tipos.filter(t => t === 'entrada').length / tipos.length,
        salida: tipos.filter(t => t === 'salida').length / tipos.length
      }
    };
  }

  /**
   * Extrae valores de una característica
   */
  extractFeatureValues(data, feature) {
    return data.map(r => {
      if (feature === 'hora') {
        return new Date(r.fecha_hora).getHours();
      }
      return r[feature] || 0;
    }).filter(v => v !== null && v !== undefined);
  }

  /**
   * Calcula drift de característica
   */
  calculateFeatureDrift(newValues, historicalValues) {
    const newMean = newValues.reduce((sum, v) => sum + v, 0) / newValues.length;
    const historicalMean = historicalValues.reduce((sum, v) => sum + v, 0) / historicalValues.length;

    const newStd = this.calculateStd(newValues);
    const historicalStd = this.calculateStd(historicalValues);

    // Calcular diferencia normalizada
    const meanDiff = Math.abs(newMean - historicalMean) / (historicalStd || 1);
    const stdDiff = Math.abs(newStd - historicalStd) / (historicalStd || 1);

    const score = (meanDiff + stdDiff) / 2;

    return {
      score: Math.min(1, score),
      meanDiff,
      stdDiff,
      newMean,
      historicalMean
    };
  }

  /**
   * Compara distribuciones
   */
  compareDistributions(dist1, dist2) {
    // Comparar distribución de horas
    const hourDiff = Math.abs(dist1.horas.mean - dist2.horas.mean) / 24;
    const hourStdDiff = Math.abs(dist1.horas.std - dist2.horas.std) / 12;

    // Comparar distribución de tipos
    const tipoDiff = Math.abs(dist1.tipos.entrada - dist2.tipos.entrada);

    // Score combinado
    return (hourDiff + hourStdDiff + tipoDiff) / 3;
  }

  /**
   * Calcula severidad del drift
   */
  calculateSeverity(scores) {
    const maxScore = Math.max(...scores);
    
    if (maxScore > 0.5) return 'high';
    if (maxScore > 0.3) return 'medium';
    if (maxScore > 0.1) return 'low';
    return 'none';
  }

  /**
   * Obtiene distribución de valores
   */
  getDistribution(values, bins) {
    const distribution = new Array(bins).fill(0);
    values.forEach(v => {
      const bin = Math.floor(v);
      if (bin >= 0 && bin < bins) {
        distribution[bin]++;
      }
    });
    return distribution.map(count => count / values.length);
  }

  /**
   * Prepara datos para predicción
   */
  prepareDataForPrediction(data, features) {
    const X = [];
    const y = [];

    data.forEach(row => {
      const featureValues = features.map(feat => {
        const value = row[feat];
        if (typeof value === 'string') {
          return this.hashString(value);
        }
        return typeof value === 'number' && !isNaN(value) ? value : 0;
      });

      X.push(featureValues);
      y.push(row.target || 0);
    });

    return { X, y };
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
   * Calcula desviación estándar
   */
  calculateStd(values) {
    const mean = values.reduce((sum, v) => sum + v, 0) / values.length;
    const variance = values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length;
    return Math.sqrt(variance);
  }

  /**
   * Genera reporte de drift
   */
  generateDriftReport(driftResults) {
    return {
      timestamp: new Date().toISOString(),
      overall: driftResults.overall,
      details: {
        statistical: driftResults.statistical,
        feature: driftResults.feature,
        performance: driftResults.performance
      },
      recommendations: this.generateRecommendations(driftResults)
    };
  }

  /**
   * Genera recomendaciones basadas en drift
   */
  generateRecommendations(driftResults) {
    const recommendations = [];

    if (driftResults.overall.detected) {
      if (driftResults.overall.severity === 'high') {
        recommendations.push('Drift alto detectado. Se recomienda reentrenamiento completo del modelo.');
      } else if (driftResults.overall.severity === 'medium') {
        recommendations.push('Drift medio detectado. Considerar reentrenamiento incremental o completo.');
      } else {
        recommendations.push('Drift bajo detectado. Monitorear de cerca y considerar actualización incremental.');
      }
    }

    if (driftResults.feature?.affectedFeatures?.length > 0) {
      recommendations.push(
        `Características afectadas: ${driftResults.feature.affectedFeatures.join(', ')}. ` +
        'Revisar si estas características siguen siendo relevantes.'
      );
    }

    if (driftResults.performance?.detected) {
      recommendations.push(
        `Degradación de performance detectada (${(driftResults.performance.score * 100).toFixed(1)}%). ` +
        'Se recomienda reentrenamiento del modelo.'
      );
    }

    return recommendations;
  }
}

module.exports = ModelDriftMonitor;

