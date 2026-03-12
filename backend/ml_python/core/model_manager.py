"""
Gestor de Modelos ML - Sistema ACEES Group
Manejo centralizado de persistencia, versionado y metadata de modelos
"""
import os
import sys
import json
import joblib
import pickle
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple, Union
import pandas as pd
import numpy as np
import logging
import shutil
from pathlib import Path

from ..config.ml_config import MLConfig

class ModelManager:
    """
    Gestor centralizado para modelos ML
    Maneja persistencia, versionado, metadata y lifecycle de modelos
    """
    
    def __init__(self, base_path: str = None):
        self.logger = logging.getLogger("ml.model_manager")
        self.config = MLConfig()
        
        # Configuración paths
        self.base_path = Path(base_path or self.config.ML_MODELS_PATH)
        self.models_path = self.base_path / "saved_models"
        self.metadata_path = self.base_path / "model_metadata" 
        self.backup_path = self.base_path / "backup_models"
        
        # Crear directorios
        self._ensure_directories()
        
        # Registry en memoria para modelos activos
        self.active_models = {}
        self.model_registry = {}
        
    def _ensure_directories(self):
        """Crear estructura de directorios si no existe"""
        for path in [self.models_path, self.metadata_path, self.backup_path]:
            path.mkdir(parents=True, exist_ok=True)
        
        self.logger.info(f"Directorios de modelos inicializados en {self.base_path}")

    async def initialize(self) -> bool:
        """Inicializar recursos del gestor para uso async."""
        try:
            self._ensure_directories()
            return True
        except Exception as e:
            self.logger.error(f"Error en initialize: {str(e)}")
            return False

    async def cleanup(self) -> bool:
        """Liberar recursos en cierre de aplicación."""
        self.active_models.clear()
        return True

    async def health_check(self) -> bool:
        """Chequeo rápido de salud para endpoints de monitoreo."""
        status = self.get_model_health_status()
        return status.get('status') in ['healthy', 'warning']
    
    def save_model(self, 
                  model: Any,
                  model_name: str,
                  model_type: str,
                  version: str = None,
                  metadata: Dict[str, Any] = None,
                  backup_previous: bool = True) -> Dict[str, Any]:
        """
        Guardar modelo con metadata completa
        
        Args:
            model: Modelo entrenado a guardar
            model_name: Nombre identificador del modelo
            model_type: Tipo de modelo (linear_regression, clustering, etc.)
            version: Versión específica (auto-generada si None)
            metadata: Metadata adicional del modelo
            backup_previous: Si crear backup del modelo anterior
            
        Returns:
            Dict con información del modelo guardado
        """
        try:
            # Generar versión si no se proporciona
            if version is None:
                version = self._generate_version()
            
            # Backup modelo anterior si existe
            if backup_previous:
                self._backup_existing_model(model_name, model_type)
            
            # Rutas de archivos
            model_filename = f"{model_name}_{model_type}_{version}.pkl"
            metadata_filename = f"{model_name}_{model_type}_{version}_metadata.json"
            
            model_filepath = self.models_path / model_filename
            metadata_filepath = self.metadata_path / metadata_filename
            
            # Guardar modelo
            joblib.dump(model, model_filepath)
            
            # Preparar metadata completa
            model_info = self._prepare_model_metadata(
                model=model,
                model_name=model_name,
                model_type=model_type,
                version=version,
                filepath=str(model_filepath),
                custom_metadata=metadata
            )
            
            # Guardar metadata
            with open(metadata_filepath, 'w', encoding='utf-8') as f:
                json.dump(model_info, f, indent=2, default=str, ensure_ascii=False)
            
            # Actualizar registry
            registry_key = f"{model_name}_{model_type}"
            self.model_registry[registry_key] = model_info
            
            self.logger.info(f"Modelo guardado exitosamente: {model_filename}")
            
            return {
                'model_name': model_name,
                'model_type': model_type,
                'version': version,
                'filepath': str(model_filepath),
                'metadata_filepath': str(metadata_filepath),
                'size_mb': model_info['model_size_mb'],
                'timestamp': model_info['timestamp']
            }
            
        except Exception as e:
            self.logger.error(f"Error guardando modelo {model_name}: {str(e)}")
            raise
    
    def load_model(self, 
                  model_name: str, 
                  model_type: str,
                  version: str = None,
                  cache_model: bool = True) -> Tuple[Any, Dict[str, Any]]:
        """
        Cargar modelo con su metadata
        
        Args:
            model_name: Nombre del modelo
            model_type: Tipo de modelo
            version: Versión específica (latest si None)
            cache_model: Si cachear el modelo en memoria
            
        Returns:
            Tuple (model, metadata)
        """
        try:
            registry_key = f"{model_name}_{model_type}"
            
            # Buscar en cache primero
            if cache_model and registry_key in self.active_models:
                if version is None or self.active_models[registry_key]['version'] == version:
                    self.logger.info(f"Modelo cargado desde cache: {registry_key}")
                    return self.active_models[registry_key]['model'], self.active_models[registry_key]['metadata']
            
            # Encontrar archivo del modelo
            model_filepath, metadata_filepath = self._find_model_files(model_name, model_type, version)
            
            # Cargar modelo
            model = joblib.load(model_filepath)
            
            # Cargar metadata
            metadata = {}
            if metadata_filepath.exists():
                with open(metadata_filepath, 'r', encoding='utf-8') as f:
                    metadata = json.load(f)
            
            # Cachear si se solicita
            if cache_model:
                self.active_models[registry_key] = {
                    'model': model,
                    'metadata': metadata,
                    'version': metadata.get('version', 'unknown'),
                    'loaded_at': datetime.now().isoformat()
                }
            
            self.logger.info(f"Modelo cargado exitosamente: {model_filepath.name}")
            
            return model, metadata
            
        except Exception as e:
            self.logger.error(f"Error cargando modelo {model_name}_{model_type}: {str(e)}")
            raise
    
    def list_models(self, model_type: str = None) -> List[Dict[str, Any]]:
        """
        Listar todos los modelos disponibles
        
        Args:
            model_type: Filtrar por tipo de modelo (opcional)
            
        Returns:
            Lista de diccionarios con información de modelos
        """
        try:
            models_list = []
            
            # Buscar archivos de metadata
            metadata_files = list(self.metadata_path.glob("*_metadata.json"))
            
            for metadata_file in metadata_files:
                try:
                    with open(metadata_file, 'r', encoding='utf-8') as f:
                        metadata = json.load(f)
                    
                    # Filtrar por tipo si se especifica
                    if model_type is None or metadata.get('model_type') == model_type:
                        models_list.append(metadata)
                        
                except Exception as e:
                    self.logger.warning(f"Error leyendo metadata {metadata_file}: {str(e)}")
                    continue
            
            # Ordenar por timestamp (más reciente primero)
            models_list.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
            
            self.logger.info(f"Modelos listados: {len(models_list)} encontrados")
            
            return models_list
            
        except Exception as e:
            self.logger.error(f"Error listando modelos: {str(e)}")
            return []
    
    def delete_model(self, 
                    model_name: str, 
                    model_type: str, 
                    version: str = None,
                    backup_before_delete: bool = True) -> bool:
        """
        Eliminar modelo y su metadata
        
        Args:
            model_name: Nombre del modelo
            model_type: Tipo de modelo
            version: Versión específica (todas las versiones si None)
            backup_before_delete: Si crear backup antes de eliminar
            
        Returns:
            True si se eliminó exitosamente
        """
        try:
            deleted_count = 0
            
            if version:
                # Eliminar versión específica
                model_filepath, metadata_filepath = self._find_model_files(model_name, model_type, version)
                
                if backup_before_delete:
                    self._backup_model_files(model_filepath, metadata_filepath)
                
                if model_filepath.exists():
                    model_filepath.unlink()
                    deleted_count += 1
                
                if metadata_filepath.exists():
                    metadata_filepath.unlink()
                
            else:
                # Eliminar todas las versiones
                pattern = f"{model_name}_{model_type}_*.pkl"
                model_files = list(self.models_path.glob(pattern))
                
                for model_file in model_files:
                    # Extraer versión del nombre
                    version_part = model_file.stem.replace(f"{model_name}_{model_type}_", "")
                    metadata_file = self.metadata_path / f"{model_name}_{model_type}_{version_part}_metadata.json"
                    
                    if backup_before_delete:
                        self._backup_model_files(model_file, metadata_file)
                    
                    model_file.unlink()
                    if metadata_file.exists():
                        metadata_file.unlink()
                    
                    deleted_count += 1
            
            # Limpiar cache
            registry_key = f"{model_name}_{model_type}"
            if registry_key in self.active_models:
                del self.active_models[registry_key]
            if registry_key in self.model_registry:
                del self.model_registry[registry_key]
            
            self.logger.info(f"Modelos eliminados: {deleted_count} archivos")
            
            return deleted_count > 0
            
        except Exception as e:
            self.logger.error(f"Error eliminando modelo {model_name}_{model_type}: {str(e)}")
            return False
    
    def compare_model_performance(self, 
                                 model_name: str, 
                                 model_type: str,
                                 metrics: List[str] = None) -> Dict[str, Any]:
        """
        Comparar rendimiento entre versiones de un modelo
        
        Args:
            model_name: Nombre del modelo
            model_type: Tipo de modelo
            metrics: Lista de métricas a comparar
            
        Returns:
            Dict con comparación de rendimiento
        """
        if metrics is None:
            metrics = ['accuracy', 'precision', 'recall', 'f1_score', 'r2_score', 'mse', 'mae']
        
        try:
            # Obtener todas las versiones del modelo
            pattern = f"{model_name}_{model_type}_*_metadata.json"
            metadata_files = list(self.metadata_path.glob(pattern))
            
            comparison_data = []
            
            for metadata_file in metadata_files:
                with open(metadata_file, 'r', encoding='utf-8') as f:
                    metadata = json.load(f)
                
                version_data = {
                    'version': metadata.get('version', 'unknown'),
                    'timestamp': metadata.get('timestamp', ''),
                    'training_time_seconds': metadata.get('training_time_seconds', 0)
                }
                
                # Extraer métricas
                model_metrics = metadata.get('metrics', {})
                for metric in metrics:
                    version_data[metric] = model_metrics.get(metric, None)
                
                comparison_data.append(version_data)
            
            # Ordenar por timestamp
            comparison_data.sort(key=lambda x: x['timestamp'])
            
            # Encontrar mejor versión por métrica
            best_versions = {}
            for metric in metrics:
                metric_values = [(v['version'], v[metric]) for v in comparison_data if v[metric] is not None]
                if metric_values:
                    # Para métricas donde mayor es mejor (accuracy, precision, etc.)
                    if metric in ['accuracy', 'precision', 'recall', 'f1_score', 'r2_score']:
                        best_versions[metric] = max(metric_values, key=lambda x: x[1])
                    # Para métricas donde menor es mejor (mse, mae, etc.)
                    else:
                        best_versions[metric] = min(metric_values, key=lambda x: x[1])
            
            result = {
                'model_name': model_name,
                'model_type': model_type,
                'total_versions': len(comparison_data),
                'versions_data': comparison_data,
                'best_versions_by_metric': best_versions,
                'comparison_timestamp': datetime.now().isoformat()
            }
            
            self.logger.info(f"Comparación completada para {model_name}_{model_type}: {len(comparison_data)} versiones")
            
            return result
            
        except Exception as e:
            self.logger.error(f"Error comparando modelos: {str(e)}")
            return {}
    
    def cleanup_old_models(self, 
                          days_to_keep: int = 30, 
                          versions_to_keep: int = 5,
                          dry_run: bool = True) -> Dict[str, Any]:
        """
        Limpiar modelos antiguos basado en criterios
        
        Args:
            days_to_keep: Días de modelos a mantener
            versions_to_keep: Número de versiones a mantener por modelo
            dry_run: Si True, solo simula la limpieza
            
        Returns:
            Dict con resumen de la limpieza
        """
        try:
            cutoff_date = datetime.now() - timedelta(days=days_to_keep)
            to_delete = []
            kept_count = 0
            
            # Agrupar modelos por nombre_tipo
            model_groups = {}
            
            metadata_files = list(self.metadata_path.glob("*_metadata.json"))
            
            for metadata_file in metadata_files:
                try:
                    with open(metadata_file, 'r', encoding='utf-8') as f:
                        metadata = json.load(f)
                    
                    model_key = f"{metadata.get('model_name')}_{metadata.get('model_type')}"
                    if model_key not in model_groups:
                        model_groups[model_key] = []
                    
                    model_groups[model_key].append({
                        'metadata_file': metadata_file,
                        'metadata': metadata,
                        'timestamp': datetime.fromisoformat(metadata.get('timestamp', '1970-01-01T00:00:00'))
                    })
                    
                except Exception as e:
                    self.logger.warning(f"Error procesando {metadata_file}: {str(e)}")
                    continue
            
            # Procesar cada grupo de modelos
            for model_key, versions in model_groups.items():
                # Ordenar por timestamp (más reciente primero)
                versions.sort(key=lambda x: x['timestamp'], reverse=True)
                
                for i, version_info in enumerate(versions):
                    should_delete = False
                    reason = ""
                    
                    # Eliminar si es muy antiguo (pero mantener al menos versions_to_keep)
                    if (version_info['timestamp'] < cutoff_date and 
                        i >= versions_to_keep):
                        should_delete = True
                        reason = f"Anterior a {cutoff_date.date()}"
                    
                    # Eliminar si excede el número de versiones a mantener
                    elif i >= versions_to_keep:
                        should_delete = True
                        reason = f"Excede límite de {versions_to_keep} versiones"
                    
                    if should_delete:
                        # Buscar archivo del modelo correspondiente
                        metadata = version_info['metadata']
                        version = metadata.get('version', '')
                        model_name = metadata.get('model_name', '')
                        model_type = metadata.get('model_type', '')
                        
                        model_file = self.models_path / f"{model_name}_{model_type}_{version}.pkl"
                        
                        to_delete.append({
                            'model_file': model_file,
                            'metadata_file': version_info['metadata_file'],
                            'version': version,
                            'timestamp': version_info['timestamp'],
                            'reason': reason
                        })
                    else:
                        kept_count += 1
            
            # Realizar eliminación si no es dry_run
            deleted_count = 0
            if not dry_run:
                for item in to_delete:
                    try:
                        # Backup antes de eliminar
                        self._backup_model_files(item['model_file'], item['metadata_file'])
                        
                        # Eliminar archivos
                        if item['model_file'].exists():
                            item['model_file'].unlink()
                        if item['metadata_file'].exists():
                            item['metadata_file'].unlink()
                        
                        deleted_count += 1
                        
                    except Exception as e:
                        self.logger.error(f"Error eliminando {item['model_file']}: {str(e)}")
                        continue
            
            result = {
                'dry_run': dry_run,
                'models_to_delete' if dry_run else 'models_deleted': len(to_delete),
                'models_kept': kept_count,
                'cutoff_date': cutoff_date.isoformat(),
                'versions_limit': versions_to_keep,
                'details': [
                    {
                        'version': item['version'],
                        'timestamp': item['timestamp'].isoformat(),
                        'reason': item['reason']
                    } for item in to_delete
                ]
            }
            
            action_word = "simularía eliminar" if dry_run else "eliminó"
            self.logger.info(f"Limpieza completada: {action_word} {len(to_delete)} modelos, mantuvo {kept_count}")
            
            return result
            
        except Exception as e:
            self.logger.error(f"Error en limpieza de modelos: {str(e)}")
            return {'error': str(e)}
    
    def get_model_health_status(self) -> Dict[str, Any]:
        """
        Obtener estado de salud del sistema de modelos
        
        Returns:
            Dict con estado completo del sistema
        """
        try:
            # Estadísticas básicas
            model_files = list(self.models_path.glob("*.pkl"))
            metadata_files = list(self.metadata_path.glob("*_metadata.json"))
            backup_files = list(self.backup_path.glob("*.pkl"))
            
            # Tamaño total
            total_size_mb = sum(f.stat().st_size for f in model_files) / (1024 * 1024)
            
            # Modelos por tipo
            model_types = {}
            for metadata_file in metadata_files:
                try:
                    with open(metadata_file, 'r') as f:
                        metadata = json.load(f)
                    
                    model_type = metadata.get('model_type', 'unknown')
                    model_types[model_type] = model_types.get(model_type, 0) + 1
                    
                except:
                    continue
            
            # Uso de espacio en disco
            disk_usage = {
                'models_path_mb': sum(f.stat().st_size for f in self.models_path.rglob("*") if f.is_file()) / (1024 * 1024),
                'metadata_path_mb': sum(f.stat().st_size for f in self.metadata_path.rglob("*") if f.is_file()) / (1024 * 1024),
                'backup_path_mb': sum(f.stat().st_size for f in self.backup_path.rglob("*") if f.is_file()) / (1024 * 1024)
            }
            
            status = {
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'statistics': {
                    'total_models': len(model_files),
                    'total_metadata_files': len(metadata_files),
                    'total_backups': len(backup_files),
                    'total_size_mb': round(total_size_mb, 2),
                    'active_models_in_memory': len(self.active_models)
                },
                'models_by_type': model_types,
                'disk_usage_mb': {k: round(v, 2) for k, v in disk_usage.items()},
                'paths': {
                    'base_path': str(self.base_path),
                    'models_path': str(self.models_path),
                    'metadata_path': str(self.metadata_path),
                    'backup_path': str(self.backup_path)
                }
            }
            
            # Verificar problemas
            issues = []
            
            # Verificar archivos huérfanos
            model_stems = {f.stem for f in model_files}
            metadata_stems = {f.stem.replace('_metadata', '') for f in metadata_files}
            
            orphaned_models = model_stems - metadata_stems
            orphaned_metadata = metadata_stems - model_stems
            
            if orphaned_models:
                issues.append(f"Modelos sin metadata: {len(orphaned_models)}")
            if orphaned_metadata:
                issues.append(f"Metadata sin modelo: {len(orphaned_metadata)}")
            
            # Verificar espacio en disco
            if disk_usage['models_path_mb'] > 1000:  # 1GB
                issues.append("Uso de disco alto en modelos")
            
            if issues:
                status['status'] = 'warning'
                status['issues'] = issues
            
            return status
            
        except Exception as e:
            self.logger.error(f"Error obteniendo estado de salud: {str(e)}")
            return {
                'status': 'error',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def _generate_version(self) -> str:
        """Generar versión automática"""
        return datetime.now().strftime("%Y%m%d_%H%M%S")
    
    def _prepare_model_metadata(self, 
                               model: Any,
                               model_name: str,
                               model_type: str,
                               version: str,
                               filepath: str,
                               custom_metadata: Dict[str, Any] = None) -> Dict[str, Any]:
        """Preparar metadata completa del modelo"""
        
        metadata = {
            'model_name': model_name,
            'model_type': model_type,
            'version': version,
            'timestamp': datetime.now().isoformat(),
            'filepath': filepath,
            'model_size_mb': round(Path(filepath).stat().st_size / (1024 * 1024), 2),
            'model_class': model.__class__.__name__ if hasattr(model, '__class__') else str(type(model)),
            'python_version': f"{sys.version_info.major}.{sys.version_info.minor}",
            'sklearn_version': self._get_sklearn_version()
        }
        
        # Agregar metadata personalizada
        if custom_metadata:
            metadata.update(custom_metadata)
        
        return metadata
    
    def _find_model_files(self, 
                         model_name: str, 
                         model_type: str, 
                         version: str = None) -> Tuple[Path, Path]:
        """Encontrar archivos de modelo y metadata"""
        
        if version:
            # Versión específica
            model_filename = f"{model_name}_{model_type}_{version}.pkl"
            metadata_filename = f"{model_name}_{model_type}_{version}_metadata.json"
        else:
            # Buscar la más reciente
            pattern = f"{model_name}_{model_type}_*.pkl"
            model_files = list(self.models_path.glob(pattern))
            
            if not model_files:
                raise FileNotFoundError(f"No se encontraron modelos para {model_name}_{model_type}")
            
            # Ordenar por fecha de modificación (más reciente primero)
            model_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
            latest_model = model_files[0]
            
            model_filename = latest_model.name
            version = latest_model.stem.replace(f"{model_name}_{model_type}_", "")
            metadata_filename = f"{model_name}_{model_type}_{version}_metadata.json"
        
        model_filepath = self.models_path / model_filename
        metadata_filepath = self.metadata_path / metadata_filename
        
        if not model_filepath.exists():
            raise FileNotFoundError(f"Archivo de modelo no encontrado: {model_filepath}")
        
        return model_filepath, metadata_filepath
    
    def _backup_existing_model(self, model_name: str, model_type: str):
        """Crear backup del modelo existente"""
        try:
            model_filepath, metadata_filepath = self._find_model_files(model_name, model_type)
            self._backup_model_files(model_filepath, metadata_filepath)
        except FileNotFoundError:
            # No hay modelo anterior, no pasa nada
            pass
    
    def _get_sklearn_version(self) -> str:
        """Obtener versión de scikit-learn de forma segura"""
        try:
            import sklearn
            return sklearn.__version__
        except ImportError:
            return 'not_installed'
    
    def _backup_model_files(self, model_filepath: Path, metadata_filepath: Path):
        """Backup archivos específicos"""
        backup_timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        if model_filepath.exists():
            backup_model_path = self.backup_path / f"backup_{backup_timestamp}_{model_filepath.name}"
            shutil.copy2(model_filepath, backup_model_path)
        
        if metadata_filepath.exists():
            backup_metadata_path = self.backup_path / f"backup_{backup_timestamp}_{metadata_filepath.name}"
            shutil.copy2(metadata_filepath, backup_metadata_path)


_model_manager_instance: Optional[ModelManager] = None


def get_model_manager() -> ModelManager:
    """Obtener instancia singleton del gestor de modelos."""
    global _model_manager_instance
    if _model_manager_instance is None:
        _model_manager_instance = ModelManager()
    return _model_manager_instance