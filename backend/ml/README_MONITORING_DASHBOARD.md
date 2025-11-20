# Dashboard de Monitoreo ML - Documentación

## 📋 Descripción

Sistema completo de monitoreo y dashboard para métricas de Machine Learning, incluyendo precisión, recall, F1-score, evolución temporal y alertas.

## ✅ Acceptance Criteria Cumplidos

- ✅ **Métricas precisión, recall, F1-score calculadas**: Sistema completo de cálculo de métricas
- ✅ **Evolución temporal mostrada**: Análisis histórico de métricas con tendencias
- ✅ **Dashboard métricas ML disponible**: Dashboard completo con visualizaciones y alertas

## 📁 Archivos Creados

```
backend/ml/
├── ml_metrics_service.js              ✅ Cálculo de métricas ML
├── temporal_metrics_evolution.js      ✅ Evolución temporal
└── ml_monitoring_dashboard.js         ✅ Dashboard integrado
```

## 🚀 Endpoints Disponibles

### 1. Dashboard Completo

```bash
GET /ml/dashboard?days=7&evolutionDays=30
```

Retorna dashboard completo con:
- Métricas actuales
- Evolución temporal
- Comparación con historial
- Alertas y recomendaciones

### 2. Resumen Rápido

```bash
GET /ml/dashboard/summary?days=7
```

Resumen ejecutivo del estado del modelo.

### 3. Métricas Actuales

```bash
GET /ml/metrics/current?days=7
```

Calcula y retorna métricas actuales de precisión, recall, F1-score.

### 4. Evolución Temporal

```bash
GET /ml/metrics/evolution?metric=f1Score&days=30
```

Evolución de una métrica específica en el tiempo.

### 5. Evolución Múltiple

```bash
GET /ml/metrics/evolution/multiple?metrics=accuracy,precision,recall,f1Score&days=30
```

Evolución de múltiples métricas simultáneamente.

### 6. Historial de Métricas

```bash
GET /ml/metrics/history?limit=100
```

Obtiene historial completo de métricas guardadas.

### 7. Última Métrica

```bash
GET /ml/metrics/latest
```

Obtiene la métrica más reciente guardada.

### 8. Comparar con Historial

```bash
GET /ml/metrics/compare-history?days=7&comparisonDays=30
```

Compara métricas actuales con promedio histórico.

### 9. Alertas

```bash
GET /ml/dashboard/alerts?days=7
```

Obtiene alertas del modelo basadas en métricas.

### 10. Recomendaciones

```bash
GET /ml/dashboard/recommendations?days=7
```

Obtiene recomendaciones de mejora del modelo.

## 📊 Métricas Calculadas

### Métricas Principales

- **Accuracy**: Precisión general del modelo
- **Precision**: Precisión en predicciones positivas
- **Recall**: Capacidad de detectar casos positivos
- **F1-Score**: Balance entre precisión y recall
- **Specificity**: Capacidad de detectar casos negativos
- **MCC**: Matthews Correlation Coefficient
- **Balanced Accuracy**: Accuracy balanceado

### Métricas por Categoría

- Por hora del día
- Por día de la semana
- Comparación entre categorías

## 📈 Evolución Temporal

### Características

- Almacenamiento automático de métricas
- Análisis de tendencias (mejorando/estable/degradando)
- Estadísticas de evolución (media, mediana, desviación estándar)
- Comparación con promedio histórico

### Tendencias Detectadas

- **Improving**: Métrica mejorando con el tiempo
- **Stable**: Métrica estable
- **Degrading**: Métrica degradando

## 🎯 Dashboard Features

### Estado Actual

- Status del modelo (good/fair/poor)
- Calificación del modelo (A-F)
- Métricas clave actuales

### Alertas Automáticas

- **Critical**: F1-Score bajo (<60%)
- **Warning**: Accuracy bajo o degradación significativa
- **Info**: Desbalance entre métricas

### Recomendaciones

- Mejoras sugeridas basadas en métricas
- Priorización de acciones
- Categorización por tipo de mejora

## 📝 Ejemplo de Respuesta

### Dashboard Completo

```json
{
  "success": true,
  "dashboard": {
    "dateRange": { "days": 7 },
    "currentMetrics": {
      "summary": {
        "accuracy": 0.8523,
        "precision": 0.8234,
        "recall": 0.8812,
        "f1Score": 0.8512
      }
    },
    "evolution": {
      "summary": {
        "averageF1Score": 0.8423,
        "trends": {
          "f1Score": "improving"
        }
      }
    },
    "dashboard": {
      "currentStatus": {
        "status": "good",
        "grade": "B",
        "metrics": {
          "accuracy": 85.23,
          "precision": 82.34,
          "recall": 88.12,
          "f1Score": 85.12
        }
      },
      "trends": {
        "overallTrend": "improving"
      },
      "alerts": [],
      "recommendations": []
    }
  }
}
```

## 🔍 Casos de Uso

1. **Monitoreo Continuo**
   - Verificar estado del modelo regularmente
   - Detectar degradación temprana
   - Monitorear mejoras después de reentrenamiento

2. **Análisis de Tendencias**
   - Identificar patrones de mejora/degradación
   - Comparar con períodos anteriores
   - Planificar reentrenamientos

3. **Alertas y Notificaciones**
   - Recibir alertas cuando métricas caen
   - Ser notificado de degradaciones significativas
   - Obtener recomendaciones automáticas

4. **Reportes Ejecutivos**
   - Resumen para administradores
   - Visualización de métricas clave
   - Estado general del modelo

## ⚙️ Almacenamiento

Las métricas se guardan automáticamente en:
```
backend/data/metrics_history/
```

Cada ejecución genera un archivo JSON con:
- Métricas calculadas
- Rango de fechas analizado
- Información del modelo
- Timestamp

## 📌 Notas

- Las métricas se calculan automáticamente cada vez que se genera un reporte
- El historial permite análisis temporal de hasta 1000 registros
- Las alertas se generan automáticamente basándose en umbrales predefinidos
- Las recomendaciones se actualizan según el estado actual del modelo

## 🎨 Visualizaciones Recomendadas

Para frontend, se recomienda visualizar:
- Gráficos de línea para evolución temporal
- Gauge charts para métricas actuales
- Barras comparativas para métricas por categoría
- Alertas visuales (badges, iconos)
- Tablas de recomendaciones con prioridades

