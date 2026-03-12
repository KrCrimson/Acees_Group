"""
Configuración Base de Datos - Sistema ACEES Group
Configuración para MongoDB y Redis
"""
import os
from typing import Dict, Any, Optional
from urllib.parse import urlparse
import logging

logger = logging.getLogger("ml.database_config")

class DatabaseConfig:
    """
    Configuración centralizada para bases de datos
    """
    
    def __init__(self):
        # ======== CONFIGURACIÓN MONGODB ========
        self.MONGODB_URI = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/acees_db')
        self.MONGODB_DATABASE = os.getenv('MONGODB_DATABASE', 'acees_db')
        self.MONGODB_TIMEOUT_MS = int(os.getenv('MONGODB_TIMEOUT_MS', '30000'))
        self.MONGODB_MAX_POOL_SIZE = int(os.getenv('MONGODB_MAX_POOL_SIZE', '10'))
        self.MONGODB_MIN_POOL_SIZE = int(os.getenv('MONGODB_MIN_POOL_SIZE', '1'))
        
        # Collections específicas
        self.COLLECTIONS = {
            'asistencias': os.getenv('COLLECTION_ASISTENCIAS', 'asistencias'),
            'usuarios': os.getenv('COLLECTION_USUARIOS', 'usuarios'),
            'fotos': os.getenv('COLLECTION_FOTOS', 'fotos'),
            'ml_metrics': os.getenv('COLLECTION_ML_METRICS', 'ml_metrics'),
            'model_versions': os.getenv('COLLECTION_MODEL_VERSIONS', 'model_versions'),
            'training_logs': os.getenv('COLLECTION_TRAINING_LOGS', 'training_logs'),
            'predictions_history': os.getenv('COLLECTION_PREDICTIONS', 'predictions_history'),
            'alerts_history': os.getenv('COLLECTION_ALERTS', 'alerts_history')
        }
        
        # ======== CONFIGURACIÓN REDIS ========
        self.REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
        self.REDIS_DB = int(os.getenv('REDIS_DB', '0'))
        self.REDIS_MAX_CONNECTIONS = int(os.getenv('REDIS_MAX_CONNECTIONS', '20'))
        self.REDIS_TIMEOUT_SECONDS = int(os.getenv('REDIS_TIMEOUT_SECONDS', '5'))
        
        # Redis key patterns
        self.REDIS_KEY_PATTERNS = {
            'model_cache': 'ml:model:{}:{}',  # ml:model:service_name:version
            'prediction_cache': 'ml:prediction:{}:{}',  # ml:prediction:model_type:hash
            'metrics_cache': 'ml:metrics:{}',  # ml:metrics:timestamp
            'rate_limit': 'ml:rate_limit:{}:{}',  # ml:rate_limit:endpoint:client_ip
            'session': 'ml:session:{}',  # ml:session:session_id
            'training_status': 'ml:training:{}',  # ml:training:job_id
        }
        
        # TTL por tipo de cache (en segundos)
        self.REDIS_TTL = {
            'model_cache': int(os.getenv('REDIS_MODEL_TTL', '3600')),  # 1 hora
            'prediction_cache': int(os.getenv('REDIS_PREDICTION_TTL', '600')),  # 10 minutos
            'metrics_cache': int(os.getenv('REDIS_METRICS_TTL', '1800')),  # 30 minutos
            'rate_limit': int(os.getenv('REDIS_RATE_LIMIT_TTL', '60')),  # 1 minuto
            'session': int(os.getenv('REDIS_SESSION_TTL', '86400')),  # 24 horas
            'training_status': int(os.getenv('REDIS_TRAINING_TTL', '7200'))  # 2 horas
        }
        
        # ======== CONFIGURACIÓN CONSULTAS ========
        self.QUERY_CONFIG = {
            'default_limit': int(os.getenv('QUERY_DEFAULT_LIMIT', '1000')),
            'max_limit': int(os.getenv('QUERY_MAX_LIMIT', '10000')),
            'timeout_seconds': int(os.getenv('QUERY_TIMEOUT_SECONDS', '60')),
            'batch_size': int(os.getenv('QUERY_BATCH_SIZE', '1000'))
        }
        
        # ======== CONFIGURACIÓN ÍNDICES MONGODB ========
        self.INDEXES = {
            'asistencias': [
                {'fields': [('fechaHora', 1)], 'background': True},
                {'fields': [('usuarioId', 1), ('fechaHora', -1)], 'background': True},
                {'fields': [('estado', 1), ('fechaHora', -1)], 'background': True},
                {'fields': [('fechaHora', 1), ('tipoAcceso', 1)], 'background': True}
            ],
            'usuarios': [
                {'fields': [('email', 1)], 'unique': True, 'background': True},
                {'fields': [('estado', 1)], 'background': True}
            ],
            'ml_metrics': [
                {'fields': [('timestamp', -1)], 'background': True},
                {'fields': [('model_type', 1), ('timestamp', -1)], 'background': True},
                {'fields': [('version', 1)], 'background': True}
            ],
            'predictions_history': [
                {'fields': [('timestamp', -1)], 'expireAfterSeconds': 2592000},  # 30 días
                {'fields': [('model_type', 1), ('timestamp', -1)], 'background': True}
            ],
            'alerts_history': [
                {'fields': [('timestamp', -1)], 'expireAfterSeconds': 7776000},  # 90 días
                {'fields': [('alert_type', 1), ('timestamp', -1)], 'background': True},
                {'fields': [('status', 1)], 'background': True}
            ]
        }
        
        # Validar configuración al inicializar
        self._validate_config()
    
    def _validate_config(self):
        """Validar configuraciones de BD"""
        errors = []
        
        # Validar MongoDB URI
        try:
            parsed_uri = urlparse(self.MONGODB_URI)
            if not parsed_uri.scheme or parsed_uri.scheme not in ['mongodb', 'mongodb+srv']:
                errors.append(f"MongoDB URI inválido: {self.MONGODB_URI}")
        except Exception as e:
            errors.append(f"Error parseando MongoDB URI: {str(e)}")
        
        # Validar Redis URL
        try:
            parsed_redis = urlparse(self.REDIS_URL)
            if not parsed_redis.scheme or parsed_redis.scheme != 'redis':
                errors.append(f"Redis URL inválido: {self.REDIS_URL}")
        except Exception as e:
            errors.append(f"Error parseando Redis URL: {str(e)}")
        
        # Validar configuraciones numéricas
        if self.MONGODB_TIMEOUT_MS <= 0:
            errors.append("MongoDB timeout debe ser positivo")
        
        if self.MONGODB_MAX_POOL_SIZE <= 0:
            errors.append("MongoDB max pool size debe ser positivo")
        
        if self.REDIS_MAX_CONNECTIONS <= 0:
            errors.append("Redis max connections debe ser positivo")
        
        if errors:
            logger.error(f"Errores de configuración BD: {'; '.join(errors)}")
            raise ValueError(f"Configuración BD inválida: {'; '.join(errors)}")
    
    def get_mongodb_connection_params(self) -> Dict[str, Any]:
        """Obtener parámetros de conexión MongoDB"""
        return {
            'uri': self.MONGODB_URI,
            'database': self.MONGODB_DATABASE,
            'serverSelectionTimeoutMS': self.MONGODB_TIMEOUT_MS,
            'maxPoolSize': self.MONGODB_MAX_POOL_SIZE,
            'minPoolSize': self.MONGODB_MIN_POOL_SIZE,
            'retryWrites': True,
            'w': 'majority'
        }
    
    def get_redis_connection_params(self) -> Dict[str, Any]:
        """Obtener parámetros de conexión Redis"""
        parsed_url = urlparse(self.REDIS_URL)
        
        return {
            'host': parsed_url.hostname or 'localhost',
            'port': parsed_url.port or 6379,
            'db': self.REDIS_DB,
            'password': parsed_url.password,
            'max_connections': self.REDIS_MAX_CONNECTIONS,
            'socket_timeout': self.REDIS_TIMEOUT_SECONDS,
            'socket_connect_timeout': self.REDIS_TIMEOUT_SECONDS,
            'decode_responses': True
        }
    
    def get_collection_name(self, collection_key: str) -> str:
        """Obtener nombre real de colección"""
        return self.COLLECTIONS.get(collection_key, collection_key)
    
    def get_redis_key(self, pattern_key: str, *args) -> str:
        """Generar clave Redis según patrón"""
        pattern = self.REDIS_KEY_PATTERNS.get(pattern_key, pattern_key)
        try:
            return pattern.format(*args)
        except (ValueError, IndexError):
            logger.warning(f"Error formateando clave Redis: {pattern} con args: {args}")
            return f"{pattern_key}:{':'.join(map(str, args))}"
    
    def get_redis_ttl(self, cache_type: str) -> int:
        """Obtener TTL para tipo de cache"""
        return self.REDIS_TTL.get(cache_type, 300)  # Default 5 minutos
    
    async def ensure_indexes(self, db):
        """Crear índices MongoDB si no existen"""
        try:
            for collection_name, indexes in self.INDEXES.items():
                collection = db[self.get_collection_name(collection_name)]
                
                existing_indexes = await collection.list_indexes().to_list(None)
                existing_names = {idx.get('name', '') for idx in existing_indexes}
                
                for index_spec in indexes:
                    fields = index_spec['fields']
                    options = {k: v for k, v in index_spec.items() if k != 'fields'}
                    
                    # Generar nombre del índice
                    index_name = '_'.join([f"{field}_{direction}" for field, direction in fields])
                    
                    if index_name not in existing_names:
                        try:
                            await collection.create_index(fields, name=index_name, **options)
                            logger.info(f"Índice creado: {collection_name}.{index_name}")
                        except Exception as e:
                            logger.error(f"Error creando índice {index_name}: {str(e)}")
            
            logger.info("Verificación de índices completada")
            
        except Exception as e:
            logger.error(f"Error verificando índices: {str(e)}")
    
    def get_query_pipeline_for_ml_data(self, 
                                      start_date=None, 
                                      end_date=None,
                                      additional_filters=None) -> List[Dict[str, Any]]:
        """Generar pipeline de agregación para datos ML"""
        pipeline = []
        
        # Filtros de fecha
        match_stage = {}
        if start_date or end_date:
            date_filter = {}
            if start_date:
                date_filter['$gte'] = start_date
            if end_date:
                date_filter['$lte'] = end_date
            match_stage['fechaHora'] = date_filter
        
        # Filtros adicionales
        if additional_filters:
            match_stage.update(additional_filters)
        
        if match_stage:
            pipeline.append({'$match': match_stage})
        
        # Enriquecimiento de datos temporales
        pipeline.extend([
            {
                '$addFields': {
                    'hour': {'$hour': '$fechaHora'},
                    'dayOfWeek': {'$dayOfWeek': '$fechaHora'},
                    'month': {'$month': '$fechaHora'},
                    'year': {'$year': '$fechaHora'}
                }
            },
            {
                '$addFields': {
                    'isWeekend': {
                        '$in': ['$dayOfWeek', [1, 7]]  # Domingo=1, Sábado=7
                    },
                    'isBusinessHour': {
                        '$and': [
                            {'$gte': ['$hour', 7]},
                            {'$lte': ['$hour', 18]},
                            {'$not': {'$in': ['$dayOfWeek', [1, 7]]}}
                        ]
                    },
                    'timePeriod': {
                        '$switch': {
                            'branches': [
                                {'case': {'$lt': ['$hour', 6]}, 'then': 'madrugada'},
                                {'case': {'$lt': ['$hour', 12]}, 'then': 'mañana'},
                                {'case': {'$lt': ['$hour', 18]}, 'then': 'tarde'}
                            ],
                            'default': 'noche'
                        }
                    }
                }
            }
        ])
        
        return pipeline
    
    def get_aggregation_pipeline_hourly_stats(self, 
                                             start_date=None, 
                                             end_date=None) -> List[Dict[str, Any]]:
        """Pipeline para estadísticas agregadas por hora"""
        base_pipeline = self.get_query_pipeline_for_ml_data(start_date, end_date)
        
        # Agregación por hora
        base_pipeline.extend([
            {
                '$group': {
                    '_id': {
                        'year': '$year',
                        'month': '$month',
                        'dayOfMonth': {'$dayOfMonth': '$fechaHora'},
                        'hour': '$hour',
                        'dayOfWeek': '$dayOfWeek'
                    },
                    'count': {'$sum': 1},
                    'uniqueUsers': {'$addToSet': '$usuarioId'},
                    'avgHour': {'$avg': '$hour'},
                    'entradas': {
                        '$sum': {
                            '$cond': [{'$eq': ['$tipoAcceso', 'entrada']}, 1, 0]
                        }
                    },
                    'salidas': {
                        '$sum': {
                            '$cond': [{'$eq': ['$tipoAcceso', 'salida']}, 1, 0]
                        }
                    }
                }
            },
            {
                '$addFields': {
                    'uniqueUsersCount': {'$size': '$uniqueUsers'},
                    'hourlyDateTime': {
                        '$dateFromParts': {
                            'year': '$_id.year',
                            'month': '$_id.month',
                            'day': '$_id.dayOfMonth',
                            'hour': '$_id.hour'
                        }
                    },
                    'isWeekend': {'$in': ['$_id.dayOfWeek', [1, 7]]},
                    'netFlow': {'$subtract': ['$entradas', '$salidas']}
                }
            },
            {
                '$sort': {'hourlyDateTime': 1}
            }
        ])
        
        return base_pipeline
    
    def get_config_summary(self) -> Dict[str, Any]:
        """Obtener resumen de configuración BD"""
        return {
            'mongodb_database': self.MONGODB_DATABASE,
            'mongodb_configured': bool(self.MONGODB_URI),
            'redis_configured': bool(self.REDIS_URL),
            'redis_db': self.REDIS_DB,
            'collections_count': len(self.COLLECTIONS),
            'indexes_defined': sum(len(idx) for idx in self.INDEXES.values()),
            'query_config': self.QUERY_CONFIG,
            'redis_key_patterns': len(self.REDIS_KEY_PATTERNS)
        }


# Instancia global de configuración BD
db_config = DatabaseConfig()

def get_db_config() -> DatabaseConfig:
    """Obtener instancia de configuración BD"""
    return db_config