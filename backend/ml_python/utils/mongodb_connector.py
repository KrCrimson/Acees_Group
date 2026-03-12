"""
Conector MongoDB Optimizado - Sistema ACEES Group
Conexión y operaciones optimizadas para MongoDB con motor asíncrono
"""
import asyncio
import logging
from typing import Dict, List, Any, Optional, AsyncGenerator, Union
from datetime import datetime, timedelta
from contextlib import asynccontextmanager

import motor.motor_asyncio
import pymongo
from pymongo import IndexModel, ASCENDING, DESCENDING
from pymongo.errors import (
    ConnectionFailure, 
    ServerSelectionTimeoutError,
    DuplicateKeyError,
    BulkWriteError
)

from config.database_config import get_db_config

class MongoDBConnector:
    """
    Conector optimizado para MongoDB con operaciones asíncronas
    """
    
    def __init__(self):
        self.config = get_db_config()
        self.logger = logging.getLogger("ml.mongodb_connector")
        
        # Cliente y base de datos
        self._client = None
        self._database = None
        
        # Pool de conexiones
        self._connection_pool = None
        
        # Cache de conexiones para optimización
        self._connection_cache = {}
        
        # Estado de conexión
        self._is_connected = False
        self._last_health_check = None
    
    async def connect(self) -> bool:
        """
        Establecer conexión con MongoDB
        
        Returns:
            True si conexión exitosa
        """
        try:
            if self._is_connected and self._client:
                return True
            
            # Parámetros de conexión
            connection_params = self.config.get_mongodb_connection_params()
            
            # Crear cliente Motor (asíncrono)
            self._client = motor.motor_asyncio.AsyncIOMotorClient(
                connection_params['uri'],
                serverSelectionTimeoutMS=connection_params['serverSelectionTimeoutMS'],
                maxPoolSize=connection_params['maxPoolSize'],
                minPoolSize=connection_params['minPoolSize'],
                retryWrites=connection_params['retryWrites'],
                w=connection_params['w']
            )
            
            # Probar conexión
            await self._client.admin.command('ping')
            
            # Obtener base de datos
            self._database = self._client[connection_params['database']]
            
            # Crear índices si es necesario
            await self.config.ensure_indexes(self._database)
            
            self._is_connected = True
            self._last_health_check = datetime.now()
            
            self.logger.info(f"Conectado a MongoDB: {connection_params['database']}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error conectando a MongoDB: {str(e)}")
            self._is_connected = False
            return False
    
    async def disconnect(self):
        """Cerrar conexión con MongoDB"""
        if self._client:
            self._client.close()
            self._client = None
            self._database = None
            self._is_connected = False
            self.logger.info("Desconectado de MongoDB")
    
    @asynccontextmanager
    async def get_connection(self):
        """Context manager para obtener conexión a BD"""
        if not self._is_connected:
            await self.connect()
        
        if not self._database:
            raise ConnectionError("No hay conexión activa a MongoDB")
        
        try:
            yield self._database
        except Exception as e:
            self.logger.error(f"Error en operación BD: {str(e)}")
            raise
    
    async def health_check(self) -> Dict[str, Any]:
        """
        Verificar estado de salud de la conexión
        
        Returns:
            Dict con estado de salud
        """
        health_status = {
            'connected': False,
            'database': self.config.MONGODB_DATABASE,
            'timestamp': datetime.now().isoformat(),
            'error': None
        }
        
        try:
            if not self._is_connected:
                await self.connect()
            
            # Ping al servidor
            async with self.get_connection() as db:
                ping_result = await db.command('ping')
                
                # Estadísticas del servidor
                server_status = await db.command('serverStatus')
                
                health_status.update({
                    'connected': True,
                    'ping_ok': ping_result.get('ok') == 1,
                    'server_version': server_status.get('version'),
                    'uptime_seconds': server_status.get('uptime'),
                    'connections': server_status.get('connections', {}),
                    'memory': server_status.get('mem', {}),
                    'collections_count': len(await db.list_collection_names())
                })
            
            self._last_health_check = datetime.now()
            
        except Exception as e:
            health_status['error'] = str(e)
            self.logger.error(f"Health check fallido: {str(e)}")
        
        return health_status
    
    async def get_ml_training_data(self, 
                                  months_back: int = 3,
                                  filters: Dict[str, Any] = None,
                                  limit: Optional[int] = None) -> List[Dict[str, Any]]:
        """
        Obtener datos para entrenamiento ML
        
        Args:
            months_back: Meses atrás de datos
            filters: Filtros adicionales
            limit: Límite de documentos
            
        Returns:
            Lista de documentos para ML
        """
        try:
            # Calcular fechas
            end_date = datetime.now()
            start_date = end_date - timedelta(days=30 * months_back)
            
            # Pipeline de agregación
            pipeline = self.config.get_query_pipeline_for_ml_data(
                start_date=start_date,
                end_date=end_date,
                additional_filters=filters
            )
            
            # Agregar límite si se especifica
            if limit:
                pipeline.append({'$limit': limit})
            
            # Ejecutar agregación
            async with self.get_connection() as db:
                collection = db[self.config.get_collection_name('asistencias')]
                cursor = collection.aggregate(pipeline)
                documents = await cursor.to_list(length=None)
            
            self.logger.info(f"Datos ML obtenidos: {len(documents)} documentos desde {start_date}")
            return documents
            
        except Exception as e:
            self.logger.error(f"Error obteniendo datos ML: {str(e)}")
            raise
    
    async def get_hourly_aggregated_data(self, 
                                       start_date: datetime = None,
                                       end_date: datetime = None,
                                       time_zone: str = 'America/Bogota') -> List[Dict[str, Any]]:
        """
        Obtener datos agregados por hora para análisis temporal
        
        Args:
            start_date: Fecha inicio
            end_date: Fecha fin
            time_zone: Zona horaria
            
        Returns:
            Lista de datos agregados por hora
        """
        try:
            if start_date is None:
                start_date = datetime.now() - timedelta(days=90)  # 3 meses por defecto
            if end_date is None:
                end_date = datetime.now()
            
            # Pipeline de agregación horaria
            pipeline = self.config.get_aggregation_pipeline_hourly_stats(start_date, end_date)
            
            async with self.get_connection() as db:
                collection = db[self.config.get_collection_name('asistencias')]
                cursor = collection.aggregate(pipeline, allowDiskUse=True)
                results = await cursor.to_list(length=None)
            
            self.logger.info(f"Datos horarios obtenidos: {len(results)} registros")
            return results
            
        except Exception as e:
            self.logger.error(f"Error obteniendo datos horarios: {str(e)}")
            raise
    
    async def save_ml_metrics(self, 
                            model_type: str,
                            version: str,
                            metrics: Dict[str, Any],
                            training_data: Dict[str, Any] = None) -> str:
        """
        Guardar métricas de modelo ML
        
        Args:
            model_type: Tipo de modelo
            version: Versión del modelo
            metrics: Métricas calculadas
            training_data: Metadata del entrenamiento
            
        Returns:
            ID del documento insertado
        """
        try:
            document = {
                'model_type': model_type,
                'version': version,
                'timestamp': datetime.now(),
                'metrics': metrics,
                'training_data': training_data or {},
                'environment': self.config.config.ENVIRONMENT if hasattr(self.config, 'config') else 'unknown'
            }
            
            async with self.get_connection() as db:
                collection = db[self.config.get_collection_name('ml_metrics')]
                result = await collection.insert_one(document)
            
            self.logger.info(f"Métricas ML guardadas: {result.inserted_id}")
            return str(result.inserted_id)
            
        except Exception as e:
            self.logger.error(f"Error guardando métricas ML: {str(e)}")
            raise
    
    async def save_prediction_history(self, 
                                    model_type: str,
                                    input_data: Dict[str, Any],
                                    prediction: Any,
                                    metadata: Dict[str, Any] = None) -> str:
        """
        Guardar historial de predicciones
        
        Args:
            model_type: Tipo de modelo usado
            input_data: Datos de entrada
            prediction: Resultado de predicción
            metadata: Metadata adicional
            
        Returns:
            ID del documento insertado
        """
        try:
            document = {
                'model_type': model_type,
                'timestamp': datetime.now(),
                'input_data': input_data,
                'prediction': prediction,
                'metadata': metadata or {}
            }
            
            async with self.get_connection() as db:
                collection = db[self.config.get_collection_name('predictions_history')]
                result = await collection.insert_one(document)
            
            return str(result.inserted_id)
            
        except Exception as e:
            self.logger.error(f"Error guardando predicción: {str(e)}")
            raise
    
    async def save_alert_history(self, 
                                alert_type: str,
                                alert_level: str,
                                message: str,
                                data: Dict[str, Any] = None,
                                recipients: List[str] = None) -> str:
        """
        Guardar historial de alertas
        
        Args:
            alert_type: Tipo de alerta
            alert_level: Nivel (low, medium, high)
            message: Mensaje de alerta
            data: Datos asociados
            recipients: Lista de destinatarios
            
        Returns:
            ID del documento insertado
        """
        try:
            document = {
                'alert_type': alert_type,
                'alert_level': alert_level,
                'message': message,
                'data': data or {},
                'recipients': recipients or [],
                'timestamp': datetime.now(),
                'status': 'sent',
                'created_at': datetime.now()
            }
            
            async with self.get_connection() as db:
                collection = db[self.config.get_collection_name('alerts_history')]
                result = await collection.insert_one(document)
            
            return str(result.inserted_id)
            
        except Exception as e:
            self.logger.error(f"Error guardando alerta: {str(e)}")
            raise
    
    async def get_recent_metrics(self, 
                               model_type: str = None,
                               hours_back: int = 24,
                               limit: int = 100) -> List[Dict[str, Any]]:
        """
        Obtener métricas recientes de modelos
        
        Args:
            model_type: Filtrar por tipo de modelo
            hours_back: Horas atrás
            limit: Límite de resultados
            
        Returns:
            Lista de métricas recientes
        """
        try:
            # Construir filtro
            start_time = datetime.now() - timedelta(hours=hours_back)
            query = {'timestamp': {'$gte': start_time}}
            
            if model_type:
                query['model_type'] = model_type
            
            async with self.get_connection() as db:
                collection = db[self.config.get_collection_name('ml_metrics')]
                cursor = collection.find(query).sort('timestamp', -1).limit(limit)
                metrics = await cursor.to_list(length=limit)
            
            return metrics
            
        except Exception as e:
            self.logger.error(f"Error obteniendo métricas recientes: {str(e)}")
            raise
    
    async def bulk_insert_training_logs(self, logs: List[Dict[str, Any]]) -> int:
        """
        Insertar logs de entrenamiento en lote
        
        Args:
            logs: Lista de logs a insertar
            
        Returns:
            Número de documentos insertados
        """
        try:
            if not logs:
                return 0
            
            # Agregar timestamp a logs que no lo tengan
            for log in logs:
                if 'timestamp' not in log:
                    log['timestamp'] = datetime.now()
            
            async with self.get_connection() as db:
                collection = db[self.config.get_collection_name('training_logs')]
                result = await collection.insert_many(logs, ordered=False)
            
            inserted_count = len(result.inserted_ids)
            self.logger.info(f"Logs insertados en lote: {inserted_count}")
            return inserted_count
            
        except BulkWriteError as e:
            # Manejar errores parciales en bulk insert
            inserted_count = e.details['nInserted'] 
            self.logger.warning(f"Bulk insert parcial: {inserted_count} insertados, {len(e.details['writeErrors'])} errores")
            return inserted_count
            
        except Exception as e:
            self.logger.error(f"Error en bulk insert: {str(e)}")
            raise
    
    async def get_data_quality_stats(self) -> Dict[str, Any]:
        """
        Obtener estadísticas de calidad de datos
        
        Returns:
            Dict con estadísticas de calidad
        """
        try:
            stats = {
                'timestamp': datetime.now().isoformat(),
                'asistencias': {},
                'usuarios': {},
                'general': {}
            }
            
            async with self.get_connection() as db:
                # Stats de asistencias
                asistencias_collection = db[self.config.get_collection_name('asistencias')]
                
                total_asistencias = await asistencias_collection.count_documents({})
                stats['asistencias']['total_count'] = total_asistencias
                
                # Asistencias por mes
                last_30_days = datetime.now() - timedelta(days=30)
                recent_count = await asistencias_collection.count_documents({
                    'fechaHora': {'$gte': last_30_days}
                })
                stats['asistencias']['last_30_days'] = recent_count
                
                # Estadísticas de nulos
                null_stats_pipeline = [
                    {
                        '$group': {
                            '_id': None,
                            'null_fechaHora': {'$sum': {'$cond': [{'$eq': ['$fechaHora', None]}, 1, 0]}},
                            'null_usuarioId': {'$sum': {'$cond': [{'$eq': ['$usuarioId', None]}, 1, 0]}},
                            'null_tipoAcceso': {'$sum': {'$cond': [{'$eq': ['$tipoAcceso', None]}, 1, 0]}}
                        }
                    }
                ]
                
                null_stats_cursor = asistencias_collection.aggregate(null_stats_pipeline)
                null_stats = await null_stats_cursor.to_list(length=1)
                
                if null_stats:
                    stats['asistencias']['null_stats'] = null_stats[0]
                
                # Stats de usuarios
                usuarios_collection = db[self.config.get_collection_name('usuarios')]
                stats['usuarios']['total_count'] = await usuarios_collection.count_documents({})
                stats['usuarios']['active_count'] = await usuarios_collection.count_documents({'estado': 'activo'})
                
                # Stats generales
                collections = await db.list_collection_names()
                stats['general']['collections_count'] = len(collections)
                
                # Tamaño de base de datos
                db_stats = await db.command('dbStats')
                stats['general']['database_size_mb'] = db_stats.get('dataSize', 0) / (1024 * 1024)
                stats['general']['index_size_mb'] = db_stats.get('indexSize', 0) / (1024 * 1024)
            
            return stats
            
        except Exception as e:
            self.logger.error(f"Error obteniendo stats de calidad: {str(e)}")
            raise
    
    async def cleanup_old_predictions(self, days_to_keep: int = 30) -> int:
        """
        Limpiar predicciones antiguas
        
        Args:
            days_to_keep: Días a mantener
            
        Returns:
            Número de documentos eliminados
        """
        try:
            cutoff_date = datetime.now() - timedelta(days=days_to_keep)
            
            async with self.get_connection() as db:
                collection = db[self.config.get_collection_name('predictions_history')]
                result = await collection.delete_many({
                    'timestamp': {'$lt': cutoff_date}
                })
            
            deleted_count = result.deleted_count
            self.logger.info(f"Predicciones antiguas eliminadas: {deleted_count}")
            return deleted_count
            
        except Exception as e:
            self.logger.error(f"Error limpiando predicciones: {str(e)}")
            raise
    
    async def ensure_collections_exist(self) -> bool:
        """
        Asegurar que todas las collections necesarias existen
        
        Returns:
            True si todas las collections existen
        """
        try:
            async with self.get_connection() as db:
                existing_collections = set(await db.list_collection_names())
                required_collections = set(self.config.COLLECTIONS.values())
                
                missing_collections = required_collections - existing_collections
                
                # Crear collections faltantes
                for collection_name in missing_collections:
                    await db.create_collection(collection_name)
                    self.logger.info(f"Collection creada: {collection_name}")
                
                # Crear índices
                await self.config.ensure_indexes(db)
                
                return True
                
        except Exception as e:
            self.logger.error(f"Error asegurando collections: {str(e)}")
            return False
    
    def __del__(self):
        """Cleanup al destruir el objeto"""
        if self._client:
            try:
                # Programar cierre de conexión
                if hasattr(asyncio, 'get_running_loop'):
                    try:
                        loop = asyncio.get_running_loop()
                        loop.create_task(self.disconnect())
                    except RuntimeError:
                        # No hay loop activo, cerrar sincrónicamente
                        self._client.close()
                else:
                    self._client.close()
            except:
                pass  # Ignora errores durante cleanup


# Instancia global del conector
_mongodb_connector = None

async def get_mongodb_connector() -> MongoDBConnector:
    """Obtener instancia singleton del conector MongoDB"""
    global _mongodb_connector
    
    if _mongodb_connector is None:
        _mongodb_connector = MongoDBConnector()
        await _mongodb_connector.connect()
    
    return _mongodb_connector

async def close_mongodb_connection():
    """Cerrar conexión global"""
    global _mongodb_connector
    
    if _mongodb_connector:
        await _mongodb_connector.disconnect()
        _mongodb_connector = None