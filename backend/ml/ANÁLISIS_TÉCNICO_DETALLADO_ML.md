# 🔬 ANÁLISIS TÉCNICO DETALLADO - ARCHIVOS ML
## Documentación Técnica Específica por Archivo JavaScript

**Complemento al Informe General:** INFORME_COMPLETO_ARCHIVOS_ML.md  
**Enfoque:** Análisis técnico profundo, métodos, clases y implementaciones

---

## 📁 CORE DATA STRUCTURES & ETL

### **ml_data_structure.js** 📊
```javascript
class MLDataStructure {
  constructor() {
    this.schema = {
      features: { temporal, estudiante, acceso, guardia },
      target: ['target', 'is_peak_hour', 'count'],
      metadata: ['id', 'fecha', 'fecha_hora', 'timestamp']
    };
  }
}
```

**🔧 MÉTODOS TÉCNICOS:**
- `defineMLStructure()` → Retorna esquema con validaciones de tipo y rango
- `validateSchema(data)` → Valida conformidad: missing fields, type mismatches, range violations
- `transformToMLFormat(rawData)` → Convierte asistencias MongoDB a formato ML
- `extractFeatures(record)` → Feature engineering: hora→numeric, fecha→temporal features
- `normalizeFeatures(features)` → Z-score normalization de features numéricos
- `encodeCategorialFeatures(features)` → Hash encoding para strings (facultad, escuela, puerta)

**🎯 CASOS DE USO:**
- Usado por TODOS los servicios ETL como base
- Reference schema para validaciones
- Feature engineering pipeline base

---

### **dataset_collector.js** 🗂️
```javascript
class DatasetCollector {
  constructor(AsistenciaModel) {
    this.minMonths = 3;
    this.datasetPath = path.join(__dirname, '../data/datasets');
    this.Asistencia = AsistenciaModel;
  }
}
```

**🔧 MÉTODOS TÉCNICOS:**
- `validateDatasetAvailability()` → MongoDB aggregation pipeline
  ```javascript
  // Implementación interna:
  const pipeline = [
    { $match: { fecha_hora: { $gte: fechaLimite } } },
    { $group: { _id: null, count: { $sum: 1 }, dates: { $addToSet: "$fecha" } } }
  ];
  ```
- `collectHistoricalData(options)` → Stream processing para datasets grandes
- `prepareMLDataset()` → Feature extraction + target generation
- `calculateMonthsAvailable(startDate)` → ISO date calculation con timezone awareness
- `getDatasetStatistics()` → Statistical summary: mean, median, std, quartiles
- `saveDataset(data, filename)` → Atomic file writes con backup

**📊 VALIDACIONES INTERNAS:**
- Mínimo 100 registros en período  
- Coverage ≥7 días únicos
- Horarios 6AM-10PM cubiertos
- No gaps >3 días consecutivos

---

### **historical_data_etl.js** 🔄
```javascript
class HistoricalDataETL {
  async executeETLPipeline(options = {}) {
    const { months = 3, outputFormat = 'json', includeRaw = true } = options;
    // 4-step pipeline: Extract → Transform → Load → Validate
  }
}
```

**🔧 PIPELINE TÉCNICO:**

**1. EXTRACT:**
```javascript
extractHistoricalData(months) {
  const pipeline = [
    { $match: { fecha_hora: { $gte: cutoffDate } } },
    { $sort: { fecha_hora: 1 } },
    { $project: { <selected_fields> } }
  ];
  return this.Asistencia.aggregate(pipeline);
}
```

**2. TRANSFORM:**
```javascript
transformData(rawData) {
  // Agrupa por fecha-hora
  const grouped = rawData.reduce((acc, record) => {
    const hourKey = `${record.fecha}_${record.hora}`;
    if (!acc[hourKey]) acc[hourKey] = { count: 0, tipos: {}, facultades: {} };
    acc[hourKey].count++;
    // ... aggregation logic
  }, {});
  return grouped;
}
```

**3. LOAD:**
- Raw data → `/data/raw/historical_TIMESTAMP.json`
- Transformed → `/data/processed/transformed_TIMESTAMP.json`  
- Metadata → `/data/etl_metadata/etl_meta_TIMESTAMP.json`

**4. VALIDATE:**
- Data quality checks post-processing
- Schema validation against ml_data_structure
- Statistical sanity checks (no negative counts, reasonable ranges)

---

### **data_cleaning_service.js** 🧹
```javascript
class DataCleaningService {
  async cleanDataset(dataset, config = {}) {
    const steps = [
      'handleMissingValues',
      'removeOutliers', 
      'normalizeData',
      'encodeCategoricalFeatures',
      'validateCleanedData'
    ];
    return this.executePipeline(dataset, steps, config);
  }
}
```

**⚙️ ALGORITMOS IMPLEMENTADOS:**

**Outlier Detection:**
```javascript
// IQR Method
detectOutliersIQR(values) {
  const sorted = values.sort((a, b) => a - b);
  const q1 = sorted[Math.floor(sorted.length * 0.25)];
  const q3 = sorted[Math.floor(sorted.length * 0.75)];
  const iqr = q3 - q1;
  const lowerBound = q1 - 1.5 * iqr;
  const upperBound = q3 + 1.5 * iqr;
  return values.filter(v => v < lowerBound || v > upperBound);
}

// Z-Score Method  
detectOutliersZScore(values, threshold = 3) {
  const mean = values.reduce((sum, v) => sum + v, 0) / values.length;
  const std = Math.sqrt(values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length);
  return values.filter(v => Math.abs((v - mean) / std) > threshold);
}
```

**Missing Value Strategies:**
- **Remove:** Elimina filas con valores faltantes
- **Impute:** Mean/median imputation por columna
- **Forward Fill:** Usa último valor válido

**Normalization:**
```javascript
// Standard Scaler (Z-score)
standardScale(values) {
  const mean = values.reduce((sum, v) => sum + v, 0) / values.length;
  const std = Math.sqrt(values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length);
  return values.map(v => (v - mean) / std);
}

// MinMax Scaler
minMaxScale(values) {
  const min = Math.min(...values);
  const max = Math.max(...values);
  return values.map(v => (v - min) / (max - min));
}
```

---

## 🤖 MODEL TRAINING & ALGORITHMS

### **linear_regression.js** 📈
```javascript
class LinearRegression {
  constructor(learningRate = 0.01, iterations = 1000, regularization = 0) {
    this.learningRate = learningRate;
    this.iterations = iterations;
    this.regularization = regularization; // L2 Ridge
    this.weights = null;
    this.bias = null;
    this.trainHistory = [];
  }
}
```

**🎯 ALGORITMO NÚCLEO:**
```javascript
fit(X, y) {
  // Inicializar pesos aleatoriamente
  this.weights = Array(X[0].length).fill(0).map(() => Math.random() * 0.01);
  this.bias = 0;
  
  for (let iter = 0; iter < this.iterations; iter++) {
    // Forward pass - calcular predicciones
    const predictions = X.map(row => 
      row.reduce((sum, feature, j) => sum + feature * this.weights[j], this.bias)
    );
    
    // Calcular cost con regularización L2
    const cost = this.calculateCostWithRegularization(predictions, y);
    
    // Backward pass - calcular gradientes
    const { weightGradients, biasGradient } = this.calculateGradients(X, predictions, y);
    
    // Update pesos con regularización
    this.weights = this.weights.map((w, j) => 
      w - this.learningRate * (weightGradients[j] + this.regularization * w)
    );
    this.bias -= this.learningRate * biasGradient;
    
    // Guardar historia
    this.trainHistory.push({ iteration: iter, cost, weights: [...this.weights] });
    
    // Early stopping por convergencia
    if (iter > 10 && Math.abs(this.trainHistory[iter].cost - this.trainHistory[iter-1].cost) < 1e-6) {
      break;
    }
  }
}
```

**📊 MÉTRICAS IMPLEMENTADAS:**
```javascript
evaluate(X, y) {
  const predictions = this.predict(X);
  const n = y.length;
  
  // Mean Squared Error
  const mse = y.reduce((sum, actual, i) => sum + Math.pow(actual - predictions[i], 2), 0) / n;
  
  // Root Mean Squared Error
  const rmse = Math.sqrt(mse);
  
  // Mean Absolute Error  
  const mae = y.reduce((sum, actual, i) => sum + Math.abs(actual - predictions[i]), 0) / n;
  
  // R² Score
  const yMean = y.reduce((sum, val) => sum + val, 0) / n;
  const totalSumSquares = y.reduce((sum, actual) => sum + Math.pow(actual - yMean, 2), 0);
  const residualSumSquares = y.reduce((sum, actual, i) => sum + Math.pow(actual - predictions[i], 2), 0);
  const r2 = 1 - (residualSumSquares / totalSumSquares);
  
  return { mse, rmse, mae, r2, predictions };
}
```

---

### **model_trainer.js** 🏭
```javascript
class ModelTrainer {
  constructor() {
    this.models = {};
    this.supportedTypes = ['logistic_regression', 'decision_tree', 'random_forest'];
  }
}
```

**🔧 FACTORY PATTERN:**
```javascript
async train(dataset, options = {}) {
  const { modelType = 'logistic_regression', features = [], target = 'target' } = options;
  
  // Preparar datos
  const { X, y, featureNames } = this.prepareData(dataset, features, target);
  
  // Factory pattern para diferentes algoritmos
  switch (modelType) {
    case 'logistic_regression':
      return this.trainLogisticRegression(X, y, featureNames);
    case 'decision_tree':
      return this.trainDecisionTree(X, y, featureNames);  
    case 'random_forest':
      return this.trainRandomForest(X, y, featureNames);
    default:
      throw new Error(`Modelo no soportado: ${modelType}`);
  }
}
```

**🌳 DECISION TREE (Implementación simplificada):**
```javascript
trainDecisionTree(X, y, featureNames, maxDepth = 5) {
  const tree = this.buildTree(X, y, featureNames, 0, maxDepth);
  
  return {
    model: tree,
    type: 'decision_tree',
    featureNames,
    predict: (x) => this.predictDecisionTree(tree, x)
  };
}

buildTree(X, y, features, depth, maxDepth) {
  // Criterio parada
  if (depth >= maxDepth || this.isHomogeneous(y)) {
    return { type: 'leaf', value: this.getMajorityClass(y) };
  }
  
  // Encontrar mejor split usando Gini impurity
  const bestSplit = this.findBestSplit(X, y, features);
  
  // Split recursivo
  const { leftX, leftY, rightX, rightY } = this.splitData(X, y, bestSplit);
  
  return {
    type: 'split',
    feature: bestSplit.feature,
    threshold: bestSplit.threshold,
    left: this.buildTree(leftX, leftY, features, depth + 1, maxDepth),
    right: this.buildTree(rightX, rightY, features, depth + 1, maxDepth)
  };
}
```

---

### **cross_validation.js** 🔀
```javascript
class CrossValidation {
  crossValidate(dataset, model, k = 5, metrics = ['mse', 'r2']) {
    const folds = this.splitKFold(dataset, k);
    const results = [];
    
    for (let i = 0; i < k; i++) {
      // Crear train/test splits
      const testFold = folds[i];
      const trainFolds = folds.filter((_, idx) => idx !== i).flat();
      
      // Entrenar y evaluar
      const trainedModel = model.fit(trainFolds);
      const evaluation = this.evaluateFold(trainedModel, testFold, metrics);
      results.push(evaluation);
    }
    
    return this.aggregateResults(results, metrics);
  }
}
```

**📊 STRATIFIED K-FOLD:**
```javascript
splitKFold(dataset, k, stratifyColumn = null) {
  if (stratifyColumn) {
    // Stratified split - mantiene proporción de clases
    const classGroups = this.groupByClass(dataset, stratifyColumn);
    const folds = Array(k).fill().map(() => []);
    
    Object.keys(classGroups).forEach(className => {
      const classData = this.shuffleArray(classGroups[className]);
      const foldSize = Math.floor(classData.length / k);
      
      for (let i = 0; i < k; i++) {
        const startIdx = i * foldSize;
        const endIdx = i === k - 1 ? classData.length : (i + 1) * foldSize;
        folds[i].push(...classData.slice(startIdx, endIdx));
      }
    });
    
    return folds;
  } else {
    // Standard random split
    const shuffled = this.shuffleArray([...dataset]);
    const foldSize = Math.floor(dataset.length / k);
    const folds = [];
    
    for (let i = 0; i < k; i++) {
      const startIdx = i * foldSize;
      const endIdx = i === k - 1 ? dataset.length : (i + 1) * foldSize;
      folds.push(shuffled.slice(startIdx, endIdx));
    }
    
    return folds;
  }
}
```

---

## 🎯 PREDICTION & SPECIALIZED MODELS

### **peak_hours_predictor.js** 🕐
```javascript
class PeakHoursPredictor {
  constructor(modelPath = null, AsistenciaModel = null) {
    this.model = null;
    this.trendAnalyzer = AsistenciaModel ? new HistoricalTrendAnalyzer(AsistenciaModel) : null;
    this.features = ['hora', 'dia_semana', 'mes', 'es_fin_semana', 'es_feriado'];
  }
}
```

**🔮 PREDICCIÓN DUAL:**
```javascript
async predictPeakHours(dateRange) {
  const predictions = [];
  const startDate = new Date(dateRange.startDate);
  const endDate = new Date(dateRange.endDate);
  
  // Iterar cada hora en el rango
  for (let date = new Date(startDate); date <= endDate; date.setHours(date.getHours() + 1)) {
    // Extraer features temporales
    const features = this.extractFeaturesForHour(date);
    
    // Predicción con modelo entrenado
    const predicted_count = this.model.predict([features])[0];
    
    // Determinar si es horario pico (umbral: 50+ accesos/hora)
    const is_peak_hour = predicted_count >= 50;
    
    // Calcular confidence usando baseline histórico
    const historical = await this.trendAnalyzer?.analyzeHistoricalTrends(date.getHours(), date.getDay());
    const confidence = this.calculateConfidence(predicted_count, historical);
    
    predictions.push({
      datetime: date.toISOString(),
      predicted_count: Math.round(predicted_count),
      is_peak_hour,
      confidence,
      baseline_comparison: historical ? predicted_count / historical.promedio : 1.0
    });
  }
  
  return { predictions, summary: this.generatePredictionSummary(predictions) };
}
```

**⏰ FEATURE EXTRACTION:**
```javascript
extractFeaturesForHour(datetime) {
  const date = new Date(datetime);
  
  return [
    date.getHours(), // 0-23
    date.getDay(), // 0-6 (0=domingo)
    date.getMonth() + 1, // 1-12
    date.getDate(), // 1-31
    this.getWeekOfYear(date), // 1-52
    this.isWeekend(date) ? 1 : 0, // 0,1
    this.isHoliday(date) ? 1 : 0, // 0,1
    this.hashString('default_faculty'), // Faculty hash
    this.hashString('default_school'), // School hash
    this.hashString('entrada'), // Access type
    this.hashString('nfc'), // Entry type
    this.hashString('main_gate'), // Door
    this.hashString('default_guard') // Guard
  ];
}
```

---

### **peak_hours_predictive_model.js** 🎯  
```javascript
class PeakHoursPredictiveModel {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.entradaModel = null;
    this.salidaModel = null;
  }
}
```

**🔄 DUAL MODEL TRAINING:**
```javascript
async trainPredictiveModels(options = {}) {
  const { months = 3, optimize = true, targetAccuracy = 0.75 } = options;
  
  // Preparar datos separados para entrada y salida
  const entradaData = await this.preparePeakHoursData(months, 'entrada');
  const salidaData = await this.preparePeakHoursData(months, 'salida');
  
  // Entrenar modelo para entradas
  const LinearRegression = require('./linear_regression');
  this.entradaModel = new LinearRegression(0.01, 1000, 0);
  const entradaResult = await this.trainSingleModel(entradaData, this.entradaModel, 'entrada');
  
  // Entrenar modelo para salidas  
  this.salidaModel = new LinearRegression(0.01, 1000, 0);
  const salidaResult = await this.trainSingleModel(salidaData, this.salidaModel, 'salida');
  
  // Optimización automática si accuracy < target
  if (optimize && (entradaResult.r2 < targetAccuracy || salidaResult.r2 < targetAccuracy)) {
    return await this.optimizeModels(entradaData, salidaData, targetAccuracy);
  }
  
  return {
    entradaModel: { model: this.entradaModel, metrics: entradaResult },
    salidaModel: { model: this.salidaModel, metrics: salidaResult },
    combined_accuracy: (entradaResult.r2 + salidaResult.r2) / 2
  };
}
```

**📊 DATA AGGREGATION:**
```javascript
async preparePeakHoursData(months, accessType) {
  const cutoffDate = new Date();
  cutoffDate.setMonth(cutoffDate.getMonth() - months);
  
  // MongoDB aggregation para agrupar por hora
  const pipeline = [
    { $match: { 
        fecha_hora: { $gte: cutoffDate },
        tipo: accessType 
    }},
    { $group: {
        _id: {
          year: { $year: "$fecha_hora" },
          month: { $month: "$fecha_hora" },
          day: { $dayOfMonth: "$fecha_hora" },
          hour: { $hour: "$fecha_hora" }
        },
        count: { $sum: 1 },
        fecha_hora: { $first: "$fecha_hora" }
    }},
    { $sort: { fecha_hora: 1 } }
  ];
  
  const aggregatedData = await this.Asistencia.aggregate(pipeline);
  
  // Convertir a formato ML
  return aggregatedData.map(record => ({
    ...this.extractFeaturesForHour(record.fecha_hora),
    target: record.count,
    is_peak_hour: record.count >= (accessType === 'entrada' ? 50 : 40)
  }));
}
```

---

## 📊 ANALYTICS & COMPARISON

### **ml_real_comparison.js** 📈
```javascript
class MLRealComparison {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
  }
}
```

**⚖️ COMPARACIÓN NÚCLEO:**
```javascript
async compareMLvsReal(mlPredictions, dateRange) {
  // Obtener datos reales de MongoDB para mismo período
  const realData = await this.getRealData(dateRange);
  const realByHour = this.groupByHour(realData);
  
  // Comparar hora por hora
  const comparisons = mlPredictions.map(prediction => {
    const hourKey = this.formatHourKey(prediction.datetime);
    const realCount = realByHour[hourKey]?.count || 0;
    const predictedCount = prediction.predicted_count;
    
    const difference = predictedCount - realCount;
    const errorPercent = realCount > 0 ? Math.abs(difference / realCount) * 100 : 100;
    const accuracy = Math.max(0, 1 - (errorPercent / 100));
    
    return {
      datetime: prediction.datetime,
      predicted: predictedCount,
      real: realCount,
      difference,
      error_percent: errorPercent,
      accuracy: accuracy,
      is_peak_predicted: prediction.is_peak_hour,
      is_peak_real: realCount >= 50
    };
  });
  
  // Calcular métricas agregadas
  const overallAccuracy = comparisons.reduce((sum, comp) => sum + comp.accuracy, 0) / comparisons.length;
  const totalPredicted = comparisons.reduce((sum, comp) => sum + comp.predicted, 0);
  const totalReal = comparisons.reduce((sum, comp) => sum + comp.real, 0);
  
  return {
    comparisons,
    summary: {
      overall_accuracy: overallAccuracy,
      total_predicted: totalPredicted,
      total_real: totalReal,
      prediction_bias: (totalPredicted - totalReal) / totalReal
    }
  };
}
```

**🕐 AGRUPACIÓN TEMPORAL:**
```javascript
groupByHour(realData) {
  return realData.reduce((acc, record) => {
    const hourKey = this.formatHourKey(record.fecha_hora);
    
    if (!acc[hourKey]) {
      acc[hourKey] = { 
        count: 0, 
        tipos: { entrada: 0, salida: 0 },
        facultades: {}
      };
    }
    
    acc[hourKey].count++;
    acc[hourKey].tipos[record.tipo]++;
    acc[hourKey].facultades[record.siglas_facultad] = 
      (acc[hourKey].facultades[record.siglas_facultad] || 0) + 1;
    
    return acc;
  }, {});
}

formatHourKey(datetime) {
  const date = new Date(datetime);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}_${String(date.getHours()).padStart(2, '0')}`;
}
```

---

### **advanced_metrics_analyzer.js** 📐
```javascript
class AdvancedMetricsAnalyzer {
  calculateAdvancedMetrics(predictions, actual) {
    const basic = this.calculateBasicMetrics(predictions, actual);
    const robust = this.calculateRobustMetrics(predictions, actual);
    const distribution = this.analyzeErrorDistribution(predictions, actual);
    const intervals = this.calculateConfidenceIntervals(predictions, actual);
    
    return { basic, robust, distribution, confidence: intervals };
  }
}
```

**📊 MÉTRICAS ROBUSTAS:**
```javascript
calculateRobustMetrics(predictions, actual) {
  const errors = predictions.map((pred, i) => actual[i] - pred);
  const absErrors = errors.map(e => Math.abs(e));
  
  // Median Absolute Error (menos sensitive a outliers)
  const medianAE = this.calculateMedian(absErrors);
  
  // Huber Loss (combina L1 y L2)
  const huberDelta = 1.0;
  const huberLoss = errors.reduce((sum, error) => {
    const absError = Math.abs(error);
    if (absError <= huberDelta) {
      return sum + 0.5 * error * error;
    } else {
      return sum + huberDelta * (absError - 0.5 * huberDelta);
    }
  }, 0) / errors.length;
  
  // Mean Absolute Percentage Error
  const mape = actual.reduce((sum, real, i) => {
    if (real !== 0) {
      return sum + Math.abs((real - predictions[i]) / real);
    }
    return sum;
  }, 0) / actual.filter(val => val !== 0).length * 100;
  
  return {
    median_absolute_error: medianAE,
    huber_loss: huberLoss,
    mape: mape
  };
}
```

**📈 ANÁLISIS DISTRIBUCIÓN ERRORES:**
```javascript
analyzeErrorDistribution(predictions, actual) {
  const errors = predictions.map((pred, i) => actual[i] - pred);
  const n = errors.length;
  
  // Estadísticos básicos
  const errorMean = errors.reduce((sum, e) => sum + e, 0) / n;
  const errorVariance = errors.reduce((sum, e) => sum + Math.pow(e - errorMean, 2), 0) / (n - 1);
  const errorStd = Math.sqrt(errorVariance);
  
  // Skewness (asimetría)
  const skewness = errors.reduce((sum, e) => sum + Math.pow((e - errorMean) / errorStd, 3), 0) / n;
  
  // Kurtosis (curtosis)
  const kurtosis = errors.reduce((sum, e) => sum + Math.pow((e - errorMean) / errorStd, 4), 0) / n;
  
  // Detección outliers (método IQR)
  const sortedErrors = [...errors].sort((a, b) => a - b);
  const q1 = sortedErrors[Math.floor(n * 0.25)];
  const q3 = sortedErrors[Math.floor(n * 0.75)];
  const iqr = q3 - q1;
  const outlierThreshold = q3 + 1.5 * iqr;
  const outliers = errors.filter(e => Math.abs(e) > outlierThreshold);
  
  return {
    error_mean: errorMean,
    error_std: errorStd,
    skewness: skewness,
    kurtosis: kurtosis,
    outliers_count: outliers.length,
    outlier_threshold: outlierThreshold,
    is_normal_distribution: Math.abs(skewness) < 0.5 && Math.abs(kurtosis - 3) < 1.0
  };
}
```

---

### **historical_trend_analyzer.js** 📅
```javascript
class HistoricalTrendAnalyzer {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.cache = new Map();
    this.cacheExpiryMs = 60 * 60 * 1000; // 1 hora TTL
  }
}
```

**📊 ANÁLISIS TENDENCIAS:**
```javascript
async analyzeHistoricalTrends(hora, diaSemana, options = {}) {
  const cacheKey = `trends_${hora}_${diaSemana}`;
  
  // Check cache first
  if (this.cache.has(cacheKey)) {
    const cached = this.cache.get(cacheKey);
    if (Date.now() - cached.timestamp < this.cacheExpiryMs) {
      return cached.data;
    }
  }
  
  // Obtener datos históricos para esa hora/día específico
  const historicalData = await this.getHistoricalHourData(hora, diaSemana);
  
  if (historicalData.length === 0) {
    return { promedio: 0, mediana: 0, desviacion: 0, tendencia: 'stable', confianza: 0 };
  }
  
  // Calcular estadísticos
  const counts = historicalData.map(d => d.count);
  const promedio = counts.reduce((sum, c) => sum + c, 0) / counts.length;
  const mediana = this.calculateMedian(counts);
  const desviacion = this.calculateStdDeviation(counts);
  
  // Detectar tendencia temporal
  const tendencia = this.calculateTrend(historicalData);
  
  // Análise estacionalidad semanal
  const estacionalidad = this.detectSeasonality(historicalData);
  
  // Confidence score basado en cantidad y consistencia de datos
  const confianza = this.calculateConfidenceScore(counts, desviacion);
  
  const result = {
    promedio,
    mediana, 
    desviacion,
    tendencia,
    estacionalidad,
    confianza,
    samples: counts.length,
    peak_probability: promedio >= 50 ? 0.8 : 0.2
  };
  
  // Cache resultado
  this.cache.set(cacheKey, { data: result, timestamp: Date.now() });
  
  return result;
}
```

**📈 DETECCIÓN TENDENCIAS:**
```javascript
calculateTrend(historicalData) {
  if (historicalData.length < 3) return 'stable';
  
  // Ordenar por fecha para análisis temporal
  const sorted = historicalData.sort((a, b) => new Date(a.fecha_hora) - new Date(b.fecha_hora));
  const recent = sorted.slice(-30); // Últimos 30 días
  const older = sorted.slice(0, -30);
  
  if (older.length === 0) return 'stable';
  
  const recentAvg = recent.reduce((sum, d) => sum + d.count, 0) / recent.length;
  const olderAvg = older.reduce((sum, d) => sum + d.count, 0) / older.length;
  
  const changePercent = (recentAvg - olderAvg) / olderAvg;
  
  if (changePercent > 0.1) return 'increasing';
  if (changePercent < -0.1) return 'decreasing'; 
  return 'stable';
}
```

---

## 🚨 ALERTS & MONITORING

### **congestion_alert_system.js** 🚨
```javascript
class CongestionAlertSystem {
  constructor() {
    this.alertThresholds = {
      low: 50,      // ℹ️ Informativo
      medium: 100,  // ⚠️ Precaución
      high: 150,    // 🚨 Alerta  
      critical: 200 // 🔴 Crítico
    };
  }
}
```

**🎯 ANÁLISIS ALERTAS:**
```javascript
async checkCongestionAlerts(predictions, options = {}) {
  const { 
    thresholds = this.alertThresholds,
    timeWindow = 60, // minutos
    includeRecommendations = true 
  } = options;
  
  const alerts = [];
  const currentTime = new Date();
  
  // Filtrar prediciones en time window
  const nearFuturePredictions = predictions.filter(pred => {
    const predTime = new Date(pred.datetime);
    const timeDiff = (predTime - currentTime) / (1000 * 60); // minutos
    return timeDiff >= 0 && timeDiff <= timeWindow;
  });
  
  // Analizar cada predicción
  nearFuturePredictions.forEach(prediction => {
    const alertLevel = this.getAlertLevel(prediction.predicted_count, thresholds);
    
    if (alertLevel !== 'none') {
      const alert = {
        datetime: prediction.datetime,
        predicted_count: prediction.predicted_count,
        alert_level: alertLevel,
        threshold_exceeded: thresholds[alertLevel],
        confidence: prediction.confidence || 0.8,
        message: this.generateAlertMessage(alertLevel, prediction),
        urgency: this.calculateUrgency(prediction.datetime, alertLevel)
      };
      
      if (includeRecommendations) {
        alert.recommendations = this.generateRecommendations(alertLevel, prediction);
      }
      
      alerts.push(alert);
    }
  });
  
  // Ordenar por urgencia
  alerts.sort((a, b) => b.urgency - a.urgency);
  
  return {
    alerts,
    summary: {
      total_alerts: alerts.length,
      critical_alerts: alerts.filter(a => a.alert_level === 'critical').length,
      next_critical_time: this.getNextCriticalTime(alerts),
      max_predicted_congestion: Math.max(...nearFuturePredictions.map(p => p.predicted_count))
    },
    thresholds_used: thresholds,
    time_window_minutes: timeWindow
  };
}
```

**💡 GENERACIÓN RECOMENDACIONES:**
```javascript
generateRecommendations(alertLevel, prediction) {
  const recommendations = {
    low: [
      "Monitorear situación en las próximas horas",
      "Preparar personal adicional si es necesario"
    ],
    medium: [
      "Activar protocolo de flujo medio",
      "Notificar a guardias sobre posible incremento",
      "Verificar funcionamiento de todos los accesos"
    ],
    high: [
      "Activar buses adicionales en horario predicho",
      "Asignar personal de refuerzo en zona de acceso",
      "Habilitar accesos secundarios si están disponibles",
      "Enviar notificación preventiva a estudiantes"
    ],
    critical: [
      "ACTIVAR PROTOCOLO DE EMERGENCIA",
      "Desplegar TODO el personal disponible",
      "Coordinar con buses para servicios extraordinarios",  
      "Abrir TODOS los accesos disponibles",
      "Implementar control de flujo dirigido",
      "Notificar a autoridades universitarias"
    ]
  };
  
  return recommendations[alertLevel] || [];
}
```

**⏰ CÁLCULO URGENCIA:**
```javascript
calculateUrgency(datetime, alertLevel) {
  const predTime = new Date(datetime);
  const currentTime = new Date();
  const minutesUntil = (predTime - currentTime) / (1000 * 60);
  
  // Urgency weights por alert level
  const levelWeights = { low: 1, medium: 2, high: 4, critical: 8 };
  const levelWeight = levelWeights[alertLevel] || 1;
  
  // Tiempo factor: más urgente si es más pronto
  const timeFactor = Math.max(0.1, 1 - (minutesUntil / 180)); // 3 hours max
  
  return levelWeight * timeFactor * 100; // Escala 0-800
}
```

---

## 🔄 AUTO-UPDATE SYSTEM

### **weekly_model_update_service.js** 🔄
```javascript
class WeeklyModelUpdateService {
  constructor(AsistenciaModel) {
    this.Asistencia = AsistenciaModel;
    this.updateHistory = [];
    this.maxHistoryLength = 10;
  }
}
```

**⚡ INCREMENTAL RETRAINING:**
```javascript
async incrementalRetrain(options = {}) {
  const { 
    newDataDays = 7,
    historicalSampleRatio = 0.3,
    performanceThreshold = 0.05 
  } = options;
  
  try {
    // 1. Obtener datos nuevos (últimos N días)
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - newDataDays);
    
    const newData = await this.Asistencia.find({
      fecha_hora: { $gte: cutoffDate }
    }).lean();
    
    if (newData.length < 50) {
      return { success: false, reason: 'Insufficient new data', newRecords: newData.length };
    }
    
    // 2. Obtener muestra representativa de datos históricos
    const historicalSample = await this.getHistoricalSample(historicalSampleRatio);
    
    // 3. Combinar datasets
    const combinedData = [...historicalSample, ...newData];
    const mlDataset = this.prepareMLDataset(combinedData);
    
    // 4. Entrenar nuevo modelo
    const TrainingPipeline = require('./training_pipeline');
    const pipeline = new TrainingPipeline(this.Asistencia);
    
    const trainingResult = await pipeline.executeTrainingPipeline({
      dataset: mlDataset,
      modelType: 'logistic_regression',
      testSize: 0.2
    });
    
    // 5. Validar performance vs modelo anterior
    const performanceComparison = await this.comparePerformance(trainingResult);
    
    // 6. Decidir si deploy
    if (performanceComparison.improvement >= performanceThreshold) {
      await this.deployNewModel(trainingResult);
      
      this.recordUpdate({
        type: 'incremental',
        newDataRecords: newData.length,
        historicalSampleRecords: historicalSample.length,
        performance: trainingResult.validation,
        improvement: performanceComparison.improvement,
        deployed: true,
        timestamp: new Date()
      });
      
      return {
        success: true,
        type: 'incremental',
        model: trainingResult,
        performance_improvement: performanceComparison.improvement,
        deployed: true
      };
    } else {
      return {
        success: false,
        reason: 'Performance degradation',
        performance_comparison: performanceComparison,
        deployed: false
      };
    }
    
  } catch (error) {
    return { success: false, error: error.message };
  }
}
```

**📈 VALIDACIÓN PERFORMANCE:**
```javascript
async comparePerformance(newModelResult) {
  // Cargar modelo anterior para comparación
  const previousModel = await this.loadPreviousModel();
  
  if (!previousModel) {
    return { improvement: 1.0, comparison: 'no_previous_model' };
  }
  
  // Usar mismo test set para comparación justa
  const testSet = newModelResult.testSet;
  
  // Evaluar modelo anterior
  const previousMetrics = await this.evaluateModel(previousModel, testSet);
  
  // Evaluar modelo nuevo
  const newMetrics = newModelResult.validation;
  
  // Calcular mejora
  const accuracyImprovement = newMetrics.accuracy - previousMetrics.accuracy;
  const r2Improvement = newMetrics.r2 - previousMetrics.r2;
  
  // Weighted average improvement
  const overallImprovement = (accuracyImprovement * 0.6) + (r2Improvement * 0.4);
  
  return {
    improvement: overallImprovement,
    previous: previousMetrics,
    new: newMetrics,
    comparison: {
      accuracy_change: accuracyImprovement,
      r2_change: r2Improvement,
      overall_change: overallImprovement
    }
  };
}
```

---

### **model_drift_monitor.js** 📊
```javascript
class ModelDriftMonitor {
  constructor() {
    this.driftThresholds = {
      statistical: 0.3,  // KS-test like threshold
      feature: 0.2,      // Feature drift threshold  
      performance: 0.1   // Performance degradation threshold
    };
  }
}
```

**🔍 STATISTICAL DRIFT DETECTION:**
```javascript
detectStatisticalDrift(newData, referenceData, threshold = 0.3) {
  // Implementación simplificada de Kolmogorov-Smirnov test
  const newDistribution = this.calculateEmpiricalDistribution(newData);
  const refDistribution = this.calculateEmpiricalDistribution(referenceData);
  
  // Calcular máxima diferencia entre distribuciones
  const maxDifference = this.calculateMaxDistributionDifference(newDistribution, refDistribution);
  
  // Crítico valor para KS test (simplificado)
  const criticalValue = threshold;
  
  return {
    drift_detected: maxDifference > criticalValue,
    drift_score: maxDifference,
    threshold: criticalValue,
    severity: this.getDriftSeverity(maxDifference, criticalValue)
  };
}

calculateEmpiricalDistribution(data) {
  const sorted = [...data].sort((a, b) => a - b);
  const n = sorted.length;
  
  return sorted.map((value, i) => ({
    value,
    cdf: (i + 1) / n
  }));
}

calculateMaxDistributionDifference(dist1, dist2) {
  // Combinar todos los valores únicos
  const allValues = [...new Set([...dist1.map(d => d.value), ...dist2.map(d => d.value)])].sort((a, b) => a - b);
  
  let maxDiff = 0;
  
  allValues.forEach(value => {
    const cdf1 = this.getCDFAtValue(dist1, value);
    const cdf2 = this.getCDFAtValue(dist2, value);
    const diff = Math.abs(cdf1 - cdf2);
    maxDiff = Math.max(maxDiff, diff);
  });
  
  return maxDiff;
}
```

**📉 FEATURE DRIFT:**
```javascript
detectFeatureDrift(newFeatures, referenceFeatures, featureNames) {
  const featureDrifts = featureNames.map((featureName, idx) => {
    const newFeatureValues = newFeatures.map(row => row[idx]);
    const refFeatureValues = referenceFeatures.map(row => row[idx]);
    
    // Calcul statistics comparison
    const newMean = newFeatureValues.reduce((sum, val) => sum + val, 0) / newFeatureValues.length;
    const refMean = refFeatureValues.reduce((sum, val) => sum + val, 0) / refFeatureValues.length;
    
    const newStd = this.calculateStdDeviation(newFeatureValues);
    const refStd = this.calculateStdDeviation(refFeatureValues);
    
    // Normalized difference
    const meanDrift = Math.abs(newMean - refMean) / Math.max(refStd, 0.001);
    const stdDrift = Math.abs(newStd - refStd) / Math.max(refStd, 0.001);
    
    const featureDrift = Math.max(meanDrift, stdDrift);
    
    return {
      feature: featureName,
      drift_score: featureDrift,
      mean_shift: meanDrift,
      std_shift: stdDrift,
      drift_detected: featureDrift > this.driftThresholds.feature
    };
  });
  
  return featureDrifts;
}
```

---

## 📊 VISUALIZATION & REPORTING

### **prediction_visualization_service.js** 📈
```javascript
class PredictionVisualizationService {
  generateVisualizationData(predictions, actual = null, granularity = 'hourly') {
    const structured = this.structurePredictionData(predictions, granularity);
    const confidence = this.calculateConfidenceIntervals(structured);
    const chartData = this.combineChartData(structured, confidence, actual);
    
    return {
      chart_data: chartData,
      chart_config: this.getChartConfiguration(granularity),
      summary: this.generateVisualizationSummary(structured, actual)
    };
  }
}
```

**📊 ESTRUCTURA PARA GRÁFICOS:**
```javascript
structurePredictionData(predictions, granularity) {
  switch (granularity) {
    case 'hourly':
      return predictions.map(pred => ({
        label: new Date(pred.datetime).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' }),
        value: pred.predicted_count,
        datetime: pred.datetime,
        confidence: pred.confidence || 0.8
      }));
      
    case 'daily':
      // Agrupar por día
      const dailyGroups = this.groupPredictionsByDay(predictions);
      return Object.keys(dailyGroups).map(day => ({
        label: new Date(day).toLocaleDateString('es-ES'),
        value: dailyGroups[day].reduce((sum, pred) => sum + pred.predicted_count, 0),
        datetime: day,
        confidence: dailyGroups[day].reduce((sum, pred) => sum + (pred.confidence || 0.8), 0) / dailyGroups[day].length
      }));
      
    case 'weekly':
      // Agrupar por semana
      const weeklyGroups = this.groupPredictionsByWeek(predictions);
      return Object.keys(weeklyGroups).map(week => ({
        label: `Semana ${week}`,
        value: weeklyGroups[week].reduce((sum, pred) => sum + pred.predicted_count, 0),
        datetime: weeklyGroups[week][0].datetime,
        confidence: weeklyGroups[week].reduce((sum, pred) => sum + (pred.confidence || 0.8), 0) / weeklyGroups[week].length
      }));
      
    default:
      throw new Error(`Granularidad no soportada: ${granularity}`);
  }
}
```

**🎨 CONFIGURACIÓN CHART.JS:**
```javascript
getChartConfiguration(granularity) {
  const baseConfig = {
    chart_type: 'line',
    responsive: true,
    plugins: {
      legend: { display: true },
      tooltip: { enabled: true }
    }
  };
  
  switch (granularity) {
    case 'hourly':
      return {
        ...baseConfig,
        x_axis_label: 'Hora del Día',
        y_axis_label: 'Accesos por Hora',
        time_format: 'HH:mm',
        point_style: 'circle'
      };
      
    case 'daily':
      return {
        ...baseConfig,
        x_axis_label: 'Fecha',
        y_axis_label: 'Accesos por Día', 
        time_format: 'DD/MM',
        point_style: 'rectRot'
      };
      
    case 'weekly':
      return {
        ...baseConfig,
        x_axis_label: 'Semana',
        y_axis_label: 'Accesos por Semana',
        time_format: '[Semana] WW',
        point_style: 'triangle'
      };
  }
}
```

---

## 🔧 UTILITY & OPTIMIZATION FILES

### **bus_schedule_optimizer.js** 📍
```javascript
class BusScheduleOptimizer {
  constructor() {
    this.defaultConfig = {
      busCapacity: 50,
      minInterval: 15, // minutos
      maxWaitTime: 30, // minutos
      operatingHours: { start: 6, end: 22 }
    };
  }
}
```

**⚡ ALGORITMO OPTIMIZACIÓN:**
```javascript
generateBusScheduleSuggestions(predictions, options = {}) {
  const config = { ...this.defaultConfig, ...options };
  
  // 1. Identificar horarios pico basado en predicciones
  const peakHours = this.identifyPeakHours(predictions, config);
  
  // 2. Calcular demanda total por horario
  const demandByHour = this.calculateHourlyDemand(predictions);
  
  // 3. Optimizar schedule ida (hacia universidad)
  const outboundSchedule = this.optimizeOutboundSchedule(demandByHour, peakHours, config);
  
  // 4. Optimizar schedule retorno (desde universidad)  
  const returnSchedule = options.includeReturn ? 
    this.optimizeReturnSchedule(outboundSchedule, config) : [];
  
  // 5. Calcular métricas de eficiencia
  const efficiencyMetrics = this.calculateEfficiencyMetrics(
    outboundSchedule, returnSchedule, demandByHour, config
  );
  
  // 6. Generar recomendaciones
  const recommendations = this.generateRecommendations(efficiencyMetrics, config);
  
  return {
    optimized_schedule: {
      outbound: outboundSchedule,
      return: returnSchedule
    },
    efficiency_metrics: efficiencyMetrics,
    recommendations: recommendations,
    config_used: config
  };
}
```

**🚌 OPTIMIZACIÓN HORARIO IDA:**
```javascript
optimizeOutboundSchedule(demandByHour, peakHours, config) {
  const schedule = [];
  const operatingHours = this.generateOperatingHours(config);
  
  operatingHours.forEach(hour => {
    const demand = demandByHour[hour] || 0;
    
    if (demand === 0) return; // Skip zero demand hours
    
    // Calcular número de buses necesarios
    const busesNeeded = Math.ceil(demand / config.busCapacity);
    
    // Determinar intervalo entre buses
    const interval = peakHours.includes(hour) ? 
      config.minInterval : 
      Math.min(60, Math.max(config.minInterval, 60 / busesNeeded));
    
    // Generar horarios específicos
    const hourSchedule = this.generateHourSchedule(hour, busesNeeded, interval, demand, config);
    schedule.push(...hourSchedule);
  });
  
  return schedule.sort((a, b) => a.time.localeCompare(b.time));
}

generateHourSchedule(hour, busesNeeded, interval, demand, config) {
  const schedules = [];
  
  for (let bus = 0; bus < busesNeeded; bus++) {
    const minutes = bus * interval;
    const time = `${String(hour).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
    
    // Calcular passengers esperados por bus
    const expectedPassengers = Math.min(
      Math.ceil(demand / busesNeeded), 
      config.busCapacity
    );
    
    schedules.push({
      time,
      expected_passengers: expectedPassengers,
      capacity_utilization: expectedPassengers / config.busCapacity,
      bus_number: bus + 1,
      total_buses_this_hour: busesNeeded
    });
  }
  
  return schedules;
}
```

**📊 MÉTRICAS EFICIENCIA:**
```javascript
calculateEfficiencyMetrics(outboundSchedule, returnSchedule, demandByHour, config) {
  const allSchedule = [...outboundSchedule, ...returnSchedule];
  
  // Ocupación promedio
  const totalPassengers = allSchedule.reduce((sum, bus) => sum + bus.expected_passengers, 0);
  const totalCapacity = allSchedule.length * config.busCapacity;
  const averageOccupancy = totalPassengers / totalCapacity;
  
  // Wait time promedio (simplificado)
  const avgWaitTime = outboundSchedule.reduce((sum, bus, idx) => {
    if (idx === 0) return sum;
    const prevTime = this.timeToMinutes(outboundSchedule[idx - 1].time);
    const currTime = this.timeToMinutes(bus.time);
    return sum + (currTime - prevTime);
  }, 0) / Math.max(outboundSchedule.length - 1, 1);
  
  // Cobertura de demanda
  const totalDemand = Object.values(demandByHour).reduce((sum, d) => sum + d, 0);
  const demandCoverage = totalPassengers / totalDemand;
  
  // Desviación estándar occupancy
  const occupancyValues = allSchedule.map(bus => bus.capacity_utilization);
  const occupancyStd = this.calculateStdDeviation(occupancyValues);
  
  return {
    average_occupancy: averageOccupancy,
    average_wait_time_minutes: avgWaitTime,
    occupancy_std_deviation: occupancyStd,
    demand_coverage: Math.min(demandCoverage, 1.0),
    total_buses_scheduled: allSchedule.length,
    efficiency_score: (averageOccupancy * 0.4) + (demandCoverage * 0.4) + ((1 - occupancyStd) * 0.2)
  };
}
```

---

## 🎯 CONCLUSIONES TÉCNICAS

### **PATRONES DE DISEÑO IMPLEMENTADOS**
- **Factory Pattern** - ModelTrainer para diferentes algoritmos
- **Strategy Pattern** - DataCleaningService con múltiples estrategias  
- **Observer Pattern** - ModelDriftMonitor con callbacks
- **Pipeline Pattern** - TrainingPipeline, ETL Pipeline
- **Cache Pattern** - HistoricalTrendAnalyzer con TTL cache

### **OPTIMIZACIONES DE PERFORMANCE**
- **MongoDB Aggregation Pipelines** - Queries optimizadas
- **Stream Processing** - Para datasets grandes  
- **In-Memory Caching** - TTL cache para análisis histórico
- **Batch Processing** - Chunks de 1000 registros
- **Early Stopping** - Previene overfitting y reduce tiempo

### **ARQUITECTURA ESCALABLE**  
- **Modular Design** - Cada archivo independent functionality
- **Dependency Injection** - AsistenciaModel pasado como parámetro
- **Configuration-Driven** - Todos los umbrales configurables  
- **Error Handling** - Try-catch comprehensivo
- **Logging** - Detailed logging para debugging

Este análisis técnico detalla la implementación interna de cada archivo ML con focus en algoritmos, métodos, y patrones de diseño utilizados. Proporciona el contexto técnico necesario para mantenimiento, debugging, y extensión del sistema.