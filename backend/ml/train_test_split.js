/**
 * Implementación de Train/Test Split
 * Divide el dataset en conjuntos de entrenamiento y prueba
 */

const fs = require('fs').promises;
const path = require('path');

class TrainTestSplit {
  constructor(options = {}) {
    this.testSize = options.testSize || 0.2; // 20% para test por defecto
    this.randomState = options.randomState || 42; // Semilla para reproducibilidad
    this.shuffle = options.shuffle !== false; // Mezclar por defecto
  }

  /**
   * Divide el dataset en train y test
   */
  async split(dataset, options = {}) {
    const {
      testSize = this.testSize,
      shuffle = this.shuffle,
      randomState = this.randomState,
      stratify = null // Para estratificación por clase
    } = options;

    if (!Array.isArray(dataset) || dataset.length === 0) {
      throw new Error('Dataset debe ser un array no vacío');
    }

    if (testSize <= 0 || testSize >= 1) {
      throw new Error('testSize debe estar entre 0 y 1');
    }

    let processedDataset = [...dataset];

    // Mezclar dataset si está habilitado
    if (shuffle) {
      processedDataset = this.shuffleArray(processedDataset, randomState);
    }

    // Estratificación si se especifica
    if (stratify) {
      return this.stratifiedSplit(processedDataset, testSize, stratify);
    }

    // División simple
    const testSizeInt = Math.floor(dataset.length * testSize);
    const trainSizeInt = dataset.length - testSizeInt;

    const trainSet = processedDataset.slice(0, trainSizeInt);
    const testSet = processedDataset.slice(trainSizeInt);

    return {
      train: trainSet,
      test: testSet,
      trainSize: trainSet.length,
      testSize: testSet.length,
      splitRatio: {
        train: (trainSet.length / dataset.length).toFixed(2),
        test: (testSet.length / dataset.length).toFixed(2)
      }
    };
  }

  /**
   * División estratificada (mantiene proporción de clases)
   */
  stratifiedSplit(dataset, testSize, stratifyColumn) {
    // Agrupar por clase
    const classes = {};
    dataset.forEach((row, index) => {
      const classValue = row[stratifyColumn];
      if (!classes[classValue]) {
        classes[classValue] = [];
      }
      classes[classValue].push({ row, index });
    });

    const trainSet = [];
    const testSet = [];

    // Dividir cada clase proporcionalmente
    Object.keys(classes).forEach(classValue => {
      const classData = classes[classValue];
      const shuffled = this.shuffleArray(classData, this.randomState);
      
      const testSizeInt = Math.floor(classData.length * testSize);
      const trainData = shuffled.slice(0, classData.length - testSizeInt);
      const testData = shuffled.slice(classData.length - testSizeInt);

      trainSet.push(...trainData.map(d => d.row));
      testSet.push(...testData.map(d => d.row));
    });

    // Mezclar resultados finales
    const finalTrain = this.shuffleArray(trainSet, this.randomState);
    const finalTest = this.shuffleArray(testSet, this.randomState);

    return {
      train: finalTrain,
      test: finalTest,
      trainSize: finalTrain.length,
      testSize: finalTest.length,
      splitRatio: {
        train: (finalTrain.length / dataset.length).toFixed(2),
        test: (finalTest.length / dataset.length).toFixed(2)
      },
      stratification: this.getStratificationStats(dataset, finalTrain, finalTest, stratifyColumn)
    };
  }

  /**
   * Obtiene estadísticas de estratificación
   */
  getStratificationStats(fullDataset, trainSet, testSet, stratifyColumn) {
    const fullStats = this.countClasses(fullDataset, stratifyColumn);
    const trainStats = this.countClasses(trainSet, stratifyColumn);
    const testStats = this.countClasses(testSet, stratifyColumn);

    return {
      full: fullStats,
      train: trainStats,
      test: testStats,
      proportions: {
        train: Object.keys(trainStats).reduce((acc, key) => {
          acc[key] = (trainStats[key] / fullStats[key]).toFixed(2);
          return acc;
        }, {}),
        test: Object.keys(testStats).reduce((acc, key) => {
          acc[key] = (testStats[key] / fullStats[key]).toFixed(2);
          return acc;
        }, {})
      }
    };
  }

  /**
   * Cuenta ocurrencias por clase
   */
  countClasses(dataset, column) {
    const counts = {};
    dataset.forEach(row => {
      const value = row[column];
      counts[value] = (counts[value] || 0) + 1;
    });
    return counts;
  }

  /**
   * Mezcla array usando Fisher-Yates shuffle con semilla
   */
  shuffleArray(array, seed) {
    const shuffled = [...array];
    let random = this.seededRandom(seed);

    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }

    return shuffled;
  }

  /**
   * Generador de números aleatorios con semilla
   */
  seededRandom(seed) {
    let value = seed;
    return function() {
      value = (value * 9301 + 49297) % 233280;
      return value / 233280;
    };
  }

  /**
   * Guarda los conjuntos train y test en archivos
   */
  async saveSplit(trainSet, testSet, outputDir, prefix = 'split') {
    try {
      await fs.mkdir(outputDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      
      const trainPath = path.join(outputDir, `${prefix}_train_${timestamp}.json`);
      const testPath = path.join(outputDir, `${prefix}_test_${timestamp}.json`);

      await fs.writeFile(trainPath, JSON.stringify(trainSet, null, 2));
      await fs.writeFile(testPath, JSON.stringify(testSet, null, 2));

      return {
        trainPath,
        testPath,
        trainSize: trainSet.length,
        testSize: testSet.length
      };
    } catch (error) {
      throw new Error(`Error guardando split: ${error.message}`);
    }
  }

  /**
   * Carga un split desde archivos
   */
  async loadSplit(trainPath, testPath) {
    try {
      const trainData = await fs.readFile(trainPath, 'utf8');
      const testData = await fs.readFile(testPath, 'utf8');

      return {
        train: JSON.parse(trainData),
        test: JSON.parse(testData)
      };
    } catch (error) {
      throw new Error(`Error cargando split: ${error.message}`);
    }
  }
}

module.exports = TrainTestSplit;

