/**
 * Optimizador de Parámetros para Regresión Lineal
 * Encuentra los mejores hiperparámetros usando grid search y validación cruzada
 */

const LinearRegression = require('./linear_regression');
const CrossValidation = require('./cross_validation');

class ParameterOptimizer {
  constructor() {
    this.bestParams = null;
    this.optimizationHistory = [];
  }

  /**
   * Grid Search para optimizar hiperparámetros
   */
  gridSearch(X, y, paramGrid, cv = 5) {
    const learningRates = paramGrid.learningRates || [0.001, 0.01, 0.1];
    const iterations = paramGrid.iterations || [500, 1000, 2000];
    const regularizations = paramGrid.regularizations || [0, 0.01, 0.1, 1];
    const featureScaling = paramGrid.featureScaling !== undefined 
      ? [paramGrid.featureScaling]
      : [true, false];

    const cvValidator = new CrossValidation({ k: cv });
    const results = [];

    let bestScore = -Infinity;
    let bestConfig = null;

    // Explorar todas las combinaciones
    for (const lr of learningRates) {
      for (const iter of iterations) {
        for (const reg of regularizations) {
          for (const fs of featureScaling) {
            const config = {
              learningRate: lr,
              iterations: iter,
              regularization: reg,
              featureScaling: fs
            };

            try {
              // Validación cruzada
              const cvResult = cvValidator.crossValidate(X, y, config, 'r2');

              const result = {
                config,
                cvScore: cvResult.mean,
                cvStd: cvResult.std,
                meetsThreshold: cvResult.mean >= 0.7
              };

              results.push(result);
              this.optimizationHistory.push(result);

              // Actualizar mejor configuración
              if (cvResult.mean > bestScore) {
                bestScore = cvResult.mean;
                bestConfig = config;
              }
            } catch (error) {
              console.warn(`Error con configuración ${JSON.stringify(config)}:`, error.message);
            }
          }
        }
      }
    }

    this.bestParams = bestConfig;

    return {
      bestParams: bestConfig,
      bestScore: parseFloat(bestScore.toFixed(4)),
      allResults: results.sort((a, b) => b.cvScore - a.cvScore),
      totalConfigurations: results.length,
      meetsThreshold: bestScore >= 0.7
    };
  }

  /**
   * Random Search para optimización más eficiente
   */
  randomSearch(X, y, paramGrid, nIterations = 20, cv = 5) {
    const learningRates = paramGrid.learningRates || [0.001, 0.01, 0.1];
    const iterations = paramGrid.iterations || [500, 1000, 2000];
    const regularizations = paramGrid.regularizations || [0, 0.01, 0.1, 1];
    const featureScaling = paramGrid.featureScaling !== undefined 
      ? [paramGrid.featureScaling]
      : [true, false];

    const cvValidator = new CrossValidation({ k: cv });
    const results = [];

    let bestScore = -Infinity;
    let bestConfig = null;

    // Explorar combinaciones aleatorias
    for (let i = 0; i < nIterations; i++) {
      const config = {
        learningRate: learningRates[Math.floor(Math.random() * learningRates.length)],
        iterations: iterations[Math.floor(Math.random() * iterations.length)],
        regularization: regularizations[Math.floor(Math.random() * regularizations.length)],
        featureScaling: featureScaling[Math.floor(Math.random() * featureScaling.length)]
      };

      try {
        const cvResult = cvValidator.crossValidate(X, y, config, 'r2');

        const result = {
          config,
          cvScore: cvResult.mean,
          cvStd: cvResult.std,
          meetsThreshold: cvResult.mean >= 0.7
        };

        results.push(result);
        this.optimizationHistory.push(result);

        if (cvResult.mean > bestScore) {
          bestScore = cvResult.mean;
          bestConfig = config;
        }
      } catch (error) {
        console.warn(`Error con configuración aleatoria:`, error.message);
      }
    }

    this.bestParams = bestConfig;

    return {
      bestParams: bestConfig,
      bestScore: parseFloat(bestScore.toFixed(4)),
      allResults: results.sort((a, b) => b.cvScore - a.cvScore),
      totalConfigurations: results.length,
      meetsThreshold: bestScore >= 0.7
    };
  }

  /**
   * Optimiza para alcanzar R² > 0.7
   */
  optimizeForR2(X, y, targetR2 = 0.7, cv = 5) {
    const cvValidator = new CrossValidation({ k: cv });
    
    // Configuraciones iniciales
    const initialConfigs = [
      { learningRate: 0.01, iterations: 1000, regularization: 0, featureScaling: true },
      { learningRate: 0.01, iterations: 2000, regularization: 0.01, featureScaling: true },
      { learningRate: 0.1, iterations: 1000, regularization: 0, featureScaling: true },
      { learningRate: 0.001, iterations: 2000, regularization: 0.1, featureScaling: true }
    ];

    let bestScore = -Infinity;
    let bestConfig = null;

    for (const config of initialConfigs) {
      try {
        const cvResult = cvValidator.crossValidate(X, y, config, 'r2');
        
        if (cvResult.mean > bestScore) {
          bestScore = cvResult.mean;
          bestConfig = config;
        }

        if (cvResult.mean >= targetR2) {
          this.bestParams = config;
          return {
            success: true,
            bestParams: config,
            r2: cvResult.mean,
            meetsThreshold: true,
            method: 'initial_search'
          };
        }
      } catch (error) {
        console.warn(`Error con configuración inicial:`, error.message);
      }
    }

    // Si no se alcanzó el umbral, hacer grid search más amplio
    if (bestScore < targetR2) {
      const gridResult = this.gridSearch(X, y, {
        learningRates: [0.001, 0.01, 0.1],
        iterations: [1000, 2000, 3000],
        regularizations: [0, 0.01, 0.1, 0.5],
        featureScaling: [true]
      }, cv);

      if (gridResult.bestScore >= targetR2) {
        return {
          success: true,
          bestParams: gridResult.bestParams,
          r2: gridResult.bestScore,
          meetsThreshold: true,
          method: 'grid_search'
        };
      }
    }

    // Retornar mejor encontrado aunque no alcance el umbral
    return {
      success: bestScore >= targetR2,
      bestParams: bestConfig || initialConfigs[0],
      r2: bestScore,
      meetsThreshold: bestScore >= targetR2,
      method: 'best_available',
      recommendation: bestScore < targetR2 
        ? 'Considerar más datos, features adicionales o modelos más complejos'
        : null
    };
  }

  /**
   * Obtiene mejores parámetros encontrados
   */
  getBestParams() {
    return this.bestParams;
  }

  /**
   * Obtiene historial de optimización
   */
  getOptimizationHistory() {
    return this.optimizationHistory.sort((a, b) => b.cvScore - a.cvScore);
  }
}

module.exports = ParameterOptimizer;

