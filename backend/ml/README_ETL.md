# Sistema ETL de Datos Históricos para ML - Documentación

## 📋 Descripción

Sistema completo ETL (Extract, Transform, Load) para recopilar, limpiar y validar datos históricos de entrada/salida para alimentar algoritmos de Machine Learning.

## ✅ Acceptance Criteria Cumplidos

- ✅ **ETL datos históricos implementado**: Pipeline completo de extracción, transformación y carga
- ✅ **Estructura para ML definida**: Schema y validación de estructura ML estándar
- ✅ **Limpieza datos automatizada**: Algoritmos avanzados de limpieza y preprocesamiento

## 📁 Archivos Creados

```
backend/ml/
├── historical_data_etl.js          ✅ ETL básico de datos históricos
├── ml_data_structure.js            ✅ Estructura de datos ML
├── data_cleaning_service.js        ✅ Servicio de limpieza de datos
├── data_quality_validator.js       ✅ Validador de calidad de datos
└── ml_etl_service.js              ✅ Servicio ETL integrado para ML
```

## 🚀 Endpoints Disponibles

### 1. Pipeline ETL Completo para ML

```bash
POST /ml/etl/pipeline
Body: {
  "months": 3,
  "cleanData": true,
  "validateData": true,
  "aggregateByHour": true,
  "normalizeStructure": true
}
```

Ejecuta pipeline completo con extracción, transformación, limpieza y validación.

### 2. ETL Básico

```bash
POST /ml/etl/basic
Body: {
  "months": 3,
  "cleanData": true,
  "validateData": true,
  "aggregateByHour": true
}
```

Ejecuta ETL básico sin normalización de estructura ML.

### 3. Limpiar Datos

```bash
POST /ml/etl/clean
Body: {
  "dataPath": "/path/to/data.json",
  "strategy": "impute"
}
```

Aplica algoritmos de limpieza a datos existentes.

### 4. Validar Calidad

```bash
POST /ml/etl/validate
Body: {
  "dataPath": "/path/to/data.json"
}
```

Valida calidad de datos existentes.

### 5. Obtener Estadísticas

```bash
GET /ml/etl/statistics
GET /ml/etl/statistics?dataPath=/path/to/data.json
```

Obtiene estadísticas del dataset procesado.

### 6. Obtener Estructura ML

```bash
GET /ml/etl/structure
```

Obtiene estructura ML definida.

### 7. Validar Estructura

```bash
POST /ml/etl/validate-structure
Body: {
  "data": [...]
}
```

Valida que datos cumplan con estructura ML.

### 8. Reporte de Calidad

```bash
POST /ml/etl/quality-report
Body: {
  "dataPath": "/path/to/data.json"
  // o
  "data": [...]
}
```

Genera reporte completo de calidad de datos.

## 🔄 Pipeline ETL Completo

### Fases del Pipeline

1. **EXTRACT** - Extracción de datos históricos
   - Consulta MongoDB por rango de fechas
   - Filtrado y selección de campos
   - Guardado de datos raw

2. **TRANSFORM** - Transformación de datos
   - Agregación por hora (opcional)
   - Extracción de características temporales
   - Normalización de formatos

3. **CLEAN** - Limpieza de datos
   - Eliminación de duplicados
   - Manejo de valores faltantes
   - Detección y manejo de outliers
   - Normalización de formatos

4. **VALIDATE** - Validación de calidad
   - Completitud
   - Consistencia
   - Validez
   - Unicidad
   - Actualidad

5. **NORMALIZE** - Normalización a estructura ML
   - Aplicación de schema ML
   - Validación de estructura
   - Preparación para ML

6. **LOAD** - Carga de datos procesados
   - Guardado de datos procesados
   - Generación de reportes

## 📊 Estructura de Datos ML

### Schema Definido

```json
{
  "features": {
    "temporal": {
      "hora": { "type": "numeric", "range": [0, 23] },
      "dia_semana": { "type": "numeric", "range": [0, 6] },
      "mes": { "type": "numeric", "range": [1, 12] },
      "es_fin_semana": { "type": "binary", "values": [0, 1] },
      "es_feriado": { "type": "binary", "values": [0, 1] }
    },
    "estudiante": {
      "siglas_facultad": { "type": "string" },
      "siglas_escuela": { "type": "string" }
    },
    "acceso": {
      "tipo": { "type": "categorical", "values": ["entrada", "salida"] },
      "puerta": { "type": "string" }
    }
  },
  "target": {
    "target": { "type": "numeric" },
    "is_peak_hour": { "type": "binary", "values": [0, 1] }
  }
}
```

## 🧹 Algoritmos de Limpieza

### Estrategias Implementadas

1. **Valores Faltantes**
   - `impute`: Imputación con valores por defecto
   - `remove`: Eliminación de registros incompletos
   - `forward_fill`: Forward fill con último valor válido

2. **Outliers**
   - `iqr`: Método IQR (Interquartile Range)
   - `zscore`: Método Z-Score (3 desviaciones estándar)

3. **Normalización**
   - `standard`: Normalización estándar (Z-score)
   - `minmax`: Normalización Min-Max

4. **Codificación**
   - `hash`: Codificación hash de strings
   - `label`: Codificación label (0, 1, 2, ...)

## ✅ Validación de Calidad

### Criterios de Validación

1. **Completitud** (≥95%)
   - Campos requeridos presentes
   - Campos opcionales opcionales

2. **Consistencia** (≥95%)
   - Formatos consistentes
   - Rangos válidos
   - Lógica consistente

3. **Validez** (≥95%)
   - Valores dentro de rangos
   - Tipos correctos
   - Fechas válidas

4. **Unicidad** (≥95%)
   - Sin duplicados
   - Identificadores únicos

5. **Actualidad** (≥80%)
   - Datos recientes
   - No muy antiguos

### Reporte de Calidad

```json
{
  "summary": {
    "isValid": true,
    "overallScore": 0.9234,
    "meetsThresholds": true,
    "totalRecords": 15000
  },
  "checks": {
    "completeness": {
      "isValid": true,
      "score": 0.9821,
      "status": "PASS"
    },
    "consistency": {
      "isValid": true,
      "score": 0.9634,
      "status": "PASS"
    }
  },
  "recommendations": []
}
```

## 📈 Ejemplo de Uso

### 1. Ejecutar Pipeline Completo

```bash
POST /ml/etl/pipeline
Body: {
  "months": 3,
  "cleanData": true,
  "validateData": true
}
```

### 2. Validar Dataset Existente

```bash
POST /ml/etl/validate
Body: {
  "dataPath": "/data/etl/processed/processed_2024-01-15.json"
}
```

### 3. Obtener Estadísticas

```bash
GET /ml/etl/statistics
```

Respuesta incluye:
- Total de registros
- Rango de fechas
- Distribución por hora
- Distribución por día
- Métricas de calidad

## 💡 Características Avanzadas

1. **Agregación por Hora**: Opción de agregar datos por hora para reducir tamaño
2. **Validación Multi-Criterio**: Validación exhaustiva con múltiples criterios
3. **Limpieza Configurable**: Estrategias configurables para diferentes necesidades
4. **Reportes Detallados**: Reportes completos de calidad y limpieza
5. **Estructura ML Estándar**: Schema definido y validado para ML

## ⚙️ Requisitos

- Datos históricos disponibles en MongoDB
- Mínimo 100 registros para ML
- Datos con campos requeridos: fecha_hora, tipo

## 📌 Notas

- El pipeline puede tardar varios minutos con grandes volúmenes de datos
- Los datos raw se guardan en `data/etl/raw/`
- Los datos procesados se guardan en `data/etl/processed/`
- La validación es automática pero configurable
- La estructura ML puede personalizarse según necesidades

