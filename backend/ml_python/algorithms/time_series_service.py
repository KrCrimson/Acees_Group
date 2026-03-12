"""
Servicio de Series Temporales ML - Sistema ACEES Group
Implementación de análisis y predicción de series temporales (RF009.3)
"""
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import logging
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LinearRegression
import warnings
warnings.filterwarnings('ignore')

# Importar librerías de series temporales
try:
    from statsmodels.tsa.arima.model import ARIMA
    from statsmodels.tsa.seasonal import seasonal_decompose
    from statsmodels.tsa.stattools import adfuller, acf, pacf
    from statsmodels.graphics.tsaplots import plot_acf, plot_pacf
    STATSMODELS_AVAILABLE = True
except ImportError:
    STATSMODELS_AVAILABLE = False
    logging.warning("Statsmodels no disponible - funcionalidad limitada en series temporales")

from backend.ml_python.core.base_ml_service import BaseMLService
from backend.ml_python.core.model_manager import get_model_manager
from backend.ml_python.utils.metrics_calculator import get_metrics_calculator
from backend.ml_python.config.ml_config import get_ml_config
from backend.ml_python.data.dataset_builder import get_dataset_builder

class TimeSeriesMLService(BaseMLService):
    """
    Servicio de análisis y predicción de series temporales
    Implementa RF009.3: Predicción temporal con análisis de estacionalidad
    """
    
    def __init__(self):
        super().__init__()
        self.service_name = "TimeSeriesMLService"
        self.model_manager = get_model_manager()
        self.ml_config = get_ml_config()
        
        # Configuraciones específicas (RF009.3)
        self.target_forecast_accuracy = self.ml_config.TARGET_FORECAST_ACCURACY
        self.min_samples_ts = self.ml_config.min_training_samples
        
        # Modelos disponibles
        self.ts_models = {
            'arima': self._create_arima_model,
            'seasonal_arima': self._create_seasonal_arima_model,
            'linear_trend': self._create_linear_trend_model,
            'moving_average': self._create_moving_average_model
        }
        
        # Estado actual
        self.current_model = None
        self.current_scaler = None
        self.series_decomposition = None
        self.ts_history = []
        self.forecast_results = None
        
        self.logger.info(f"Inicializado {self.service_name} - Target Accuracy: {self.target_forecast_accuracy}")
    
    async def train_time_series_model(self, 
                                    training_config: Dict[str, Any],
                                    dataset_id: Optional[str] = None,
                                    custom_data: Optional[pd.DataFrame] = None) -> Dict[str, Any]:
        """
        Entrenar modelo de series temporales
        
        Args:
            training_config: Configuración de entrenamiento
            dataset_id: ID del dataset preprocesado
            custom_data: Datos personalizados
            
        Returns:
            Resultado del entrenamiento con métricas
        """
        try:
            self.logger.info("Iniciando entrenamiento de modelo de series temporales")
            
            # Obtener datos de entrenamiento
            time_series_data = await self._prepare_time_series_data(training_config, dataset_id, custom_data)
            
            # Validar datos
            if len(time_series_data) < self.min_samples_ts:
                raise ValueError(f"Datos insuficientes para series temporales: {len(time_series_data)} < {self.min_samples_ts}")
            
            # Análisis exploratorio de la serie
            ts_analysis = await self._analyze_time_series(time_series_data, training_config)
            
            # Preprocesamiento específico para series temporales
            processed_series = await self._preprocess_time_series(time_series_data, training_config)
            
            # Dividir en train/test temporal (manteniendo orden cronológico)
            train_series, test_series = await self._temporal_train_test_split(
                processed_series, training_config.get('test_size', 0.2)
            )
            
            # Seleccionar y entrenar modelo
            model_type = training_config.get('model_type', 'arima')
            model = await self._create_and_train_model(train_series, model_type, training_config)
            
            # Realizar predicciones en test
            test_predictions = await self._make_predictions(model, len(test_series), training_config)
            
            # Calcular métricas
            metrics = await self._calculate_time_series_metrics(test_series.values, test_predictions, ts_analysis)
            
            # Verificar cumplimiento RF009.3
            forecast_accuracy = metrics.get('forecast_accuracy', 0)
            meets_requirement = forecast_accuracy >= self.target_forecast_accuracy
            
            # Guardar modelo si cumple requisitos
            model_id = None
            if meets_requirement or training_config.get('force_save', False):
                model_metadata = {
                    'model_type': 'time_series',
                    'algorithm': model_type,
                    'target_accuracy': self.target_forecast_accuracy,
                    'achieved_accuracy': forecast_accuracy,
                    'meets_rf009_3': meets_requirement,
                    'training_samples': len(train_series),
                    'test_samples': len(test_series),
                    'time_series_analysis': ts_analysis,
                    'training_config': training_config,
                    'training_timestamp': datetime.now().isoformat()
                }
                
                model_artifacts = {
                    'model': model,
                    'scaler': self.current_scaler,
                    'series_decomposition': self.series_decomposition,
                    'training_data': train_series,
                    'time_column': training_config.get('time_column', 'hourlyDateTime'),
                    'target_column': training_config.get('target_column', 'count')
                }
                
                model_id = await self.model_manager.save_model(
                    model_artifacts, model_metadata
                )
            
            # Resultado del entrenamiento
            result = {
                'success': True,
                'model_id': model_id,
                'model_type': model_type,
                'metrics': metrics,
                'rf009_3_compliance': {
                    'target_accuracy': self.target_forecast_accuracy,
                    'achieved_accuracy': forecast_accuracy,
                    'meets_requirement': meets_requirement,
                    'requirement_status': 'PASS' if meets_requirement else 'FAIL'
                },
                'time_series_analysis': ts_analysis,
                'data_info': {
                    'total_samples': len(time_series_data),
                    'training_samples': len(train_series),
                    'test_samples': len(test_series),
                    'time_range': {
                        'start': str(time_series_data.index.min()),
                        'end': str(time_series_data.index.max()),
                        'frequency': self._infer_frequency(time_series_data.index)
                    }
                },
                'training_completed_at': datetime.now().isoformat()
            }
            
            # Registrar en historial
            self.ts_history.append({
                'timestamp': datetime.now(),
                'model_type': model_type,
                'forecast_accuracy': forecast_accuracy,
                'meets_rf009_3': meets_requirement,
                'model_id': model_id
            })
            
            self.logger.info(f"Entrenamiento completado - Accuracy: {forecast_accuracy:.3f}, RF009.3: {'PASS' if meets_requirement else 'FAIL'}")
            return result
            
        except Exception as e:
            self.logger.error(f"Error en entrenamiento de series temporales: {str(e)}")
            raise
    
    async def forecast(self, 
                     periods: int,
                     model_id: Optional[str] = None,
                     confidence_interval: bool = True) -> Dict[str, Any]:
        """
        Realizar pronóstico temporal
        
        Args:
            periods: Número de períodos a pronosticar
            model_id: ID del modelo específico
            confidence_interval: Incluir intervalos de confianza
            
        Returns:
            Pronósticos con intervalos de confianza
        """
        try:
            self.logger.info(f"Realizando pronóstico para {periods} períodos")
            
            # Cargar modelo si se especifica ID
            if model_id:
                model_artifacts = await self.model_manager.load_model(model_id)
                model = model_artifacts['model']
                scaler = model_artifacts.get('scaler')
                training_data = model_artifacts.get('training_data')
            else:
                # Usar modelo actual
                if self.current_model is None:
                    raise ValueError("No hay modelo de series temporales entrenado disponible")
                model = self.current_model
                scaler = self.current_scaler
                training_data = None
            
            # Realizar pronóstico
            forecast_values = await self._make_predictions(model, periods, {})
            
            # Calcular intervalos de confianza si se solicita
            confidence_intervals = None
            if confidence_interval:
                confidence_intervals = await self._calculate_confidence_intervals(
                    model, forecast_values, periods
                )
            
            # Generar fechas futuras
            if training_data is not None and hasattr(training_data, 'index'):
                last_date = training_data.index[-1]
                freq = self._infer_frequency(training_data.index)
                future_dates = pd.date_range(
                    start=last_date + pd.Timedelta(freq),
                    periods=periods,
                    freq=freq
                )
            else:
                # Fechas genéricas
                future_dates = pd.date_range(
                    start=datetime.now(),
                    periods=periods,
                    freq='H'  # Default hourly
                )
            
            # Preparar resultado
            result = {
                'success': True,
                'forecast_periods': periods,
                'forecasts': forecast_values.tolist(),
                'forecast_dates': [date.isoformat() for date in future_dates],
                'model_info': {
                    'model_id': model_id,
                    'model_type': type(model).__name__
                }
            }
            
            if confidence_intervals:
                result['confidence_intervals'] = {
                    'lower_bound': confidence_intervals['lower'].tolist(),
                    'upper_bound': confidence_intervals['upper'].tolist(),
                    'confidence_level': confidence_intervals.get('level', 0.95)
                }
            
            # DataFrame con pronósticos
            forecast_df = pd.DataFrame({
                'date': future_dates,
                'forecast': forecast_values
            })
            
            if confidence_intervals:
                forecast_df['lower_bound'] = confidence_intervals['lower']
                forecast_df['upper_bound'] = confidence_intervals['upper']
            
            result['forecast_df'] = forecast_df.to_dict('records')
            result['forecast_timestamp'] = datetime.now().isoformat()
            
            self.forecast_results = result
            
            self.logger.info(f"Pronóstico completado para {periods} períodos")
            return result
            
        except Exception as e:
            self.logger.error(f"Error en pronóstico: {str(e)}")
            raise
    
    async def evaluate_forecast(self, 
                              actual_data: pd.Series,
                              forecast_data: pd.Series,
                              model_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Evaluar precisión de pronósticos
        
        Args:
            actual_data: Valores reales
            forecast_data: Valores pronosticados
            model_id: ID del modelo
            
        Returns:
            Métricas de evaluación del pronóstico
        """
        try:
            self.logger.info("Evaluando precisión de pronósticos")
            
            # Alinear series por índice
            aligned_data = pd.DataFrame({
                'actual': actual_data,
                'forecast': forecast_data
            }).dropna()
            
            if len(aligned_data) == 0:
                raise ValueError("No hay datos alineados para evaluación")
            
            actual_values = aligned_data['actual'].values
            forecast_values = aligned_data['forecast'].values
            
            # Calcular métricas de pronóstico
            metrics = await self._calculate_forecast_evaluation_metrics(actual_values, forecast_values)
            
            # Verificar cumplimiento RF009.3
            forecast_accuracy = metrics.get('forecast_accuracy', 0)
            meets_rf009_3 = forecast_accuracy >= self.target_forecast_accuracy
            
            # Análisis de errores temporales
            errors = forecast_values - actual_values
            error_analysis = {
                'mean_error': float(np.mean(errors)),
                'std_error': float(np.std(errors)),
                'max_error': float(np.max(np.abs(errors))),
                'directional_accuracy': float(np.mean(np.sign(forecast_values[1:] - forecast_values[:-1]) == 
                                                    np.sign(actual_values[1:] - actual_values[:-1]))),
                'error_autocorrelation': float(np.corrcoef(errors[:-1], errors[1:])[0, 1]) if len(errors) > 1 else 0
            }
            
            # Resultado de evaluación
            evaluation_result = {
                'success': True,
                'evaluation_samples': len(aligned_data),
                'metrics': metrics,
                'rf009_3_compliance': {
                    'target_accuracy': self.target_forecast_accuracy,
                    'achieved_accuracy': forecast_accuracy,
                    'meets_requirement': meets_rf009_3,
                    'requirement_status': 'PASS' if meets_rf009_3 else 'FAIL'
                },
                'error_analysis': error_analysis,
                'forecast_quality': {
                    'excellent': forecast_accuracy >= 0.9,
                    'good': 0.8 <= forecast_accuracy < 0.9,
                    'acceptable': 0.7 <= forecast_accuracy < 0.8,
                    'poor': forecast_accuracy < 0.7,
                    'quality_level': self._get_forecast_quality_level(forecast_accuracy)
                },
                'evaluation_timestamp': datetime.now().isoformat()
            }
            
            self.logger.info(f"Evaluación completada - Accuracy: {forecast_accuracy:.3f}")
            return evaluation_result
            
        except Exception as e:
            self.logger.error(f"Error en evaluación de pronóstico: {str(e)}")
            raise
    
    async def decompose_time_series(self, 
                                  data: pd.Series,
                                  model: str = 'additive',
                                  period: Optional[int] = None) -> Dict[str, Any]:
        """
        Descomponer serie temporal en componentes
        
        Args:
            data: Serie temporal
            model: Tipo de descomposición ('additive', 'multiplicative')
            period: Período de estacionalidad
            
        Returns:
            Componentes de la serie temporal
        """
        try:
            self.logger.info("Descomponiendo serie temporal")
            
            if not STATSMODELS_AVAILABLE:
                return await self._simple_decomposition(data)
            
            # Inferir período si no se especifica
            if period is None:
                period = self._infer_seasonal_period(data)
            
            # Realizar descomposición
            decomposition = seasonal_decompose(
                data, 
                model=model, 
                period=period,
                extrapolate_trend='freq'
            )
            
            # Extraer componentes
            components = {
                'trend': decomposition.trend.dropna().to_dict(),
                'seasonal': decomposition.seasonal.to_dict(),
                'residual': decomposition.resid.dropna().to_dict(),
                'original': data.to_dict()
            }
            
            # Análisis de componentes
            analysis = {
                'decomposition_model': model,
                'seasonal_period': period,
                'trend_strength': float(1 - np.var(decomposition.resid.dropna()) / np.var(data.dropna())),
                'seasonal_strength': float(1 - np.var(decomposition.resid.dropna()) / 
                                         np.var(data.dropna() - decomposition.trend.dropna())),
                'residual_stats': {
                    'mean': float(decomposition.resid.dropna().mean()),
                    'std': float(decomposition.resid.dropna().std()),
                    'skewness': float(decomposition.resid.dropna().skew()),
                    'kurtosis': float(decomposition.resid.dropna().kurtosis())
                }
            }
            
            self.series_decomposition = {
                'components': components,
                'analysis': analysis,
                'decomposition_obj': decomposition
            }
            
            result = {
                'success': True,
                'components': components,
                'analysis': analysis,
                'decomposition_timestamp': datetime.now().isoformat()
            }
            
            self.logger.info("Descomposición completada")
            return result
            
        except Exception as e:
            self.logger.error(f"Error en descomposición: {str(e)}")
            raise
    
    async def _prepare_time_series_data(self, config: Dict[str, Any], dataset_id: Optional[str], custom_data: Optional[pd.DataFrame]) -> pd.Series:
        """Preparar datos de series temporales"""
        try:
            if dataset_id:
                train_data = await self.model_manager.load_dataset(dataset_id)
                df = train_data['train']['X']
                # Para series temporales, necesitamos unir X e y si existe
                if 'y' in train_data['train']:
                    df[config.get('target_column', 'count')] = train_data['train']['y']
            elif custom_data is not None:
                df = custom_data
            else:
                # Construir dataset automáticamente
                dataset_builder = await get_dataset_builder()
                dataset_result = await dataset_builder.build_dataset(
                    model_type="time_series",
                    dataset_config=config.get('dataset_config', {}),
                    target_column=config.get('target_column', 'count')
                )
                df = dataset_result['data']
            
            # Configurar series temporal
            time_col = config.get('time_column', 'hourlyDateTime')
            target_col = config.get('target_column', 'count')
            
            if time_col not in df.columns:
                raise ValueError(f"Columna de tiempo '{time_col}' no encontrada")
            
            if target_col not in df.columns:
                raise ValueError(f"Columna objetivo '{target_col}' no encontrada")
            
            # Crear serie temporal
            df[time_col] = pd.to_datetime(df[time_col])
            df = df.sort_values(time_col)
            
            # Crear índice temporal
            time_series = pd.Series(
                df[target_col].values,
                index=df[time_col],
                name=target_col
            )
            
            # Remover duplicados manteniendo el último
            time_series = time_series[~time_series.index.duplicated(keep='last')]
            
            return time_series
            
        except Exception as e:
            self.logger.error(f"Error preparando datos de series temporales: {str(e)}")
            raise
    
    async def _analyze_time_series(self, data: pd.Series, config: Dict[str, Any]) -> Dict[str, Any]:
        """Analizar características de la serie temporal"""
        try:
            analysis = {
                'length': len(data),
                'start_date': str(data.index.min()),
                'end_date': str(data.index.max()),
                'frequency': self._infer_frequency(data.index),
                'basic_stats': {
                    'mean': float(data.mean()),
                    'std': float(data.std()),
                    'min': float(data.min()),
                    'max': float(data.max()),
                    'median': float(data.median())
                }
            }
            
            # Análisis de estacionariedad si statsmodels está disponible
            if STATSMODELS_AVAILABLE:
                # Test de Dickey-Fuller
                adf_result = adfuller(data.dropna())
                analysis['stationarity'] = {
                    'adf_statistic': float(adf_result[0]),
                    'p_value': float(adf_result[1]),
                    'is_stationary': adf_result[1] < 0.05,
                    'critical_values': {k: float(v) for k, v in adf_result[4].items()}
                }
            
            # Análisis de tendencia simple
            x = np.arange(len(data))
            y = data.values
            trend_slope = np.corrcoef(x, y)[0, 1] if len(data) > 1 else 0
            
            analysis['trend'] = {
                'has_trend': abs(trend_slope) > 0.1,
                'trend_direction': 'increasing' if trend_slope > 0 else 'decreasing',
                'trend_strength': abs(float(trend_slope))
            }
            
            # Análisis de estacionalidad simple
            seasonal_period = self._infer_seasonal_period(data)
            analysis['seasonality'] = {
                'detected_period': seasonal_period,
                'has_seasonality': seasonal_period is not None
            }
            
            # Análisis de missing values
            missing_analysis = {
                'total_missing': int(data.isnull().sum()),
                'missing_percentage': float(data.isnull().sum() / len(data) * 100),
                'consecutive_missing': self._find_max_consecutive_missing(data)
            }
            analysis['missing_data'] = missing_analysis
            
            return analysis
            
        except Exception as e:
            self.logger.error(f"Error analizando serie temporal: {str(e)}")
            return {}
    
    async def _preprocess_time_series(self, data: pd.Series, config: Dict[str, Any]) -> pd.Series:
        """Preprocesar serie temporal"""
        try:
            processed_data = data.copy()
            
            # Manejar valores faltantes
            missing_method = config.get('missing_method', 'interpolate')
            if missing_method == 'interpolate':
                processed_data = processed_data.interpolate(method='linear')
            elif missing_method == 'forward_fill':
                processed_data = processed_data.fillna(method='ffill')
            elif missing_method == 'backward_fill':
                processed_data = processed_data.fillna(method='bfill')
            elif missing_method == 'drop':
                processed_data = processed_data.dropna()
            
            # Remover outliers extremos si se especifica
            if config.get('remove_outliers', False):
                Q1 = processed_data.quantile(0.25)
                Q3 = processed_data.quantile(0.75)
                IQR = Q3 - Q1
                lower_bound = Q1 - 3 * IQR
                upper_bound = Q3 + 3 * IQR
                processed_data = processed_data.clip(lower_bound, upper_bound)
            
            # Escalado si se requiere
            if config.get('scale_data', False):
                self.current_scaler = StandardScaler()
                scaled_values = self.current_scaler.fit_transform(processed_data.values.reshape(-1, 1))
                processed_data = pd.Series(scaled_values.flatten(), index=processed_data.index)
            
            return processed_data
            
        except Exception as e:
            self.logger.error(f"Error preprocesando serie temporal: {str(e)}")
            raise
    
    async def _temporal_train_test_split(self, data: pd.Series, test_size: float) -> Tuple[pd.Series, pd.Series]:
        """División temporal manteniendo orden cronológico"""
        try:
            split_idx = int(len(data) * (1 - test_size))
            train_data = data.iloc[:split_idx]
            test_data = data.iloc[split_idx:]
            
            return train_data, test_data
            
        except Exception as e:
            self.logger.error(f"Error en división temporal: {str(e)}")
            raise
    
    async def _create_and_train_model(self, train_data: pd.Series, model_type: str, config: Dict[str, Any]):
        """Crear y entrenar modelo de series temporales"""
        try:
            if model_type in self.ts_models:
                model = self.ts_models[model_type](train_data, config)
                self.current_model = model
                return model
            else:
                raise ValueError(f"Tipo de modelo no soportado: {model_type}")
                
        except Exception as e:
            self.logger.error(f"Error creando/entrenando modelo: {str(e)}")
            raise
    
    def _create_arima_model(self, data: pd.Series, config: Dict[str, Any]):
        """Crear modelo ARIMA"""
        if not STATSMODELS_AVAILABLE:
            return self._create_linear_trend_model(data, config)
        
        # Parámetros ARIMA
        order = config.get('arima_order', (1, 1, 1))
        
        model = ARIMA(data, order=order)
        fitted_model = model.fit()
        
        return fitted_model
    
    def _create_seasonal_arima_model(self, data: pd.Series, config: Dict[str, Any]):
        """Crear modelo SARIMA"""
        if not STATSMODELS_AVAILABLE:
            return self._create_linear_trend_model(data, config)
        
        # Parámetros SARIMA
        order = config.get('arima_order', (1, 1, 1))
        seasonal_order = config.get('seasonal_order', (1, 1, 1, 12))
        
        from statsmodels.tsa.statespace.sarimax import SARIMAX
        model = SARIMAX(data, order=order, seasonal_order=seasonal_order)
        fitted_model = model.fit(disp=False)
        
        return fitted_model
    
    def _create_linear_trend_model(self, data: pd.Series, config: Dict[str, Any]):
        """Crear modelo de tendencia lineal simple"""
        # Modelo de regresión lineal con tiempo como feature
        X = np.arange(len(data)).reshape(-1, 1)
        y = data.values
        
        model = LinearRegression()
        model.fit(X, y)
        
        # Añadir información adicional
        model._data_length = len(data)
        model._last_value = data.iloc[-1]
        model._data_index = data.index
        
        return model
    
    def _create_moving_average_model(self, data: pd.Series, config: Dict[str, Any]):
        """Crear modelo de media móvil"""
        window = config.get('ma_window', min(12, len(data) // 4))
        
        class MovingAverageModel:
            def __init__(self, data, window):
                self.data = data
                self.window = window
                self.last_values = data.tail(window)
            
            def forecast(self, steps):
                # Predicción simple: última media móvil
                last_ma = self.last_values.mean()
                return np.full(steps, last_ma)
        
        return MovingAverageModel(data, window)
    
    async def _make_predictions(self, model, periods: int, config: Dict[str, Any]) -> np.ndarray:
        """Realizar predicciones con el modelo"""
        try:
            if hasattr(model, 'forecast'):
                # Modelos ARIMA/SARIMA
                forecast = model.forecast(steps=periods)
                return np.array(forecast)
            
            elif hasattr(model, 'predict') and hasattr(model, '_data_length'):
                # Modelo de regresión lineal
                start_idx = model._data_length
                future_X = np.arange(start_idx, start_idx + periods).reshape(-1, 1)
                predictions = model.predict(future_X)
                return predictions
            
            elif hasattr(model, 'forecast') and hasattr(model, 'data'):
                # Modelo de media móvil
                return model.forecast(periods)
            
            else:
                raise ValueError(f"Modelo {type(model)} no soporta predicción")
                
        except Exception as e:
            self.logger.error(f"Error realizando predicciones: {str(e)}")
            raise
    
    async def _calculate_time_series_metrics(self, actual: np.ndarray, predicted: np.ndarray, ts_analysis: Dict[str, Any]) -> Dict[str, Any]:
        """Calcular métricas específicas de series temporales"""
        try:
            # Métricas básicas
            mse = mean_squared_error(actual, predicted)
            mae = mean_absolute_error(actual, predicted)
            rmse = np.sqrt(mse)
            r2 = r2_score(actual, predicted)
            
            # MAPE (Mean Absolute Percentage Error)
            mape = np.mean(np.abs((actual - predicted) / actual)) * 100 if np.all(actual != 0) else float('inf')
            
            # Forecast Accuracy (1 - MAPE/100) para RF009.3
            forecast_accuracy = max(0, 1 - mape / 100) if mape != float('inf') else 0
            
            # Métricas direccionales
            actual_changes = np.diff(actual)
            predicted_changes = np.diff(predicted)
            directional_accuracy = np.mean(np.sign(actual_changes) == np.sign(predicted_changes)) if len(actual_changes) > 0 else 0
            
            metrics = {
                'mse': float(mse),
                'mae': float(mae),
                'rmse': float(rmse),
                'r2_score': float(r2),
                'mape': float(mape),
                'forecast_accuracy': float(forecast_accuracy),
                'directional_accuracy': float(directional_accuracy),
                'rf009_3_compliant': forecast_accuracy >= self.target_forecast_accuracy
            }
            
            return metrics
            
        except Exception as e:
            self.logger.error(f"Error calculando métricas: {str(e)}")
            raise
    
    async def _calculate_forecast_evaluation_metrics(self, actual: np.ndarray, forecast: np.ndarray) -> Dict[str, Any]:
        """Calcular métricas de evaluación de pronóstico"""
        try:
            metrics_calculator = await get_metrics_calculator()
            
            # Métricas de regresión básicas
            regression_metrics = await metrics_calculator.calculate_regression_metrics(actual, forecast)
            
            # Métricas específicas de pronóstico
            mape = np.mean(np.abs((actual - forecast) / actual)) * 100 if np.all(actual != 0) else float('inf')
            forecast_accuracy = max(0, 1 - mape / 100) if mape != float('inf') else 0
            
            # Combinar métricas
            all_metrics = {**regression_metrics}
            all_metrics.update({
                'mape': float(mape),
                'forecast_accuracy': float(forecast_accuracy),
                'rf009_3_compliant': forecast_accuracy >= self.target_forecast_accuracy
            })
            
            return all_metrics
            
        except Exception as e:
            self.logger.error(f"Error calculando métricas de evaluación: {str(e)}")
            raise
    
    async def _calculate_confidence_intervals(self, model, forecast_values: np.ndarray, periods: int) -> Dict[str, np.ndarray]:
        """Calcular intervalos de confianza para pronósticos"""
        try:
            if hasattr(model, 'get_forecast'):
                # Modelos ARIMA/SARIMA con intervalos nativos
                forecast_result = model.get_forecast(steps=periods)
                conf_int = forecast_result.conf_int()
                
                return {
                    'lower': conf_int.iloc[:, 0].values,
                    'upper': conf_int.iloc[:, 1].values,
                    'level': 0.95
                }
            else:
                # Intervalos simples basados en error histórico
                # (En producción se usaría un método más robusto)
                forecast_std = np.std(forecast_values) * 0.2  # Estimación simple
                
                return {
                    'lower': forecast_values - 1.96 * forecast_std,
                    'upper': forecast_values + 1.96 * forecast_std,
                    'level': 0.95
                }
                
        except Exception as e:
            self.logger.error(f"Error calculando intervalos de confianza: {str(e)}")
            # Fallback
            forecast_std = np.std(forecast_values) * 0.1
            return {
                'lower': forecast_values - forecast_std,
                'upper': forecast_values + forecast_std,
                'level': 0.95
            }
    
    def _infer_frequency(self, index: pd.DatetimeIndex) -> str:
        """Inferir frecuencia de la serie temporal"""
        try:
            if len(index) < 2:
                return 'H'  # Default hourly
            
            freq = pd.infer_freq(index)
            return freq if freq else 'H'
            
        except:
            return 'H'  # Default hourly
    
    def _infer_seasonal_period(self, data: pd.Series) -> Optional[int]:
        """Inferir período estacional"""
        try:
            # Basado en frecuencia de datos
            freq = self._infer_frequency(data.index)
            
            # Mapeo de frecuencias a períodos estacionales comunes
            seasonal_map = {
                'H': 24,   # Hourly -> Daily seasonality
                'D': 7,    # Daily -> Weekly seasonality
                'W': 52,   # Weekly -> Yearly seasonality
                'M': 12    # Monthly -> Yearly seasonality
            }
            
            return seasonal_map.get(freq, 24)  # Default to daily pattern
            
        except:
            return 24  # Default daily pattern
    
    def _find_max_consecutive_missing(self, data: pd.Series) -> int:
        """Encontrar máximo de valores faltantes consecutivos"""
        try:
            if not data.isnull().any():
                return 0
            
            # Encontrar secuencias de valores faltantes
            missing_mask = data.isnull()
            groups = missing_mask.ne(missing_mask.shift()).cumsum()
            consecutive_missing = missing_mask.groupby(groups).sum()
            
            return int(consecutive_missing.max()) if len(consecutive_missing) > 0 else 0
            
        except:
            return 0
    
    async def _simple_decomposition(self, data: pd.Series) -> Dict[str, Any]:
        """Descomposición simple sin statsmodels"""
        try:
            # Tendencia usando media móvil
            window = min(12, len(data) // 4)
            trend = data.rolling(window=window, center=True).mean()
            
            # Componente estacional simple
            detrended = data - trend
            period = self._infer_seasonal_period(data)
            seasonal = detrended.groupby(data.index.hour if hasattr(data.index, 'hour') else data.index % period).transform('mean')
            
            # Residuos
            residual = data - trend - seasonal
            
            components = {
                'trend': trend.dropna().to_dict(),
                'seasonal': seasonal.to_dict(),
                'residual': residual.dropna().to_dict(),
                'original': data.to_dict()
            }
            
            analysis = {
                'decomposition_model': 'simple_additive',
                'seasonal_period': period,
                'trend_strength': float(1 - np.var(residual.dropna()) / np.var(data.dropna())),
                'seasonal_strength': 0.5  # Estimación simple
            }
            
            return {
                'success': True,
                'components': components,
                'analysis': analysis,
                'note': 'Descomposición simplificada - instalar statsmodels para análisis completo'
            }
            
        except Exception as e:
            self.logger.error(f"Error en descomposición simple: {str(e)}")
            raise
    
    def _get_forecast_quality_level(self, accuracy: float) -> str:
        """Obtener nivel de calidad del pronóstico"""
        if accuracy >= 0.9:
            return "Excellent"
        elif accuracy >= 0.8:
            return "Good"
        elif accuracy >= 0.7:
            return "Acceptable"
        else:
            return "Poor"
    
    async def get_time_series_history(self) -> List[Dict[str, Any]]:
        """Obtener historial de modelos de series temporales"""
        return [
            {
                'timestamp': entry['timestamp'].isoformat(),
                'model_type': entry['model_type'],
                'forecast_accuracy': entry['forecast_accuracy'],
                'meets_rf009_3': entry['meets_rf009_3'],
                'model_id': entry['model_id']
            }
            for entry in self.ts_history
        ]
    
    async def get_best_model_info(self) -> Dict[str, Any]:
        """Obtener información del mejor modelo de series temporales"""
        try:
            if not self.ts_history:
                return {'message': 'No hay modelos de series temporales entrenados'}
            
            # Filtrar modelos que cumplen RF009.3
            compliant_models = [m for m in self.ts_history if m['meets_rf009_3']]
            
            if compliant_models:
                best_model = max(compliant_models, key=lambda x: x['forecast_accuracy'])
            else:
                best_model = max(self.ts_history, key=lambda x: x['forecast_accuracy'])
            
            return {
                'best_model_id': best_model['model_id'],
                'forecast_accuracy': best_model['forecast_accuracy'],
                'meets_rf009_3': best_model['meets_rf009_3'],
                'trained_at': best_model['timestamp'].isoformat(),
                'model_type': best_model['model_type']
            }
            
        except Exception as e:
            self.logger.error(f"Error obteniendo mejor modelo: {str(e)}")
            return {'error': str(e)}


# Instancia global
time_series_service = TimeSeriesMLService()

async def get_time_series_service() -> TimeSeriesMLService:
    """Obtener instancia del servicio de series temporales"""
    return time_series_service