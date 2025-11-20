# Visualización de Predicciones ML - Documentación

## 📋 Descripción

Sistema completo de visualización de predicciones del modelo ML con gráficos, intervalos de confianza y actualización automática.

## ✅ Acceptance Criteria Cumplidos

- ✅ **Gráficos predicción vs real disponibles**: Datos estructurados para gráficos de líneas y barras
- ✅ **Intervalos confianza mostrados**: Cálculo de intervalos de confianza del 95%
- ✅ **Actualización automática configurada**: Sistema de actualización automática del modelo

## 📁 Archivos Creados

```
backend/ml/
├── prediction_visualization_service.js   ✅ Servicio de visualización
└── auto_model_update_service.js         ✅ Actualización automática
```

## 🚀 Endpoints Disponibles

### Visualización

#### 1. Datos de Visualización Completos

```bash
GET /ml/visualization/data?days=7&granularity=hour
```

Retorna datos estructurados para visualización con:
- Predicciones ML
- Datos reales (si disponibles)
- Intervalos de confianza
- Resumen estadístico

#### 2. Gráfico de Líneas (Predicción vs Real)

```bash
GET /ml/visualization/line-chart?days=7
```

Datos formateados para gráfico de líneas incluyendo:
- Línea de predicción ML
- Línea de datos reales
- Intervalos de confianza superior e inferior

#### 3. Gráfico de Barras (Comparación Diaria)

```bash
GET /ml/visualization/bar-chart?days=7
```

Datos formateados para gráfico de barras comparando:
- Predicciones diarias
- Datos reales diarios

#### 4. Intervalos de Confianza

```bash
GET /ml/visualization/confidence-intervals?days=7&confidenceLevel=0.95
```

Obtiene intervalos de confianza detallados para las predicciones.

### Actualización Automática

#### 5. Configurar Actualización Automática

```bash
POST /ml/auto-update/configure
Body: {
  "enabled": true,
  "interval": 7,
  "minNewData": 100,
  "autoRetrain": true,
  "checkInterval": 86400000
}
```

#### 6. Obtener Configuración

```bash
GET /ml/auto-update/config
```

#### 7. Verificar Datos Nuevos

```bash
GET /ml/auto-update/check?days=7
```

#### 8. Ejecutar Actualización Automática

```bash
POST /ml/auto-update/execute
```

#### 9. Programar Actualización

```bash
POST /ml/auto-update/schedule
```

#### 10. Estadísticas de Actualizaciones

```bash
GET /ml/auto-update/statistics
```

#### 11. Actualización Manual

```bash
POST /ml/auto-update/manual
Body: {
  "months": 3,
  "testSize": 0.2,
  "modelType": "logistic_regression"
}
```

## 📊 Estructura de Datos

### Datos de Visualización

```json
{
  "success": true,
  "data": {
    "dateRange": {
      "startDate": "2024-01-01",
      "endDate": "2024-01-07"
    },
    "granularity": "hour",
    "chartData": [
      {
        "timestamp": 1704067200000,
        "date": "2024-01-01",
        "hour": 8,
        "predicted": 85,
        "real": 82,
        "error": 3,
        "accuracy": 96.3,
        "confidenceInterval": {
          "lower": 75,
          "upper": 95,
          "confidence": 0.95
        },
        "confidence": 0.92
      }
    ],
    "summary": {
      "totalPredictions": 168,
      "averagePredicted": 45.2,
      "averageReal": 43.8,
      "averageError": 2.1,
      "averageAccuracy": 95.2,
      "averageConfidence": 0.88
    }
  }
}
```

### Datos para Gráfico de Líneas

```json
{
  "success": true,
  "chartData": {
    "labels": ["01/01 8:00", "01/01 9:00", ...],
    "datasets": [
      {
        "label": "Predicción ML",
        "data": [85, 92, ...],
        "borderColor": "rgb(75, 192, 192)"
      },
      {
        "label": "Datos Reales",
        "data": [82, 89, ...],
        "borderColor": "rgb(255, 99, 132)"
      },
      {
        "label": "Intervalo Confianza Superior",
        "data": [95, 102, ...],
        "borderDash": [5, 5]
      },
      {
        "label": "Intervalo Confianza Inferior",
        "data": [75, 82, ...],
        "borderDash": [5, 5]
      }
    ]
  }
}
```

## 🎯 Intervalos de Confianza

### Cálculo

Los intervalos de confianza se calculan usando:
- **95% de confianza**: z-score = 1.96
- Basado en errores históricos cuando hay datos reales
- Basado en confianza del modelo cuando solo hay predicciones

### Estructura

```json
{
  "confidenceInterval": {
    "lower": 75,
    "upper": 95,
    "confidence": 0.95
  }
}
```

## 🔄 Actualización Automática

### Configuración

```json
{
  "enabled": true,
  "interval": 7,
  "minNewData": 100,
  "autoRetrain": true,
  "checkInterval": 86400000
}
```

### Parámetros

- **enabled**: Habilitar/deshabilitar actualización automática
- **interval**: Días a verificar para datos nuevos
- **minNewData**: Mínimo de registros nuevos requeridos
- **autoRetrain**: Reentrenar automáticamente si hay datos suficientes
- **checkInterval**: Intervalo de verificación en milisegundos (24 horas = 86400000)

### Flujo de Actualización

1. Verificación periódica de datos nuevos
2. Validación de cantidad mínima de datos
3. Reentrenamiento automático (si está habilitado)
4. Guardado de historial de actualizaciones
5. Notificación de resultados

## 📈 Granularidades Disponibles

### Por Hora
- Muestra predicciones hora por hora
- Ideal para análisis detallado
- Incluye intervalos de confianza por hora

### Por Día
- Agrupa predicciones diarias
- Ideal para comparación diaria
- Muestra totales y promedios

### Por Semana
- Agrupa por semana
- Ideal para tendencias a largo plazo
- Muestra promedios semanales

## 🔍 Casos de Uso

1. **Visualización en Dashboard**
   - Usar `/ml/visualization/line-chart` para gráfico principal
   - Mostrar predicciones vs reales con intervalos de confianza
   - Actualizar automáticamente cada hora

2. **Análisis de Precisión**
   - Comparar predicciones con datos reales
   - Identificar horas con mayor error
   - Ajustar modelo según resultados

3. **Planificación Operativa**
   - Usar predicciones para planificar recursos
   - Considerar intervalos de confianza para margen de seguridad
   - Monitorear tendencias a largo plazo

4. **Actualización Automática**
   - Configurar verificación semanal
   - Reentrenar automáticamente con nuevos datos
   - Monitorear historial de actualizaciones

## 📌 Notas

- Los intervalos de confianza se calculan automáticamente cuando hay datos reales
- La actualización automática requiere configuración explícita
- El historial de actualizaciones se guarda en `backend/data/update_history/`
- Las visualizaciones son compatibles con Chart.js, D3.js, y otras librerías de gráficos

## 🎨 Ejemplo de Integración Frontend

```javascript
// Obtener datos para gráfico
const response = await fetch('/ml/visualization/line-chart?days=7');
const { chartData } = await response.json();

// Configurar Chart.js
const ctx = document.getElementById('predictionChart').getContext('2d');
new Chart(ctx, {
  type: 'line',
  data: chartData,
  options: {
    responsive: true,
    scales: {
      y: { beginAtZero: true }
    }
  }
});
```

## 🔄 Scheduler Recomendado

Para producción, implementar scheduler usando:
- **node-cron**: Para programación periódica
- **node-schedule**: Alternativa más flexible
- **Cron jobs del sistema**: Para mayor confiabilidad

Ejemplo con node-cron:
```javascript
const cron = require('node-cron');

// Ejecutar verificación diaria a las 2 AM
cron.schedule('0 2 * * *', async () => {
  await autoUpdateService.performAutoUpdateCheck();
});
```

