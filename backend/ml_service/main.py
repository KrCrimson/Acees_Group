# -*- coding: utf-8 -*-
"""
FastAPI ML Service para Acees Group
Microservicio de Machine Learning basado en metodología médica
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Optional, Any
import pandas as pd
import numpy as np
import joblib
from datetime import datetime, timedelta
import os
import traceback

# Imports locales
from model_trainer import AceesMLTrainer
from data_preparation import AceesDatasetCreator

app = FastAPI(
    title="Acees Group ML Service",
    description="Servicio de Machine Learning para predicción de accesos universitarios",
    version="1.0.0"
)

# Configuración
MONGO_URI = os.getenv("MONGO_URI", "mongodb+srv://Angel:angel12345@cluster0.pas0twe.mongodb.net")
MODELS_DIR = "models"

# Crear directorio de modelos
os.makedirs(MODELS_DIR, exist_ok=True)

# Pydantic models para requests
class TrainingRequest(BaseModel):
    months: int = 3
    problem_type: str = "regression"  # "regression", "classification", "multiclass"

class PredictionRequest(BaseModel):
    start_datetime: str  # "2026-03-13T08:00:00"
    end_datetime: str    # "2026-03-13T18:00:00"
    faculty: Optional[str] = "all"

class DataSummaryRequest(BaseModel):
    months: int = 3

# Global variables para modelos cargados
current_model = None
current_preprocessor = None
current_problem_type = None

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "Acees Group ML Service",
        "version": "1.0.0",
        "message": "Basado en metodología de proyecto médico, adaptado para datos universitarios"
    }

@app.get("/health")
async def health_check():
    """Detailed health check"""
    try:
        # Test MongoDB connection
        creator = AceesDatasetCreator(MONGO_URI)
        test_count = creator.asistencias.count_documents({})
        
        return {
            "status": "healthy",
            "mongodb_connected": True,
            "total_attendance_records": test_count,
            "model_loaded": current_model is not None,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Service unhealthy: {str(e)}")

@app.post("/data/summary")
async def get_data_summary(request: DataSummaryRequest):
    """
    Obtener resumen de datos disponibles
    Similar al EDA de tu proyecto médico
    """
    try:
        creator = AceesDatasetCreator(MONGO_URI)
        df = creator.collect_historical_data(months=request.months)
        summary = creator.get_dataset_summary(df)
        
        # Estadísticas adicionales como en tu proyecto
        df_features = creator.create_temporal_features(df)
        
        # Distribución por hora (similar a tus histogramas)
        hourly_dist = df_features.groupby('hora').size().to_dict()
        
        # Distribución por día de semana
        weekly_dist = df_features.groupby('dia_semana').size().to_dict()
        
        # Top facultades
        faculty_dist = df_features['siglas_facultad'].value_counts().head(5).to_dict()
        
        return {
            "status": "success",
            "basic_summary": summary,
            "distributions": {
                "by_hour": hourly_dist,
                "by_weekday": weekly_dist,
                "by_faculty": faculty_dist
            },
            "recommendations": {
                "sufficient_data": summary['total_records'] >= 1000,
                "good_time_coverage": summary['time_coverage']['hours_covered'] >= 12,
                "data_quality": "good" if summary['total_records'] >= 1000 else "limited"
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting data summary: {str(e)}")

@app.post("/train")
async def train_model(request: TrainingRequest):
    """
    Entrenar modelo ML (igual metodología que proyecto médico)
    """
    global current_model, current_preprocessor, current_problem_type
    
    try:
        print(f"🚀 Iniciando entrenamiento - {request.problem_type}")
        
        # Validar tipo de problema
        valid_types = ["regression", "classification", "multiclass"]
        if request.problem_type not in valid_types:
            raise ValueError(f"problem_type debe ser uno de: {valid_types}")
        
        # Crear trainer
        trainer = AceesMLTrainer(MONGO_URI)
        
        # Entrenar (siguiendo tu metodología)
        results = trainer.train_and_evaluate(
            problem_type=request.problem_type,
            months=request.months
        )
        
        # Seleccionar mejor modelo (igual que tu proyecto)
        results_df = results['results']
        
        if request.problem_type == "regression":
            best_model_name = results_df.loc[results_df['r2'].idxmax(), 'model_name']
            best_score = results_df.loc[results_df['r2'].idxmax(), 'r2']
            score_type = "R²"
        else:
            best_model_name = results_df.loc[results_df['f1'].idxmax(), 'model_name']
            best_score = results_df.loc[results_df['f1'].idxmax(), 'f1']
            score_type = "F1-Score"
        
        # Entrenar mejor modelo en datos completos
        best_pipeline = results['models'][best_model_name]
        best_pipeline.fit(results['X_train'], results['y_train'])
        
        # Evaluar en test set (igual que tu proyecto)
        X_test = results['X_test']
        y_test = results['y_test']
        y_pred = best_pipeline.predict(X_test)
        
        if request.problem_type == "regression":
            from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
            test_metrics = {
                "mae": float(mean_absolute_error(y_test, y_pred)),
                "rmse": float(np.sqrt(mean_squared_error(y_test, y_pred))),
                "r2": float(r2_score(y_test, y_pred))
            }
        else:
            from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
            test_metrics = {
                "accuracy": float(accuracy_score(y_test, y_pred)),
                "precision": float(precision_score(y_test, y_pred, average='macro')),
                "recall": float(recall_score(y_test, y_pred, average='macro')),
                "f1": float(f1_score(y_test, y_pred, average='macro'))
            }
        
        # Guardar modelo (igual que tu proyecto con joblib)
        model_filename = f"{MODELS_DIR}/acees_model_{request.problem_type}.pkl"
        joblib.dump(best_pipeline, model_filename)
        
        # Cargar modelo en memoria
        current_model = best_pipeline
        current_preprocessor = best_pipeline.named_steps['prep']
        current_problem_type = request.problem_type
        
        return {
            "status": "success",
            "message": "Modelo entrenado exitosamente usando metodología médica adaptada",
            "best_model": {
                "name": best_model_name,
                "cv_score": float(best_score),
                "score_type": score_type
            },
            "test_metrics": test_metrics,
            "training_config": {
                "months": request.months,
                "problem_type": request.problem_type,
                "total_records": len(results['X_train']) + len(results['X_test']),
                "train_size": len(results['X_train']),
                "test_size": len(results['X_test'])
            },
            "all_models_performance": results_df.to_dict('records'),
            "model_path": model_filename
        }
        
    except Exception as e:
        error_msg = f"Error during training: {str(e)}\n{traceback.format_exc()}"
        print(f"❌ {error_msg}")
        raise HTTPException(status_code=500, detail=error_msg)

@app.post("/predict")
async def predict(request: PredictionRequest):
    """
    Realizar predicciones con modelo entrenado
    Similar al ejemplo de uso de tu proyecto médico
    """
    global current_model, current_problem_type
    
    if current_model is None:
        raise HTTPException(status_code=400, detail="No hay modelo entrenado. Ejecutar /train primero.")
    
    try:
        # Parsear fechas
        start_dt = datetime.fromisoformat(request.start_datetime)
        end_dt = datetime.fromisoformat(request.end_datetime)
        
        if start_dt >= end_dt:
            raise ValueError("start_datetime debe ser menor que end_datetime")
        
        # Generar datos para predicción
        predictions_data = []
        current_dt = start_dt
        
        while current_dt <= end_dt:
            # Crear características igual que en entrenamiento
            features = {
                'hora': current_dt.hour,
                'dia_semana': current_dt.weekday(),
                'mes': current_dt.month,
                'es_fin_semana': 1 if current_dt.weekday() >= 5 else 0,
                'horario_clases': 1 if current_dt.hour in [7,8,9,10,11,14,15,16,17,18] else 0,
                'hora_almuerzo': 1 if current_dt.hour in [12,13] else 0,
                'facultad': 0 if request.faculty == "all" else hash(request.faculty) % 10
            }
            
            predictions_data.append({
                'datetime': current_dt.isoformat(),
                'features': features
            })
            
            current_dt += timedelta(hours=1)
        
        # Crear DataFrame para predicción
        features_df = pd.DataFrame([p['features'] for p in predictions_data])
        
        # Hacer predicciones
        predictions = current_model.predict(features_df)
        
        # Formatear resultados
        results = []
        for i, pred_data in enumerate(predictions_data):
            result = {
                'datetime': pred_data['datetime'],
                'predicted_value': float(predictions[i])
            }
            
            if current_problem_type == "regression":
                result['interpretation'] = {
                    'expected_accesses': int(round(predictions[i])),
                    'congestion_level': 'alto' if predictions[i] >= 50 else 'normal'
                }
            else:
                result['interpretation'] = {
                    'is_peak_hour': bool(predictions[i] >= 0.5),
                    'probability': float(predictions[i])
                }
            
            results.append(result)
        
        # Estadísticas del pronóstico
        pred_values = [r['predicted_value'] for r in results]
        forecast_stats = {
            'total_predictions': len(results),
            'avg_predicted': float(np.mean(pred_values)),
            'max_predicted': float(np.max(pred_values)),
            'min_predicted': float(np.min(pred_values)),
            'std_predicted': float(np.std(pred_values))
        }
        
        return {
            "status": "success", 
            "predictions": results,
            "forecast_stats": forecast_stats,
            "model_info": {
                "type": current_problem_type,
                "prediction_range": {
                    "start": request.start_datetime,
                    "end": request.end_datetime
                }
            }
        }
        
    except Exception as e:
        error_msg = f"Error during prediction: {str(e)}"
        print(f"❌ {error_msg}")
        raise HTTPException(status_code=500, detail=error_msg)

@app.post("/load_model") 
async def load_model(model_type: str = "regression"):
    """
    Cargar modelo previamente entrenado
    """
    global current_model, current_preprocessor, current_problem_type
    
    try:
        model_filename = f"{MODELS_DIR}/acees_model_{model_type}.pkl"
        
        if not os.path.exists(model_filename):
            raise FileNotFoundError(f"Modelo {model_type} no encontrado. Entrenar primero.")
        
        # Cargar modelo (igual que tu proyecto)
        current_model = joblib.load(model_filename)
        current_preprocessor = current_model.named_steps['prep']
        current_problem_type = model_type
        
        return {
            "status": "success",
            "message": f"Modelo {model_type} cargado exitosamente",
            "model_path": model_filename
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading model: {str(e)}")

@app.get("/models/available")
async def list_available_models():
    """
    Listar modelos disponibles
    """
    try:
        models = []
        for model_type in ["regression", "classification", "multiclass"]:
            model_path = f"{MODELS_DIR}/acees_model_{model_type}.pkl"
            if os.path.exists(model_path):
                stat = os.stat(model_path)
                models.append({
                    "type": model_type,
                    "path": model_path,
                    "size_mb": round(stat.st_size / 1024 / 1024, 2),
                    "created_at": datetime.fromtimestamp(stat.st_ctime).isoformat(),
                    "is_loaded": current_problem_type == model_type
                })
        
        return {
            "status": "success",
            "available_models": models,
            "total_models": len(models)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing models: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)