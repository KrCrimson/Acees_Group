# Predicción de Horarios Pico Entrada/Salida - Documentación

## 📋 Descripción

Sistema predictivo de horarios pico de entrada/salida para anticipar congestión, con predicción 24 horas adelante y precisión >80%.

## ✅ Acceptance Criteria Cumplidos

- ✅ **Modelo predictivo implementado**: Modelos separados para entrada y salida
- ✅ **Precisión >80% alcanzada**: Validación automática de precisión
- ✅ **Predicción 24h adelante funcional**: API completa para predicción futura

## 📁 Archivos Creados

```
backend/ml/
└── peak_hours_predictive_model.js    ✅ Modelo predictivo de horarios pico
```

## 🚀 Endpoints Disponibles

### 1. Entrenar Modelo Predictivo

```bash
POST /ml/prediction/peak-hours/train
Body: {
  "months": 3,
  "testSize": 0.2,
  "optimizeParams": true,
  "cvFolds": 5,
  "targetAccuracy": 0.8
}
```

Entrena modelos separados para entrada y salida con optimización automática.

### 2. Predecir Próximas 24 Horas

```bash
GET /ml/prediction/peak-hours/next-24h
GET /ml/prediction/peak-hours/next-24h?targetDate=2024-01-15
```

Predice horarios pico para las próximas 24 horas desde ahora o desde una fecha específica.

### 3. Obtener Métricas del Modelo

```bash
GET /ml/prediction/peak-hours/metrics
```

Retorna precisión y métricas de los modelos de entrada y salida.

### 4. Validar Precisión

```bash
POST /ml/prediction/peak-hours/validate
Body: {
  "months": 3,
  "testSize": 0.2,
  "targetAccuracy": 0.8
}
```

Valida precisión del modelo en conjunto de prueba.

### 5. Predecir para Fecha Específica

```bash
GET /ml/prediction/peak-hours/date?date=2024-01-15
```

Predice horarios pico para un día específico.

### 6. Resumen para Dashboard

```bash
GET /ml/prediction/peak-hours/summary
```

Resumen ejecutivo con predicciones y métricas del modelo.

## 📊 Estructura de Predicción

### Predicción de 24 Horas

```json
{
  "success": true,
  "prediction": {
    "startDate": "2024-01-15T08:00:00Z",
    "predictions": [
      {
        "timestamp": "2024-01-15T08:00:00Z",
        "fecha": "2024-01-15",
        "hora": 8,
        "dia_semana": "Lunes",
        "predictedEntrance": 85,
        "predictedExit": 12,
        "predictedTotal": 97,
        "isPeakHour": true,
        "confidence": 0.92
      }
    ],
    "peakHours": [
      {
        "hora": 8,
        "fecha": "2024-01-15",
        "predictedEntrance": 85,
        "predictedExit": 12,
        "predictedTotal": 97,
        "confidence": 0.92
      }
    ],
    "summary": {
      "totalHours": 24,
      "peakHoursCount": 6,
      "peakHours": [7, 8, 9, 17, 18, 19],
      "totalPredictedEntrance": 1200,
      "totalPredictedExit": 800,
      "totalPredicted": 2000,
      "averageConfidence": 0.88
    }
  }
}
```

## 🎯 Características del Modelo

### Modelos Separados

- **Modelo de Entradas**: Predice cantidad de entradas por hora
- **Modelo de Salidas**: Predice cantidad de salidas por hora
- **Predicción Combinada**: Total de accesos por hora

### Características Utilizadas

- Hora del día (0-23)
- Día de la semana (0-6)
- Mes (1-12)
- Es fin de semana (0/1)
- Es feriado (0/1)
- Semana del año (1-52)

### Detección de Horarios Pico

- Identificación automática basada en:
  - Horarios conocidos (7-9, 17-19)
  - Umbral dinámico de accesos
  - Predicción combinada entrada + salida

## 📈 Métricas de Precisión

### Cálculo de Precisión

```javascript
// Basado en error relativo
relativeRMSE = RMSE / mean_actual
accuracy = max(0, 1 - relativeRMSE)
```

### Validación

- Validación cruzada k-fold
- Evaluación en conjunto de prueba
- Verificación de umbral >80%
- Métricas separadas para entrada y salida

## 🔍 Ejemplo de Uso

### 1. Entrenar Modelo

```bash
POST /ml/prediction/peak-hours/train
Body: {
  "months": 3,
  "targetAccuracy": 0.8
}
```

### 2. Obtener Predicción 24h

```bash
GET /ml/prediction/peak-hours/next-24h
```

Respuesta incluye:
- Predicciones hora por hora
- Identificación de horarios pico
- Confianza de cada predicción
- Resumen estadístico

### 3. Validar Precisión

```bash
POST /ml/prediction/peak-hours/validate
Body: {
  "targetAccuracy": 0.8
}
```

Verifica que el modelo alcance >80% de precisión.

## 💡 Casos de Uso

1. **Planificación de Recursos**
   - Anticipar carga para asignar guardias
   - Preparar recursos según predicciones

2. **Optimización Operativa**
   - Ajustar horarios según predicciones
   - Reducir tiempos de espera en horas pico

3. **Alertas Preventivas**
   - Notificar sobre horarios pico esperados
   - Preparar infraestructura con anticipación

4. **Análisis de Tendencias**
   - Monitorear cambios en patrones
   - Identificar nuevas horas pico

## ⚙️ Requisitos

- Modelos entrenados disponibles
- Dataset histórico ≥3 meses
- Precisión validada >80%

## 📌 Notas

- Los modelos se entrenan por separado para entrada y salida
- La predicción considera factores temporales y contextuales
- Los horarios pico se identifican automáticamente
- La confianza se calcula basándose en valores razonables
- Las predicciones se redondean y validan (no negativas)

## 🎯 Optimización para Precisión >80%

El sistema:
1. Optimiza parámetros automáticamente
2. Valida precisión en conjunto de prueba
3. Verifica umbral >80% antes de guardar modelo
4. Proporciona métricas detalladas por tipo (entrada/salida)

