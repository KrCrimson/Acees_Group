"""
Configuración de Logging - Sistema ACEES Group
Configuración centralizada de logging para sistema ML
"""
import os
import logging
import logging.handlers
from typing import Dict, Any, Optional
from pathlib import Path
import json
from datetime import datetime

class MLLoggingConfig:
    """
    Configuración centralizada de logging para ML
    """
    
    def __init__(self):
        # ======== CONFIGURACIÓN BÁSICA ========
        self.LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO').upper()
        self.ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')
        self.LOG_DIR = Path(os.getenv('LOG_DIR', './logs'))
        
        # ======== CONFIGURACIÓN DE ARCHIVOS LOG ========
        self.LOG_FILES = {
            'main': self.LOG_DIR / 'ml_system.log',
            'training': self.LOG_DIR / 'training.log', 
            'prediction': self.LOG_DIR / 'prediction.log',
            'api': self.LOG_DIR / 'api.log',
            'error': self.LOG_DIR / 'error.log',
            'performance': self.LOG_DIR / 'performance.log',
            'audit': self.LOG_DIR / 'audit.log'
        }
        
        # ======== CONFIGURACIÓN ROTATIVO ========
        self.ROTATION_CONFIG = {
            'max_bytes': int(os.getenv('LOG_MAX_BYTES', '10485760')),  # 10 MB
            'backup_count': int(os.getenv('LOG_BACKUP_COUNT', '5')),
            'when': os.getenv('LOG_ROTATION_WHEN', 'midnight'),
            'interval': int(os.getenv('LOG_ROTATION_INTERVAL', '1'))
        }
        
        # ======== FORMATOS DE LOG ========
        self.LOG_FORMATS = {
            'detailed': '[{asctime}] {levelname:<8} [{name}] {filename}:{lineno} - {message}',
            'simple': '[{asctime}] {levelname} - {message}',
            'json': None,  # Se manejará con JSONFormatter personalizado
            'console': '{levelname:<8} | {name:<20} | {message}'
        }
        
        # ======== CONFIGURACIÓN POR LOGGER ========
        self.LOGGER_CONFIG = {
            'ml.training': {
                'level': 'INFO',
                'file': 'training',
                'console': True,
                'format': 'detailed'
            },
            'ml.prediction': {
                'level': 'INFO', 
                'file': 'prediction',
                'console': self.ENVIRONMENT == 'development',
                'format': 'detailed'
            },
            'ml.api': {
                'level': 'INFO',
                'file': 'api',
                'console': self.ENVIRONMENT == 'development',
                'format': 'simple'
            },
            'ml.performance': {
                'level': 'DEBUG' if self.ENVIRONMENT == 'development' else 'INFO',
                'file': 'performance',
                'console': False,
                'format': 'json'
            },
            'ml.error': {
                'level': 'ERROR',
                'file': 'error',
                'console': True,
                'format': 'detailed'
            },
            'ml.audit': {
                'level': 'INFO',
                'file': 'audit',
                'console': False,
                'format': 'json'
            }
        }
        
        # ======== CONFIGURACIÓN ESPECIAL ========
        self.STRUCTURED_LOGGING = os.getenv('STRUCTURED_LOGGING', 'false').lower() == 'true'
        self.LOG_TO_EXTERNAL = os.getenv('LOG_TO_EXTERNAL', 'false').lower() == 'true'
        self.EXTERNAL_LOG_URL = os.getenv('EXTERNAL_LOG_URL', '')
        self.CORRELATION_ID_HEADER = os.getenv('CORRELATION_ID_HEADER', 'X-Correlation-ID')
        
        # Crear directorios
        self._ensure_directories()
        
        # Configurar logging
        self._setup_logging()
    
    def _ensure_directories(self):
        """Crear directorios de logs si no existen"""
        self.LOG_DIR.mkdir(parents=True, exist_ok=True)
        
        # Crear subdirectorios si es necesario
        for log_type in ['archived', 'temp']:
            (self.LOG_DIR / log_type).mkdir(exist_ok=True)
    
    def _setup_logging(self):
        """Configurar sistema de logging"""
        # Configuración root logger
        root_logger = logging.getLogger()
        root_logger.setLevel(logging.DEBUG)
        
        # Limpiar handlers existentes
        for handler in root_logger.handlers[:]:
            root_logger.removeHandler(handler)
        
        # Configurar cada logger específico
        for logger_name, config in self.LOGGER_CONFIG.items():
            self._setup_logger(logger_name, config)
        
        # Configurar logger principal del sistema
        self._setup_main_logger()
        
        # Configurar logging de terceros
        self._configure_third_party_logging()
    
    def _setup_logger(self, logger_name: str, config: Dict[str, Any]):
        """Configurar logger específico"""
        logger = logging.getLogger(logger_name)
        logger.setLevel(getattr(logging, config['level']))
        
        # Limpiar handlers existentes
        for handler in logger.handlers[:]:
            logger.removeHandler(handler)
        
        # Handler de archivo
        if config.get('file'):
            log_file = self.LOG_FILES[config['file']]
            file_handler = self._create_file_handler(log_file)
            file_handler.setFormatter(self._get_formatter(config.get('format', 'detailed')))
            logger.addHandler(file_handler)
        
        # Handler de consola
        if config.get('console', False):
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(self._get_formatter('console'))
            console_handler.setLevel(getattr(logging, config['level']))
            logger.addHandler(console_handler)
        
        # No propagar al logger padre para evitar duplicados
        logger.propagate = False
    
    def _setup_main_logger(self):
        """Configurar logger principal"""
        main_logger = logging.getLogger('ml')
        main_logger.setLevel(getattr(logging, self.LOG_LEVEL))
        
        # Handler archivo principal
        main_file_handler = self._create_file_handler(self.LOG_FILES['main'])
        main_file_handler.setFormatter(self._get_formatter('detailed'))
        main_logger.addHandler(main_file_handler)
        
        # Handler consola para desarrollo
        if self.ENVIRONMENT == 'development':
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(self._get_formatter('console'))
            main_logger.addHandler(console_handler)
        
        # Handler para errores críticos
        error_handler = self._create_file_handler(self.LOG_FILES['error'])
        error_handler.setLevel(logging.ERROR)
        error_handler.setFormatter(self._get_formatter('detailed'))
        main_logger.addHandler(error_handler)
    
    def _create_file_handler(self, log_file: Path) -> logging.Handler:
        """Crear handler de archivo con rotación"""
        if self.ROTATION_CONFIG['when'] == 'size':
            handler = logging.handlers.RotatingFileHandler(
                log_file,
                maxBytes=self.ROTATION_CONFIG['max_bytes'],
                backupCount=self.ROTATION_CONFIG['backup_count'],
                encoding='utf-8'
            )
        else:
            handler = logging.handlers.TimedRotatingFileHandler(
                log_file,
                when=self.ROTATION_CONFIG['when'],
                interval=self.ROTATION_CONFIG['interval'],
                backupCount=self.ROTATION_CONFIG['backup_count'],
                encoding='utf-8'
            )
            # Sufijo para archivos rotados
            handler.suffix = "%Y-%m-%d"
        
        return handler
    
    def _get_formatter(self, format_type: str) -> logging.Formatter:
        """Obtener formateador según tipo"""
        if format_type == 'json':
            return JSONFormatter()
        else:
            format_string = self.LOG_FORMATS.get(format_type, self.LOG_FORMATS['detailed'])
            return logging.Formatter(
                format_string,
                style='{',
                datefmt='%Y-%m-%d %H:%M:%S'
            )
    
    def _configure_third_party_logging(self):
        """Configurar logging de librerías de terceros"""
        # Reducir verbosidad de librerías externas
        third_party_loggers = {
            'urllib3.connectionpool': logging.WARNING,
            'pymongo': logging.WARNING,
            'httpx': logging.WARNING,
            'uvicorn.access': logging.WARNING if self.ENVIRONMENT == 'production' else logging.INFO,
            'fastapi': logging.INFO,
            'celery': logging.INFO,
            'sklearn': logging.WARNING,
        }
        
        for logger_name, level in third_party_loggers.items():
            logger = logging.getLogger(logger_name)
            logger.setLevel(level)
    
    def get_logger(self, name: str) -> logging.Logger:
        """Obtener logger configurado"""
        # Asegurar que el nombre empiece con 'ml.'
        if not name.startswith('ml.'):
            name = f'ml.{name}'
        
        return logging.getLogger(name)
    
    def log_training_start(self, model_type: str, data_shape: tuple, **kwargs):
        """Log especializado para inicio de entrenamiento"""
        logger = self.get_logger('training')
        logger.info(f"TRAINING_START - Model: {model_type}, Data: {data_shape}, Params: {kwargs}")
        
        # Log estructurado si está habilitado
        if self.STRUCTURED_LOGGING:
            self.log_structured('training_start', {
                'model_type': model_type,
                'data_shape': data_shape,
                'parameters': kwargs,
                'timestamp': datetime.now().isoformat()
            })
    
    def log_training_end(self, model_type: str, metrics: Dict[str, Any], duration: float):
        """Log especializado para fin de entrenamiento"""
        logger = self.get_logger('training')
        logger.info(f"TRAINING_END - Model: {model_type}, Duration: {duration:.2f}s, Metrics: {metrics}")
        
        if self.STRUCTURED_LOGGING:
            self.log_structured('training_end', {
                'model_type': model_type,
                'duration_seconds': duration,
                'metrics': metrics,
                'timestamp': datetime.now().isoformat()
            })
    
    def log_prediction_request(self, model_type: str, input_size: int, user_id: str = None):
        """Log especializado para requests de predicción"""
        logger = self.get_logger('prediction')
        logger.info(f"PREDICTION_REQUEST - Model: {model_type}, Input size: {input_size}, User: {user_id}")
        
        if self.STRUCTURED_LOGGING:
            self.log_structured('prediction_request', {
                'model_type': model_type,
                'input_size': input_size,
                'user_id': user_id,
                'timestamp': datetime.now().isoformat()
            })
    
    def log_performance_metrics(self, operation: str, duration: float, **metrics):
        """Log especializado para métricas de performance"""
        logger = self.get_logger('performance')
        logger.debug(f"PERFORMANCE - Operation: {operation}, Duration: {duration:.3f}s, Metrics: {metrics}")
        
        if self.STRUCTURED_LOGGING:
            self.log_structured('performance_metric', {
                'operation': operation,
                'duration_seconds': duration,
                'metrics': metrics,
                'timestamp': datetime.now().isoformat()
            })
    
    def log_error_with_context(self, error: Exception, context: Dict[str, Any]):
        """Log especializado para errores con contexto"""
        logger = self.get_logger('error')
        logger.error(f"ERROR - {type(error).__name__}: {str(error)}, Context: {context}", exc_info=True)
        
        if self.STRUCTURED_LOGGING:
            self.log_structured('error', {
                'error_type': type(error).__name__,
                'error_message': str(error),
                'context': context,
                'timestamp': datetime.now().isoformat()
            })
    
    def log_audit_event(self, event_type: str, user_id: str, details: Dict[str, Any]):
        """Log especializado para auditoría"""
        logger = self.get_logger('audit')
        logger.info(f"AUDIT - Event: {event_type}, User: {user_id}, Details: {details}")
        
        if self.STRUCTURED_LOGGING:
            self.log_structured('audit_event', {
                'event_type': event_type,
                'user_id': user_id,
                'details': details,
                'timestamp': datetime.now().isoformat()
            })
    
    def log_structured(self, event_type: str, data: Dict[str, Any]):
        """Log estructurado en formato JSON"""
        structured_logger = logging.getLogger('ml.structured')
        
        if not structured_logger.handlers:
            # Configurar handler para logs estructurados
            structured_file = self.LOG_DIR / 'structured.log'
            handler = self._create_file_handler(structured_file)
            handler.setFormatter(JSONFormatter())
            structured_logger.addHandler(handler)
            structured_logger.setLevel(logging.INFO)
            structured_logger.propagate = False
        
        log_data = {
            'event_type': event_type,
            'data': data,
            'timestamp': datetime.now().isoformat(),
            'environment': self.ENVIRONMENT
        }
        
        structured_logger.info(log_data)
    
    def cleanup_old_logs(self, days_to_keep: int = 30):
        """Limpiar logs antiguos"""
        import glob
        from datetime import timedelta
        
        cutoff_date = datetime.now() - timedelta(days=days_to_keep)
        
        for log_file in self.LOG_FILES.values():
            # Buscar archivos rotados
            pattern = f"{log_file}.*"
            old_files = glob.glob(str(pattern))
            
            for old_file in old_files:
                try:
                    file_path = Path(old_file)
                    if file_path.stat().st_mtime < cutoff_date.timestamp():
                        file_path.unlink()
                        print(f"Log eliminado: {old_file}")
                except Exception as e:
                    print(f"Error eliminando {old_file}: {str(e)}")
    
    def get_logging_status(self) -> Dict[str, Any]:
        """Obtener estado del sistema de logging"""
        return {
            'log_level': self.LOG_LEVEL,
            'environment': self.ENVIRONMENT,
            'log_directory': str(self.LOG_DIR),
            'structured_logging': self.STRUCTURED_LOGGING,
            'external_logging': self.LOG_TO_EXTERNAL,
            'configured_loggers': list(self.LOGGER_CONFIG.keys()),
            'log_files': {k: str(v) for k, v in self.LOG_FILES.items()},
            'rotation_config': self.ROTATION_CONFIG
        }


class JSONFormatter(logging.Formatter):
    """
    Formateador JSON personalizado para logging estructurado
    """
    
    def format(self, record):
        log_entry = {
            'timestamp': datetime.fromtimestamp(record.created).isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno
        }
        
        # Agregar información de excepción si existe
        if record.exc_info:
            log_entry['exception'] = self.formatException(record.exc_info)
        
        # Agregar campos adicionales si existen
        for key, value in record.__dict__.items():
            if key not in ['name', 'msg', 'args', 'levelname', 'levelno', 
                          'pathname', 'filename', 'module', 'lineno', 
                          'funcName', 'created', 'msecs', 'relativeCreated', 
                          'thread', 'threadName', 'processName', 'process',
                          'message', 'exc_info', 'exc_text', 'stack_info']:
                log_entry[key] = value
        
        return json.dumps(log_entry, default=str, ensure_ascii=False)


# Instancia global de configuración logging
logging_config = MLLoggingConfig()

def get_ml_logger(name: str) -> logging.Logger:
    """Obtener logger ML configurado"""
    return logging_config.get_logger(name)

def log_training_event(event_type: str, model_type: str, **data):
    """Función de utilidad para logging de entrenamiento"""
    if event_type == 'start':
        logging_config.log_training_start(model_type, **data)
    elif event_type == 'end':
        logging_config.log_training_end(model_type, **data)

def log_performance(operation: str, duration: float, **metrics):
    """Función de utilidad para logging de performance"""
    logging_config.log_performance_metrics(operation, duration, **metrics)

def log_ml_error(error: Exception, **context):
    """Función de utilidad para logging de errores ML"""
    logging_config.log_error_with_context(error, context)