"""
Servicio ETL de Datos ML - Sistema ACEES Group
Extracción, transformación y carga de datos para ML (US030)
"""
import asyncio
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import logging
from pathlib import Path

from backend.ml_python.core.base_ml_service import BaseMLService
from backend.ml_python.utils.mongodb_connector import get_mongodb_connector
from backend.ml_python.config.database_config import get_database_config
from backend.ml_python.config.ml_config import get_ml_config

class MLDataETLService(BaseMLService):
    """
    Servicio ETL para procesamiento de datos ML
    Implementa US030: Preparación automática de datasets
    """
    
    def __init__(self):
        super().__init__()
        self.service_name = "MLDataETLService"
        self.mongodb = get_mongodb_connector()
        self.db_config = get_database_config()
        self.ml_config = get_ml_config()
        
        # Configuraciones específicas
        self.batch_size = 1000
        self.historical_days = self.ml_config.historical_analysis_days
        self.min_records_threshold = self.ml_config.min_training_samples
        
        self.logger.info(f"Inicializado {self.service_name}")
    
    async def extract_training_data(self, 
                                  model_type: str = "regression",
                                  start_date: Optional[datetime] = None,
                                  end_date: Optional[datetime] = None,
                                  filters: Optional[Dict[str, Any]] = None) -> pd.DataFrame:
        """
        Extraer datos para entrenamiento (US030)
        
        Args:
            model_type: Tipo de modelo (regression, classification, clustering)
            start_date: Fecha inicio
            end_date: Fecha fin
            filters: Filtros adicionales
            
        Returns:
            DataFrame con datos de entrenamiento
        """
        try:
            self.logger.info(f"Extrayendo datos para modelo {model_type}")
            
            # Configurar fechas por defecto
            if not end_date:
                end_date = datetime.now()
            if not start_date:
                start_date = end_date - timedelta(days=self.historical_days)
            
            # Obtener datos según el tipo de modelo
            if model_type in ["regression", "peak_hours"]:
                df = await self._extract_regression_data(start_date, end_date, filters)
            elif model_type == "clustering":
                df = await self._extract_clustering_data(start_date, end_date, filters)
            elif model_type == "time_series":
                df = await self._extract_time_series_data(start_date, end_date, filters)
            else:
                raise ValueError(f"Tipo de modelo no soportado: {model_type}")
            
            # Validar cantidad mínima de registros
            if len(df) < self.min_records_threshold:
                raise ValueError(f"Datos insuficientes: {len(df)} < {self.min_records_threshold}")
            
            self.logger.info(f"Extraídos {len(df)} registros para {model_type}")
            return df
            
        except Exception as e:
            self.logger.error(f"Error extrayendo datos: {str(e)}")
            raise
    
    async def transform_data(self, 
                           df: pd.DataFrame, 
                           transformation_config: Dict[str, Any]) -> pd.DataFrame:
        """
        Transformar datos según configuración
        
        Args:
            df: DataFrame original
            transformation_config: Configuración de transformaciones
            
        Returns:
            DataFrame transformado
        """
        try:
            transformed_df = df.copy()
            
            # Aplicar transformaciones en orden
            for transformation in transformation_config.get('transformations', []):
                transformed_df = await self._apply_transformation(transformed_df, transformation)
            
            # Validar resultado
            if len(transformed_df) == 0:
                raise ValueError("Transformación resultó en DataFrame vacío")
            
            self.logger.info(f"Datos transformados: {len(df)} -> {len(transformed_df)} registros")
            return transformed_df
            
        except Exception as e:
            self.logger.error(f"Error transformando datos: {str(e)}")
            raise
    
    async def load_processed_data(self, 
                                df: pd.DataFrame, 
                                dataset_name: str,
                                metadata: Optional[Dict[str, Any]] = None) -> str:
        """
        Cargar datos procesados a la base de datos
        
        Args:
            df: DataFrame procesado
            dataset_name: Nombre del dataset
            metadata: Metadatos adicionales
            
        Returns:
            ID del dataset guardado
        """
        try:
            # Preparar documento para MongoDB
            dataset_doc = {
                'dataset_name': dataset_name,
                'created_at': datetime.now(),
                'record_count': len(df),
                'column_count': len(df.columns),
                'columns': list(df.columns),
                'data_types': {col: str(dtype) for col, dtype in df.dtypes.items()},
                'quality_score': await self._calculate_data_quality_score(df),
                'metadata': metadata or {},
                'data': df.to_dict('records')  # Almacenar datos como lista de diccionarios
            }
            
            # Guardar en MongoDB
            result = await self.mongodb.save_processed_dataset(dataset_doc)
            dataset_id = str(result.inserted_id)
            
            self.logger.info(f"Dataset guardado con ID: {dataset_id}")
            return dataset_id
            
        except Exception as e:
            self.logger.error(f"Error guardando dataset: {str(e)}")
            raise
    
    async def run_full_etl_pipeline(self, 
                                  model_type: str,
                                  pipeline_config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Ejecutar pipeline ETL completo (US030)
        
        Args:
            model_type: Tipo de modelo
            pipeline_config: Configuración del pipeline
            
        Returns:
            Resultado del pipeline con métricas
        """
        try:
            start_time = datetime.now()
            self.logger.info(f"Iniciando pipeline ETL para {model_type}")
            
            # Etapa 1: Extracción
            extraction_start = datetime.now()
            raw_data = await self.extract_training_data(
                model_type=model_type,
                start_date=pipeline_config.get('start_date'),
                end_date=pipeline_config.get('end_date'),
                filters=pipeline_config.get('filters')
            )
            extraction_time = (datetime.now() - extraction_start).total_seconds()
            
            # Etapa 2: Transformación
            transformation_start = datetime.now()
            processed_data = await self.transform_data(
                raw_data, 
                pipeline_config.get('transformation_config', {})
            )
            transformation_time = (datetime.now() - transformation_start).total_seconds()
            
            # Etapa 3: Carga
            loading_start = datetime.now()
            dataset_id = await self.load_processed_data(
                processed_data,
                pipeline_config.get('dataset_name', f"{model_type}_dataset_{int(datetime.now().timestamp())}"),
                {
                    'model_type': model_type,
                    'pipeline_config': pipeline_config,
                    'processing_stats': {
                        'raw_records': len(raw_data),
                        'processed_records': len(processed_data),
                        'extraction_time': extraction_time,
                        'transformation_time': transformation_time
                    }
                }
            )
            loading_time = (datetime.now() - loading_start).total_seconds()
            
            total_time = (datetime.now() - start_time).total_seconds()
            
            # Resultado del pipeline
            result = {
                'success': True,
                'dataset_id': dataset_id,
                'model_type': model_type,
                'processing_stats': {
                    'raw_records': len(raw_data),
                    'processed_records': len(processed_data),
                    'data_quality_score': await self._calculate_data_quality_score(processed_data),
                    'processing_times': {
                        'extraction': extraction_time,
                        'transformation': transformation_time,
                        'loading': loading_time,
                        'total': total_time
                    }
                },
                'data_summary': {
                    'columns': list(processed_data.columns),
                    'shape': processed_data.shape,
                    'memory_usage': processed_data.memory_usage(deep=True).sum(),
                    'null_counts': processed_data.isnull().sum().to_dict()
                },
                'completed_at': datetime.now()
            }
            
            self.logger.info(f"Pipeline ETL completado en {total_time:.2f}s")
            return result
            
        except Exception as e:
            self.logger.error(f"Error en pipeline ETL: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'completed_at': datetime.now()
            }
    
    async def _extract_regression_data(self, start_date: datetime, end_date: datetime, filters: Optional[Dict]) -> pd.DataFrame:
        """Extraer datos para modelos de regresión"""
        try:
            # Obtener datos de asistencias agregados por hora
            aggregation_pipeline = [
                {
                    '$match': {
                        'hourlyDateTime': {
                            '$gte': start_date,
                            '$lte': end_date
                        }
                    }
                },
                {
                    '$group': {
                        '_id': {
                            'date': {'$dateToString': {'format': '%Y-%m-%d', 'date': '$hourlyDateTime'}},
                            'hour': {'$hour': '$hourlyDateTime'},
                            'area': '$area'
                        },
                        'count': {'$sum': '$count'},
                        'hourlyDateTime': {'$first': '$hourlyDateTime'}
                    }
                },
                {
                    '$sort': {'hourlyDateTime': 1}
                }
            ]
            
            # Aplicar filtros adicionales
            if filters:
                aggregation_pipeline[0]['$match'].update(filters)
            
            # Ejecutar agregación
            data = await self.mongodb.aggregate_data('AsistenciasAgregadas', aggregation_pipeline)
            
            if not data:
                raise ValueError("No se encontraron datos en el rango especificado")
            
            # Convertir a DataFrame
            df = pd.DataFrame(data)
            
            # Procesar campos
            df['date'] = df['_id'].apply(lambda x: x['date'])
            df['hour'] = df['_id'].apply(lambda x: x['hour'])
            df['area'] = df['_id'].apply(lambda x: x['area'])
            df = df.drop('_id', axis=1)
            
            # Convertir tipos
            df['hourlyDateTime'] = pd.to_datetime(df['hourlyDateTime'])
            df['count'] = df['count'].astype(int)
            df['hour'] = df['hour'].astype(int)
            
            # Añadir features temporales
            df['day_of_week'] = df['hourlyDateTime'].dt.dayofweek
            df['is_weekend'] = df['day_of_week'].isin([5, 6]).astype(int)
            df['month'] = df['hourlyDateTime'].dt.month
            df['is_peak_hour'] = df['hour'].isin([7, 8, 9, 17, 18, 19]).astype(int)
            
            return df
            
        except Exception as e:
            self.logger.error(f"Error extrayendo datos de regresión: {str(e)}")
            raise
    
    async def _extract_clustering_data(self, start_date: datetime, end_date: datetime, filters: Optional[Dict]) -> pd.DataFrame:
        """Extraer datos para clustering"""
        try:
            # Obtener patrones de uso por área y período
            aggregation_pipeline = [
                {
                    '$match': {
                        'hourlyDateTime': {
                            '$gte': start_date,
                            '$lte': end_date
                        }
                    }
                },
                {
                    '$group': {
                        '_id': {
                            'area': '$area',
                            'hour': {'$hour': '$hourlyDateTime'},
                            'day_of_week': {'$dayOfWeek': '$hourlyDateTime'}
                        },
                        'avg_count': {'$avg': '$count'},
                        'max_count': {'$max': '$count'},
                        'min_count': {'$min': '$count'},
                        'total_records': {'$sum': 1}
                    }
                }
            ]
            
            if filters:
                aggregation_pipeline[0]['$match'].update(filters)
            
            data = await self.mongodb.aggregate_data('AsistenciasAgregadas', aggregation_pipeline)
            
            if not data:
                raise ValueError("No se encontraron datos para clustering")
            
            df = pd.DataFrame(data)
            
            # Procesar campos
            df['area'] = df['_id'].apply(lambda x: x['area'])
            df['hour'] = df['_id'].apply(lambda x: x['hour'])
            df['day_of_week'] = df['_id'].apply(lambda x: x['day_of_week'])
            df = df.drop('_id', axis=1)
            
            # Añadir features calculadas
            df['usage_variability'] = (df['max_count'] - df['min_count']) / (df['avg_count'] + 1)
            df['usage_intensity'] = df['avg_count'] / df['total_records']
            
            return df
            
        except Exception as e:
            self.logger.error(f"Error extrayendo datos de clustering: {str(e)}")
            raise
    
    async def _extract_time_series_data(self, start_date: datetime, end_date: datetime, filters: Optional[Dict]) -> pd.DataFrame:
        """Extraer datos para series temporales"""
        try:
            # Obtener serie temporal ordenada
            aggregation_pipeline = [
                {
                    '$match': {
                        'hourlyDateTime': {
                            '$gte': start_date,
                            '$lte': end_date
                        }
                    }
                },
                {
                    '$group': {
                        '_id': '$hourlyDateTime',
                        'total_count': {'$sum': '$count'},
                        'unique_areas': {'$addToSet': '$area'},
                        'area_counts': {'$push': {'area': '$area', 'count': '$count'}}
                    }
                },
                {
                    '$sort': {'_id': 1}
                }
            ]
            
            if filters:
                aggregation_pipeline[0]['$match'].update(filters)
            
            data = await self.mongodb.aggregate_data('AsistenciasAgregadas', aggregation_pipeline)
            
            if not data:
                raise ValueError("No se encontraron datos para series temporales")
            
            df = pd.DataFrame(data)
            df['hourlyDateTime'] = df['_id']
            df = df.drop('_id', axis=1)
            
            # Convertir a datetime
            df['hourlyDateTime'] = pd.to_datetime(df['hourlyDateTime'])
            df = df.sort_values('hourlyDateTime')
            
            # Añadir features temporales
            df['hour'] = df['hourlyDateTime'].dt.hour
            df['day_of_week'] = df['hourlyDateTime'].dt.dayofweek
            df['day_of_year'] = df['hourlyDateTime'].dt.dayofyear
            
            # Features de lag (valores anteriores)
            df['lag_1'] = df['total_count'].shift(1)
            df['lag_24'] = df['total_count'].shift(24)  # Mismo momento día anterior
            df['lag_168'] = df['total_count'].shift(168)  # Mismo momento semana anterior
            
            # Rolling averages
            df['rolling_mean_24h'] = df['total_count'].rolling(window=24).mean()
            df['rolling_mean_7d'] = df['total_count'].rolling(window=168).mean()
            
            return df
            
        except Exception as e:
            self.logger.error(f"Error extrayendo datos de series temporales: {str(e)}")
            raise
    
    async def _apply_transformation(self, df: pd.DataFrame, transformation: Dict[str, Any]) -> pd.DataFrame:
        """Aplicar transformación específica"""
        try:
            transform_type = transformation.get('type')
            
            if transform_type == 'remove_nulls':
                return df.dropna(subset=transformation.get('columns', []))
            
            elif transform_type == 'fill_nulls':
                fill_value = transformation.get('fill_value', 0)
                columns = transformation.get('columns', df.columns)
                return df.fillna({col: fill_value for col in columns})
            
            elif transform_type == 'remove_outliers':
                return await self._remove_outliers(df, transformation)
            
            elif transform_type == 'normalize':
                return await self._normalize_columns(df, transformation)
            
            elif transform_type == 'encode_categorical':
                return await self._encode_categorical(df, transformation)
            
            elif transform_type == 'add_derived_features':
                return await self._add_derived_features(df, transformation)
            
            else:
                self.logger.warning(f"Transformación no reconocida: {transform_type}")
                return df
                
        except Exception as e:
            self.logger.error(f"Error aplicando transformación {transform_type}: {str(e)}")
            raise
    
    async def _remove_outliers(self, df: pd.DataFrame, config: Dict[str, Any]) -> pd.DataFrame:
        """Remover outliers usando IQR o Z-score"""
        try:
            method = config.get('method', 'iqr')
            columns = config.get('columns', df.select_dtypes(include=[np.number]).columns)
            
            result_df = df.copy()
            
            for col in columns:
                if col not in df.columns:
                    continue
                    
                if method == 'iqr':
                    Q1 = df[col].quantile(0.25)
                    Q3 = df[col].quantile(0.75)
                    IQR = Q3 - Q1
                    lower_bound = Q1 - 1.5 * IQR
                    upper_bound = Q3 + 1.5 * IQR
                    
                    result_df = result_df[(result_df[col] >= lower_bound) & (result_df[col] <= upper_bound)]
                
                elif method == 'zscore':
                    z_threshold = config.get('z_threshold', 3)
                    z_scores = np.abs((df[col] - df[col].mean()) / df[col].std())
                    result_df = result_df[z_scores <= z_threshold]
            
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error removiendo outliers: {str(e)}")
            raise
    
    async def _normalize_columns(self, df: pd.DataFrame, config: Dict[str, Any]) -> pd.DataFrame:
        """Normalizar columnas numéricas"""
        try:
            method = config.get('method', 'minmax')
            columns = config.get('columns', df.select_dtypes(include=[np.number]).columns)
            
            result_df = df.copy()
            
            for col in columns:
                if col not in df.columns:
                    continue
                
                if method == 'minmax':
                    min_val = df[col].min()
                    max_val = df[col].max()
                    if max_val > min_val:
                        result_df[col] = (df[col] - min_val) / (max_val - min_val)
                
                elif method == 'standard':
                    mean_val = df[col].mean()
                    std_val = df[col].std()
                    if std_val > 0:
                        result_df[col] = (df[col] - mean_val) / std_val
            
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error normalizando columnas: {str(e)}")
            raise
    
    async def _encode_categorical(self, df: pd.DataFrame, config: Dict[str, Any]) -> pd.DataFrame:
        """Codificar variables categóricas"""
        try:
            method = config.get('method', 'onehot')
            columns = config.get('columns', df.select_dtypes(include=['object']).columns)
            
            result_df = df.copy()
            
            for col in columns:
                if col not in df.columns:
                    continue
                
                if method == 'onehot':
                    dummies = pd.get_dummies(df[col], prefix=col)
                    result_df = pd.concat([result_df.drop(col, axis=1), dummies], axis=1)
                
                elif method == 'label':
                    unique_values = df[col].unique()
                    label_mapping = {val: i for i, val in enumerate(unique_values)}
                    result_df[col] = df[col].map(label_mapping)
            
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error codificando categóricas: {str(e)}")
            raise
    
    async def _add_derived_features(self, df: pd.DataFrame, config: Dict[str, Any]) -> pd.DataFrame:
        """Añadir features derivadas"""
        try:
            result_df = df.copy()
            feature_configs = config.get('features', [])
            
            for feature_config in feature_configs:
                feature_type = feature_config.get('type')
                
                if feature_type == 'datetime_features' and 'hourlyDateTime' in df.columns:
                    # Features temporales
                    result_df['year'] = df['hourlyDateTime'].dt.year
                    result_df['month'] = df['hourlyDateTime'].dt.month
                    result_df['day'] = df['hourlyDateTime'].dt.day
                    result_df['hour'] = df['hourlyDateTime'].dt.hour
                    result_df['day_of_week'] = df['hourlyDateTime'].dt.dayofweek
                    result_df['is_weekend'] = result_df['day_of_week'].isin([5, 6]).astype(int)
                    
                elif feature_type == 'interaction_features':
                    # Features de interacción
                    col1, col2 = feature_config.get('columns', [])
                    if col1 in df.columns and col2 in df.columns:
                        result_df[f'{col1}_{col2}_interaction'] = df[col1] * df[col2]
                
                elif feature_type == 'aggregation_features':
                    # Features de agregación por grupos
                    group_col = feature_config.get('group_col')
                    agg_col = feature_config.get('agg_col')
                    agg_type = feature_config.get('agg_type', 'mean')
                    
                    if group_col in df.columns and agg_col in df.columns:
                        grouped = df.groupby(group_col)[agg_col].transform(agg_type)
                        result_df[f'{group_col}_{agg_col}_{agg_type}'] = grouped
            
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error añadiendo features derivadas: {str(e)}")
            raise
    
    async def _calculate_data_quality_score(self, df: pd.DataFrame) -> float:
        """Calcular score de calidad de datos"""
        try:
            total_cells = df.shape[0] * df.shape[1]
            
            if total_cells == 0:
                return 0.0
            
            # Factores de calidad
            null_ratio = df.isnull().sum().sum() / total_cells
            duplicate_ratio = df.duplicated().sum() / len(df) if len(df) > 0 else 0
            
            # Score base (completitud)
            completeness_score = 1 - null_ratio
            
            # Penalización por duplicados
            uniqueness_score = 1 - duplicate_ratio
            
            # Score combinado
            quality_score = (completeness_score * 0.6 + uniqueness_score * 0.4)
            
            return max(0.0, min(1.0, quality_score))
            
        except Exception as e:
            self.logger.error(f"Error calculando score de calidad: {str(e)}")
            return 0.0


# Instancia global
etl_service = MLDataETLService()

async def get_etl_service() -> MLDataETLService:
    """Obtener instancia del servicio ETL"""
    return etl_service