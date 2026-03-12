"""
Servicio de Clustering ML - Sistema ACEES Group
Implementación de clustering para análisis de patrones (RF009.2)
"""
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import logging
from sklearn.cluster import KMeans, DBSCAN, AgglomerativeClustering
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import silhouette_score, calinski_harabasz_score, davies_bouldin_score
from sklearn.decomposition import PCA
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

from backend.ml_python.core.base_ml_service import BaseMLService
from backend.ml_python.core.model_manager import get_model_manager
from backend.ml_python.utils.metrics_calculator import get_metrics_calculator
from backend.ml_python.config.ml_config import get_ml_config
from backend.ml_python.data.dataset_builder import get_dataset_builder

class ClusteringMLService(BaseMLService):
    """
    Servicio de clustering para análisis de patrones
    Implementa RF009.2: Silhouette Score >= 0.5 en clustering
    """
    
    def __init__(self):
        super().__init__()
        self.service_name = "ClusteringMLService"
        self.model_manager = get_model_manager()
        self.ml_config = get_ml_config()
        
        # Configuraciones específicas (RF009.2)
        self.target_silhouette_score = self.ml_config.TARGET_SILHOUETTE_SCORE
        self.min_samples_cluster = self.ml_config.min_training_samples
        
        # Algoritmos disponibles
        self.clustering_algorithms = {
            'kmeans': self._create_kmeans,
            'dbscan': self._create_dbscan,
            'hierarchical': self._create_hierarchical
        }
        
        # Estado actual
        self.current_model = None
        self.current_scaler = None
        self.current_pca = None
        self.clustering_history = []
        self.cluster_labels_ = None
        self.cluster_centers_ = None
        
        self.logger.info(f"Inicializado {self.service_name} - Target Silhouette: {self.target_silhouette_score}")
    
    async def train_clustering(self, 
                             training_config: Dict[str, Any],
                             dataset_id: Optional[str] = None,
                             custom_data: Optional[pd.DataFrame] = None) -> Dict[str, Any]:
        """
        Entrenar modelo de clustering
        
        Args:
            training_config: Configuración de entrenamiento
            dataset_id: ID del dataset preprocesado
            custom_data: Datos personalizados
            
        Returns:
            Resultado del clustering con métricas
        """
        try:
            self.logger.info("Iniciando entrenamiento de clustering")
            
            # Obtener datos de entrenamiento
            if dataset_id:
                train_data = await self.model_manager.load_dataset(dataset_id)
                X_train = train_data['train']['X']
            elif custom_data is not None:
                X_train = custom_data
            else:
                # Construir dataset automáticamente
                dataset_builder = await get_dataset_builder()
                dataset_result = await dataset_builder.build_dataset(
                    model_type="clustering",
                    dataset_config=training_config.get('dataset_config', {})
                )
                # En clustering no hay target, solo X
                X_train = dataset_result['data']
            
            # Validar datos
            if len(X_train) < self.min_samples_cluster:
                raise ValueError(f"Datos insuficientes: {len(X_train)} < {self.min_samples_cluster}")
            
            # Preprocesamiento
            X_processed = await self._preprocess_clustering_data(X_train, training_config)
            
            # Determinar número óptimo de clusters si no se especifica
            algorithm_name = training_config.get('algorithm', 'kmeans')
            
            # Para K-means, encontrar K óptimo
            if algorithm_name == 'kmeans':
                optimal_k = await self._find_optimal_clusters(X_processed, training_config)
                training_config['n_clusters'] = optimal_k
            
            # Crear y entrenar modelo
            clustering_model = await self._create_clustering_model(algorithm_name, training_config)
            
            # Entrenar clustering
            if hasattr(clustering_model, 'fit_predict'):
                cluster_labels = clustering_model.fit_predict(X_processed)
            else:
                cluster_labels = clustering_model.fit(X_processed).labels_
            
            self.current_model = clustering_model
            self.cluster_labels_ = cluster_labels
            
            # Obtener centros de clusters si están disponibles
            self.cluster_centers_ = None
            if hasattr(clustering_model, 'cluster_centers_'):
                self.cluster_centers_ = clustering_model.cluster_centers_
            
            # Calcular métricas de clustering
            metrics = await self._calculate_clustering_metrics(X_processed, cluster_labels)
            
            # Verificar cumplimiento RF009.2
            silhouette_score_value = metrics.get('silhouette_score', 0)
            meets_requirement = silhouette_score_value >= self.target_silhouette_score
            
            # Análisis de clusters
            cluster_analysis = await self._analyze_clusters(
                X_train, X_processed, cluster_labels, training_config
            )
            
            # Guardar modelo si cumple requisitos
            model_id = None
            if meets_requirement or training_config.get('force_save', False):
                model_metadata = {
                    'model_type': 'clustering',
                    'algorithm': algorithm_name,
                    'target_silhouette': self.target_silhouette_score,
                    'achieved_silhouette': silhouette_score_value,
                    'meets_rf009_2': meets_requirement,
                    'training_samples': len(X_train),
                    'feature_count': X_processed.shape[1],
                    'n_clusters': len(np.unique(cluster_labels)),
                    'training_config': training_config,
                    'training_timestamp': datetime.now().isoformat()
                }
                
                model_artifacts = {
                    'model': clustering_model,
                    'scaler': self.current_scaler,
                    'pca': self.current_pca,
                    'feature_names': list(X_train.columns),
                    'cluster_centers': self.cluster_centers_,
                    'cluster_labels': cluster_labels
                }
                
                model_id = await self.model_manager.save_model(
                    model_artifacts, model_metadata
                )
            
            # Resultado del entrenamiento
            result = {
                'success': True,
                'model_id': model_id,
                'algorithm': algorithm_name,
                'metrics': metrics,
                'rf009_2_compliance': {
                    'target_silhouette': self.target_silhouette_score,
                    'achieved_silhouette': silhouette_score_value,
                    'meets_requirement': meets_requirement,
                    'requirement_status': 'PASS' if meets_requirement else 'FAIL'
                },
                'cluster_info': {
                    'n_clusters': len(np.unique(cluster_labels)),
                    'cluster_sizes': np.bincount(cluster_labels).tolist(),
                    'samples_per_cluster': {
                        f'cluster_{i}': int(count) 
                        for i, count in enumerate(np.bincount(cluster_labels))
                    }
                },
                'cluster_analysis': cluster_analysis,
                'model_info': {
                    'algorithm': algorithm_name,
                    'features': X_processed.shape[1],
                    'samples': len(X_train),
                    'hyperparameters': self._get_model_params(clustering_model)
                },
                'training_completed_at': datetime.now().isoformat()
            }
            
            # Registrar en historial
            self.clustering_history.append({
                'timestamp': datetime.now(),
                'algorithm': algorithm_name,
                'silhouette_score': silhouette_score_value,
                'n_clusters': len(np.unique(cluster_labels)),
                'meets_rf009_2': meets_requirement,
                'model_id': model_id
            })
            
            self.logger.info(f"Clustering completado - Silhouette: {silhouette_score_value:.3f}, RF009.2: {'PASS' if meets_requirement else 'FAIL'}")
            return result
            
        except Exception as e:
            self.logger.error(f"Error en clustering: {str(e)}")
            raise
    
    async def predict_clusters(self, 
                             X: pd.DataFrame,
                             model_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Predecir clusters para nuevas muestras
        
        Args:
            X: Features para clustering
            model_id: ID del modelo específico
            
        Returns:
            Etiquetas de cluster y análisis
        """
        try:
            self.logger.info(f"Prediciendo clusters para {len(X)} muestras")
            
            # Cargar modelo si se especifica ID
            if model_id:
                model_artifacts = await self.model_manager.load_model(model_id)
                clustering_model = model_artifacts['model']
                scaler = model_artifacts.get('scaler')
                pca = model_artifacts.get('pca')
            else:
                # Usar modelo actual
                if self.current_model is None:
                    raise ValueError("No hay modelo de clustering entrenado disponible")
                clustering_model = self.current_model
                scaler = self.current_scaler
                pca = self.current_pca
            
            # Preprocesar datos
            X_processed = await self._apply_preprocessing(X, scaler, pca)
            
            # Predecir clusters
            if hasattr(clustering_model, 'predict'):
                # K-means tiene método predict
                cluster_labels = clustering_model.predict(X_processed)
            elif hasattr(clustering_model, 'fit_predict'):
                # DBSCAN necesita re-entrenar (no ideal para producción)
                cluster_labels = clustering_model.fit_predict(X_processed)
            else:
                # Para algoritmos sin predicción directa
                raise ValueError(f"Algoritmo {type(clustering_model).__name__} no soporta predicción en nuevos datos")
            
            # Análisis de las predicciones
            prediction_analysis = {
                'cluster_distribution': np.bincount(cluster_labels[cluster_labels >= 0]).tolist(),
                'outliers': np.sum(cluster_labels == -1) if -1 in cluster_labels else 0,
                'n_clusters_found': len(np.unique(cluster_labels[cluster_labels >= 0]))
            }
            
            # Distancias a centros de clusters (si están disponibles)
            cluster_distances = None
            if hasattr(clustering_model, 'cluster_centers_'):
                # Calcular distancias a todos los centros
                distances = []
                for center in clustering_model.cluster_centers_:
                    dist = np.linalg.norm(X_processed - center, axis=1)
                    distances.append(dist)
                cluster_distances = np.array(distances).T
            
            # Resultado
            result = {
                'success': True,
                'cluster_labels': cluster_labels.tolist(),
                'prediction_analysis': prediction_analysis,
                'sample_count': len(X),
                'model_info': {
                    'model_id': model_id,
                    'algorithm': type(clustering_model).__name__,
                    'feature_count': X_processed.shape[1]
                }
            }
            
            if cluster_distances is not None:
                result['cluster_distances'] = cluster_distances.tolist()
                result['closest_cluster_distances'] = np.min(cluster_distances, axis=1).tolist()
            
            # DataFrame con resultados si es útil
            if hasattr(X, 'index'):
                results_df = pd.DataFrame({
                    'cluster_label': cluster_labels
                }, index=X.index)
                
                if cluster_distances is not None:
                    for i in range(len(clustering_model.cluster_centers_)):
                        results_df[f'distance_to_cluster_{i}'] = cluster_distances[:, i]
                
                result['predictions_df'] = results_df.to_dict('records')
            
            result['prediction_timestamp'] = datetime.now().isoformat()
            
            self.logger.info(f"Predicción de clusters completada para {len(X)} muestras")
            return result
            
        except Exception as e:
            self.logger.error(f"Error en predicción de clusters: {str(e)}")
            raise
    
    async def evaluate_clustering(self, 
                                X: pd.DataFrame,
                                model_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Evaluar calidad del clustering
        
        Args:
            X: Datos para evaluación
            model_id: ID del modelo específico
            
        Returns:
            Métricas de evaluación
        """
        try:
            self.logger.info("Evaluando calidad del clustering")
            
            # Obtener predicciones
            prediction_result = await self.predict_clusters(X, model_id)
            cluster_labels = np.array(prediction_result['cluster_labels'])
            
            # Preprocesar datos para métricas
            if model_id:
                model_artifacts = await self.model_manager.load_model(model_id)
                scaler = model_artifacts.get('scaler')
                pca = model_artifacts.get('pca')
            else:
                scaler = self.current_scaler
                pca = self.current_pca
            
            X_processed = await self._apply_preprocessing(X, scaler, pca)
            
            # Calcular métricas
            metrics = await self._calculate_clustering_metrics(X_processed, cluster_labels)
            
            # Verificar cumplimiento RF009.2
            silhouette_score_value = metrics.get('silhouette_score', 0)
            meets_rf009_2 = silhouette_score_value >= self.target_silhouette_score
            
            # Análisis adicional
            cluster_analysis = await self._analyze_clusters(X, X_processed, cluster_labels, {})
            
            # Resultado de evaluación
            evaluation_result = {
                'success': True,
                'evaluation_samples': len(X),
                'metrics': metrics,
                'rf009_2_compliance': {
                    'target_silhouette': self.target_silhouette_score,
                    'achieved_silhouette': silhouette_score_value,
                    'meets_requirement': meets_rf009_2,
                    'requirement_status': 'PASS' if meets_rf009_2 else 'FAIL'
                },
                'cluster_analysis': cluster_analysis,
                'cluster_quality_assessment': {
                    'well_separated': silhouette_score_value >= 0.5,
                    'moderately_separated': 0.3 <= silhouette_score_value < 0.5,
                    'poorly_separated': silhouette_score_value < 0.3,
                    'quality_level': self._get_clustering_quality_level(silhouette_score_value)
                },
                'evaluation_timestamp': datetime.now().isoformat()
            }
            
            self.logger.info(f"Evaluación completada - Silhouette: {silhouette_score_value:.3f}")
            return evaluation_result
            
        except Exception as e:
            self.logger.error(f"Error en evaluación de clustering: {str(e)}")
            raise
    
    async def find_optimal_clusters_analysis(self, 
                                           X: pd.DataFrame,
                                           max_clusters: int = 10,
                                           algorithm: str = 'kmeans') -> Dict[str, Any]:
        """
        Análisis para encontrar número óptimo de clusters
        
        Args:
            X: Datos para análisis
            max_clusters: Máximo número de clusters a probar
            algorithm: Algoritmo de clustering
            
        Returns:
            Análisis de clusters óptimos
        """
        try:
            self.logger.info(f"Analizando número óptimo de clusters (max: {max_clusters})")
            
            # Preprocesar datos
            X_processed = await self._preprocess_clustering_data(X, {'scale_features': True})
            
            # Arrays para métricas
            k_values = range(2, min(max_clusters + 1, len(X) // 2))
            inertias = []
            silhouette_scores = []
            calinski_scores = []
            davies_bouldin_scores = []
            
            # Probar diferentes números de clusters
            for k in k_values:
                if algorithm == 'kmeans':
                    model = KMeans(n_clusters=k, random_state=42, n_init=10)
                    labels = model.fit_predict(X_processed)
                    
                    # Inercia (solo para K-means)
                    inertias.append(model.inertia_)
                else:
                    # Para otros algoritmos (simplificado)
                    model = KMeans(n_clusters=k, random_state=42, n_init=10)
                    labels = model.fit_predict(X_processed)
                    inertias.append(model.inertia_)
                
                # Métricas de calidad
                if len(np.unique(labels)) > 1:
                    silhouette_avg = silhouette_score(X_processed, labels)
                    calinski_score = calinski_harabasz_score(X_processed, labels)
                    davies_bouldin = davies_bouldin_score(X_processed, labels)
                    
                    silhouette_scores.append(silhouette_avg)
                    calinski_scores.append(calinski_score)
                    davies_bouldin_scores.append(davies_bouldin)
                else:
                    silhouette_scores.append(0)
                    calinski_scores.append(0)
                    davies_bouldin_scores.append(float('inf'))
            
            # Encontrar K óptimo usando diferentes métodos
            # 1. Método del codo para inercia
            optimal_k_elbow = self._find_elbow_point(list(k_values), inertias)
            
            # 2. Máximo silhouette score
            optimal_k_silhouette = k_values[np.argmax(silhouette_scores)]
            
            # 3. Máximo Calinski-Harabasz
            optimal_k_calinski = k_values[np.argmax(calinski_scores)]
            
            # 4. Mínimo Davies-Bouldin
            optimal_k_davies = k_values[np.argmin(davies_bouldin_scores)]
            
            # Determinar recomendación final
            # Priorizar silhouette score para RF009.2
            recommended_k = optimal_k_silhouette
            max_silhouette = max(silhouette_scores)
            
            # Resultado del análisis
            analysis_result = {
                'success': True,
                'k_range_tested': list(k_values),
                'metrics_by_k': {
                    'inertias': inertias,
                    'silhouette_scores': silhouette_scores,
                    'calinski_scores': calinski_scores,
                    'davies_bouldin_scores': davies_bouldin_scores
                },
                'optimal_k_methods': {
                    'elbow_method': optimal_k_elbow,
                    'silhouette_method': optimal_k_silhouette,
                    'calinski_method': optimal_k_calinski,
                    'davies_bouldin_method': optimal_k_davies
                },
                'recommendation': {
                    'optimal_k': recommended_k,
                    'expected_silhouette': max_silhouette,
                    'meets_rf009_2': max_silhouette >= self.target_silhouette_score,
                    'reasoning': f"Basado en máximo Silhouette Score ({max_silhouette:.3f})"
                },
                'rf009_2_compliance_forecast': {
                    'target_silhouette': self.target_silhouette_score,
                    'best_achievable_silhouette': max_silhouette,
                    'will_meet_requirement': max_silhouette >= self.target_silhouette_score
                },
                'analysis_completed_at': datetime.now().isoformat()
            }
            
            self.logger.info(f"Análisis completado - K óptimo: {recommended_k}, Silhouette: {max_silhouette:.3f}")
            return analysis_result
            
        except Exception as e:
            self.logger.error(f"Error en análisis de clusters óptimos: {str(e)}")
            raise
    
    async def _preprocess_clustering_data(self, X: pd.DataFrame, config: Dict[str, Any]) -> np.ndarray:
        """Preprocesar datos para clustering"""
        try:
            X_processed = X.copy()
            
            # Seleccionar solo features numéricas
            numeric_cols = X_processed.select_dtypes(include=[np.number]).columns
            X_numeric = X_processed[numeric_cols]
            
            # Manejar valores nulos
            X_numeric = X_numeric.fillna(X_numeric.median())
            
            # Escalado (importante para clustering)
            if config.get('scale_features', True):
                self.current_scaler = StandardScaler()
                X_scaled = self.current_scaler.fit_transform(X_numeric)
            else:
                X_scaled = X_numeric.values
            
            # Reducción de dimensionalidad si hay muchas features
            if X_scaled.shape[1] > 10:  # Umbral configurable
                n_components = min(10, X_scaled.shape[1])
                self.current_pca = PCA(n_components=n_components)
                X_scaled = self.current_pca.fit_transform(X_scaled)
                self.logger.info(f"PCA aplicado: {X_numeric.shape[1]} -> {n_components} features")
            
            return X_scaled
            
        except Exception as e:
            self.logger.error(f"Error en preprocesamiento: {str(e)}")
            raise
    
    async def _apply_preprocessing(self, X: pd.DataFrame, scaler=None, pca=None) -> np.ndarray:
        """Aplicar preprocesamiento usando transformadores entrenados"""
        try:
            # Seleccionar features numéricas
            numeric_cols = X.select_dtypes(include=[np.number]).columns
            X_numeric = X[numeric_cols].fillna(X[numeric_cols].median())
            
            # Aplicar escalado
            if scaler:
                X_scaled = scaler.transform(X_numeric)
            else:
                X_scaled = X_numeric.values
            
            # Aplicar PCA
            if pca:
                X_scaled = pca.transform(X_scaled)
            
            return X_scaled
            
        except Exception as e:
            self.logger.error(f"Error aplicando preprocesamiento: {str(e)}")
            raise
    
    async def _find_optimal_clusters(self, X: np.ndarray, config: Dict[str, Any]) -> int:
        """Encontrar número óptimo de clusters usando método del codo y silhouette"""
        try:
            max_k = min(config.get('max_clusters', 8), len(X) // 3)
            min_k = config.get('min_clusters', 2)
            
            k_values = range(min_k, max_k + 1)
            silhouette_scores = []
            
            for k in k_values:
                kmeans = KMeans(n_clusters=k, random_state=42, n_init=10)
                labels = kmeans.fit_predict(X)
                
                if len(np.unique(labels)) > 1:
                    score = silhouette_score(X, labels)
                    silhouette_scores.append(score)
                else:
                    silhouette_scores.append(0)
            
            # Seleccionar K con mejor silhouette score
            optimal_k = k_values[np.argmax(silhouette_scores)]
            
            self.logger.info(f"K óptimo encontrado: {optimal_k} (Silhouette: {max(silhouette_scores):.3f})")
            return optimal_k
            
        except Exception as e:
            self.logger.error(f"Error encontrando K óptimo: {str(e)}")
            return config.get('n_clusters', 3)  # Fallback
    
    def _find_elbow_point(self, k_values: List[int], inertias: List[float]) -> int:
        """Encontrar punto de codo en curva de inercia"""
        try:
            # Método simple: mayor cambio de pendiente
            if len(inertias) < 3:
                return k_values[0] if k_values else 2
            
            # Calcular diferencias
            diffs = np.diff(inertias)
            diff_diffs = np.diff(diffs)
            
            # Encontrar el punto con mayor cambio
            elbow_idx = np.argmax(diff_diffs) + 1
            return k_values[elbow_idx]
            
        except Exception as e:
            self.logger.error(f"Error encontrando punto de codo: {str(e)}")
            return k_values[len(k_values)//2] if k_values else 3
    
    async def _create_clustering_model(self, algorithm: str, config: Dict[str, Any]):
        """Crear modelo de clustering según algoritmo"""
        try:
            if algorithm == 'kmeans':
                return self._create_kmeans(config)
            elif algorithm == 'dbscan':
                return self._create_dbscan(config)
            elif algorithm == 'hierarchical':
                return self._create_hierarchical(config)
            else:
                raise ValueError(f"Algoritmo no soportado: {algorithm}")
                
        except Exception as e:
            self.logger.error(f"Error creando modelo: {str(e)}")
            raise
    
    def _create_kmeans(self, config: Dict[str, Any]) -> KMeans:
        """Crear modelo K-means"""
        return KMeans(
            n_clusters=config.get('n_clusters', 3),
            random_state=config.get('random_state', 42),
            n_init=config.get('n_init', 10),
            max_iter=config.get('max_iter', 300)
        )
    
    def _create_dbscan(self, config: Dict[str, Any]) -> DBSCAN:
        """Crear modelo DBSCAN"""
        return DBSCAN(
            eps=config.get('eps', 0.5),
            min_samples=config.get('min_samples', 5)
        )
    
    def _create_hierarchical(self, config: Dict[str, Any]) -> AgglomerativeClustering:
        """Crear modelo jerárquico"""
        return AgglomerativeClustering(
            n_clusters=config.get('n_clusters', 3),
            linkage=config.get('linkage', 'ward')
        )
    
    async def _calculate_clustering_metrics(self, X: np.ndarray, labels: np.ndarray) -> Dict[str, Any]:
        """Calcular métricas de clustering"""
        try:
            metrics_calculator = await get_metrics_calculator()
            metrics = await metrics_calculator.calculate_clustering_metrics(X, labels)
            
            # RF009.2 compliance check
            silhouette_value = metrics.get('silhouette_score', 0)
            metrics['rf009_2_compliant'] = silhouette_value >= self.target_silhouette_score
            
            return metrics
            
        except Exception as e:
            self.logger.error(f"Error calculando métricas: {str(e)}")
            raise
    
    async def _analyze_clusters(self, X_original: pd.DataFrame, X_processed: np.ndarray, labels: np.ndarray, config: Dict[str, Any]) -> Dict[str, Any]:
        """Analizar características de los clusters"""
        try:
            unique_labels = np.unique(labels)
            n_clusters = len(unique_labels[unique_labels >= 0])  # Excluir outliers (-1)
            
            analysis = {
                'n_clusters': n_clusters,
                'cluster_sizes': np.bincount(labels[labels >= 0]).tolist(),
                'outliers_count': np.sum(labels == -1),
                'clusters_info': {}
            }
            
            # Análisis por cluster
            for cluster_id in unique_labels:
                if cluster_id == -1:  # Outliers
                    continue
                
                cluster_mask = labels == cluster_id
                cluster_data_original = X_original[cluster_mask]
                cluster_data_processed = X_processed[cluster_mask]
                
                cluster_info = {
                    'size': int(np.sum(cluster_mask)),
                    'percentage': float(np.sum(cluster_mask) / len(labels) * 100),
                    'centroid': np.mean(cluster_data_processed, axis=0).tolist(),
                    'std_dev': np.std(cluster_data_processed, axis=0).tolist(),
                    'compactness': float(np.mean(np.std(cluster_data_processed, axis=0)))
                }
                
                # Estadísticas de features originales
                if not cluster_data_original.empty:
                    numeric_cols = cluster_data_original.select_dtypes(include=[np.number]).columns
                    if len(numeric_cols) > 0:
                        cluster_info['original_features_stats'] = {
                            col: {
                                'mean': float(cluster_data_original[col].mean()),
                                'std': float(cluster_data_original[col].std()),
                                'min': float(cluster_data_original[col].min()),
                                'max': float(cluster_data_original[col].max())
                            }
                            for col in numeric_cols
                        }
                
                analysis['clusters_info'][f'cluster_{cluster_id}'] = cluster_info
            
            return analysis
            
        except Exception as e:
            self.logger.error(f"Error analizando clusters: {str(e)}")
            return {}
    
    def _get_model_params(self, model) -> Dict[str, Any]:
        """Obtener parámetros del modelo"""
        try:
            return model.get_params()
        except:
            return {}
    
    def _get_clustering_quality_level(self, silhouette_score: float) -> str:
        """Obtener nivel de calidad del clustering"""
        if silhouette_score >= 0.7:
            return "Excellent"
        elif silhouette_score >= 0.5:
            return "Good"
        elif silhouette_score >= 0.3:
            return "Fair"
        else:
            return "Poor"
    
    async def get_clustering_history(self) -> List[Dict[str, Any]]:
        """Obtener historial de clustering"""
        return [
            {
                'timestamp': entry['timestamp'].isoformat(),
                'algorithm': entry['algorithm'],
                'silhouette_score': entry['silhouette_score'],
                'n_clusters': entry['n_clusters'],
                'meets_rf009_2': entry['meets_rf009_2'],
                'model_id': entry['model_id']
            }
            for entry in self.clustering_history
        ]
    
    async def get_best_clustering_info(self) -> Dict[str, Any]:
        """Obtener información del mejor clustering"""
        try:
            if not self.clustering_history:
                return {'message': 'No hay modelos de clustering entrenados'}
            
            # Filtrar clusters que cumplen RF009.2
            compliant_clusters = [c for c in self.clustering_history if c['meets_rf009_2']]
            
            if compliant_clusters:
                best_cluster = max(compliant_clusters, key=lambda x: x['silhouette_score'])
            else:
                best_cluster = max(self.clustering_history, key=lambda x: x['silhouette_score'])
            
            return {
                'best_model_id': best_cluster['model_id'],
                'silhouette_score': best_cluster['silhouette_score'],
                'n_clusters': best_cluster['n_clusters'],
                'meets_rf009_2': best_cluster['meets_rf009_2'],
                'trained_at': best_cluster['timestamp'].isoformat(),
                'algorithm': best_cluster['algorithm']
            }
            
        except Exception as e:
            self.logger.error(f"Error obteniendo mejor clustering: {str(e)}")
            return {'error': str(e)}


# Instancia global
clustering_service = ClusteringMLService()

async def get_clustering_service() -> ClusteringMLService:
    """Obtener instancia del servicio de clustering"""
    return clustering_service