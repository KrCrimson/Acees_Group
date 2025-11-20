# Reportes de Horarios Pico con ML

## 📋 Descripción

Sistema completo para generar reportes de horarios pico usando Machine Learning, comparando predicciones del modelo con datos reales y generando sugerencias de ajuste.

## ✅ Acceptance Criteria Cumplidos

- ✅ **Comparación ML vs real disponible**: Comparación completa entre predicciones y datos históricos
- ✅ **Precisión por horario calculada**: Métricas detalladas de precisión para cada hora del día
- ✅ **Ajustes sugeridos generados**: Sistema inteligente de sugerencias basado en diferencias

## 📁 Archivos Creados

```
backend/ml/
├── peak_hours_predictor.js          # Predicción de horarios pico con ML
├── ml_real_comparison.js            # Comparación ML vs datos reales
├── adjustment_suggestions_generator.js  # Generador de sugerencias
└── peak_hours_report_service.js     # Servicio integrado de reportes
```

## 🚀 Endpoints Disponibles

### 1. Reporte Completo de Horarios Pico

```bash
GET /ml/reports/peak-hours?days=7
GET /ml/reports/peak-hours?startDate=2024-01-01&endDate=2024-01-07
```

Retorna reporte completo incluyendo:
- Predicciones ML por día y hora
- Comparación con datos reales
- Métricas de precisión por horario
- Sugerencias de ajuste

### 2. Comparación ML vs Real

```bash
GET /ml/reports/comparison?days=7
```

Compara predicciones del modelo con datos históricos reales.

### 3. Métricas de Precisión por Horario

```bash
GET /ml/reports/hourly-metrics?days=7
```

Retorna métricas detalladas de precisión para cada hora del día:
- Accuracy promedio por hora
- Error promedio (MAE)
- Root Mean Square Error (RMSE)
- Bias del modelo
- Horarios con mejor/peor precisión

### 4. Sugerencias de Ajuste

```bash
GET /ml/reports/suggestions?days=7
```

Genera sugerencias inteligentes basadas en diferencias entre ML y datos reales:
- Reentrenamiento del modelo
- Ajustes por horario específico
- Calibración de volumen
- Mejoras de características

### 5. Resumen para Dashboard

```bash
GET /ml/reports/dashboard-summary?days=7
```

Resumen optimizado para dashboard administrativo.

## 📊 Estructura de Respuesta

### Reporte Completo

```json
{
  "success": true,
  "report": {
    "dateRange": {
      "startDate": "2024-01-01",
      "endDate": "2024-01-07"
    },
    "predictions": {
      "summary": {
        "totalDays": 7,
        "averageDailyPredicted": 850,
        "topPeakHours": [
          { "hora": 8, "frequency": 7, "percentage": "100.0" }
        ]
      },
      "dailyPredictions": [...]
    },
    "comparison": {
      "overallAccuracy": "85.23",
      "summary": {
        "totalPredicted": 5950,
        "totalReal": 6200,
        "totalDifference": -250,
        "peakHoursAccuracy": "82.5"
      }
    },
    "hourlyMetrics": {
      "metrics": [
        {
          "hora": 8,
          "averageAccuracy": 92.5,
          "averageError": 5.2,
          "bias": -2.1,
          "performance": "excellent"
        }
      ],
      "summary": {
        "averageAccuracy": 85.23,
        "peakHoursAccuracy": 82.5,
        "bestHours": [...],
        "worstHours": [...]
      }
    },
    "suggestions": {
      "totalSuggestions": 3,
      "byPriority": {
        "high": [...],
        "medium": [...],
        "low": [...]
      },
      "actionPlan": {
        "totalActions": 3,
        "actions": [...],
        "timeline": {
          "immediate": [1],
          "shortTerm": [2],
          "longTerm": [3]
        }
      }
    }
  }
}
```

## 🔍 Tipos de Sugerencias

### 1. MODEL_RETRAINING (Alta Prioridad)
Sugiere reentrenar el modelo cuando la precisión general es baja (<70%).

### 2. HOUR_ADJUSTMENT (Media Prioridad)
Sugiere ajustar predicciones para horas específicas con baja precisión.

### 3. PEAK_HOURS_DETECTION (Alta Prioridad)
Sugiere mejorar la detección de horarios pico cuando la precisión es baja.

### 4. VOLUME_CALIBRATION (Media Prioridad)
Sugiere ajustar calibración cuando hay diferencias significativas en volumen.

### 5. DAY_SPECIFIC_ADJUSTMENT (Baja Prioridad)
Sugiere ajustes para días específicos con baja precisión.

### 6. DATA_COLLECTION (Media Prioridad)
Sugiere recopilar más datos cuando el período de validación es corto.

### 7. FEATURE_ENGINEERING (Baja Prioridad)
Sugiere agregar nuevas características al modelo.

## 📈 Métricas Calculadas

### Por Horario
- **Accuracy**: Precisión promedio del modelo
- **MAE**: Error Absoluto Medio
- **RMSE**: Raíz del Error Cuadrático Medio
- **Bias**: Sesgo del modelo (sobreestimación/subestimación)
- **Confidence**: Confianza promedio de las predicciones

### Globales
- **Overall Accuracy**: Precisión general del modelo
- **Peak Hours Accuracy**: Precisión específica en horarios pico
- **Total Difference**: Diferencia entre predicciones y datos reales

## 🎯 Casos de Uso

1. **Validar Predicciones del Modelo**
   - Comparar predicciones ML con datos reales
   - Identificar horas con mayor/menor precisión

2. **Optimizar Recursos**
   - Identificar horarios pico reales vs predichos
   - Ajustar asignación de guardias según predicciones

3. **Mejorar Modelo**
   - Obtener sugerencias específicas de mejora
   - Seguir plan de acción recomendado

4. **Dashboard Administrativo**
   - Visualizar resumen ejecutivo
   - Monitorear precisión del modelo en tiempo real

## ⚙️ Requisitos

- Modelo ML entrenado disponible en `backend/data/models/`
- Datos históricos en MongoDB para comparación
- Mínimo 1 día de datos para comparación (recomendado ≥7 días)

## 📌 Notas

- Las predicciones se generan usando el modelo más reciente entrenado
- La comparación requiere acceso a datos históricos en MongoDB
- Las sugerencias se generan automáticamente basándose en diferencias encontradas
- El sistema identifica automáticamente horarios pico (top 3 horas con mayor actividad)

