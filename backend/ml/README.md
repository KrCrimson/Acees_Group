# Sistema de Entrenamiento de Modelo ML

## 📋 Descripción

Sistema completo para entrenar modelos de Machine Learning con datos históricos mínimos de 3 meses del sistema de control de asistencias NFC.

## ✅ Acceptance Criteria Cumplidos

- ✅ **Dataset ≥3 meses disponible**: Validación automática de disponibilidad de datos
- ✅ **Train/test split realizado**: División estratificada del dataset
- ✅ **Pipeline entrenamiento**: Pipeline completo automatizado
- ✅ **Métricas validación calculadas**: Accuracy, Precision, Recall, F1-Score, Matriz de Confusión

## 📁 Estructura de Archivos

```
backend/ml/
├── dataset_collector.js    # Recopilación de datos históricos
├── train_test_split.js     # División train/test
├── model_trainer.js        # Entrenamiento de modelos
├── model_validator.js      # Validación y métricas
├── training_pipeline.js   # Pipeline completo
└── run_training.js         # Script de ejecución

backend/data/
├── datasets/              # Datasets recopilados
├── splits/                # Conjuntos train/test
├── models/                # Modelos entrenados
└── logs/                  # Reportes de entrenamiento
```

## 🚀 Uso

### 1. Validar Disponibilidad de Dataset

```bash
GET /ml/dataset/validate
```

Retorna información sobre la disponibilidad de datos históricos (≥3 meses).

### 2. Recopilar Dataset Histórico

```bash
POST /ml/dataset/collect
Body: {
  "months": 3,
  "includeFeatures": true,
  "outputFormat": "json"
}
```

### 3. Ejecutar Pipeline Completo

```bash
POST /ml/pipeline/train
Body: {
  "months": 3,
  "testSize": 0.2,
  "modelType": "logistic_regression",
  "stratify": "target"
}
```

### 4. Ejecutar desde Línea de Comandos

```bash
cd backend/ml
node run_training.js [meses] [testSize] [modelType]

# Ejemplo:
node run_training.js 3 0.2 logistic_regression
```

## 📊 Tipos de Modelos Disponibles

1. **logistic_regression**: Regresión Logística (por defecto)
2. **decision_tree**: Árbol de Decisión
3. **random_forest**: Random Forest (10 árboles)

## 🔧 Características Extraídas

El sistema extrae automáticamente las siguientes características:

- **Temporales**: hora, minuto, día de semana, día del mes, mes, semana del año
- **Contextuales**: es fin de semana, es feriado
- **Estudiante**: facultad, escuela
- **Acceso**: tipo (entrada/salida), puerta, guardia
- **Autorización**: autorización manual (target)

## 📈 Métricas de Validación

El sistema calcula las siguientes métricas:

- **Accuracy**: Precisión general del modelo
- **Precision**: Precisión en predicciones positivas
- **Recall**: Capacidad de detectar casos positivos
- **F1-Score**: Balance entre precisión y recall
- **Specificity**: Capacidad de detectar casos negativos
- **Confusion Matrix**: Matriz de confusión completa

## 📝 Ejemplo de Respuesta

```json
{
  "success": true,
  "model": { ... },
  "validation": {
    "accuracy": 0.85,
    "precision": 0.82,
    "recall": 0.88,
    "f1Score": 0.85,
    "confusionMatrix": {
      "truePositives": 150,
      "trueNegatives": 200,
      "falsePositives": 30,
      "falseNegatives": 20
    }
  },
  "modelPath": "backend/data/models/model_2024-01-15.json",
  "reportPath": "backend/data/logs/training_report_2024-01-15.json"
}
```

## 🔍 Endpoints Disponibles

- `GET /ml/dataset/validate` - Validar disponibilidad de datos
- `GET /ml/dataset/statistics` - Estadísticas del dataset
- `POST /ml/dataset/collect` - Recopilar dataset
- `POST /ml/pipeline/train` - Entrenar modelo
- `GET /ml/models` - Listar modelos entrenados
- `POST /ml/models/predict` - Hacer predicción

## ⚙️ Requisitos

- Node.js >= 12.0.0
- MongoDB Atlas con datos históricos ≥3 meses
- Mínimo 100 registros en el período

## 📌 Notas

- El entrenamiento puede tardar varios minutos dependiendo del tamaño del dataset
- Los modelos se guardan en formato JSON en `backend/data/models/`
- Los reportes se generan automáticamente en `backend/data/logs/`
- El split es estratificado por defecto para mantener proporción de clases

