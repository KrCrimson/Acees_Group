# -*- coding: utf-8 -*-
"""
Preparación de Dataset para Acees Group ML
Conversión de datos de asistencia a formato de Machine Learning
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from pymongo import MongoClient
from typing import Dict, Tuple, List
import warnings
warnings.filterwarnings("ignore")

class AceesDatasetCreator:
    """
    Crea datasets de ML a partir de datos de asistencias NFC
    Similar al proyecto médico pero adaptado para datos temporales
    """
    
    def __init__(self, mongo_uri: str, db_name: str = "ASISTENCIA"):
        self.client = MongoClient(mongo_uri)
        self.db = self.client[db_name]
        self.asistencias = self.db.asistencias
        
    def collect_historical_data(self, months: int = 3) -> pd.DataFrame:
        """
        Recopila datos históricos de asistencias
        Similar a tu proyecto médico pero desde MongoDB
        """
        cutoff_date = datetime.now() - timedelta(days=30 * months)
        
        pipeline = [
            {"$match": {"fecha_hora": {"$gte": cutoff_date}}},
            {"$project": {
                "fecha_hora": 1,
                "tipo": 1,
                "siglas_facultad": 1,
                "siglas_escuela": 1,
                "puerta": 1,
                "guardia_nombre": 1,
                "codigo_universitario": 1
            }}
        ]
        
        cursor = self.asistencias.aggregate(pipeline)
        data = list(cursor)
        
        if not data:
            raise ValueError(f"No se encontraron datos en los últimos {months} meses")
        
        df = pd.DataFrame(data)
        df['fecha_hora'] = pd.to_datetime(df['fecha_hora'])
        
        print(f"✅ Datos recopilados: {len(df)} registros desde {cutoff_date.strftime('%Y-%m-%d')}")
        return df
    
    def create_temporal_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Crear características temporales
        Equivalente a tu función create_features pero para tiempo
        """
        df_features = df.copy()
        
        # Características temporales básicas
        df_features['hora'] = df_features['fecha_hora'].dt.hour
        df_features['minuto'] = df_features['fecha_hora'].dt.minute
        df_features['dia_semana'] = df_features['fecha_hora'].dt.dayofweek
        df_features['dia_mes'] = df_features['fecha_hora'].dt.day
        df_features['mes'] = df_features['fecha_hora'].dt.month
        df_features['semana_anio'] = df_features['fecha_hora'].dt.isocalendar().week
        
        # Características categóricas de tiempo
        df_features['es_fin_semana'] = df_features['dia_semana'].isin([5, 6]).astype(int)
        df_features['es_lunes'] = (df_features['dia_semana'] == 0).astype(int)
        df_features['es_viernes'] = (df_features['dia_semana'] == 4).astype(int)
        
        # Períodos del día
        df_features['periodo_dia'] = pd.cut(
            df_features['hora'],
            bins=[0, 6, 12, 18, 24],
            labels=['madrugada', 'mañana', 'tarde', 'noche'],
            include_lowest=True
        )
        
        # Horarios típicos universitarios
        df_features['horario_clases'] = df_features['hora'].isin([7, 8, 9, 10, 11, 14, 15, 16, 17, 18]).astype(int)
        df_features['hora_almuerzo'] = df_features['hora'].isin([12, 13]).astype(int)
        df_features['hora_entrada_matutina'] = df_features['hora'].isin([7, 8]).astype(int)
        df_features['hora_salida_tarde'] = df_features['hora'].isin([17, 18, 19]).astype(int)
        
        # Características de ubicación
        df_features['facultad_encoded'] = df_features['siglas_facultad'].astype('category').cat.codes
        df_features['escuela_encoded'] = df_features['siglas_escuela'].astype('category').cat.codes
        df_features['puerta_encoded'] = df_features['puerta'].astype('category').cat.codes
        
        return df_features
    
    def create_regression_dataset(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.Series]:
        """
        ENFOQUE 1: Dataset para REGRESIÓN
        Target: Número de accesos por hora
        Similar a tu proyecto pero prediciendo cantidad en lugar de clase
        """
        # Crear características temporales
        df_with_features = self.create_temporal_features(df)
        
        # Agregar por hora para contar accesos
        hourly_agg = df_with_features.groupby([
            df_with_features['fecha_hora'].dt.date,
            df_with_features['fecha_hora'].dt.hour,
            'siglas_facultad'
        ]).agg({
            'codigo_universitario': 'count',  # Contar accesos total
            'tipo': lambda x: (x == 'entrada').sum(),  # Contar entradas
            'dia_semana': 'first',
            'mes': 'first', 
            'es_fin_semana': 'first',
            'horario_clases': 'first',
            'hora_almuerzo': 'first'
        }).reset_index()
        
        # Renombrar columnas
        hourly_agg.columns = [
            'fecha', 'hora', 'facultad', 'num_accesos', 'num_entradas',
            'dia_semana', 'mes', 'es_fin_semana', 'horario_clases', 'hora_almuerzo'
        ]
        
        # Calcular salidas
        hourly_agg['num_salidas'] = hourly_agg['num_accesos'] - hourly_agg['num_entradas']
        
        # Features para el modelo
        feature_columns = [
            'hora', 'dia_semana', 'mes', 'es_fin_semana', 
            'horario_clases', 'hora_almuerzo', 'facultad'
        ]
        
        X = hourly_agg[feature_columns].copy()
        # Codificar facultad
        X['facultad'] = X['facultad'].astype('category').cat.codes
        
        y = hourly_agg['num_accesos']  # TARGET: número de accesos
        
        print(f"✅ Dataset de regresión creado:")
        print(f"   - Samples: {len(X)}")
        print(f"   - Features: {len(feature_columns)}")
        print(f"   - Target: accesos por hora (min: {y.min()}, max: {y.max()}, mean: {y.mean():.1f})")
        
        return X, y
    
    def create_classification_dataset(self, df: pd.DataFrame, threshold: int = 50) -> Tuple[pd.DataFrame, pd.Series]:
        """
        ENFOQUE 2: Dataset para CLASIFICACIÓN
        Target: ¿Es horario pico o no?
        Similar a tu enfoque médico: 0/1 pero para horarios
        """
        X, y_regression = self.create_regression_dataset(df)
        
        # Crear target binario: horario pico (1) o normal (0)
        y_classification = (y_regression >= threshold).astype(int)
        
        # Estadísticas del balance
        peak_hours = (y_classification == 1).sum()
        normal_hours = (y_classification == 0).sum()
        balance_ratio = min(peak_hours, normal_hours) / max(peak_hours, normal_hours)
        
        print(f"✅ Dataset de clasificación creado:")
        print(f"   - Threshold: {threshold} accesos")
        print(f"   - Horarios normales: {normal_hours} ({normal_hours/len(y_classification)*100:.1f}%)")
        print(f"   - Horarios pico: {peak_hours} ({peak_hours/len(y_classification)*100:.1f}%)")
        print(f"   - Balance ratio: {balance_ratio:.2f}")
        
        if balance_ratio < 0.3:
            print("   ⚠️  Dataset desbalanceado - considerar técnicas de balanceo")
        
        return X, y_classification
    
    def create_multiclass_dataset(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.Series]:
        """
        ENFOQUE 3: Dataset MULTI-CLASE
        Target: Nivel de congestión (0=vacío, 1=bajo, 2=medio, 3=alto)
        """
        X, y_regression = self.create_regression_dataset(df)
        
        # Definir niveles de congestión basados en cuartiles
        q25, q50, q75 = y_regression.quantile([0.25, 0.5, 0.75])
        
        y_multiclass = pd.cut(
            y_regression,
            bins=[0, q25, q50, q75, y_regression.max() + 1],
            labels=[0, 1, 2, 3],  # vacío, bajo, medio, alto
            include_lowest=True
        ).astype(int)
        
        print(f"✅ Dataset multiclase creado:")
        print(f"   - Nivel 0 (vacío): 0-{q25:.0f} accesos ({(y_multiclass==0).sum()} samples)")
        print(f"   - Nivel 1 (bajo): {q25:.0f}-{q50:.0f} accesos ({(y_multiclass==1).sum()} samples)")
        print(f"   - Nivel 2 (medio): {q50:.0f}-{q75:.0f} accesos ({(y_multiclass==2).sum()} samples)")
        print(f"   - Nivel 3 (alto): {q75:.0f}+ accesos ({(y_multiclass==3).sum()} samples)")
        
        return X, y_multiclass
    
    def get_dataset_summary(self, df: pd.DataFrame) -> Dict:
        """
        Resumen del dataset similar a tu análisis exploratorio
        """
        summary = {
            'total_records': len(df),
            'date_range': {
                'start': df['fecha_hora'].min().strftime('%Y-%m-%d'),
                'end': df['fecha_hora'].max().strftime('%Y-%m-%d'),
                'days': (df['fecha_hora'].max() - df['fecha_hora'].min()).days
            },
            'time_coverage': {
                'hours_covered': df['fecha_hora'].dt.hour.nunique(),
                'min_hour': df['fecha_hora'].dt.hour.min(),
                'max_hour': df['fecha_hora'].dt.hour.max()
            },
            'access_types': df['tipo'].value_counts().to_dict(),
            'faculties': df['siglas_facultad'].nunique(),
            'schools': df['siglas_escuela'].nunique(),
            'unique_students': df['codigo_universitario'].nunique()
        }
        
        return summary

# Ejemplo de uso
if __name__ == "__main__":
    # Configuración (similar a tu proyecto médico)
    MONGO_URI = "mongodb+srv://Angel:angel12345@cluster0.pas0twe.mongodb.net"
    
    # Crear el preparador de datos
    creator = AceesDatasetCreator(MONGO_URI)
    
    # Recopilar datos históricos
    df = creator.collect_historical_data(months=3)
    
    # Crear diferentes tipos de datasets
    X_reg, y_reg = creator.create_regression_dataset(df)
    X_clf, y_clf = creator.create_classification_dataset(df, threshold=50)
    X_multi, y_multi = creator.create_multiclass_dataset(df)
    
    # Resumen
    summary = creator.get_dataset_summary(df)
    print("\n" + "="*60)
    print("RESUMEN DEL DATASET")
    print("="*60)
    for key, value in summary.items():
        print(f"{key}: {value}")