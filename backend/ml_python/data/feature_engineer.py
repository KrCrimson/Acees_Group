"""
Ingeniero de Features ML - Sistema ACEES Group
Ingeniería de features automática y optimizada para ML
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple, Union, Callable
import logging
from sklearn.preprocessing import PolynomialFeatures
from sklearn.feature_selection import SelectKBest, chi2, f_classif, f_regression, mutual_info_classif, mutual_info_regression
from sklearn.decomposition import PCA
from sklearn.cluster import KMeans
import warnings

warnings.filterwarnings('ignore')

from backend.ml_python.core.base_ml_service import BaseMLService
from backend.ml_python.config.ml_config import get_ml_config

class MLFeatureEngineer(BaseMLService):
    """
    Ingeniería de features automática para ML
    Genera, selecciona y optimiza features para mejorar rendimiento de modelos
    """
    
    def __init__(self):
        super().__init__()
        self.service_name = "MLFeatureEngineer"
        self.ml_config = get_ml_config()
        
        # Configuraciones
        self.max_features = 100  # Máximo número de features para evitar explosión dimensional
        self.correlation_threshold = 0.99  # Umbral para remover features correlacionadas
        
        # Cachés para transformadores
        self.feature_selectors = {}
        self.pca_transformers = {}
        self.polynomial_transformers = {}
        
        self.logger.info(f"Inicializado {self.service_name}")
    
    async def engineer_features(self, 
                              df: pd.DataFrame,
                              target_column: Optional[str] = None,
                              model_type: str = "regression",
                              engineering_config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Realizar ingeniería completa de features
        
        Args:
            df: DataFrame con datos base
            target_column: Columna objetivo (para feature selection supervisada)
            model_type: Tipo de modelo para optimizaciones específicas
            engineering_config: Configuración personalizada
            
        Returns:
            Diccionario con DataFrame procesado y metadatos
        """
        try:
            self.logger.info(f"Iniciando ingeniería de features para {model_type}")
            
            config = engineering_config or {}
            original_shape = df.shape
            
            # Pipeline de ingeniería
            processed_df = df.copy()
            feature_history = []
            
            # 1. Features temporales avanzadas
            if config.get('temporal_features', True):
                processed_df, temp_features = await self._create_temporal_features(processed_df)
                feature_history.extend(temp_features)
            
            # 2. Features de interacción
            if config.get('interaction_features', False):
                processed_df, interaction_features = await self._create_interaction_features(
                    processed_df, config.get('interaction_config', {})
                )
                feature_history.extend(interaction_features)
            
            # 3. Features polinomiales
            if config.get('polynomial_features', False):
                processed_df, poly_features = await self._create_polynomial_features(
                    processed_df, config.get('polynomial_config', {})
                )
                feature_history.extend(poly_features)
            
            # 4. Features de agregación y rolling
            if config.get('aggregation_features', True):
                processed_df, agg_features = await self._create_aggregation_features(
                    processed_df, config.get('aggregation_config', {})
                )
                feature_history.extend(agg_features)
            
            # 5. Features específicas por modelo
            processed_df, model_features = await self._create_model_specific_features(
                processed_df, model_type, config
            )
            feature_history.extend(model_features)
            
            # 6. Features de clustering (para representación de patrones)
            if config.get('clustering_features', False):
                processed_df, cluster_features = await self._create_clustering_features(
                    processed_df, config.get('clustering_config', {})
                )
                feature_history.extend(cluster_features)
            
            # 7. Reducción de dimensionalidad si es necesario
            if len(processed_df.columns) > self.max_features:
                processed_df, reduction_info = await self._apply_dimensionality_reduction(
                    processed_df, target_column, model_type, config.get('reduction_config', {})
                )
                feature_history.append(f"Reducción dimensional: {reduction_info}")
            
            # 8. Selección de features
            if config.get('feature_selection', True) and target_column:
                processed_df, selection_info = await self._select_best_features(
                    processed_df, target_column, model_type, config.get('selection_config', {})
                )
                feature_history.append(f"Selección de features: {selection_info}")
            
            # 9. Limpieza de features correlacionadas
            if config.get('remove_correlated', True):
                processed_df, correlation_info = await self._remove_correlated_features(processed_df)
                feature_history.append(f"Limpieza correlaciones: {correlation_info}")
            
            # Generar metadatos
            engineering_metadata = {
                'original_shape': original_shape,
                'final_shape': processed_df.shape,
                'features_created': len(processed_df.columns) - len(df.columns),
                'feature_history': feature_history,
                'model_type': model_type,
                'target_column': target_column,
                'config_applied': config,
                'feature_names': list(processed_df.columns),
                'processing_timestamp': datetime.now().isoformat()
            }
            
            # Calcular importancia de features si es posible
            if target_column and target_column in processed_df.columns:
                feature_importance = await self._calculate_feature_importance(
                    processed_df.drop(target_column, axis=1),
                    processed_df[target_column],
                    model_type
                )
                engineering_metadata['feature_importance'] = feature_importance
            
            result = {
                'success': True,
                'data': processed_df,
                'metadata': engineering_metadata,
                'transformers': {
                    'feature_selectors': self.feature_selectors,
                    'pca_transformers': self.pca_transformers,
                    'polynomial_transformers': self.polynomial_transformers
                }
            }
            
            self.logger.info(f"Ingeniería completada: {original_shape} -> {processed_df.shape}")
            return result
            
        except Exception as e:
            self.logger.error(f"Error en ingeniería de features: {str(e)}")
            raise
    
    async def _create_temporal_features(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, List[str]]:
        """Crear features temporales avanzadas"""
        try:
            result_df = df.copy()
            created_features = []
            
            # Detectar columnas de fecha
            datetime_columns = []
            for col in df.columns:
                if 'date' in col.lower() or 'time' in col.lower():
                    try:
                        result_df[col] = pd.to_datetime(result_df[col])
                        datetime_columns.append(col)
                    except:
                        continue
            
            for date_col in datetime_columns:
                # Features básicas
                result_df[f'{date_col}_year'] = result_df[date_col].dt.year
                result_df[f'{date_col}_month'] = result_df[date_col].dt.month
                result_df[f'{date_col}_day'] = result_df[date_col].dt.day
                result_df[f'{date_col}_hour'] = result_df[date_col].dt.hour
                result_df[f'{date_col}_minute'] = result_df[date_col].dt.minute
                result_df[f'{date_col}_dayofweek'] = result_df[date_col].dt.dayofweek
                result_df[f'{date_col}_dayofyear'] = result_df[date_col].dt.dayofyear
                result_df[f'{date_col}_week'] = result_df[date_col].dt.isocalendar().week
                result_df[f'{date_col}_quarter'] = result_df[date_col].dt.quarter
                
                # Features cíclicas (mejor para ML)
                result_df[f'{date_col}_hour_sin'] = np.sin(2 * np.pi * result_df[f'{date_col}_hour'] / 24)
                result_df[f'{date_col}_hour_cos'] = np.cos(2 * np.pi * result_df[f'{date_col}_hour'] / 24)
                result_df[f'{date_col}_day_sin'] = np.sin(2 * np.pi * result_df[f'{date_col}_dayofweek'] / 7)
                result_df[f'{date_col}_day_cos'] = np.cos(2 * np.pi * result_df[f'{date_col}_dayofweek'] / 7)
                result_df[f'{date_col}_month_sin'] = np.sin(2 * np.pi * result_df[f'{date_col}_month'] / 12)
                result_df[f'{date_col}_month_cos'] = np.cos(2 * np.pi * result_df[f'{date_col}_month'] / 12)
                
                # Features de patrones de negocio
                result_df[f'{date_col}_is_weekend'] = (result_df[f'{date_col}_dayofweek'] >= 5).astype(int)
                result_df[f'{date_col}_is_business_hour'] = (
                    (result_df[f'{date_col}_hour'] >= 9) & 
                    (result_df[f'{date_col}_hour'] <= 17) &
                    (result_df[f'{date_col}_dayofweek'] < 5)
                ).astype(int)
                result_df[f'{date_col}_is_peak_morning'] = (
                    (result_df[f'{date_col}_hour'] >= 7) & (result_df[f'{date_col}_hour'] <= 9)
                ).astype(int)
                result_df[f'{date_col}_is_peak_evening'] = (
                    (result_df[f'{date_col}_hour'] >= 17) & (result_df[f'{date_col}_hour'] <= 19)
                ).astype(int)
                
                # Features de época del año
                result_df[f'{date_col}_is_holiday_season'] = (
                    (result_df[f'{date_col}_month'] == 12) | (result_df[f'{date_col}_month'] == 1)
                ).astype(int)
                
                # Features de tiempo relativo
                if len(result_df) > 1:
                    min_date = result_df[date_col].min()
                    result_df[f'{date_col}_days_since_start'] = (result_df[date_col] - min_date).dt.days
                
                created_features.extend([
                    f'Features temporales básicas para {date_col}',
                    f'Features cíclicas para {date_col}',
                    f'Features de patrones de negocio para {date_col}'
                ])
            
            return result_df, created_features
            
        except Exception as e:
            self.logger.error(f"Error creando features temporales: {str(e)}")
            raise
    
    async def _create_interaction_features(self, df: pd.DataFrame, config: Dict[str, Any]) -> Tuple[pd.DataFrame, List[str]]:
        """Crear features de interacción"""
        try:
            result_df = df.copy()
            created_features = []
            
            numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
            max_interactions = config.get('max_interactions', 20)
            
            # Interacciones automáticas entre features numéricas importantes
            if config.get('auto_interactions', True) and len(numeric_cols) > 1:
                # Seleccionar top features por varianza
                variances = df[numeric_cols].var().sort_values(ascending=False)
                top_features = variances.head(min(6, len(variances))).index.tolist()
                
                interaction_count = 0
                for i, col1 in enumerate(top_features):
                    if interaction_count >= max_interactions:
                        break
                    for col2 in top_features[i+1:]:
                        if interaction_count >= max_interactions:
                            break
                        
                        # Multiplicación
                        result_df[f'{col1}_x_{col2}'] = df[col1] * df[col2]
                        
                        # División (con protección contra división por cero)
                        result_df[f'{col1}_div_{col2}'] = df[col1] / (df[col2] + 1e-8)
                        
                        # Diferencia
                        result_df[f'{col1}_diff_{col2}'] = df[col1] - df[col2]
                        
                        # Ratio
                        result_df[f'{col1}_ratio_{col2}'] = df[col1] / (df[col1] + df[col2] + 1e-8)
                        
                        interaction_count += 4
                
                created_features.append(f'Interacciones automáticas: {interaction_count} features')
            
            # Interacciones específicas configuradas
            custom_interactions = config.get('custom_interactions', [])
            for interaction in custom_interactions:
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
                    
                    created_features.append(f'Interacción custom: {col1} {operation} {col2}')
            
            return result_df, created_features
            
        except Exception as e:
            self.logger.error(f"Error creando features de interacción: {str(e)}")
            raise
    
    async def _create_polynomial_features(self, df: pd.DataFrame, config: Dict[str, Any]) -> Tuple[pd.DataFrame, List[str]]:
        """Crear features polinomiales"""
        try:
            result_df = df.copy()
            created_features = []
            
            degree = config.get('degree', 2)
            max_features = config.get('max_features', 50)
            include_bias = config.get('include_bias', False)
            
            # Seleccionar features numéricas para polinomios
            numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
            
            if len(numeric_cols) == 0:
                return result_df, created_features
            
            # Limitar número de features de entrada para evitar explosión
            max_input_features = min(5, len(numeric_cols))
            selected_cols = numeric_cols[:max_input_features]
            
            # Crear features polinomiales
            poly = PolynomialFeatures(
                degree=degree,
                include_bias=include_bias,
                interaction_only=False
            )
            
            X_poly = poly.fit_transform(df[selected_cols])
            
            # Obtener nombres de las nuevas features
            feature_names = poly.get_feature_names_out(selected_cols)
            
            # Crear DataFrame con features polinomiales
            poly_df = pd.DataFrame(X_poly, columns=feature_names, index=df.index)
            
            # Remover features originales (ya están en poly_df)
            new_features = [col for col in feature_names if col not in selected_cols]
            
            # Limitar número de features nuevas
            if len(new_features) > max_features:
                # Seleccionar features con mayor varianza
                variances = poly_df[new_features].var().sort_values(ascending=False)
                new_features = variances.head(max_features).index.tolist()
            
            # Añadir nuevas features polinomiales
            for col in new_features:
                result_df[col] = poly_df[col]
            
            # Guardar transformer
            self.polynomial_transformers[f'poly_degree_{degree}'] = poly
            
            created_features.append(f'Features polinomiales grado {degree}: {len(new_features)} features')
            
            return result_df, created_features
            
        except Exception as e:
            self.logger.error(f"Error creando features polinomiales: {str(e)}")
            raise
    
    async def _create_aggregation_features(self, df: pd.DataFrame, config: Dict[str, Any]) -> Tuple[pd.DataFrame, List[str]]:
        """Crear features de agregación y rolling"""
        try:
            result_df = df.copy()
            created_features = []
            
            # Features de rolling windows
            if config.get('rolling_features', True):
                numeric_cols = [col for col in df.select_dtypes(include=[np.number]).columns 
                              if col in ['count', 'total_count']]  # Features principales
                
                windows = config.get('rolling_windows', [3, 6, 12, 24])
                operations = config.get('rolling_operations', ['mean', 'std', 'min', 'max'])
                
                for col in numeric_cols:
                    for window in windows:
                        if len(df) > window:
                            for op in operations:
                                if op == 'mean':
                                    result_df[f'{col}_rolling_{window}_mean'] = df[col].rolling(window=window, min_periods=1).mean()
                                elif op == 'std':
                                    result_df[f'{col}_rolling_{window}_std'] = df[col].rolling(window=window, min_periods=1).std()
                                elif op == 'min':
                                    result_df[f'{col}_rolling_{window}_min'] = df[col].rolling(window=window, min_periods=1).min()
                                elif op == 'max':
                                    result_df[f'{col}_rolling_{window}_max'] = df[col].rolling(window=window, min_periods=1).max()
                    
                    created_features.append(f'Rolling features para {col}')
            
            # Features de lag
            if config.get('lag_features', True):
                lag_columns = [col for col in df.select_dtypes(include=[np.number]).columns 
                             if col in ['count', 'total_count']]
                lags = config.get('lag_periods', [1, 2, 24, 168])  # 1h, 2h, 1d, 1w
                
                for col in lag_columns:
                    for lag in lags:
                        if len(df) > lag:
                            result_df[f'{col}_lag_{lag}'] = df[col].shift(lag)
                    
                    created_features.append(f'Lag features para {col}')
            
            # Features de cambio y tendencia
            if config.get('change_features', True):
                change_columns = [col for col in df.select_dtypes(include=[np.number]).columns 
                                if col in ['count', 'total_count']]
                
                for col in change_columns:
                    if len(df) > 1:
                        # Cambio absoluto
                        result_df[f'{col}_diff'] = df[col].diff()
                        
                        # Cambio porcentual
                        result_df[f'{col}_pct_change'] = df[col].pct_change()
                        
                        # Aceleración (segunda derivada)
                        result_df[f'{col}_acceleration'] = df[col].diff().diff()
                        
                        # Features de momentum
                        if len(df) > 5:
                            result_df[f'{col}_momentum_5'] = df[col] - df[col].shift(5)
                            result_df[f'{col}_momentum_rate'] = result_df[f'{col}_momentum_5'] / 5
                    
                    created_features.append(f'Features de cambio para {col}')
            
            # Features de posición relativa
            if config.get('relative_features', True):
                numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
                
                for col in numeric_cols:
                    if len(df) > 1:
                        # Percentil relativo
                        result_df[f'{col}_percentile'] = df[col].rank(pct=True)
                        
                        # Z-score rolante
                        if len(df) > 10:
                            rolling_mean = df[col].rolling(window=min(24, len(df))).mean()
                            rolling_std = df[col].rolling(window=min(24, len(df))).std()
                            result_df[f'{col}_zscore_rolling'] = (df[col] - rolling_mean) / (rolling_std + 1e-8)
                
                created_features.append('Features de posición relativa')
            
            return result_df, created_features
            
        except Exception as e:
            self.logger.error(f"Error creando features de agregación: {str(e)}")
            raise
    
    async def _create_model_specific_features(self, df: pd.DataFrame, model_type: str, config: Dict[str, Any]) -> Tuple[pd.DataFrame, List[str]]:
        """Crear features específicas por tipo de modelo"""
        try:
            result_df = df.copy()
            created_features = []
            
            if model_type in ["regression", "peak_hours"]:
                # Features para regresión y predicción de picos
                if 'count' in df.columns:
                    # Features de densidad temporal
                    if 'hour' in df.columns or 'hourlyDateTime_hour' in df.columns:
                        hour_col = 'hour' if 'hour' in df.columns else 'hourlyDateTime_hour'
                        
                        # Peak indicators más granulares
                        result_df['is_early_morning'] = (result_df[hour_col].between(5, 7)).astype(int)
                        result_df['is_morning_peak'] = (result_df[hour_col].between(7, 10)).astype(int)
                        result_df['is_lunch_time'] = (result_df[hour_col].between(12, 14)).astype(int)
                        result_df['is_evening_peak'] = (result_df[hour_col].between(17, 20)).astype(int)
                        result_df['is_night'] = (result_df[hour_col].between(22, 24) | result_df[hour_col].between(0, 5)).astype(int)
                        
                        created_features.append('Features de períodos específicos')
                    
                    # Features de intensidad
                    if len(df) > 24:
                        # Comparación con promedios históricos
                        result_df['count_vs_daily_avg'] = df['count'] / df['count'].rolling(window=24).mean()
                        result_df['count_vs_weekly_avg'] = df['count'] / df['count'].rolling(window=168).mean()
                        
                        # Volatilidad local
                        result_df['count_volatility'] = df['count'].rolling(window=12).std()
                        
                        created_features.append('Features de comparación temporal')
            
            elif model_type == "clustering":
                # Features para clustering de patrones
                numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
                
                for col in numeric_cols:
                    if len(df) > 1:
                        # Features de distribución
                        result_df[f'{col}_normalized'] = (df[col] - df[col].min()) / (df[col].max() - df[col].min() + 1e-8)
                        
                        # Desviación de la mediana
                        result_df[f'{col}_dev_from_median'] = np.abs(df[col] - df[col].median())
                        
                        # Quartile position
                        result_df[f'{col}_quartile'] = pd.qcut(df[col], q=4, labels=[1, 2, 3, 4], duplicates='drop').astype(float)
                
                created_features.append('Features de distribución para clustering')
            
            elif model_type == "time_series":
                # Features específicas para series temporales
                if 'count' in df.columns and len(df) > 1:
                    # Features de estacionalidad
                    if 'hour' in df.columns or 'hourlyDateTime_hour' in df.columns:
                        hour_col = 'hour' if 'hour' in df.columns else 'hourlyDateTime_hour'
                        
                        # Componentes armónicos
                        for period in [24, 168]:  # Diario y semanal
                            result_df[f'harmonic_sin_{period}'] = np.sin(2 * np.pi * result_df.index / period)
                            result_df[f'harmonic_cos_{period}'] = np.cos(2 * np.pi * result_df.index / period)
                    
                    # Features de tendencia
                    if len(df) > 10:
                        # Trend mediante regresión lineal local
                        from scipy.stats import linregress
                        window = min(48, len(df) // 2)
                        
                        def local_trend(series, window):
                            trends = []
                            for i in range(len(series)):
                                start = max(0, i - window // 2)
                                end = min(len(series), i + window // 2 + 1)
                                if end - start > 2:
                                    x = np.arange(end - start)
                                    y = series.iloc[start:end].values
                                    slope, _, _, _, _ = linregress(x, y)
                                    trends.append(slope)
                                else:
                                    trends.append(0)
                            return trends
                        
                        result_df['local_trend'] = local_trend(df['count'], window)
                    
                    created_features.append('Features de estacionalidad y tendencia')
            
            return result_df, created_features
            
        except Exception as e:
            self.logger.error(f"Error creando features específicas para {model_type}: {str(e)}")
            raise
    
    async def _create_clustering_features(self, df: pd.DataFrame, config: Dict[str, Any]) -> Tuple[pd.DataFrame, List[str]]:
        """Crear features basadas en clustering de patrones"""
        try:
            result_df = df.copy()
            created_features = []
            
            # Seleccionar features numéricas para clustering
            numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
            
            if len(numeric_cols) < 2:
                return result_df, created_features
            
            # Limitar features para clustering
            max_features_for_clustering = min(8, len(numeric_cols))
            selected_features = numeric_cols[:max_features_for_clustering]
            
            # Datos para clustering
            cluster_data = df[selected_features].fillna(df[selected_features].median())
            
            n_clusters = config.get('n_clusters', min(5, max(2, len(df) // 20)))
            
            if len(cluster_data) > n_clusters:
                # K-means clustering
                kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
                cluster_labels = kmeans.fit_predict(cluster_data)
                
                # Feature de cluster assignment
                result_df['cluster_id'] = cluster_labels
                
                # Features de distancia a centroids
                distances = kmeans.transform(cluster_data)
                for i in range(n_clusters):
                    result_df[f'distance_to_cluster_{i}'] = distances[:, i]
                
                # Feature de distancia mínima (cohesión)
                result_df['min_cluster_distance'] = distances.min(axis=1)
                
                # Feature de ratio de distancias (separación)
                sorted_distances = np.sort(distances, axis=1)
                result_df['cluster_separation_ratio'] = sorted_distances[:, 1] / (sorted_distances[:, 0] + 1e-8)
                
                created_features.append(f'Features de clustering: {n_clusters} clusters')
            
            return result_df, created_features
            
        except Exception as e:
            self.logger.error(f"Error creando features de clustering: {str(e)}")
            raise
    
    async def _apply_dimensionality_reduction(self, df: pd.DataFrame, target_column: Optional[str], model_type: str, config: Dict[str, Any]) -> Tuple[pd.DataFrame, str]:
        """Aplicar reducción de dimensionalidad si hay demasiadas features"""
        try:
            method = config.get('method', 'pca')
            n_components = config.get('n_components', min(50, len(df.columns) // 2))
            
            # Separar features numéricas para reducción
            numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
            
            # Remover target si existe
            if target_column and target_column in numeric_cols:
                numeric_cols.remove(target_column)
            
            if len(numeric_cols) <= n_components:
                return df, "No se requiere reducción dimensional"
            
            result_df = df.copy()
            
            if method == 'pca':
                # PCA
                pca = PCA(n_components=n_components)
                X_reduced = pca.fit_transform(df[numeric_cols].fillna(0))
                
                # Crear nuevas columnas PCA
                pca_columns = [f'pca_{i}' for i in range(n_components)]
                pca_df = pd.DataFrame(X_reduced, columns=pca_columns, index=df.index)
                
                # Remover features originales y añadir PCA
                result_df = result_df.drop(numeric_cols, axis=1)
                result_df = pd.concat([result_df, pca_df], axis=1)
                
                # Guardar transformer
                self.pca_transformers[f'pca_{n_components}'] = pca
                
                variance_explained = pca.explained_variance_ratio_.sum()
                info = f"PCA: {len(numeric_cols)} -> {n_components} features, {variance_explained:.3f} varianza explicada"
            
            else:
                info = f"Método {method} no implementado"
            
            return result_df, info
            
        except Exception as e:
            self.logger.error(f"Error en reducción dimensional: {str(e)}")
            raise
    
    async def _select_best_features(self, df: pd.DataFrame, target_column: str, model_type: str, config: Dict[str, Any]) -> Tuple[pd.DataFrame, str]:
        """Seleccionar las mejores features usando métodos estadísticos"""
        try:
            method = config.get('method', 'auto')
            k_features = config.get('k_features', min(20, len(df.columns) - 1))
            
            if target_column not in df.columns:
                return df, "Target column no encontrada"
            
            X = df.drop(target_column, axis=1)
            y = df[target_column]
            
            # Seleccionar solo features numéricas para selection
            numeric_features = X.select_dtypes(include=[np.number]).columns.tolist()
            
            if len(numeric_features) <= k_features:
                return df, f"No se requiere selección: {len(numeric_features)} features numéricas"
            
            X_numeric = X[numeric_features].fillna(0)
            
            # Seleccionar método basado en modelo
            if method == 'auto':
                if model_type == 'regression':
                    score_func = f_regression
                elif model_type == 'classification':
                    score_func = f_classif
                else:
                    score_func = f_regression
            elif method == 'mutual_info':
                if model_type == 'regression':
                    score_func = mutual_info_regression
                else:
                    score_func = mutual_info_classif
            else:
                score_func = f_regression
            
            # Aplicar selección
            selector = SelectKBest(score_func=score_func, k=min(k_features, len(numeric_features)))
            X_selected = selector.fit_transform(X_numeric, y)
            
            # Obtener features seleccionadas
            selected_mask = selector.get_support()
            selected_features = [numeric_features[i] for i in range(len(numeric_features)) if selected_mask[i]]
            
            # Crear DataFrame resultado
            result_df = df.copy()
            
            # Mantener features no numéricas y target
            non_numeric_features = [col for col in df.columns if col not in numeric_features or col == target_column]
            features_to_keep = selected_features + non_numeric_features
            
            result_df = result_df[features_to_keep]
            
            # Guardar selector
            self.feature_selectors[f'{method}_{k_features}'] = selector
            
            info = f"Selección {method}: {len(numeric_features)} -> {len(selected_features)} features"
            
            return result_df, info
            
        except Exception as e:
            self.logger.error(f"Error en selección de features: {str(e)}")
            raise
    
    async def _remove_correlated_features(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, str]:
        """Remover features altamente correlacionadas"""
        try:
            numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
            
            if len(numeric_cols) < 2:
                return df, "Insuficientes features numéricas para análisis de correlación"
            
            # Calcular matriz de correlación
            corr_matrix = df[numeric_cols].corr().abs()
            
            # Encontrar pares altamente correlacionados
            upper_triangle = corr_matrix.where(
                np.triu(np.ones(corr_matrix.shape), k=1).astype(bool)
            )
            
            # Features a remover
            to_drop = [column for column in upper_triangle.columns 
                      if any(upper_triangle[column] > self.correlation_threshold)]
            
            if to_drop:
                result_df = df.drop(to_drop, axis=1)
                info = f"Removidas {len(to_drop)} features correlacionadas (r > {self.correlation_threshold})"
            else:
                result_df = df
                info = "No se encontraron features altamente correlacionadas"
            
            return result_df, info
            
        except Exception as e:
            self.logger.error(f"Error removiendo correlaciones: {str(e)}")
            raise
    
    async def _calculate_feature_importance(self, X: pd.DataFrame, y: pd.Series, model_type: str) -> Dict[str, float]:
        """Calcular importancia de features"""
        try:
            from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier
            
            # Llenar valores nulos
            X_filled = X.fillna(0)
            
            if len(X_filled.columns) == 0 or len(X_filled) < 2:
                return {}
            
            # Seleccionar modelo apropiado
            if model_type == 'regression':
                model = RandomForestRegressor(n_estimators=50, random_state=42, max_depth=10)
            else:
                model = RandomForestClassifier(n_estimators=50, random_state=42, max_depth=10)
            
            # Entrenar modelo
            model.fit(X_filled, y)
            
            # Obtener importancia
            feature_importance = dict(zip(X.columns, model.feature_importances_))
            
            # Ordenar por importancia
            sorted_importance = dict(sorted(feature_importance.items(), key=lambda x: x[1], reverse=True))
            
            return sorted_importance
            
        except Exception as e:
            self.logger.error(f"Error calculando importancia: {str(e)}")
            return {}


# Instancia global
feature_engineer = MLFeatureEngineer()

async def get_feature_engineer() -> MLFeatureEngineer:
    """Obtener instancia del ingeniero de features"""
    return feature_engineer