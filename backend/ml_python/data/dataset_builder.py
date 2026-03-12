"""
Constructor de Datasets ML - Sistema ACEES Group
Construcción automática de datasets optimizados para ML (US030)
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple, Union
import logging
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, MinMaxScaler, LabelEncoder
from sklearn.impute import SimpleImputer, KNNImputer
import pickle
from pathlib import Path

from backend.ml_python.core.base_ml_service import BaseMLService
from backend.ml_python.data.data_etl_service import get_etl_service
from backend.ml_python.data.data_quality_validator import get_quality_validator
from backend.ml_python.config.ml_config import get_ml_config
from backend.ml_python.utils.mongodb_connector import get_mongodb_connector

class MLDatasetBuilder(BaseMLService):
    """
    Constructor de datasets optimizados para ML
    Implementa US030: Preparación automática de datasets
    """
    
    def __init__(self):
        super().__init__()
        self.service_name = "MLDatasetBuilder"
        self.ml_config = get_ml_config()
        self.mongodb = get_mongodb_connector()
        
        # Configuraciones
        self.test_size = 0.2
        self.validation_size = 0.2
        self.random_state = 42
        
        # Cachés para re-uso
        self.scalers_cache = {}
        self.encoders_cache = {}
        self.imputers_cache = {}
        
        self.logger.info(f"Inicializado {self.service_name}")
    
    async def build_dataset(self, 
                          model_type: str,
                          dataset_config: Dict[str, Any],
                          target_column: Optional[str] = None,
                          feature_columns: Optional[List[str]] = None) -> Dict[str, Any]:
        """
        Construir dataset completo para ML
        
        Args:
            model_type: Tipo de modelo (regression, classification, clustering, time_series)
            dataset_config: Configuración del dataset
            target_column: Columna objetivo (para supervised learning)
            feature_columns: Columnas de features específicas
            
        Returns:
            Dataset construido con splits y metadatos
        """
        try:
            self.logger.info(f"Construyendo dataset para modelo {model_type}")
            
            # Etapa 1: Obtener datos raw
            etl_service = await get_etl_service()
            raw_data = await etl_service.extract_training_data(
                model_type=model_type,
                start_date=dataset_config.get('start_date'),
                end_date=dataset_config.get('end_date'),
                filters=dataset_config.get('filters')
            )
            
            # Etapa 2: Validar calidad
            quality_validator = await get_quality_validator()
            quality_report = await quality_validator.validate_dataset(raw_data, model_type=model_type)
            
            if not quality_report['is_ml_ready']:
                self.logger.warning("Dataset no cumple estándares de calidad para ML")
                if dataset_config.get('enforce_quality', True):
                    raise ValueError(f"Calidad insuficiente: {quality_report['overall_score']:.3f}")
            
            # Etapa 3: Preprocesamiento
            processed_data = await self._preprocess_data(
                raw_data, 
                model_type, 
                dataset_config.get('preprocessing', {})
            )
            
            # Etapa 4: Feature engineering
            engineered_data = await self._apply_feature_engineering(
                processed_data,
                model_type,
                dataset_config.get('feature_engineering', {})
            )
            
            # Etapa 5: Selección de features
            if feature_columns:
                available_features = [col for col in feature_columns if col in engineered_data.columns]
                if not available_features:
                    raise ValueError("Ninguna feature especificada está disponible")
                feature_data = engineered_data[available_features]
            else:
                feature_data = await self._select_optimal_features(
                    engineered_data,
                    model_type,
                    target_column,
                    dataset_config.get('feature_selection', {})
                )
            
            # Etapa 6: Crear splits
            dataset_splits = await self._create_dataset_splits(
                feature_data,
                target_column,
                model_type,
                dataset_config.get('split_config', {})
            )
            
            # Etapa 7: Metadatos del dataset
            dataset_metadata = await self._generate_dataset_metadata(
                raw_data,
                feature_data,
                quality_report,
                model_type,
                dataset_config
            )
            
            # Etapa 8: Guardar dataset construido
            dataset_id = await self._save_built_dataset(
                dataset_splits,
                dataset_metadata,
                dataset_config.get('save_location', 'mongodb')
            )
            
            # Resultado final
            result = {
                'success': True,
                'dataset_id': dataset_id,
                'model_type': model_type,
                'splits': {
                    'train_shape': dataset_splits['train']['X'].shape,
                    'test_shape': dataset_splits['test']['X'].shape,
                    'validation_shape': dataset_splits.get('validation', {}).get('X', pd.DataFrame()).shape
                },
                'features': {
                    'total_features': len(feature_data.columns),
                    'feature_names': list(feature_data.columns),
                    'target_column': target_column,
                    'feature_types': {col: str(dtype) for col, dtype in feature_data.dtypes.items()}
                },
                'quality_metrics': {
                    'overall_score': quality_report['overall_score'],
                    'is_ml_ready': quality_report['is_ml_ready'],
                    'critical_issues': quality_report['issues']['critical']
                },
                'preprocessing_applied': dataset_metadata['preprocessing_steps'],
                'created_at': datetime.now().isoformat()
            }
            
            self.logger.info(f"Dataset construido exitosamente - ID: {dataset_id}")
            return result
            
        except Exception as e:
            self.logger.error(f"Error construyendo dataset: {str(e)}")
            raise
    
    async def _preprocess_data(self, df: pd.DataFrame, model_type: str, preprocessing_config: Dict[str, Any]) -> pd.DataFrame:
        """Aplicar preprocesamiento básico"""
        try:
            processed_df = df.copy()
            applied_steps = []
            
            # 1. Manejo de valores nulos
            null_strategy = preprocessing_config.get('null_handling', 'auto')
            if null_strategy == 'auto':
                # Estrategia automática basada en porcentaje de nulos
                for col in processed_df.columns:
                    null_percentage = processed_df[col].isnull().sum() / len(processed_df)
                    
                    if null_percentage > 0.5:
                        # Remover columnas con más del 50% de nulos
                        processed_df = processed_df.drop(col, axis=1)
                        applied_steps.append(f"Removida columna {col} (>{50}% nulos)")
                    elif null_percentage > 0:
                        # Imputar valores
                        if processed_df[col].dtype in ['int64', 'float64']:
                            processed_df[col].fillna(processed_df[col].median(), inplace=True)
                            applied_steps.append(f"Imputada columna {col} con mediana")
                        else:
                            processed_df[col].fillna(processed_df[col].mode().iloc[0] if len(processed_df[col].mode()) > 0 else 'unknown', inplace=True)
                            applied_steps.append(f"Imputada columna {col} con moda")
            
            elif null_strategy == 'drop':
                # Remover registros con cualquier nulo
                initial_rows = len(processed_df)
                processed_df = processed_df.dropna()
                applied_steps.append(f"Removidos {initial_rows - len(processed_df)} registros con nulos")
            
            elif null_strategy == 'impute':
                # Imputación avanzada
                numeric_columns = processed_df.select_dtypes(include=[np.number]).columns
                categorical_columns = processed_df.select_dtypes(include=['object']).columns
                
                if len(numeric_columns) > 0:
                    imputer_method = preprocessing_config.get('numeric_imputation', 'median')
                    if imputer_method == 'knn':
                        imputer = KNNImputer(n_neighbors=5)
                        processed_df[numeric_columns] = imputer.fit_transform(processed_df[numeric_columns])
                        self.imputers_cache[f'knn_numeric'] = imputer
                    else:
                        imputer = SimpleImputer(strategy=imputer_method)
                        processed_df[numeric_columns] = imputer.fit_transform(processed_df[numeric_columns])
                        self.imputers_cache[f'simple_numeric'] = imputer
                    
                    applied_steps.append(f"Imputación numérica: {imputer_method}")
                
                if len(categorical_columns) > 0:
                    cat_imputer = SimpleImputer(strategy='most_frequent')
                    processed_df[categorical_columns] = cat_imputer.fit_transform(processed_df[categorical_columns])
                    self.imputers_cache['simple_categorical'] = cat_imputer
                    applied_steps.append("Imputación categórica: moda")
            
            # 2. Detección y manejo de outliers
            if preprocessing_config.get('handle_outliers', True):
                numeric_columns = processed_df.select_dtypes(include=[np.number]).columns
                outlier_method = preprocessing_config.get('outlier_method', 'iqr')
                
                for col in numeric_columns:
                    if outlier_method == 'iqr':
                        Q1 = processed_df[col].quantile(0.25)
                        Q3 = processed_df[col].quantile(0.75)
                        IQR = Q3 - Q1
                        lower_bound = Q1 - 1.5 * IQR
                        upper_bound = Q3 + 1.5 * IQR
                        
                        outliers_count = ((processed_df[col] < lower_bound) | (processed_df[col] > upper_bound)).sum()
                        if outliers_count > 0:
                            processed_df[col] = processed_df[col].clip(lower_bound, upper_bound)
                            applied_steps.append(f"Limitados outliers en {col}: {outliers_count} valores")
                    
                    elif outlier_method == 'zscore':
                        z_threshold = preprocessing_config.get('z_threshold', 3)
                        z_scores = np.abs((processed_df[col] - processed_df[col].mean()) / processed_df[col].std())
                        outliers_mask = z_scores > z_threshold
                        outliers_count = outliers_mask.sum()
                        
                        if outliers_count > 0:
                            processed_df = processed_df[~outliers_mask]
                            applied_steps.append(f"Removidos outliers en {col}: {outliers_count} registros")
            
            # 3. Normalización/Estandarización
            scaling_method = preprocessing_config.get('scaling', 'none')
            if scaling_method != 'none':
                numeric_columns = processed_df.select_dtypes(include=[np.number]).columns
                
                if scaling_method == 'standard':
                    scaler = StandardScaler()
                    processed_df[numeric_columns] = scaler.fit_transform(processed_df[numeric_columns])
                    self.scalers_cache['standard'] = scaler
                    applied_steps.append("Estandarización aplicada")
                
                elif scaling_method == 'minmax':
                    scaler = MinMaxScaler()
                    processed_df[numeric_columns] = scaler.fit_transform(processed_df[numeric_columns])
                    self.scalers_cache['minmax'] = scaler
                    applied_steps.append("Normalización MinMax aplicada")
            
            # 4. Codificación de variables categóricas
            if preprocessing_config.get('encode_categorical', True):
                categorical_columns = processed_df.select_dtypes(include=['object']).columns
                encoding_method = preprocessing_config.get('categorical_encoding', 'auto')
                
                for col in categorical_columns:
                    unique_values = processed_df[col].nunique()
                    
                    if encoding_method == 'auto':
                        if unique_values <= 10:  # One-hot para pocas categorías
                            dummies = pd.get_dummies(processed_df[col], prefix=col)
                            processed_df = pd.concat([processed_df.drop(col, axis=1), dummies], axis=1)
                            applied_steps.append(f"One-hot encoding: {col}")
                        else:  # Label encoding para muchas categorías
                            encoder = LabelEncoder()
                            processed_df[col] = encoder.fit_transform(processed_df[col])
                            self.encoders_cache[col] = encoder
                            applied_steps.append(f"Label encoding: {col}")
                    
                    elif encoding_method == 'onehot':
                        dummies = pd.get_dummies(processed_df[col], prefix=col)
                        processed_df = pd.concat([processed_df.drop(col, axis=1), dummies], axis=1)
                        applied_steps.append(f"One-hot encoding: {col}")
                    
                    elif encoding_method == 'label':
                        encoder = LabelEncoder()
                        processed_df[col] = encoder.fit_transform(processed_df[col])
                        self.encoders_cache[col] = encoder
                        applied_steps.append(f"Label encoding: {col}")
            
            # Guardar pasos aplicados en metadatos
            processed_df.attrs['preprocessing_steps'] = applied_steps
            
            self.logger.info(f"Preprocesamiento completado: {len(applied_steps)} pasos aplicados")
            return processed_df
            
        except Exception as e:
            self.logger.error(f"Error en preprocesamiento: {str(e)}")
            raise
    
    async def _apply_feature_engineering(self, df: pd.DataFrame, model_type: str, feature_config: Dict[str, Any]) -> pd.DataFrame:
        """Aplicar ingeniería de features"""
        try:
            engineered_df = df.copy()
            
            # Features temporales automáticas
            if feature_config.get('temporal_features', True) and 'hourlyDateTime' in df.columns:
                engineered_df = await self._add_temporal_features(engineered_df)
            
            # Features de interacción
            if feature_config.get('interaction_features', False):
                engineered_df = await self._add_interaction_features(engineered_df, feature_config)
            
            # Features de agregación
            if feature_config.get('aggregation_features', False):
                engineered_df = await self._add_aggregation_features(engineered_df, feature_config)
            
            # Features específicas por modelo
            if model_type == "regression" or model_type == "peak_hours":
                engineered_df = await self._add_regression_specific_features(engineered_df)
            elif model_type == "clustering":
                engineered_df = await self._add_clustering_specific_features(engineered_df)
            elif model_type == "time_series":
                engineered_df = await self._add_time_series_specific_features(engineered_df)
            
            self.logger.info(f"Feature engineering completado: {len(engineered_df.columns)} features totales")
            return engineered_df
            
        except Exception as e:
            self.logger.error(f"Error en feature engineering: {str(e)}")
            raise
    
    async def _add_temporal_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Añadir features temporales"""
        try:
            result_df = df.copy()
            
            if 'hourlyDateTime' in df.columns:
                # Convertir a datetime si no lo es
                result_df['hourlyDateTime'] = pd.to_datetime(result_df['hourlyDateTime'])
                
                # Features básicas
                result_df['hour'] = result_df['hourlyDateTime'].dt.hour
                result_df['day_of_week'] = result_df['hourlyDateTime'].dt.dayofweek
                result_df['day_of_month'] = result_df['hourlyDateTime'].dt.day
                result_df['month'] = result_df['hourlyDateTime'].dt.month
                result_df['quarter'] = result_df['hourlyDateTime'].dt.quarter
                result_df['is_weekend'] = result_df['day_of_week'].isin([5, 6]).astype(int)
                
                # Features cíclicas
                result_df['hour_sin'] = np.sin(2 * np.pi * result_df['hour'] / 24)
                result_df['hour_cos'] = np.cos(2 * np.pi * result_df['hour'] / 24)
                result_df['day_sin'] = np.sin(2 * np.pi * result_df['day_of_week'] / 7)
                result_df['day_cos'] = np.cos(2 * np.pi * result_df['day_of_week'] / 7)
                result_df['month_sin'] = np.sin(2 * np.pi * result_df['month'] / 12)
                result_df['month_cos'] = np.cos(2 * np.pi * result_df['month'] / 12)
                
                # Features de patrones
                result_df['is_business_hour'] = ((result_df['hour'] >= 9) & (result_df['hour'] <= 17) & 
                                               (result_df['day_of_week'] < 5)).astype(int)
                result_df['is_peak_morning'] = ((result_df['hour'] >= 7) & (result_df['hour'] <= 9)).astype(int)
                result_df['is_peak_evening'] = ((result_df['hour'] >= 17) & (result_df['hour'] <= 19)).astype(int)
                result_df['is_peak_hour'] = (result_df['is_peak_morning'] | result_df['is_peak_evening']).astype(int)
            
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error añadiendo features temporales: {str(e)}")
            raise
    
    async def _add_interaction_features(self, df: pd.DataFrame, config: Dict[str, Any]) -> pd.DataFrame:
        """Añadir features de interacción"""
        try:
            result_df = df.copy()
            
            # Interacciones configuradas
            interactions = config.get('interactions', [])
            for interaction in interactions:
                col1, col2 = interaction.get('columns', [])
                operation = interaction.get('operation', 'multiply')
                
                if col1 in df.columns and col2 in df.columns:
                    if operation == 'multiply':
                        result_df[f'{col1}_x_{col2}'] = df[col1] * df[col2]
                    elif operation == 'divide':
                        result_df[f'{col1}_div_{col2}'] = df[col1] / (df[col2] + 1e-8)
                    elif operation == 'add':
                        result_df[f'{col1}_plus_{col2}'] = df[col1] + df[col2]
                    elif operation == 'subtract':
                        result_df[f'{col1}_minus_{col2}'] = df[col1] - df[col2]
            
            # Interacciones automáticas para features numéricas importantes
            if config.get('auto_interactions', False):
                numeric_cols = df.select_dtypes(include=[np.number]).columns[:5]  # Top 5 para evitar explosión
                for i, col1 in enumerate(numeric_cols):
                    for col2 in numeric_cols[i+1:]:
                        if col1 != col2:
                            result_df[f'{col1}_x_{col2}'] = df[col1] * df[col2]
            
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error añadiendo features de interacción: {str(e)}")
            raise
    
    async def _add_aggregation_features(self, df: pd.DataFrame, config: Dict[str, Any]) -> pd.DataFrame:
        """Añadir features de agregación"""
        try:
            result_df = df.copy()
            
            # Agregaciones configuradas
            aggregations = config.get('aggregations', [])
            for agg in aggregations:
                group_col = agg.get('group_by')
                target_col = agg.get('target_column')
                operation = agg.get('operation', 'mean')
                
                if group_col in df.columns and target_col in df.columns:
                    grouped = df.groupby(group_col)[target_col].transform(operation)
                    result_df[f'{target_col}_{operation}_by_{group_col}'] = grouped
            
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error añadiendo features de agregación: {str(e)}")
            raise
    
    async def _add_regression_specific_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Features específicas para regresión"""
        try:
            result_df = df.copy()
            
            # Features de tendencia
            if 'count' in df.columns:
                # Rolling averages
                if len(df) > 24:
                    result_df['count_ma_24h'] = df['count'].rolling(window=24, min_periods=1).mean()
                    result_df['count_std_24h'] = df['count'].rolling(window=24, min_periods=1).std()
                
                # Lag features
                for lag in [1, 2, 24, 168]:  # 1h, 2h, 1d, 1w
                    if len(df) > lag:
                        result_df[f'count_lag_{lag}'] = df['count'].shift(lag)
                
                # Features de cambio
                result_df['count_change'] = df['count'].diff()
                result_df['count_pct_change'] = df['count'].pct_change().fillna(0)
            
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error añadiendo features de regresión: {str(e)}")
            raise
    
    async def _add_clustering_specific_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Features específicas para clustering"""
        try:
            result_df = df.copy()
            
            # Features de densidad y distribución
            numeric_cols = df.select_dtypes(include=[np.number]).columns
            
            for col in numeric_cols:
                if len(df) > 1:
                    # Percentiles
                    result_df[f'{col}_percentile'] = df[col].rank(pct=True)
                    
                    # Z-score
                    mean_val = df[col].mean()
                    std_val = df[col].std()
                    if std_val > 0:
                        result_df[f'{col}_zscore'] = (df[col] - mean_val) / std_val
            
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error añadiendo features de clustering: {str(e)}")
            raise
    
    async def _add_time_series_specific_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Features específicas para series temporales"""
        try:
            result_df = df.copy()
            
            if 'count' in df.columns and len(df) > 1:
                # Lag features extendidos
                for lag in [1, 2, 3, 6, 12, 24, 48, 168]:
                    if len(df) > lag:
                        result_df[f'lag_{lag}'] = df['count'].shift(lag)
                
                # Rolling statistics
                for window in [6, 12, 24, 168]:
                    if len(df) > window:
                        result_df[f'rolling_mean_{window}'] = df['count'].rolling(window=window).mean()
                        result_df[f'rolling_std_{window}'] = df['count'].rolling(window=window).std()
                        result_df[f'rolling_min_{window}'] = df['count'].rolling(window=window).min()
                        result_df[f'rolling_max_{window}'] = df['count'].rolling(window=window).max()
                
                # Features de estacionalidad
                if 'hour' in result_df.columns:
                    result_df['seasonal_hour'] = np.sin(2 * np.pi * result_df['hour'] / 24)
                
                if 'day_of_week' in result_df.columns:
                    result_df['seasonal_day'] = np.sin(2 * np.pi * result_df['day_of_week'] / 7)
            
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error añadiendo features de series temporales: {str(e)}")
            raise
    
    async def _select_optimal_features(self, df: pd.DataFrame, model_type: str, target_column: Optional[str], selection_config: Dict[str, Any]) -> pd.DataFrame:
        """Seleccionar features óptimas para el modelo"""
        try:
            # Por defecto, usar todas las features disponibles
            if not selection_config.get('enabled', False):
                return df
            
            selected_features = []
            
            # Features temporales importantes
            temporal_features = [col for col in df.columns if any(keyword in col.lower() for keyword in 
                               ['hour', 'day', 'week', 'month', 'weekend', 'peak', 'business'])]
            selected_features.extend(temporal_features)
            
            # Features numéricas base
            base_numeric = [col for col in df.columns if col in ['count', 'area'] and col in df.columns]
            selected_features.extend(base_numeric)
            
            # Features específicas por modelo
            if model_type in ["regression", "peak_hours"]:
                # Features de tendencia y lag
                trend_features = [col for col in df.columns if any(keyword in col.lower() for keyword in 
                                ['lag', 'ma', 'rolling', 'change', 'trend'])]
                selected_features.extend(trend_features)
            
            elif model_type == "clustering":
                # Features de distribución
                dist_features = [col for col in df.columns if any(keyword in col.lower() for keyword in 
                               ['percentile', 'zscore', 'std', 'var'])]
                selected_features.extend(dist_features)
            
            # Remover duplicados y verificar existencia
            selected_features = list(set(selected_features))
            selected_features = [col for col in selected_features if col in df.columns]
            
            # Si target_column está especificado, no incluirlo en features
            if target_column and target_column in selected_features:
                selected_features.remove(target_column)
            
            # Si no hay features seleccionadas, usar todas menos target
            if not selected_features:
                selected_features = [col for col in df.columns if col != target_column]
            
            result_df = df[selected_features]
            
            self.logger.info(f"Seleccionadas {len(selected_features)} features para {model_type}")
            return result_df
            
        except Exception as e:
            self.logger.error(f"Error seleccionando features: {str(e)}")
            raise
    
    async def _create_dataset_splits(self, feature_data: pd.DataFrame, target_column: Optional[str], model_type: str, split_config: Dict[str, Any]) -> Dict[str, Dict[str, pd.DataFrame]]:
        """Crear splits de entrenamiento, validación y test"""
        try:
            # Configuración de splits
            test_size = split_config.get('test_size', self.test_size)
            validation_size = split_config.get('validation_size', self.validation_size)
            random_state = split_config.get('random_state', self.random_state)
            
            # Para modelos no supervisados
            if model_type == "clustering" or target_column is None:
                # Split simple por índices
                if split_config.get('temporal_split', False) and 'hourlyDateTime' in feature_data.columns:
                    # Split temporal para series de tiempo
                    sorted_data = feature_data.sort_values('hourlyDateTime')
                    n_total = len(sorted_data)
                    
                    n_train = int(n_total * (1 - test_size - validation_size))
                    n_val = int(n_total * validation_size)
                    
                    train_data = sorted_data.iloc[:n_train]
                    val_data = sorted_data.iloc[n_train:n_train + n_val]
                    test_data = sorted_data.iloc[n_train + n_val:]
                    
                    splits = {
                        'train': {'X': train_data},
                        'validation': {'X': val_data},
                        'test': {'X': test_data}
                    }
                else:
                    # Split aleatorio
                    X_temp, X_test = train_test_split(feature_data, test_size=test_size, random_state=random_state)
                    
                    if validation_size > 0:
                        val_size_adjusted = validation_size / (1 - test_size)
                        X_train, X_val = train_test_split(X_temp, test_size=val_size_adjusted, random_state=random_state)
                        
                        splits = {
                            'train': {'X': X_train},
                            'validation': {'X': X_val},
                            'test': {'X': X_test}
                        }
                    else:
                        splits = {
                            'train': {'X': X_temp},
                            'test': {'X': X_test}
                        }
            
            else:
                # Modelos supervisados
                if target_column not in feature_data.columns:
                    raise ValueError(f"Columna objetivo '{target_column}' no encontrada")
                
                X = feature_data.drop(target_column, axis=1)
                y = feature_data[target_column]
                
                if split_config.get('temporal_split', False) and 'hourlyDateTime' in X.columns:
                    # Split temporal conservando orden
                    # Ordenar por fecha
                    combined_data = pd.concat([X, y], axis=1).sort_values('hourlyDateTime')
                    X_sorted = combined_data.drop(target_column, axis=1)
                    y_sorted = combined_data[target_column]
                    
                    n_total = len(X_sorted)
                    n_train = int(n_total * (1 - test_size - validation_size))
                    n_val = int(n_total * validation_size)
                    
                    X_train = X_sorted.iloc[:n_train]
                    y_train = y_sorted.iloc[:n_train]
                    X_val = X_sorted.iloc[n_train:n_train + n_val]
                    y_val = y_sorted.iloc[n_train:n_train + n_val]
                    X_test = X_sorted.iloc[n_train + n_val:]
                    y_test = y_sorted.iloc[n_train + n_val:]
                    
                    splits = {
                        'train': {'X': X_train, 'y': y_train},
                        'validation': {'X': X_val, 'y': y_val},
                        'test': {'X': X_test, 'y': y_test}
                    }
                else:
                    # Split aleatorio estratificado para clasificación
                    stratify = y if model_type == "classification" and y.nunique() < 50 else None
                    
                    X_temp, X_test, y_temp, y_test = train_test_split(
                        X, y, test_size=test_size, random_state=random_state, stratify=stratify
                    )
                    
                    if validation_size > 0:
                        val_size_adjusted = validation_size / (1 - test_size)
                        stratify_val = y_temp if model_type == "classification" and y_temp.nunique() < 50 else None
                        
                        X_train, X_val, y_train, y_val = train_test_split(
                            X_temp, y_temp, test_size=val_size_adjusted, 
                            random_state=random_state, stratify=stratify_val
                        )
                        
                        splits = {
                            'train': {'X': X_train, 'y': y_train},
                            'validation': {'X': X_val, 'y': y_val},
                            'test': {'X': X_test, 'y': y_test}
                        }
                    else:
                        splits = {
                            'train': {'X': X_temp, 'y': y_temp},
                            'test': {'X': X_test, 'y': y_test}
                        }
            
            # Logging de información de splits
            for split_name, split_data in splits.items():
                self.logger.info(f"Split {split_name}: {split_data['X'].shape}")
            
            return splits
            
        except Exception as e:
            self.logger.error(f"Error creando splits: {str(e)}")
            raise
    
    async def _generate_dataset_metadata(self, raw_data: pd.DataFrame, feature_data: pd.DataFrame, quality_report: Dict[str, Any], model_type: str, dataset_config: Dict[str, Any]) -> Dict[str, Any]:
        """Generar metadatos completos del dataset"""
        try:
            metadata = {
                'creation_timestamp': datetime.now().isoformat(),
                'model_type': model_type,
                'raw_data_shape': raw_data.shape,
                'processed_data_shape': feature_data.shape,
                'quality_score': quality_report['overall_score'],
                'feature_count': len(feature_data.columns),
                'feature_names': list(feature_data.columns),
                'feature_types': {col: str(dtype) for col, dtype in feature_data.dtypes.items()},
                'preprocessing_steps': getattr(feature_data, 'attrs', {}).get('preprocessing_steps', []),
                'dataset_config': dataset_config,
                'quality_report_summary': {
                    'overall_status': quality_report['overall_status'],
                    'critical_issues': quality_report['issues']['critical'],
                    'warnings': quality_report['issues']['warnings'],
                    'is_ml_ready': quality_report['is_ml_ready']
                },
                'statistics': {
                    'memory_usage_mb': feature_data.memory_usage(deep=True).sum() / (1024**2),
                    'null_values': feature_data.isnull().sum().to_dict(),
                    'numeric_features': len(feature_data.select_dtypes(include=[np.number]).columns),
                    'categorical_features': len(feature_data.select_dtypes(include=['object']).columns)
                }
            }
            
            # Estadísticas descriptivas para features numéricas
            numeric_stats = feature_data.describe().to_dict()
            metadata['descriptive_statistics'] = numeric_stats
            
            return metadata
            
        except Exception as e:
            self.logger.error(f"Error generando metadatos: {str(e)}")
            raise
    
    async def _save_built_dataset(self, dataset_splits: Dict[str, Dict[str, pd.DataFrame]], metadata: Dict[str, Any], save_location: str) -> str:
        """Guardar dataset construido"""
        try:
            if save_location == 'mongodb':
                # Guardar en MongoDB
                dataset_doc = {
                    'metadata': metadata,
                    'splits': {}
                }
                
                # Convertir splits a formato serializable
                for split_name, split_data in dataset_splits.items():
                    dataset_doc['splits'][split_name] = {}
                    for data_name, data_df in split_data.items():
                        dataset_doc['splits'][split_name][data_name] = {
                            'data': data_df.to_dict('records'),
                            'columns': list(data_df.columns),
                            'shape': data_df.shape
                        }
                
                result = await self.mongodb.save_processed_dataset(dataset_doc)
                return str(result.inserted_id)
            
            else:
                # Guardar en sistema de archivos
                save_path = Path(save_location) / f"dataset_{int(datetime.now().timestamp())}"
                save_path.mkdir(parents=True, exist_ok=True)
                
                # Guardar splits
                for split_name, split_data in dataset_splits.items():
                    split_path = save_path / split_name
                    split_path.mkdir(exist_ok=True)
                    
                    for data_name, data_df in split_data.items():
                        data_df.to_parquet(split_path / f"{data_name}.parquet")
                
                # Guardar metadatos
                import json
                with open(save_path / "metadata.json", 'w') as f:
                    json.dump(metadata, f, indent=2, default=str)
                
                # Guardar scalers y encoders si existen
                if self.scalers_cache:
                    with open(save_path / "scalers.pkl", 'wb') as f:
                        pickle.dump(self.scalers_cache, f)
                
                if self.encoders_cache:
                    with open(save_path / "encoders.pkl", 'wb') as f:
                        pickle.dump(self.encoders_cache, f)
                
                return str(save_path)
                
        except Exception as e:
            self.logger.error(f"Error guardando dataset: {str(e)}")
            raise


# Instancia global
dataset_builder = MLDatasetBuilder()

async def get_dataset_builder() -> MLDatasetBuilder:
    """Obtener instancia del constructor de datasets"""
    return dataset_builder