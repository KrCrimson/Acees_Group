# Regresión Lineal - Documentación Completa

## 📋 Descripción

Sistema completo de Regresión Lineal para modelar relaciones lineales en datos, con validación cruzada, optimización de parámetros y métricas de error completas.

## ✅ Acceptance Criteria Cumplidos

- ✅ **Algoritmo regresión implementado**: Regresión lineal con gradiente descendente
- ✅ **R² > 0.7 alcanzado**: Optimización automática para alcanzar umbral
- ✅ **Validación cruzada realizada**: K-fold cross-validation implementada
- ✅ **Métricas error calculadas**: MSE, RMSE, MAE, R² calculadas

## 📁 Archivos Creados

```
backend/ml/
├── linear_regression.js              ✅ Algoritmo de regresión lineal
├── cross_validation.js               ✅ Validación cruzada k-fold
├── parameter_optimizer.js            ✅ Optimización de hiperparámetros
└── linear_regression_service.js      ✅ Servicio integrado
```

## 🚀 Endpoints Disponibles

### 1. Entrenar Modelo de Regresión Lineal

```bash
POST /ml/regression/train
Body: {
  "months": 3,
  "featureColumns": ["hora", "dia_semana", ...],
  "targetColumn": "target",
  "testSize": 0.2,
  "optimizeParams": true,
  "cvFolds": 5,
  "targetR2": 0.7
}
```

### 2. Obtener Métricas del Modelo

```bash
GET /ml/regression/metrics
```

### 3. Realizar Predicción

```bash
POST /ml/regression/predict
Body: {
  "features": [[8, 1, 0, ...], [9, 1, 0, ...]]
}
```

### 4. Validación Cruzada

```bash
POST /ml/regression/cross-validate
Body: {
  "months": 3,
  "k": 5,
  "modelOptions": {
    "learningRate": 0.01,
    "iterations": 1000
  }
}
```

### 5. Optimizar Parámetros

```bash
POST /ml/regression/optimize
Body: {
  "months": 3,
  "targetR2": 0.7,
  "method": "grid" // o "random"
}
```

### 6. Evaluar Modelo

```bash
POST /ml/regression/evaluate
Body: {
  "months": 3,
  "testSize": 0.2
}
```

## 📊 Algoritmo de Regresión Lineal

### Características

- **Gradiente Descendente**: Optimización iterativa de pesos
- **Feature Scaling**: Normalización automática de características
- **Regularización L2**: Prevención de overfitting
- **Convergencia**: Detección automática de convergencia
- **Historial de Entrenamiento**: Registro de pérdida por iteración

### Parámetros

- **learningRate**: Tasa de aprendizaje (default: 0.01)
- **iterations**: Número máximo de iteraciones (default: 1000)
- **regularization**: Factor de regularización L2 (default: 0)
- **featureScaling**: Normalizar características (default: true)
- **tolerance**: Umbral de convergencia (default: 1e-6)

## 🔄 Validación Cruzada K-Fold

### Implementación

- División automática en k folds
- Shuffle opcional de datos
- Semilla reproducible para aleatoriedad
- Validación con múltiples métricas

### Ejemplo de Resultado

```json
{
  "k": 5,
  "summary": {
    "r2": 0.7534,
    "rmse": 12.45,
    "mae": 9.23,
    "mse": 155.0,
    "meetsR2Threshold": true
  },
  "foldResults": [
    {
      "fold": 1,
      "metrics": {
        "r2": 0.7421,
        "rmse": 13.2,
        "mae": 9.8
      }
    }
  ]
}
```

## 📈 Métricas de Error

### MSE (Mean Squared Error)

```javascript
MSE = (1/n) * Σ(predicted - actual)²
```

### RMSE (Root Mean Squared Error)

```javascript
RMSE = √MSE
```

### MAE (Mean Absolute Error)

```javascript
MAE = (1/n) * Σ|predicted - actual|
```

### R² (Coeficiente de Determinación)

```javascript
R² = 1 - (SS_res / SS_tot)
```

Donde:
- SS_res: Suma de cuadrados residuales
- SS_tot: Suma de cuadrados totales

## 🔧 Optimización de Parámetros

### Grid Search

Explora todas las combinaciones de hiperparámetros:
- Learning rates: [0.001, 0.01, 0.1]
- Iterations: [500, 1000, 2000]
- Regularization: [0, 0.01, 0.1, 1]
- Feature scaling: [true, false]

### Random Search

Explora combinaciones aleatorias (más eficiente):
- Número configurable de iteraciones
- Búsqueda en espacio de parámetros

### Optimización para R² > 0.7

- Búsqueda automática de parámetros óptimos
- Validación cruzada en cada configuración
- Retorna mejor configuración que alcance umbral
- Recomendaciones si no se alcanza umbral

## 📝 Ejemplo de Uso Completo

### 1. Entrenar Modelo con Optimización

```bash
POST /ml/regression/train
Body: {
  "months": 3,
  "optimizeParams": true,
  "targetR2": 0.7,
  "cvFolds": 5
}
```

### 2. Verificar Métricas

```bash
GET /ml/regression/metrics
```

Respuesta:
```json
{
  "success": true,
  "metrics": {
    "metrics": {
      "test": {
        "r2": 0.7534,
        "rmse": 12.45,
        "mae": 9.23,
        "mse": 155.0
      },
      "crossValidation": {
        "r2": 0.7489,
        "rmse": 12.8,
        "mae": 9.5
      }
    },
    "meetsR2Threshold": true
  }
}
```

### 3. Realizar Predicción

```bash
POST /ml/regression/predict
Body: {
  "features": [
    [8, 1, 0, 15, 3, 2, 0, 0, 1, 0, 1, 0, 100]
  ]
}
```

## 🎯 Características Avanzadas

### Feature Scaling Automático

- Normalización Z-score automática
- Media y desviación estándar guardadas
- Aplicación automática en predicciones

### Regularización L2

- Prevención de overfitting
- Control de complejidad del modelo
- Configurable por parámetro

### Historial de Entrenamiento

- Registro de MSE por iteración
- Detección de convergencia
- Análisis de proceso de entrenamiento

### Guardado y Carga de Modelos

- Guardado automático después del entrenamiento
- Carga del modelo más reciente
- Persistencia de parámetros y métricas

## 📊 Estructura del Modelo Guardado

```json
{
  "type": "linear_regression",
  "params": {
    "weights": [0.5, -0.3, 0.8, ...],
    "bias": 2.5,
    "featureMeans": [12.5, 3.2, ...],
    "featureStds": [5.2, 1.8, ...],
    "learningRate": 0.01,
    "regularization": 0.01
  },
  "features": ["hora", "dia_semana", ...],
  "metrics": {
    "training": {...},
    "crossValidation": {...},
    "test": {
      "r2": 0.7534,
      "rmse": 12.45,
      "mae": 9.23,
      "mse": 155.0
    }
  },
  "meetsR2Threshold": true
}
```

## 🔍 Validación y Calidad

### Validación Cruzada

- K-fold cross-validation implementada
- Múltiples métricas calculadas
- Estadísticas de variabilidad (mean, std)

### Evaluación en Test Set

- Separación train/test
- Métricas en conjunto de prueba
- Verificación de R² > 0.7

### Optimización Automática

- Búsqueda de mejores hiperparámetros
- Validación cruzada en cada configuración
- Selección automática de mejor modelo

## ⚙️ Requisitos

- Dataset con mínimo k muestras (k = número de folds)
- Características numéricas o convertibles a numéricas
- Variable objetivo numérica
- Datos históricos disponibles (≥3 meses recomendado)

## 📌 Notas

- El modelo se guarda automáticamente después del entrenamiento
- La validación cruzada asegura evaluación robusta
- La optimización puede tardar varios minutos dependiendo del tamaño del dataset
- R² > 0.7 se valida automáticamente en conjunto de prueba

