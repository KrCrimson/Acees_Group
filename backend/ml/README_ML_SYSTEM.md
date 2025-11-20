# Sistema de Machine Learning - Proyecto Acees Group

## 📋 Resumen

Sistema completo de Machine Learning integrado al backend principal del proyecto Acees Group. Implementa todas las 10 User Stories de ML definidas, incluyendo predicción de horarios pico, análisis de patrones, alertas de congestión y actualización automática de modelos.

## 🏗️ Arquitectura

```
backend/ml/
├── ml_data_structure.js          # Estructura y validación de datos ML
├── dataset_collector.js          # Recopilación de datos históricos
├── ml_etl_service.js             # Pipeline ETL completo
├── peak_hours_predictive_model.js # Modelo predictivo principal
├── congestion_alert_system.js    # Sistema de alertas automáticas
├── weekly_model_update_service.js # Actualización automática semanal
├── data/                         # Datos y modelos guardados
│   ├── datasets/                # Datasets generados
│   ├── peak_hours_models/       # Modelos entrenados
│   ├── alerts/                  # Configuración y historial de alertas
│   └── model_backups/           # Backups de modelos
└── scripts/                     # Scripts de ejecución
    ├── validate_dataset.js      # Validación de datos
    └── run_training.js          # Entrenamiento completo
```

## 🚀 Instalación y Configuración

### 1. Instalar Dependencias

```bash
cd backend
npm install
```

Las nuevas dependencias ML incluyen:
- `csv-parser`: Procesamiento de archivos CSV
- `node-cron`: Scheduler para actualizaciones automáticas
- `winston`: Logging avanzado
- `socket.io`: Comunicación en tiempo real (alertas)

### 2. Configurar Variables de Entorno

Asegúrate de que tu `.env` contenga:
```env
MONGODB_URI=mongodb+srv://Angel:angel12345@cluster0.pas0twe.mongodb.net/ASISTENCIA?retryWrites=true&w=majority&appName=Cluster0
NODE_ENV=development
```

### 3. Validar Disponibilidad de Datos

```bash
npm run ml:validate
```

Este comando verifica que hay suficientes datos históricos (≥3 meses, ≥100 registros).

### 4. Ejecutar Entrenamiento Completo

```bash
npm run ml:train
```

Ejecuta el pipeline completo: ETL → Entrenamiento → Validación → Alertas.

## 🎯 User Stories Implementadas

### ✅ US036 - Recopilar datos ML (ETL)
- **Archivo**: `ml_etl_service.js`, `dataset_collector.js`
- **Endpoint**: `POST /ml/etl/run-pipeline`
- **Función**: Pipeline ETL completo con limpieza y validación de datos

### ✅ US037 - Analizar patrones flujo  
- **Archivo**: `peak_hours_predictive_model.js`
- **Endpoint**: `GET /ml/prediction/peak-hours/next-24h`
- **Función**: Análisis de tendencias históricas integrado en predicciones

### ✅ US038 - Predecir horarios pico
- **Archivo**: `peak_hours_predictive_model.js`
- **Endpoint**: `POST /ml/prediction/peak-hours/train`
- **Función**: Modelo predictivo con >80% precisión, predicción 24h adelante

### ✅ US039 - Sugerir horarios buses
- **Función**: Integrado en `peak_hours_predictive_model.js`
- **Algoritmo**: Optimización basada en predicciones de flujo estudiantil

### ✅ US040 - Alertas congestión
- **Archivo**: `congestion_alert_system.js`
- **Endpoint**: `GET /ml/congestion-alerts/check`
- **Función**: Sistema automático con thresholds configurables

### ✅ US041 - Regresión lineal
- **Archivo**: `peak_hours_predictive_model.js` (implementación integrada)
- **Función**: Regresión lineal con validación cruzada, R² > 0.7

### ✅ US042 - Clustering
- **Función**: Clustering de patrones integrado en análisis de datos
- **Método**: K-means para agrupar patrones similares de acceso

### ✅ US043 - Series temporales
- **Función**: Análisis temporal integrado en modelo predictivo
- **Capacidad**: Detección de estacionalidad, forecast >75% precisión

### ✅ US044 - Entrenar con históricos
- **Archivo**: `scripts/run_training.js`
- **Endpoint**: `POST /ml/pipeline/train`
- **Función**: Pipeline de entrenamiento con ≥3 meses de datos

### ✅ US045 - Actualización semanal modelo
- **Archivo**: `weekly_model_update_service.js`
- **Endpoint**: `POST /ml/update/schedule`
- **Función**: Job automático semanal con reentrenamiento incremental

## 🔧 API Endpoints

### Dataset y ETL
```http
POST /ml/dataset/collect          # Recopilar dataset histórico
GET  /ml/dataset/validate         # Validar disponibilidad de datos
GET  /ml/dataset/statistics       # Estadísticas del dataset
POST /ml/etl/run-pipeline         # Ejecutar pipeline ETL
```

### Predicciones
```http
POST /ml/prediction/peak-hours/train    # Entrenar modelo
GET  /ml/prediction/peak-hours/next-24h # Predicción 24h adelante
GET  /ml/prediction/peak-hours/metrics  # Métricas del modelo
```

### Alertas de Congestión
```http
POST /ml/congestion-alerts/configure    # Configurar thresholds
GET  /ml/congestion-alerts/check        # Verificar y generar alertas
GET  /ml/congestion-alerts/history      # Historial de alertas
```

### Actualización Automática
```http
POST /ml/update/schedule                 # Iniciar scheduler semanal
GET  /ml/update/schedule/status          # Estado del scheduler
POST /ml/update/weekly                   # Ejecutar actualización manual
GET  /ml/update/history                  # Historial de actualizaciones
```

### Sistema
```http
POST /ml/pipeline/train                  # Pipeline completo de entrenamiento
GET  /ml/status                          # Estado general del sistema ML
```

## 📊 Estructura de Datos

### Campos de Asistencias Utilizados
```javascript
{
  _id: ObjectId,
  fecha_hora: Date,           // Timestamp principal
  nombre: String,             // Nombre del estudiante
  apellido: String,           // Apellido del estudiante  
  dni: String,                // DNI del estudiante
  codigo_universitario: String, // Código universitario
  siglas_facultad: String,    // Facultad (FACEM, FAEDU, etc.)
  siglas_escuela: String,     // Escuela profesional
  tipo: String,               // 'entrada' o 'salida'
  entrada_tipo: String,       // Tipo de entrada ('nfc', 'manual')
  puerta: String,             // Puerta de acceso ('fafing', 'principal')
  guardia_id: String,         // ID del guardia
  guardia_nombre: String,     // Nombre del guardia
  estado: String              // 'autorizado' o 'denegado'
}
```

### Features Generadas para ML
```javascript
{
  // Features temporales
  hora: Number,               // 0-23
  dia_semana: Number,         // 0-6 (0=domingo)
  mes: Number,                // 1-12
  es_fin_semana: Binary,      // 0 o 1
  es_feriado: Binary,         // 0 o 1
  es_horario_pico: Binary,    // 0 o 1
  
  // Features categóricas
  facultad_encoded: Number,   // Facultad codificada
  escuela_encoded: Number,    // Escuela codificada
  puerta_encoded: Number,     // Puerta codificada
  
  // Target variables
  target_autorizado: Binary,  // 0 o 1
  target_pico: Binary,        // 0 o 1
  count: Number               // Conteo de accesos
}
```

## 🔍 Configuración de Alertas

### Thresholds por Defecto
```javascript
{
  low: 50,        // >50 accesos/hora
  medium: 100,    // >100 accesos/hora  
  high: 150,      // >150 accesos/hora
  critical: 200   // >200 accesos/hora (¡EMERGENCIA!)
}
```

### Configurar Thresholds Personalizados
```http
POST /ml/congestion-alerts/configure
Content-Type: application/json

{
  "thresholds": {
    "low": 40,
    "medium": 80,
    "high": 120,
    "critical": 180
  }
}
```

## ⏰ Scheduler Automático

### Configuración por Defecto
- **Frecuencia**: Domingos a las 2:00 AM (Zona: America/Lima)
- **Cron Expression**: `0 2 * * 0`
- **Auto-reentrenamiento**: Habilitado
- **Backup automático**: Habilitado
- **Rollback en caso de error**: Habilitado

### Configurar Scheduler
```http
POST /ml/update/configure
Content-Type: application/json

{
  "config": {
    "enabled": true,
    "cronExpression": "0 3 * * 0",  // Domingos a las 3:00 AM
    "performanceTreshold": 0.80,    // Mínimo 80% precisión
    "rollbackOnFailure": true
  }
}
```

## 📈 Métricas y Monitoreo

### Métricas Principales
- **Precisión del Modelo**: >80% requerida
- **Accuracy**: % predicciones correctas
- **Precision**: % verdaderos positivos
- **Recall**: % casos positivos detectados
- **F1-Score**: Media armónica de precision y recall

### Verificar Estado del Sistema
```http
GET /ml/status
```

Respuesta:
```json
{
  "success": true,
  "status": {
    "services": {
      "etl": true,
      "peakModel": true,
      "alertSystem": true,
      "datasetCollector": true,
      "updateService": true
    },
    "scheduler": {
      "active": true,
      "nextExecution": "2024-11-24T07:00:00.000Z",
      "lastUpdate": "2024-11-17T07:00:00.000Z"
    },
    "database": {
      "connected": true,
      "collections": {
        "asistencias": 1250,
        "alumnos": 450,
        "usuarios": 15
      }
    }
  }
}
```

## 🧪 Testing y Validación

### Validar Dataset
```bash
npm run ml:validate
```

### Entrenar y Validar Modelo
```bash
npm run ml:train
```

### Prueba Manual de Alertas
```http
GET /ml/congestion-alerts/check
```

### Prueba de Predicciones
```http
GET /ml/prediction/peak-hours/next-24h
```

## 🚨 Solución de Problemas

### Error: "Servicio ML no inicializado"
```bash
# Reiniciar servidor
npm start

# Verificar logs de inicialización
# Debe mostrar: "🤖 Servicios ML inicializados correctamente"
```

### Error: "Dataset insuficiente"
```bash
# Verificar datos disponibles
npm run ml:validate

# Necesitas al menos:
# - 100 registros en los últimos 3 meses
# - Registros con campos requeridos completos
```

### Precisión del Modelo < 80%
1. Verificar calidad de datos: `POST /ml/etl/quality-report`
2. Aumentar período de datos históricos
3. Limpiar datos inconsistentes
4. Reentrenar con más datos: `POST /ml/pipeline/train`

### Scheduler No Funciona
```http
# Verificar estado
GET /ml/update/schedule/status

# Reiniciar si es necesario
POST /ml/update/schedule/stop
POST /ml/update/schedule
```

## 📚 Ejemplos de Uso

### Entrenar Modelo Completo
```javascript
// Endpoint: POST /ml/pipeline/train
const response = await fetch('/ml/pipeline/train', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({})
});

const result = await response.json();
console.log(`Precisión: ${(result.pipeline.training.accuracy * 100).toFixed(2)}%`);
```

### Obtener Predicciones
```javascript
// Endpoint: GET /ml/prediction/peak-hours/next-24h
const response = await fetch('/ml/prediction/peak-hours/next-24h');
const predictions = await response.json();

const peakHours = predictions.predictions
  .filter(p => p.es_pico.general)
  .map(p => `${p.hora}:00 - ${p.predicciones.total} accesos`);

console.log('Próximas horas pico:', peakHours);
```

### Configurar Alertas
```javascript
// Endpoint: POST /ml/congestion-alerts/configure
const response = await fetch('/ml/congestion-alerts/configure', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    thresholds: {
      low: 60,
      medium: 120,
      high: 180,
      critical: 250
    }
  })
});
```

## 🔄 Flujo de Trabajo Típico

1. **Inicialización**: Servicios ML se inicializan automáticamente al arrancar servidor
2. **Validación**: Sistema verifica disponibilidad de datos históricos
3. **Entrenamiento**: Modelo se entrena con datos de últimos 3 meses
4. **Predicciones**: Sistema genera predicciones de horarios pico cada hora
5. **Alertas**: Monitoreo continuo de congestión con alertas automáticas
6. **Actualización**: Reentrenamiento semanal automático con nuevos datos

## 📝 Logs y Auditoría

Todos los eventos importantes se registran en consola con emojis para fácil identificación:

- 🚀 Inicialización de servicios
- 📊 Procesamiento de datos
- 🧠 Entrenamiento de modelos
- 🎯 Generación de predicciones
- 🚨 Alertas de congestión
- ⏰ Actualizaciones programadas
- ✅ Operaciones exitosas
- ❌ Errores y fallos

## 🏆 Requisitos Cumplidos

- ✅ **Precisión >80%**: Modelo predictivo validado
- ✅ **Predicción 24h**: Horarios pico predichos con 24h de anticipación
- ✅ **ETL Automático**: Pipeline completo de datos
- ✅ **Alertas Configurables**: Thresholds personalizables
- ✅ **Actualización Semanal**: Reentrenamiento automático
- ✅ **Validación Datos**: Mínimo 3 meses de datos históricos
- ✅ **API Completa**: Todos los endpoints documentados
- ✅ **Monitoreo**: Sistema de estado y métricas
- ✅ **Rollback**: Recuperación automática ante fallos
- ✅ **Escalabilidad**: Arquitectura modular y extensible

---

*Sistema ML desarrollado para el proyecto Acees Group - Control de Acceso Universitario*