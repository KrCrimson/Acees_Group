/**
 * Early Stopping para Entrenamiento de Modelos
 * Detiene el entrenamiento cuando no hay mejora para evitar overfitting
 */

class EarlyStopping {
  constructor(options = {}) {
    this.patience = options.patience || 10; // Número de épocas sin mejora
    this.minDelta = options.minDelta || 0.001; // Mejora mínima considerada
    this.monitor = options.monitor || 'loss'; // Métrica a monitorear
    this.mode = options.mode || 'min'; // 'min' para loss, 'max' para accuracy
    this.restoreBestWeights = options.restoreBestWeights !== false;
    
    this.bestValue = this.mode === 'min' ? Infinity : -Infinity;
    this.wait = 0;
    this.bestWeights = null;
    this.bestBias = null;
    this.stoppedEpoch = 0;
  }

  /**
   * Verifica si debe detenerse el entrenamiento
   */
  shouldStop(currentValue, weights = null, bias = null) {
    const isBetter = this.mode === 'min' 
      ? currentValue < (this.bestValue - this.minDelta)
      : currentValue > (this.bestValue + this.minDelta);

    if (isBetter) {
      this.bestValue = currentValue;
      this.wait = 0;
      
      if (this.restoreBestWeights && weights) {
        this.bestWeights = JSON.parse(JSON.stringify(weights));
        this.bestBias = bias;
      }
    } else {
      this.wait++;
    }

    if (this.wait >= this.patience) {
      this.stoppedEpoch = this.wait;
      return true;
    }

    return false;
  }

  /**
   * Obtiene los mejores pesos guardados
   */
  getBestWeights() {
    return {
      weights: this.bestWeights,
      bias: this.bestBias,
      bestValue: this.bestValue
    };
  }

  /**
   * Reinicia el early stopping
   */
  reset() {
    this.bestValue = this.mode === 'min' ? Infinity : -Infinity;
    this.wait = 0;
    this.bestWeights = null;
    this.bestBias = null;
    this.stoppedEpoch = 0;
  }

  /**
   * Obtiene estado actual
   */
  getState() {
    return {
      bestValue: this.bestValue,
      wait: this.wait,
      patience: this.patience,
      stopped: this.wait >= this.patience
    };
  }
}

module.exports = EarlyStopping;

