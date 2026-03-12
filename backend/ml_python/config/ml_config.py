"""
Configuración ML - Sistema ACEES Group
Configuración centralizada para hiperparámetros, umbrales y parámetros ML
"""
import os
from typing import Dict, Any, List
from dataclasses import dataclass
from pathlib import Path

@dataclass
class MLConfig:
    """
    Configuración centralizada para sistema ML
    """
    
    # ======== CONFIGURACIÓN BASE ========
    ML_MODELS_PATH: str = os.getenv('ML_MODELS_PATH', './models/saved_models')
    MIN_DATA_MONTHS: int = int(os.getenv('MIN_DATA_MONTHS', '3'))
    LOG_LEVEL: str = os.getenv('LOG_LEVEL', 'INFO')
    ENVIRONMENT: str = os.getenv('ENVIRONMENT', 'development')
    
    # ======== CONFIGURACIÓN BD ========
    MONGODB_URI: str = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/acees_db')
    REDIS_URL: str = os.getenv('REDIS_URL', 'redis://localhost:6379')
    
    # ======== UMBRALES DE CALIDAD ========
    # User Stories requirements
    TARGET_R2_SCORE: float = float(os.getenv('TARGET_R2_SCORE', '0.7'))          # RF009.1
    TARGET_PEAK_ACCURACY: float = float(os.getenv('TARGET_PEAK_ACCURACY', '0.8'))  # US037
    TARGET_CLUSTERING_SILHOUETTE: float = float(os.getenv('TARGET_CLUSTERING_SILHOUETTE', '0.5'))  # RF009.2
    TARGET_TIMESERIES_ACCURACY: float = float(os.getenv('TARGET_TIMESERIES_ACCURACY', '0.75'))  # RF009.3
    
    # ======== CONFIGURACIÓN REGRESIÓN LINEAL (RF009.1) ========
    LINEAR_REGRESSION_CONFIG = {
        'learning_rate': float(os.getenv('LR_LEARNING_RATE', '0.01')),
        'max_iterations': int(os.getenv('LR_MAX_ITERATIONS', '1000')),
        'regularization': float(os.getenv('LR_REGULARIZATION', '0.1')),
        'tolerance': float(os.getenv('LR_TOLERANCE', '1e-6')),
        'feature_scaling': os.getenv('LR_FEATURE_SCALING', 'true').lower() == 'true',
        'target_r2': TARGET_R2_SCORE,
        'cv_folds': int(os.getenv('LR_CV_FOLDS', '5')),
        'test_size': float(os.getenv('LR_TEST_SIZE', '0.2'))
    }
    
    # ======== CONFIGURACIÓN CLUSTERING (RF009.2) ========
    CLUSTERING_CONFIG = {
        'algorithm': os.getenv('CLUSTERING_ALGORITHM', 'kmeans'),
        'min_k': int(os.getenv('CLUSTERING_MIN_K', '2')),
        'max_k': int(os.getenv('CLUSTERING_MAX_K', '10')),
        'target_silhouette': TARGET_CLUSTERING_SILHOUETTE,
        'max_iterations': int(os.getenv('CLUSTERING_MAX_ITER', '300')),
        'tolerance': float(os.getenv('CLUSTERING_TOLERANCE', '1e-4')),
        'n_init': int(os.getenv('CLUSTERING_N_INIT', '10')),
        'random_state': int(os.getenv('CLUSTERING_RANDOM_STATE', '42'))
    }
    
    # ======== CONFIGURACIÓN SERIES TEMPORALES (RF009.3) ========
    TIME_SERIES_CONFIG = {
        'seasonal_periods': [24, 168],  # 24h (diario), 168h (semanal)
        'target_accuracy': TARGET_TIMESERIES_ACCURACY,
        'forecast_horizon_hours': int(os.getenv('TS_FORECAST_HORIZON', '24')),
        'min_history_hours': int(os.getenv('TS_MIN_HISTORY', '720')),  # 30 días
        'trend': os.getenv('TS_TREND', 'add'),  # 'add', 'mul', None
        'seasonal': os.getenv('TS_SEASONAL', 'add'),
        'auto_arima_max_p': int(os.getenv('TS_MAX_P', '5')),
        'auto_arima_max_d': int(os.getenv('TS_MAX_D', '2')),
        'auto_arima_max_q': int(os.getenv('TS_MAX_Q', '5'))
    }
    
    # ======== CONFIGURACIÓN PREDICCIÓN HORARIOS PICO (US037) ========
    PEAK_HOURS_CONFIG = {
        'target_accuracy': TARGET_PEAK_ACCURACY,
        'prediction_horizon_hours': 24,  # 24h adelante como requiere US037
        'peak_threshold_percentile': float(os.getenv('PEAK_THRESHOLD_PERCENTILE', '80')),
        'business_hours_start': int(os.getenv('BUSINESS_HOURS_START', '7')),
        'business_hours_end': int(os.getenv('BUSINESS_HOURS_END', '18')),
        'weekend_adjustment_factor': float(os.getenv('WEEKEND_ADJUSTMENT', '0.6')),
        'exam_period_boost_factor': float(os.getenv('EXAM_BOOST_FACTOR', '1.3')),
        'holiday_reduction_factor': float(os.getenv('HOLIDAY_REDUCTION', '0.3'))
    }
    
    # ======== CONFIGURACIÓN OPTIMIZACIÓN BUSES (US038) ========
    BUS_OPTIMIZATION_CONFIG = {
        'min_frequency_minutes': int(os.getenv('BUS_MIN_FREQUENCY', '15')),
        'max_frequency_minutes': int(os.getenv('BUS_MAX_FREQUENCY', '60')),
        'capacity_per_bus': int(os.getenv('BUS_CAPACITY', '50')),
        'efficiency_threshold': float(os.getenv('BUS_EFFICIENCY_THRESHOLD', '0.7')),
        'peak_hours_boost': float(os.getenv('BUS_PEAK_BOOST', '1.5')),
        'off_peak_reduction': float(os.getenv('BUS_OFF_PEAK_REDUCTION', '0.5'))
    }
    
    # ======== CONFIGURACIÓN ALERTAS CONGESTIÓN (US038) ========
    CONGESTION_ALERTS_CONFIG = {
        'alert_threshold_low': float(os.getenv('CONGESTION_LOW_THRESHOLD', '0.6')),
        'alert_threshold_medium': float(os.getenv('CONGESTION_MEDIUM_THRESHOLD', '0.8')),
        'alert_threshold_high': float(os.getenv('CONGESTION_HIGH_THRESHOLD', '0.9')),
        'alert_advance_hours': int(os.getenv('CONGESTION_ALERT_ADVANCE', '2')),  # 2h anticipación
        'alert_channels': os.getenv('ALERT_CHANNELS', 'email,slack').split(','),
        'alert_frequency_minutes': int(os.getenv('ALERT_FREQUENCY', '30')),
        'escalation_threshold': float(os.getenv('ESCALATION_THRESHOLD', '0.95'))
    }
    
    # ======== CONFIGURACIÓN ANÁLISIS PATRONES (US036) ========
    PATTERN_ANALYSIS_CONFIG = {
        'time_windows': ['1H', '4H', '1D', '1W'],  # Ventanas de análisis
        'trend_detection_window': int(os.getenv('TREND_WINDOW_DAYS', '30')),
        'anomaly_detection_threshold': float(os.getenv('ANOMALY_THRESHOLD', '2.5')),  # Z-score
        'seasonal_decomposition': os.getenv('SEASONAL_DECOMP', 'true').lower() == 'true',
        'min_pattern_confidence': float(os.getenv('MIN_PATTERN_CONFIDENCE', '0.7'))
    }
    
    # ======== CONFIGURACIÓN ETL DATOS (US030) ========
    DATA_ETL_CONFIG = {
        'batch_size': int(os.getenv('ETL_BATCH_SIZE', '10000')),
        'max_null_percentage': float(os.getenv('ETL_MAX_NULL_PCT', '0.8')),
        'min_data_quality_score': float(os.getenv('ETL_MIN_QUALITY', '0.7')),
        'duplicate_threshold': float(os.getenv('ETL_DUPLICATE_THRESHOLD', '0.1')),
        'outlier_detection_method': os.getenv('ETL_OUTLIER_METHOD', 'iqr'),  # 'iqr', 'zscore'
        'feature_correlation_threshold': float(os.getenv('ETL_CORRELATION_THRESHOLD', '0.95'))
    }
    
    # ======== CONFIGURACIÓN ENTRENAMIENTO AUTOMÁTICO (RF009.4, RF009.5) ========
    AUTO_TRAINING_CONFIG = {
        'weekly_retrain': os.getenv('WEEKLY_RETRAIN', 'true').lower() == 'true',
        'retrain_day': os.getenv('RETRAIN_DAY', 'sunday'),  # día de la semana
        'retrain_hour': int(os.getenv('RETRAIN_HOUR', '2')),  # hora del día
        'performance_degradation_threshold': float(os.getenv('PERF_DEGRADATION_THRESHOLD', '0.05')),
        'model_drift_threshold': float(os.getenv('MODEL_DRIFT_THRESHOLD', '0.1')),
        'backup_models_count': int(os.getenv('BACKUP_MODELS_COUNT', '5')),
        'notification_channels': os.getenv('NOTIFICATION_CHANNELS', 'email,slack').split(',')
    }
    
    # ======== CONFIGURACIÓN VALIDACIÓN CRUZADA ========
    CROSS_VALIDATION_CONFIG = {
        'cv_folds': int(os.getenv('CV_FOLDS', '5')),
        'cv_scoring': os.getenv('CV_SCORING', 'r2'),  # r2, mse, mae para regresión
        'cv_shuffle': os.getenv('CV_SHUFFLE', 'true').lower() == 'true',
        'cv_random_state': int(os.getenv('CV_RANDOM_STATE', '42'))
    }
    
    # ======== CONFIGURACIÓN OPTIMIZACIÓN HIPERPARÁMETROS ========
    HYPERPARAMETER_TUNING_CONFIG = {
        'tuning_method': os.getenv('TUNING_METHOD', 'optuna'),  # 'optuna', 'grid', 'random'
        'n_trials': int(os.getenv('TUNING_N_TRIALS', '100')),
        'optimization_direction': os.getenv('TUNING_DIRECTION', 'maximize'),  # maximize, minimize
        'pruning_enabled': os.getenv('TUNING_PRUNING', 'true').lower() == 'true',
        'parallel_jobs': int(os.getenv('TUNING_PARALLEL_JOBS', '-1')),
        'timeout_seconds': int(os.getenv('TUNING_TIMEOUT', '3600'))  # 1 hora
    }
    
    # ======== CONFIGURACIÓN MONITOREO PERFORMANCE ========
    MONITORING_CONFIG = {
        'metrics_collection_interval_seconds': int(os.getenv('METRICS_INTERVAL', '60')),
        'alert_on_degradation': os.getenv('ALERT_ON_DEGRADATION', 'true').lower() == 'true',
        'performance_history_days': int(os.getenv('PERF_HISTORY_DAYS', '30')),
        'model_drift_check_frequency': os.getenv('DRIFT_CHECK_FREQUENCY', 'daily'),
        'resource_usage_alerts': os.getenv('RESOURCE_ALERTS', 'true').lower() == 'true'
    }
    
    # ======== CONFIGURACIÓN API ========
    API_CONFIG = {
        'host': os.getenv('HOST', '0.0.0.0'),
        'port': int(os.getenv('PORT', '8000')),
        'reload': ENVIRONMENT == 'development',
        'cors_origins': os.getenv('CORS_ORIGINS', '*').split(','),
        'rate_limit_requests': int(os.getenv('RATE_LIMIT_REQUESTS', '100')),
        'rate_limit_window_seconds': int(os.getenv('RATE_LIMIT_WINDOW', '60')),
        'request_timeout_seconds': int(os.getenv('REQUEST_TIMEOUT', '30'))
    }
    
    # ======== CONFIGURACIÓN CACHE ========
    CACHE_CONFIG = {
        'default_ttl_seconds': int(os.getenv('CACHE_DEFAULT_TTL', '300')),  # 5 minutos
        'model_cache_ttl_seconds': int(os.getenv('CACHE_MODEL_TTL', '3600')),  # 1 hora
        'prediction_cache_ttl_seconds': int(os.getenv('CACHE_PREDICTION_TTL', '600')),  # 10 minutos
        'max_cache_size_mb': int(os.getenv('CACHE_MAX_SIZE_MB', '500'))
    }
    
    # ======== CONFIGURACIÓN TESTING ========
    TESTING_CONFIG = {
        'test_data_size': int(os.getenv('TEST_DATA_SIZE', '1000')),
        'test_coverage_threshold': float(os.getenv('TEST_COVERAGE_THRESHOLD', '0.8')),
        'performance_test_iterations': int(os.getenv('PERF_TEST_ITERATIONS', '10')),
        'integration_test_timeout': int(os.getenv('INTEGRATION_TEST_TIMEOUT', '60'))
    }
    
    def __post_init__(self):
        """Validaciones y configuraciones adicionales post-inicialización"""
        # Crear directorios necesarios
        Path(self.ML_MODELS_PATH).mkdir(parents=True, exist_ok=True)
        
        # Validar configuraciones críticas
        self._validate_config()
    
    def _validate_config(self):
        """Validar configuraciones críticas"""
        errors = []
        
        # Validar umbrales de calidad
        if not 0 < self.TARGET_R2_SCORE <= 1:
            errors.append(f"TARGET_R2_SCORE debe estar en (0, 1], actual: {self.TARGET_R2_SCORE}")
        
        if not 0 < self.TARGET_PEAK_ACCURACY <= 1:
            errors.append(f"TARGET_PEAK_ACCURACY debe estar en (0, 1], actual: {self.TARGET_PEAK_ACCURACY}")
        
        if not 0 < self.TARGET_CLUSTERING_SILHOUETTE <= 1:
            errors.append(f"TARGET_CLUSTERING_SILHOUETTE debe estar en (0, 1], actual: {self.TARGET_CLUSTERING_SILHOUETTE}")
        
        # Validar configuraciones ML
        if self.LINEAR_REGRESSION_CONFIG['learning_rate'] <= 0:
            errors.append("Learning rate debe ser positivo")
        
        if self.CLUSTERING_CONFIG['min_k'] >= self.CLUSTERING_CONFIG['max_k']:
            errors.append("min_k debe ser menor que max_k en clustering")
        
        # Validar configuración API
        if not 1024 <= self.API_CONFIG['port'] <= 65535:
            errors.append(f"Puerto API inválido: {self.API_CONFIG['port']}")
        
        if errors:
            raise ValueError(f"Errores de configuración ML: {'; '.join(errors)}")
    
    def get_config_summary(self) -> Dict[str, Any]:
        """Obtener resumen de configuración actual"""
        return {
            'environment': self.ENVIRONMENT,
            'models_path': self.ML_MODELS_PATH,
            'mongodb_configured': bool(self.MONGODB_URI),
            'redis_configured': bool(self.REDIS_URL),
            'quality_thresholds': {
                'r2_score': self.TARGET_R2_SCORE,
                'peak_accuracy': self.TARGET_PEAK_ACCURACY,
                'clustering_silhouette': self.TARGET_CLUSTERING_SILHOUETTE,
                'timeseries_accuracy': self.TARGET_TIMESERIES_ACCURACY
            },
            'auto_training_enabled': self.AUTO_TRAINING_CONFIG['weekly_retrain'],
            'api_port': self.API_CONFIG['port'],
            'log_level': self.LOG_LEVEL
        }
    
    def update_config_from_dict(self, updates: Dict[str, Any]):
        """Actualizar configuración desde diccionario"""
        for key, value in updates.items():
            if hasattr(self, key):
                setattr(self, key, value)
            else:
                # Intentar actualizar en sub-configs
                for config_name in ['LINEAR_REGRESSION_CONFIG', 'CLUSTERING_CONFIG', 
                                   'TIME_SERIES_CONFIG', 'PEAK_HOURS_CONFIG']:
                    if hasattr(self, config_name):
                        config = getattr(self, config_name)
                        if key in config:
                            config[key] = value
                            break
        
        # Re-validar después de actualización
        self._validate_config()
    
    @classmethod
    def from_file(cls, config_file: str) -> 'MLConfig':
        """Cargar configuración desde archivo JSON/YAML"""
        import json
        
        with open(config_file, 'r') as f:
            if config_file.endswith('.json'):
                config_data = json.load(f)
            else:
                # YAML support futuro
                raise NotImplementedError("YAML support not implemented yet")
        
        instance = cls()
        instance.update_config_from_dict(config_data)
        return instance


# Instancia global de configuración
ml_config = MLConfig()

# Funciones de utilidad para acceso rápido
def get_ml_config() -> MLConfig:
    """Obtener instancia de configuración ML"""
    return ml_config

def get_model_config(model_type: str) -> Dict[str, Any]:
    """Obtener configuración específica de modelo"""
    config_mapping = {
        'linear_regression': ml_config.LINEAR_REGRESSION_CONFIG,
        'clustering': ml_config.CLUSTERING_CONFIG,
        'time_series': ml_config.TIME_SERIES_CONFIG,
        'peak_hours': ml_config.PEAK_HOURS_CONFIG,
        'bus_optimization': ml_config.BUS_OPTIMIZATION_CONFIG,
        'congestion_alerts': ml_config.CONGESTION_ALERTS_CONFIG,
        'pattern_analysis': ml_config.PATTERN_ANALYSIS_CONFIG
    }
    
    return config_mapping.get(model_type, {})

def get_quality_thresholds() -> Dict[str, float]:
    """Obtener umbrales de calidad definidos en User Stories"""
    return {
        'r2_score_threshold': ml_config.TARGET_R2_SCORE,
        'peak_accuracy_threshold': ml_config.TARGET_PEAK_ACCURACY,
        'clustering_silhouette_threshold': ml_config.TARGET_CLUSTERING_SILHOUETTE,
        'timeseries_accuracy_threshold': ml_config.TARGET_TIMESERIES_ACCURACY
    }