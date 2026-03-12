# 🧠 Microservicio ML para Acees Group

## Basado en Metodología del Proyecto Médico de Enfermedades Cardíacas

Este microservicio adapta **tu excelente metodología** del proyecto médico para el contexto de control de acceso universitario.

---

## 🎯 **RESPUESTA A TU PREGUNTA**

### **¿Funcionaría igual sin "respuestas correctas"?**
**¡SÍ FUNCIONA IGUAL!** Pero necesitamos **crear los targets (respuestas) artificialmente** a partir de tus datos de asistencia.

### **Diferencia Clave:**

| Tu Proyecto Médico | Acees Group |
|-------------------|-------------|
| **Labels explícitos:** Médico diagnosticó cada paciente (1=enfermo, 0=sano) | **Labels implícitos:** Creamos targets contando accesos por hora |
| `paciente → target=1 (diagnosticado enfermo)` | `2026-03-12 08:00 → target=87 (87 accesos registrados)` |

---

## 📊 **CÓMO CREAMOS LOS "LABELS" AUTOMÁTICAMENTE**

### **ENFOQUE 1: Regresión (Principal)**
```python
# De tus datos de asistencia MongoDB:
asistencia_1: 2026-03-12 08:15 - juan_perez - entrada - facem
asistencia_2: 2026-03-12 08:17 - maria_lopez - entrada - facem  
asistencia_3: 2026-03-12 08:23 - carlos_ruiz - salida - faing

# Los AGRUPAMOS por hora y CONTAMOS:
2026-03-12 08:00 → 87 accesos  ← Este es nuestro TARGET
2026-03-12 09:00 → 45 accesos  ← 
2026-03-12 10:00 → 23 accesos  ←

# Features (igual que tu proyecto):
X = [hora, dia_semana, mes, es_fin_semana, facultad]  ← CARACTERÍSTICAS
y = [87, 45, 23, ...]                                ← TARGETS (números de accesos)
```

### **ENFOQUE 2: Clasificación (Como tu proyecto médico)**
```python
# Convertimos números a clases binarias:
87 accesos → 1 (HORARIO PICO)    ← igual que "enfermo"  
23 accesos → 0 (HORARIO NORMAL)  ← igual que "sano"

# Mismo formato que tu proyecto:
X = [hora, dia_semana, facultad, ...]  ← CARACTERÍSTICAS  
y = [1, 0, 0, 1, 1, 0, ...]           ← TARGETS (horario pico sí/no)
```

---

## 🏗️ **ESTRUCTURA DEL MICROSERVICIO**

```
backend/ml_service/
├── main.py                 # FastAPI service (endpoints ML)
├── data_preparation.py     # Crear datasets (reemplaza tu CSV)
├── model_trainer.py        # Entrenar modelos (igual metodología)  
├── requirements.txt        # Dependencias Python
└── models/                 # Modelos entrenados (joblib)
    ├── acees_model_regression.pkl
    ├── acees_model_classification.pkl
    └── acees_model_multiclass.pkl
```

---

## 🚀 **INSTALACIÓN Y USO**

### **1. Setup del entorno**
```bash
cd backend/ml_service
python -m venv ml_env
source ml_env/bin/activate  # Linux/Mac
# ml_env\Scripts\activate  # Windows

pip install -r requirements.txt
```

### **2. Ejecutar servicio**
```bash
python main.py
# Servidor en http://localhost:8001
```

### **3. Entrenar modelo (igual que tu proyecto médico)**
```bash
curl -X POST "http://localhost:8001/train" \
  -H "Content-Type: application/json" \
  -d '{
    "months": 3,
    "problem_type": "regression"
  }'
```

### **4. Hacer predicciones**
```bash  
curl -X POST "http://localhost:8001/predict" \
  -H "Content-Type: application/json" \
  -d '{
    "start_datetime": "2026-03-13T08:00:00",
    "end_datetime": "2026-03-13T18:00:00", 
    "faculty": "facem"
  }'
```

---

## 📚 **METODOLOGÍA ADAPTADA DE TU PROYECTO**

### ✅ **Lo que MANTUVIMOS igual:**
- **División train/test estratificada** (`train_test_split`)
- **Pipeline de preprocesamiento** (`ColumnTransformer`, `StandardScaler`)  
- **Cross-validation K-Fold** para evaluación robusta
- **Múltiples algoritmos** comparados simultáneamente
- **Optimización de hiperparámetros** (`RandomizedSearchCV`)
- **Análisis exhaustivo de métricas**
- **Persistencia del modelo** con `joblib`
- **Estructura de código modular**

### 🔄 **Lo que ADAPTAMOS:**
- **Datos:** CSV médico → MongoDB asistencias
- **Features:** Edad, presión, colesterol → Hora, día, facultad, mes
- **Target:** Enfermo/Sano → Número de accesos por hora
- **Métricas:** Accuracy, F1-Score → MAE, RMSE, R²
- **Modelos:** Clasificación → Regresión principalmente

---

## 🎯 **TIPOS DE PREDICCIÓN DISPONIBLES**

### **1. Regresión (Principal)**
```python
# Predice: ¿Cuántos accesos habrá?
input:  [hora=8, dia_semana=1, facultad="facem"]
output: 87.3 accesos estimados
```

### **2. Clasificación (Como tu proyecto)**
```python 
# Predice: ¿Será horario pico?
input:  [hora=8, dia_semana=1, facultad="facem"]  
output: probability=0.89 → SÍ es horario pico (como "enfermo")
```

### **3. Multi-clase**
```python
# Predice: Nivel de congestión  
input:  [hora=8, dia_semana=1, facultad="facem"]
output: clase=3 → "Congestión alta"
```

---

## 📊 **VENTAJAS vs Tu Dataset Médico**

| Aspecto | Proyecto Médico | Acees Group |
|---------|-----------------|-------------|
| **Volumen** | 1,025 registros | 50,000+ registros ✅ |
| **Temporalidad** | Datos estáticos | Series temporales ✅ |
| **Variedad** | 1 tipo problema | 3 tipos problemas ✅ |
| **Actualización** | Dataset fijo | Datos crecen diariamente ✅ |
| **Aplicabilidad** | Medicina | Logística/Optimización ✅ |

---

## 🔮 **EJEMPLOS DE PREDICCIONES**

### **Prediction API Response:**
```json
{
  "status": "success",
  "predictions": [
    {
      "datetime": "2026-03-13T08:00:00",
      "predicted_value": 87.3,
      "interpretation": {
        "expected_accesses": 87,
        "congestion_level": "alto"
      }
    },
    {
      "datetime": "2026-03-13T09:00:00", 
      "predicted_value": 45.1,
      "interpretation": {
        "expected_accesses": 45,
        "congestion_level": "normal"
      }
    }
  ],
  "forecast_stats": {
    "avg_predicted": 66.2,
    "max_predicted": 87.3,
    "min_predicted": 23.8
  }
}
```

---

## 🎉 **CONCLUSIÓN**

**¡Tu metodología médica es PERFECTA para este proyecto!** 

### **Lo que hicimos:**
1. ✅ **Mantuvimos tu estructura de código excelente**
2. ✅ **Adaptamos los datos** médicos → universitarios  
3. ✅ **Creamos targets automáticamente** de los datos de asistencia
4. ✅ **Seguimos las mejores prácticas** que implementaste
5. ✅ **Ampliamos a múltiples tipos** de problema ML

### **El resultado:**
- **Mismo rigor metodológico** que tu proyecto médico
- **Mejor dataset** (más grande, temporal, diverso)
- **Mayor aplicabilidad** (optimización recursos universitarios)
- **Escalabilidad** futura con más datos

**Tu proyecto médico es la BASE PERFECTA.** Solo necesitábamos adaptar:
- Médico → Universitario  
- CSV → MongoDB
- Clasificación → Regresión + Clasificación
- Variables biométricas → Variables temporales

**¡El enfoque "sin respuestas explícitas" funciona perfecto porque CREAMOS las respuestas!** 🚀