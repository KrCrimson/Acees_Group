"""
Utilidades de Validación ML - Sistema ACEES Group
Validaciones comunes para datos, modelos y resultados ML
"""
import pandas as pd
import numpy as np
from typing import Dict, List, Any, Optional, Tuple, Union
import logging
from datetime import datetime, timedelta
import warnings

class ValidationUtils:
    """
    Utilidades centralizadas para validación de datos y modelos ML
    """
    
    def __init__(self):
        self.logger = logging.getLogger("ml.validation")
    
    def validate_dataframe(self, 
                          df: pd.DataFrame, 
                          required_columns: List[str] = None,
                          min_rows: int = 10,
                          max_null_percentage: float = 0.8) -> Tuple[bool, List[str]]:
        """
        Validar DataFrame básico para ML
        
        Args:
            df: DataFrame a validar
            required_columns: Columnas requeridas
            min_rows: Mínimo número de filas
            max_null_percentage: Máximo porcentaje de nulos por columna
            
        Returns:
            Tuple (is_valid, list_of_errors)
        """
        errors = []
        
        # Validación básica de existencia
        if df is None:
            errors.append("DataFrame es None")
            return False, errors
        
        if df.empty:
            errors.append("DataFrame está vacío")
            return False, errors
        
        # Validar número mínimo de filas
        if len(df) < min_rows:
            errors.append(f"DataFrame tiene {len(df)} filas, mínimo requerido: {min_rows}")
        
        # Validar columnas requeridas
        if required_columns:
            missing_columns = set(required_columns) - set(df.columns)
            if missing_columns:
                errors.append(f"Columnas faltantes: {list(missing_columns)}")
        
        # Validar porcentaje de nulos
        for column in df.columns:
            null_percentage = df[column].isnull().sum() / len(df)
            if null_percentage > max_null_percentage:
                errors.append(f"Columna '{column}' tiene {null_percentage:.2%} nulos (máximo: {max_null_percentage:.2%})")
        
        # Validar tipos de datos básicos
        if 'fechaHora' in df.columns:
            try:
                pd.to_datetime(df['fechaHora'].dropna().iloc[:100], errors='raise')
            except:
                errors.append("Columna 'fechaHora' no tiene formato de fecha válido")
        
        # Validar duplicados excesivos
        duplicate_percentage = df.duplicated().sum() / len(df)
        if duplicate_percentage > 0.5:  # Más del 50% duplicados
            errors.append(f"Demasiados duplicados: {duplicate_percentage:.2%}")
        
        is_valid = len(errors) == 0
        
        if is_valid:
            self.logger.info(f"DataFrame válido: {len(df)} filas, {len(df.columns)} columnas")
        else:
            self.logger.warning(f"DataFrame inválido: {len(errors)} errores encontrados")
            
        return is_valid, errors
    
    def validate_temporal_data(self, 
                              df: pd.DataFrame,
                              datetime_column: str = 'fechaHora',
                              min_months_data: int = 3) -> Tuple[bool, List[str]]:
        """
        Validar datos temporales para ML
        
        Args:
            df: DataFrame con datos temporales
            datetime_column: Columna de fecha/hora
            min_months_data: Mínimo meses de datos requeridos
            
        Returns:
            Tuple (is_valid, list_of_errors)
        """
        errors = []
        
        if datetime_column not in df.columns:
            errors.append(f"Columna temporal '{datetime_column}' no encontrada")
            return False, errors
        
        try:
            # Convertir a datetime si no lo está
            dates = pd.to_datetime(df[datetime_column], errors='coerce')
            
            # Eliminar fechas inválidas para análisis
            valid_dates = dates.dropna()
            
            if len(valid_dates) == 0:
                errors.append("No hay fechas válidas en los datos")
                return False, errors
            
            # Validar rango temporal
            min_date = valid_dates.min()
            max_date = valid_dates.max()
            date_range_months = (max_date - min_date).days / 30.44  # Promedio días por mes
            
            if date_range_months < min_months_data:
                errors.append(f"Rango temporal insuficiente: {date_range_months:.1f} meses (mínimo: {min_months_data})")
            
            # Validar fechas futuras
            future_dates = valid_dates > datetime.now()
            if future_dates.sum() > 0:
                errors.append(f"Fechas futuras encontradas: {future_dates.sum()} registros")
            
            # Validar distribución temporal (detectar gaps grandes)
            date_diff = valid_dates.sort_values().diff()
            max_gap_days = date_diff.max().days if not date_diff.empty else 0
            
            if max_gap_days > 30:  # Gap de más de 30 días
                errors.append(f"Gap temporal grande detectado: {max_gap_days} días")
            
            # Validar frecuencia mínima de datos
            daily_counts = valid_dates.dt.date.value_counts()
            days_with_data = len(daily_counts)
            total_days = (max_date.date() - min_date.date()).days + 1
            data_coverage = days_with_data / total_days
            
            if data_coverage < 0.5:  # Menos del 50% de días con datos
                errors.append(f"Cobertura de datos baja: {data_coverage:.2%}")
            
        except Exception as e:
            errors.append(f"Error validando datos temporales: {str(e)}")
        
        is_valid = len(errors) == 0
        
        if is_valid:
            self.logger.info(f"Datos temporales válidos: {date_range_months:.1f} meses, cobertura {data_coverage:.2%}")
        else:
            self.logger.warning(f"Datos temporales inválidos: {len(errors)} errores")
            
        return is_valid, errors
    
    def validate_ml_features(self, 
                            X: Union[pd.DataFrame, np.ndarray],
                            y: Union[pd.Series, np.ndarray] = None,
                            feature_names: List[str] = None) -> Tuple[bool, List[str]]:
        """
        Validar features para entrenamiento ML
        
        Args:
            X: Features matrix
            y: Target vector (opcional)
            feature_names: Nombres de características
            
        Returns:
            Tuple (is_valid, list_of_errors)
        """
        errors = []
        
        # Convertir a arrays si es necesario
        if isinstance(X, pd.DataFrame):
            X_array = X.values
            if feature_names is None:
                feature_names = list(X.columns)
        else:
            X_array = np.array(X)
        
        if y is not None:
            if isinstance(y, pd.Series):
                y_array = y.values
            else:
                y_array = np.array(y)
        
        # Validaciones básicas de forma
        if X_array.size == 0:
            errors.append("Matrix de features está vacía")
            return False, errors
        
        if len(X_array.shape) != 2:
            errors.append(f"Features deben ser matriz 2D, recibido: {X_array.shape}")
        
        n_samples, n_features = X_array.shape
        
        # Validar número mínimo de muestras
        if n_samples < 10:
            errors.append(f"Muy pocas muestras: {n_samples} (mínimo: 10)")
        
        # Validar número mínimo de features
        if n_features < 1:
            errors.append(f"Sin features: {n_features}")
        
        # Validar target si se proporciona
        if y is not None:
            if len(y_array) != n_samples:
                errors.append(f"Desajuste muestras: X={n_samples}, y={len(y_array)}")
        
        # Validar valores numéricos
        if not np.all(np.isfinite(X_array)):
            inf_count = np.isinf(X_array).sum()
            nan_count = np.isnan(X_array).sum()
            if inf_count > 0:
                errors.append(f"Valores infinitos en features: {inf_count}")
            if nan_count > 0:
                errors.append(f"Valores NaN en features: {nan_count}")
        
        # Validar varianza en features
        if n_samples > 1:
            feature_vars = np.var(X_array, axis=0)
            zero_var_features = np.sum(feature_vars == 0)
            if zero_var_features > 0:
                if feature_names:
                    zero_var_names = [feature_names[i] for i in range(len(feature_vars)) if feature_vars[i] == 0]
                    errors.append(f"Features con varianza cero: {zero_var_names}")
                else:
                    errors.append(f"Features con varianza cero: {zero_var_features}")
        
        # Validar correlaciones altas entre features (multicolinealidad básica)
        if n_features > 1 and n_samples > n_features:
            try:
                correlation_matrix = np.corrcoef(X_array.T)
                # Eliminar diagonal y tomar valores absolutos
                correlation_matrix = np.abs(correlation_matrix)
                np.fill_diagonal(correlation_matrix, 0)
                
                high_corr_pairs = np.where(correlation_matrix > 0.95)
                if len(high_corr_pairs[0]) > 0:
                    errors.append(f"Correlaciones muy altas detectadas: {len(high_corr_pairs[0])} pares")
                    
            except Exception as e:
                self.logger.warning(f"No se pudo calcular correlaciones: {str(e)}")
        
        is_valid = len(errors) == 0
        
        if is_valid:
            self.logger.info(f"Features válidas: {n_samples} muestras, {n_features} features")
        else:
            self.logger.warning(f"Features inválidas: {len(errors)} errores")
            
        return is_valid, errors
    
    def validate_model_metrics(self, 
                              metrics: Dict[str, float],
                              model_type: str = 'regression',
                              minimum_thresholds: Dict[str, float] = None) -> Tuple[bool, List[str]]:
        """
        Validar métricas de modelo ML
        
        Args:
            metrics: Diccionario de métricas
            model_type: Tipo de modelo ('regression', 'classification')
            minimum_thresholds: Umbrales mínimos por métrica
            
        Returns:
            Tuple (is_valid, list_of_warnings)
        """
        warnings_list = []
        
        # Umbrales por defecto
        if minimum_thresholds is None:
            if model_type == 'regression':
                minimum_thresholds = {
                    'r2_score': 0.5,
                    'mse': None,  # No tiene umbral mínimo (menor es mejor)
                    'mae': None,
                    'rmse': None
                }
            elif model_type == 'classification':
                minimum_thresholds = {
                    'accuracy': 0.7,
                    'precision': 0.6,
                    'recall': 0.6,
                    'f1_score': 0.6
                }
            else:
                minimum_thresholds = {}
        
        # Validar métricas de regresión
        if model_type == 'regression':
            r2 = metrics.get('r2_score')
            if r2 is not None:
                if r2 < 0:
                    warnings_list.append(f"R² negativo: {r2:.3f} (peor que predicción constante)")
                elif r2 < minimum_thresholds.get('r2_score', 0.5):
                    warnings_list.append(f"R² bajo: {r2:.3f} (umbral: {minimum_thresholds['r2_score']:.3f})")
            
            # Verificar consistencia entre métricas
            mse = metrics.get('mse')
            rmse = metrics.get('rmse')
            if mse is not None and rmse is not None:
                expected_rmse = np.sqrt(mse)
                if abs(rmse - expected_rmse) > 0.01:
                    warnings_list.append(f"RMSE inconsistente: {rmse:.3f}, esperado: {expected_rmse:.3f}")
        
        # Validar métricas de clasificación
        elif model_type == 'classification':
            for metric_name in ['accuracy', 'precision', 'recall', 'f1_score']:
                metric_value = metrics.get(metric_name)
                if metric_value is not None:
                    if metric_value < 0 or metric_value > 1:
                        warnings_list.append(f"{metric_name} fuera de rango [0,1]: {metric_value:.3f}")
                    elif metric_value < minimum_thresholds.get(metric_name, 0.5):
                        warnings_list.append(f"{metric_name} bajo: {metric_value:.3f}")
            
            # Verificar balance precision/recall
            precision = metrics.get('precision')
            recall = metrics.get('recall')
            if precision is not None and recall is not None:
                if abs(precision - recall) > 0.3:
                    warnings_list.append(f"Desbalance precision/recall: P={precision:.3f}, R={recall:.3f}")
        
        # Validar métricas generales
        for metric_name, metric_value in metrics.items():
            if not isinstance(metric_value, (int, float)):
                warnings_list.append(f"Métrica '{metric_name}' no es numérica: {type(metric_value)}")
            elif np.isnan(metric_value):
                warnings_list.append(f"Métrica '{metric_name}' es NaN")
            elif np.isinf(metric_value):
                warnings_list.append(f"Métrica '{metric_name}' es infinita")
        
        is_valid = len(warnings_list) == 0
        
        if is_valid:
            self.logger.info(f"Métricas válidas para {model_type}")
        else:
            self.logger.warning(f"Métricas con {len(warnings_list)} advertencias")
            
        return is_valid, warnings_list
    
    def validate_prediction_input(self, 
                                 data: Union[pd.DataFrame, Dict[str, Any], List[Dict[str, Any]]],
                                 expected_features: List[str] = None) -> Tuple[bool, List[str]]:
        """
        Validar datos de entrada para predicción
        
        Args:
            data: Datos para predicción
            expected_features: Features esperadas por el modelo
            
        Returns:
            Tuple (is_valid, list_of_errors)
        """
        errors = []
        
        # Convertir a DataFrame si es necesario
        if isinstance(data, dict):
            df = pd.DataFrame([data])
        elif isinstance(data, list):
            df = pd.DataFrame(data)
        elif isinstance(data, pd.DataFrame):
            df = data.copy()
        else:
            errors.append(f"Tipo de datos no soportado: {type(data)}")
            return False, errors
        
        # Validar que no esté vacío
        if df.empty:
            errors.append("Datos de predicción vacíos")
            return False, errors
        
        # Validar features esperadas
        if expected_features:
            missing_features = set(expected_features) - set(df.columns)
            if missing_features:
                errors.append(f"Features faltantes: {list(missing_features)}")
            
            extra_features = set(df.columns) - set(expected_features)
            if extra_features:
                # Esto es solo warning, no error crítico
                self.logger.warning(f"Features adicionales (serán ignoradas): {list(extra_features)}")
        
        # Validar valores numéricos
        numeric_columns = df.select_dtypes(include=[np.number]).columns
        for col in numeric_columns:
            if df[col].isnull().any():
                null_count = df[col].isnull().sum()
                errors.append(f"Valores nulos en '{col}': {null_count}")
            
            if np.isinf(df[col]).any():
                inf_count = np.isinf(df[col]).sum()
                errors.append(f"Valores infinitos en '{col}': {inf_count}")
        
        # Validar fechas si existen
        if 'fechaHora' in df.columns:
            try:
                dates = pd.to_datetime(df['fechaHora'], errors='coerce')
                invalid_dates = dates.isnull().sum()
                if invalid_dates > 0:
                    errors.append(f"Fechas inválidas: {invalid_dates}")
            except:
                errors.append("Error procesando columna 'fechaHora'")
        
        is_valid = len(errors) == 0
        
        if is_valid:
            self.logger.info(f"Datos de predicción válidos: {len(df)} muestras")
        else:
            self.logger.warning(f"Datos de predicción inválidos: {len(errors)} errores")
            
        return is_valid, errors
    
    def validate_training_results(self, 
                                 training_result: Dict[str, Any],
                                 expected_keys: List[str] = None) -> Tuple[bool, List[str]]:
        """
        Validar resultados de entrenamiento
        
        Args:
            training_result: Diccionario con resultados
            expected_keys: Claves esperadas en el resultado
            
        Returns:
            Tuple (is_valid, list_of_errors)
        """
        errors = []
        
        if not isinstance(training_result, dict):
            errors.append(f"Resultado debe ser diccionario, recibido: {type(training_result)}")
            return False, errors
        
        # Validar claves esperadas
        if expected_keys is None:
            expected_keys = ['model', 'metrics', 'training_time', 'version']
        
        missing_keys = set(expected_keys) - set(training_result.keys())
        if missing_keys:
            errors.append(f"Claves faltantes en resultado: {list(missing_keys)}")
        
        # Validar métricas si están presentes
        if 'metrics' in training_result:
            metrics = training_result['metrics']
            if not isinstance(metrics, dict):
                errors.append("Métricas deben ser diccionario")
            else:
                # Usar validación de métricas
                metrics_valid, metrics_warnings = self.validate_model_metrics(metrics)
                if not metrics_valid:
                    errors.extend([f"Métrica: {w}" for w in metrics_warnings])
        
        # Validar tiempo de entrenamiento
        if 'training_time' in training_result:
            training_time = training_result['training_time']
            if not isinstance(training_time, (int, float)):
                errors.append("training_time debe ser numérico")
            elif training_time < 0:
                errors.append("training_time no puede ser negativo")
            elif training_time > 86400:  # Más de 24 horas
                errors.append(f"training_time muy alto: {training_time}s")
        
        # Validar modelo
        if 'model' in training_result:
            model = training_result['model']
            if model is None:
                errors.append("Modelo es None")
            elif not hasattr(model, 'predict'):
                errors.append("Modelo no tiene método predict")
        
        is_valid = len(errors) == 0
        
        if is_valid:
            self.logger.info("Resultados de entrenamiento válidos")
        else:
            self.logger.warning(f"Resultados de entrenamiento inválidos: {len(errors)} errores")
            
        return is_valid, errors
    
    def get_data_quality_report(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        Generar reporte completo de calidad de datos
        
        Args:
            df: DataFrame a analizar
            
        Returns:
            Dict con reporte de calidad
        """
        report = {
            'timestamp': datetime.now().isoformat(),
            'basic_info': {
                'rows': len(df),
                'columns': len(df.columns),
                'size_mb': df.memory_usage(deep=True).sum() / (1024 * 1024)
            },
            'null_analysis': {},
            'data_types': {},
            'duplicates': {
                'total_duplicates': df.duplicated().sum(),
                'duplicate_percentage': df.duplicated().sum() / len(df) if len(df) > 0 else 0
            },
            'temporal_analysis': {},
            'numeric_analysis': {},
            'categorical_analysis': {}
        }
        
        try:
            # Análisis de nulos
            for col in df.columns:
                null_count = df[col].isnull().sum()
                report['null_analysis'][col] = {
                    'null_count': int(null_count),
                    'null_percentage': float(null_count / len(df)) if len(df) > 0 else 0
                }
            
            # Tipos de datos
            report['data_types'] = {col: str(dtype) for col, dtype in df.dtypes.items()}
            
            # Análisis temporal
            datetime_columns = df.select_dtypes(include=['datetime64']).columns
            for col in datetime_columns:
                if not df[col].empty:
                    report['temporal_analysis'][col] = {
                        'min_date': str(df[col].min()),
                        'max_date': str(df[col].max()),
                        'date_range_days': (df[col].max() - df[col].min()).days if df[col].notna().any() else 0
                    }
            
            # Análisis numérico
            numeric_columns = df.select_dtypes(include=[np.number]).columns
            for col in numeric_columns:
                if not df[col].empty:
                    report['numeric_analysis'][col] = {
                        'min': float(df[col].min()) if df[col].notna().any() else None,
                        'max': float(df[col].max()) if df[col].notna().any() else None,
                        'mean': float(df[col].mean()) if df[col].notna().any() else None,
                        'std': float(df[col].std()) if df[col].notna().any() else None,
                        'zeros_count': int((df[col] == 0).sum()),
                        'negative_count': int((df[col] < 0).sum())
                    }
            
            # Análisis categórico
            categorical_columns = df.select_dtypes(include=['object', 'category']).columns
            for col in categorical_columns:
                if not df[col].empty:
                    value_counts = df[col].value_counts()
                    report['categorical_analysis'][col] = {
                        'unique_values': int(df[col].nunique()),
                        'most_frequent': str(value_counts.index[0]) if len(value_counts) > 0 else None,
                        'most_frequent_count': int(value_counts.iloc[0]) if len(value_counts) > 0 else 0
                    }
            
        except Exception as e:
            report['error'] = f"Error generando reporte: {str(e)}"
            self.logger.error(f"Error en reporte de calidad: {str(e)}")
        
        return report