"""
Clase Base para Servicios ML - Sistema ACEES Group
Proporciona funcionalidades comunes para todos los servicios ML
"""
from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional, Union, Tuple
import logging
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import joblib
import json
import os

from utils.mongodb_connector import MongoDBConnector
from config.ml_config import MLConfig

class BaseMLService(ABC):
    """
    Clase base abstracta para todos los servicios ML
    Proporciona funcionalidades comunes y define interfaz estándar
    """
    
    def __init__(self, service_name: str):
        self.service_name = service_name
        self.logger = logging.getLogger(f"ml.{service_name}")
        self.config = MLConfig()
        self.db_connector = MongoDBConnector()
        self.model = None
        self.model_metadata = {}
        self.is_trained = False
        
        # Configuración paths
        self.models_base_path = self.config.ML_MODELS_PATH
        self.service_models_path = os.path.join(self.models_base_path, service_name)
        self._ensure_directories()
    
    def _ensure_directories(self):
        """Crear directorios necesarios si no existen"""
        os.makedirs(self.service_models_path, exist_ok=True)
        os.makedirs(os.path.join(self.service_models_path, 'metadata'), exist_ok=True)
        os.makedirs(os.path.join(self.service_models_path, 'backup'), exist_ok=True)
    
    @abstractmethod
    async def train(self, data: pd.DataFrame, **kwargs) -> Dict[str, Any]:
        """
        Método abstracto para entrenamiento del modelo
        Debe ser implementado por cada servicio específico
        
        Args:
            data: DataFrame con datos de entrenamiento
            **kwargs: Parámetros específicos del algoritmo
            
        Returns:
            Dict con resultados del entrenamiento
        """
        pass
    
    @abstractmethod
    async def predict(self, data: Union[pd.DataFrame, Dict[str, Any]]) -> Dict[str, Any]:
        """
        Método abstracto para predicción
        Debe ser implementado por cada servicio específico
        
        Args:
            data: Datos para predicción
            
        Returns:
            Dict con predicciones y metadata
        """
        pass
    
    @abstractmethod
    def validate_input_data(self, data: pd.DataFrame) -> Tuple[bool, List[str]]:
        """
        Método abstracto para validación de datos de entrada
        
        Args:
            data: DataFrame a validar
            
        Returns:
            Tuple (is_valid, list_of_errors)
        """
        pass
    
    async def get_training_data(self, 
                              months_back: int = None, 
                              filters: Dict[str, Any] = None) -> pd.DataFrame:
        """
        Obtener datos de entrenamiento desde MongoDB
        
        Args:
            months_back: Meses atrás a obtener (default: config)
            filters: Filtros adicionales para la query
            
        Returns:
            DataFrame con datos de entrenamiento
        """
        months_back = months_back or self.config.MIN_DATA_MONTHS
        
        # Calcular fecha de inicio
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30 * months_back)
        
        # Query base
        query = {
            'fechaHora': {
                '$gte': start_date,
                '$lte': end_date
            }
        }
        
        # Agregar filtros adicionales
        if filters:
            query.update(filters)
        
        try:
            # Obtener datos de asistencias
            async with self.db_connector.get_connection() as db:
                cursor = db.asistencias.find(query)
                data = await cursor.to_list(length=None)
            
            if not data:
                raise ValueError(f"No se encontraron datos para entrenamiento en los últimos {months_back} meses")
            
            # Convertir a DataFrame
            df = pd.DataFrame(data)
            
            # Conversiones básicas
            if 'fechaHora' in df.columns:
                df['fechaHora'] = pd.to_datetime(df['fechaHora'])
            
            self.logger.info(f"Datos obtenidos: {len(df)} registros desde {start_date} hasta {end_date}")
            return df
            
        except Exception as e:
            self.logger.error(f"Error obteniendo datos de entrenamiento: {str(e)}")
            raise
    
    def save_model(self, 
                  model: Any, 
                  metadata: Dict[str, Any] = None, 
                  version: str = None) -> str:
        """
        Guardar modelo entrenado con metadata
        
        Args:
            model: Modelo entrenado
            metadata: Metadata del modelo
            version: Versión del modelo (auto-generada si no se proporciona)
            
        Returns:
            Path del modelo guardado
        """
        if version is None:
            version = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Rutas de archivos
        model_filename = f"{self.service_name}_{version}.pkl"
        metadata_filename = f"{self.service_name}_{version}_metadata.json"
        
        model_path = os.path.join(self.service_models_path, model_filename)
        metadata_path = os.path.join(self.service_models_path, 'metadata', metadata_filename)
        
        try:
            # Guardar modelo
            joblib.dump(model, model_path)
            
            # Preparar metadata completa
            full_metadata = {
                'service_name': self.service_name,
                'version': version,
                'timestamp': datetime.now().isoformat(),
                'model_path': model_path,
                'model_size_mb': os.path.getsize(model_path) / (1024 * 1024),
                **(metadata or {})
            }
            
            # Guardar metadata
            with open(metadata_path, 'w') as f:
                json.dump(full_metadata, f, indent=2, default=str)
            
            self.logger.info(f"Modelo guardado: {model_path}")
            return model_path
            
        except Exception as e:
            self.logger.error(f"Error guardando modelo: {str(e)}")
            raise
    
    def load_model(self, version: str = None) -> Tuple[Any, Dict[str, Any]]:
        """
        Cargar modelo con su metadata
        
        Args:
            version: Versión específica (si None, carga la más reciente)
            
        Returns:
            Tuple (model, metadata)
        """
        try:
            if version is None:
                # Buscar versión más reciente
                model_files = [f for f in os.listdir(self.service_models_path) 
                              if f.startswith(self.service_name) and f.endswith('.pkl')]
                
                if not model_files:
                    raise FileNotFoundError(f"No se encontraron modelos para {self.service_name}")
                
                # Ordenar por fecha (más reciente primero)
                model_files.sort(reverse=True)
                latest_file = model_files[0]
                version = latest_file.replace(f"{self.service_name}_", "").replace(".pkl", "")
            
            # Rutas de archivos
            model_filename = f"{self.service_name}_{version}.pkl"
            metadata_filename = f"{self.service_name}_{version}_metadata.json"
            
            model_path = os.path.join(self.service_models_path, model_filename)
            metadata_path = os.path.join(self.service_models_path, 'metadata', metadata_filename)
            
            # Cargar modelo
            if not os.path.exists(model_path):
                raise FileNotFoundError(f"Modelo no encontrado: {model_path}")
            
            model = joblib.load(model_path)
            
            # Cargar metadata
            metadata = {}
            if os.path.exists(metadata_path):
                with open(metadata_path, 'r') as f:
                    metadata = json.load(f)
            
            self.model = model
            self.model_metadata = metadata
            self.is_trained = True
            
            self.logger.info(f"Modelo cargado: {model_path}")
            return model, metadata
            
        except Exception as e:
            self.logger.error(f"Error cargando modelo: {str(e)}")
            raise
    
    def backup_current_model(self) -> bool:
        """
        Crear backup del modelo actual antes de sobrescribir
        
        Returns:
            True si el backup fue exitoso
        """
        try:
            # Encontrar modelo más reciente
            model_files = [f for f in os.listdir(self.service_models_path) 
                          if f.startswith(self.service_name) and f.endswith('.pkl')]
            
            if not model_files:
                self.logger.info("No hay modelos para respaldar")
                return True
            
            # Modelo más reciente
            model_files.sort(reverse=True)
            latest_model = model_files[0]
            
            # Crear paths de backup
            backup_dir = os.path.join(self.service_models_path, 'backup')
            backup_timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            
            source_path = os.path.join(self.service_models_path, latest_model)
            backup_path = os.path.join(backup_dir, f"backup_{backup_timestamp}_{latest_model}")
            
            # Copiar archivo
            import shutil
            shutil.copy2(source_path, backup_path)
            
            # Backup metadata si existe
            version = latest_model.replace(f"{self.service_name}_", "").replace(".pkl", "")
            metadata_file = f"{self.service_name}_{version}_metadata.json"
            metadata_source = os.path.join(self.service_models_path, 'metadata', metadata_file)
            
            if os.path.exists(metadata_source):
                metadata_backup = os.path.join(backup_dir, f"backup_{backup_timestamp}_{metadata_file}")
                shutil.copy2(metadata_source, metadata_backup)
            
            self.logger.info(f"Backup creado: {backup_path}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error creando backup: {str(e)}")
            return False
    
    def get_model_info(self) -> Dict[str, Any]:
        """
        Obtener información del modelo actual
        
        Returns:
            Dict con información del modelo
        """
        return {
            'service_name': self.service_name,
            'is_trained': self.is_trained,
            'model_metadata': self.model_metadata,
            'model_type': type(self.model).__name__ if self.model else None,
            'last_updated': self.model_metadata.get('timestamp', 'Unknown')
        }
    
    def calculate_basic_metrics(self, y_true: np.ndarray, y_pred: np.ndarray) -> Dict[str, float]:
        """
        Calcular métricas básicas de evaluación
        
        Args:
            y_true: Valores reales
            y_pred: Valores predichos
            
        Returns:
            Dict con métricas calculadas
        """
        from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
        
        metrics = {
            'mse': float(mean_squared_error(y_true, y_pred)),
            'rmse': float(np.sqrt(mean_squared_error(y_true, y_pred))),
            'mae': float(mean_absolute_error(y_true, y_pred)),
            'r2_score': float(r2_score(y_true, y_pred))
        }
        
        # Métricas adicionales
        metrics['mean_error'] = float(np.mean(y_pred - y_true))
        metrics['std_error'] = float(np.std(y_pred - y_true))
        
        return metrics
    
    def log_training_start(self, data_shape: Tuple[int, int], **params):
        """Log inicio de entrenamiento"""
        self.logger.info(f"Iniciando entrenamiento {self.service_name}")
        self.logger.info(f"Datos: {data_shape[0]} filas, {data_shape[1]} columnas")
        self.logger.info(f"Parámetros: {params}")
    
    def log_training_end(self, metrics: Dict[str, Any], duration_seconds: float):
        """Log fin de entrenamiento"""
        self.logger.info(f"Entrenamiento completado en {duration_seconds:.2f}s")
        self.logger.info(f"Métricas: {metrics}")
    
    def __str__(self) -> str:
        return f"{self.__class__.__name__}(service_name={self.service_name}, trained={self.is_trained})"
    
    def __repr__(self) -> str:
        return self.__str__()