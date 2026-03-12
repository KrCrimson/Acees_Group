"""
Calculadora de Métricas ML - Sistema ACEES Group  
Cálculo avanzado de métricas para evaluación de modelos ML
"""
import numpy as np
import pandas as pd
from typing import Dict, List, Any, Tuple, Optional, Union
import logging
from datetime import datetime
from sklearn.metrics import (
    mean_squared_error, mean_absolute_error, r2_score,
    accuracy_score, precision_score, recall_score, f1_score,
    confusion_matrix, classification_report, roc_auc_score, roc_curve,
    silhouette_score, calinski_harabasz_score, davies_bouldin_score
)
from sklearn.model_selection import cross_val_score
import warnings

class MLMetricsCalculator:
    """
    Calculadora avanzada de métricas ML para todos los tipos de modelos
    """
    
    def __init__(self):
        self.logger = logging.getLogger("ml.metrics_calculator")
        self.metric_history = []
    
    def calculate_regression_metrics(self, 
                                   y_true: Union[np.ndarray, List[float]], 
                                   y_pred: Union[np.ndarray, List[float]],
                                   model_name: str = "regression") -> Dict[str, float]:
        """
        Calcular métricas completas para regresión
        
        Args:
            y_true: Valores reales
            y_pred: Valores predichos
            model_name: Nombre del modelo
            
        Returns:
            Dict con métricas de regresión
        """
        try:
            y_true = np.array(y_true)
            y_pred = np.array(y_pred)
            
            if len(y_true) != len(y_pred):
                raise ValueError(f"Tamaños no coinciden: y_true={len(y_true)}, y_pred={len(y_pred)}")
            
            # Métricas básicas
            mse = mean_squared_error(y_true, y_pred)
            mae = mean_absolute_error(y_true, y_pred)
            rmse = np.sqrt(mse)
            r2 = r2_score(y_true, y_pred)
            
            # Métricas adicionales
            mean_error = np.mean(y_pred - y_true)  # Bias
            std_error = np.std(y_pred - y_true)
            
            # Error porcentual medio absoluto
            mape = np.mean(np.abs((y_true - y_pred) / np.where(y_true != 0, y_true, 1))) * 100
            
            # Métricas de percentiles de error
            abs_errors = np.abs(y_true - y_pred)
            error_percentiles = {
                'p50_error': np.percentile(abs_errors, 50),
                'p90_error': np.percentile(abs_errors, 90),
                'p95_error': np.percentile(abs_errors, 95),
                'p99_error': np.percentile(abs_errors, 99)
            }
            
            # Métricas de calidad de predicción
            std_y_true = np.std(y_true) if np.std(y_true) > 0 else 1
            normalized_rmse = rmse / std_y_true
            
            # Coeficiente de variación del error
            cv_error = std_error / np.abs(np.mean(y_true)) if np.mean(y_true) != 0 else 0
            
            metrics = {
                'mse': float(mse),
                'mae': float(mae), 
                'rmse': float(rmse),
                'r2_score': float(r2),
                'mean_error': float(mean_error),
                'std_error': float(std_error),
                'mape': float(mape),
                'normalized_rmse': float(normalized_rmse),
                'cv_error': float(cv_error),
                **error_percentiles,
                'n_samples': len(y_true),
                'model_name': model_name,
                'metric_type': 'regression'
            }
            
            # Verificar cumplimiento de umbrales (User Stories)
            metrics['meets_r2_threshold'] = r2 >= 0.7  # RF009.1
            metrics['quality_score'] = self._calculate_regression_quality_score(metrics)
            
            self.logger.info(f"Métricas regresión calculadas: R²={r2:.3f}, RMSE={rmse:.3f}")
            
            return metrics
            
        except Exception as e:
            self.logger.error(f"Error calculando métricas regresión: {str(e)}")
            raise
    
    def calculate_classification_metrics(self, 
                                       y_true: Union[np.ndarray, List],
                                       y_pred: Union[np.ndarray, List],
                                       y_pred_proba: Optional[np.ndarray] = None,
                                       model_name: str = "classification") -> Dict[str, Any]:
        """
        Calcular métricas completas para clasificación
        
        Args:
            y_true: Etiquetas reales
            y_pred: Etiquetas predichas
            y_pred_proba: Probabilidades predichas (opcional)
            model_name: Nombre del modelo
            
        Returns:
            Dict con métricas de clasificación
        """
        try:
            y_true = np.array(y_true)
            y_pred = np.array(y_pred)
            
            # Métricas básicas
            accuracy = accuracy_score(y_true, y_pred)
            precision = precision_score(y_true, y_pred, average='weighted', zero_division=0)
            recall = recall_score(y_true, y_pred, average='weighted', zero_division=0)
            f1 = f1_score(y_true, y_pred, average='weighted', zero_division=0)
            
            # Matriz de confusión
            cm = confusion_matrix(y_true, y_pred)
            
            # Métricas por clase
            precision_per_class = precision_score(y_true, y_pred, average=None, zero_division=0)
            recall_per_class = recall_score(y_true, y_pred, average=None, zero_division=0)
            f1_per_class = f1_score(y_true, y_pred, average=None, zero_division=0)
            
            # Reporte de clasificación
            class_report = classification_report(y_true, y_pred, output_dict=True, zero_division=0)
            
            metrics = {
                'accuracy': float(accuracy),
                'precision': float(precision),
                'recall': float(recall),
                'f1_score': float(f1),
                'confusion_matrix': cm.tolist(),
                'precision_per_class': precision_per_class.tolist(),
                'recall_per_class': recall_per_class.tolist(),
                'f1_per_class': f1_per_class.tolist(),
                'classification_report': class_report,
                'n_samples': len(y_true),
                'n_classes': len(np.unique(y_true)),
                'model_name': model_name,
                'metric_type': 'classification'
            }
            
            # AUC-ROC si hay probabilidades
            if y_pred_proba is not None:
                try:
                    if len(np.unique(y_true)) == 2:  # Clasificación binaria
                        auc_roc = roc_auc_score(y_true, y_pred_proba[:, 1] if y_pred_proba.ndim > 1 else y_pred_proba)
                        fpr, tpr, _ = roc_curve(y_true, y_pred_proba[:, 1] if y_pred_proba.ndim > 1 else y_pred_proba)
                        metrics['auc_roc'] = float(auc_roc)
                        metrics['roc_curve'] = {'fpr': fpr.tolist(), 'tpr': tpr.tolist()}
                    else:  # Multiclase
                        auc_roc = roc_auc_score(y_true, y_pred_proba, multi_class='ovr', average='weighted')
                        metrics['auc_roc'] = float(auc_roc)
                except Exception as e:
                    self.logger.warning(f"No se pudo calcular AUC-ROC: {str(e)}")
            
            # Verificar cumplimiento de umbrales para predicción horarios pico (US037)
            metrics['meets_peak_accuracy_threshold'] = accuracy >= 0.8  # US037 requiere >80%
            metrics['quality_score'] = self._calculate_classification_quality_score(metrics)
            
            self.logger.info(f"Métricas clasificación calculadas: Accuracy={accuracy:.3f}, F1={f1:.3f}")
            
            return metrics
            
        except Exception as e:
            self.logger.error(f"Error calculando métricas clasificación: {str(e)}")
            raise
    
    def calculate_clustering_metrics(self, 
                                   X: np.ndarray, 
                                   cluster_labels: np.ndarray,
                                   model_name: str = "clustering") -> Dict[str, float]:
        """
        Calcular métricas para clustering
        
        Args:
            X: Datos originales
            cluster_labels: Etiquetas de clusters
            model_name: Nombre del modelo
            
        Returns:
            Dict con métricas de clustering
        """
        try:
            n_clusters = len(np.unique(cluster_labels))
            n_samples = len(X)
            
            if n_clusters < 2:
                raise ValueError("Se requieren al menos 2 clusters para calcular métricas")
            
            # Silhouette Score
            silhouette_avg = silhouette_score(X, cluster_labels)
            
            # Calinski-Harabasz Index (mayor es mejor)
            calinski_harabasz = calinski_harabasz_score(X, cluster_labels)
            
            # Davies-Bouldin Index (menor es mejor)
            davies_bouldin = davies_bouldin_score(X, cluster_labels)
            
            # Métricas adicionales
            cluster_counts = np.bincount(cluster_labels)
            cluster_balance = np.std(cluster_counts) / np.mean(cluster_counts)  # Menor = más balanceado
            
            # Inertia (suma de distancias cuadráticas a centroides)
            inertia = self._calculate_inertia(X, cluster_labels)
            
            # Métricas de separación
            separation_metrics = self._calculate_cluster_separation(X, cluster_labels)
            
            metrics = {
                'silhouette_score': float(silhouette_avg),
                'calinski_harabasz_index': float(calinski_harabasz),
                'davies_bouldin_index': float(davies_bouldin),
                'inertia': float(inertia),
                'n_clusters': int(n_clusters),
                'n_samples': int(n_samples),
                'cluster_balance': float(cluster_balance),
                'cluster_sizes': cluster_counts.tolist(),
                **separation_metrics,
                'model_name': model_name,
                'metric_type': 'clustering'
            }
            
            # Verificar cumplimiento umbral silhouette (RF009.2)
            metrics['meets_silhouette_threshold'] = silhouette_avg >= 0.5  # RF009.2
            metrics['quality_score'] = self._calculate_clustering_quality_score(metrics)
            
            self.logger.info(f"Métricas clustering calculadas: Silhouette={silhouette_avg:.3f}, K={n_clusters}")
            
            return metrics
            
        except Exception as e:
            self.logger.error(f"Error calculando métricas clustering: {str(e)}")
            raise
    
    def calculate_time_series_metrics(self, 
                                    y_true: np.ndarray, 
                                    y_pred: np.ndarray,
                                    seasonal_period: int = 24,
                                    model_name: str = "time_series") -> Dict[str, float]:
        """
        Calcular métricas específicas para series temporales
        
        Args:
            y_true: Series temporal real
            y_pred: Series temporal predicha
            seasonal_period: Período estacional (24 para datos horarios)
            model_name: Nombre del modelo
            
        Returns:
            Dict con métricas de series temporales
        """
        try:
            # Métricas básicas de regresión
            base_metrics = self.calculate_regression_metrics(y_true, y_pred, model_name)
            
            # Métricas específicas de series temporales
            
            # Accuracy direccional (porcentaje de cambios de dirección correctos)
            if len(y_true) > 1:
                true_directions = np.diff(y_true) > 0
                pred_directions = np.diff(y_pred) > 0
                directional_accuracy = np.mean(true_directions == pred_directions)
            else:
                directional_accuracy = np.nan
            
            # Error estacional (comparar con misma hora del día anterior)
            if len(y_true) > seasonal_period:
                seasonal_naive_pred = y_true[:-seasonal_period]
                seasonal_naive_mae = mean_absolute_error(
                    y_true[seasonal_period:], 
                    seasonal_naive_pred
                )
                seasonal_improvement = (seasonal_naive_mae - base_metrics['mae']) / seasonal_naive_mae
            else:
                seasonal_naive_mae = np.nan
                seasonal_improvement = np.nan
            
            # Métricas de persistencia (comparar con último valor)
            persistence_pred = np.roll(y_true, 1)[1:]  # Predicción = valor anterior
            persistence_mae = mean_absolute_error(y_true[1:], persistence_pred)
            persistence_improvement = (persistence_mae - base_metrics['mae']) / persistence_mae
            
            # Métricas de tendencia
            trend_metrics = self._calculate_trend_metrics(y_true, y_pred)
            
            ts_metrics = {
                **base_metrics,
                'directional_accuracy': float(directional_accuracy) if not np.isnan(directional_accuracy) else None,
                'seasonal_naive_mae': float(seasonal_naive_mae) if not np.isnan(seasonal_naive_mae) else None,
                'seasonal_improvement': float(seasonal_improvement) if not np.isnan(seasonal_improvement) else None,
                'persistence_mae': float(persistence_mae),
                'persistence_improvement': float(persistence_improvement),
                **trend_metrics,
                'seasonal_period': seasonal_period,
                'metric_type': 'time_series'
            }
            
            # Calcular accuracy específica para series temporales (más estricta)
            ts_accuracy = self._calculate_time_series_accuracy(y_true, y_pred)
            ts_metrics['ts_accuracy'] = ts_accuracy
            
            # Verificar cumplimiento umbral series temporales (RF009.3)
            ts_metrics['meets_ts_accuracy_threshold'] = ts_accuracy >= 0.75  # RF009.3
            
            self.logger.info(f"Métricas series temporales: TS_Accuracy={ts_accuracy:.3f}, Dir_Acc={directional_accuracy:.3f}")
            
            return ts_metrics
            
        except Exception as e:
            self.logger.error(f"Error calculando métricas series temporales: {str(e)}")
            raise
    
    def calculate_cross_validation_metrics(self, 
                                         model, 
                                         X: np.ndarray, 
                                         y: np.ndarray,
                                         cv: int = 5,
                                         scoring: str = 'r2') -> Dict[str, float]:
        """
        Calcular métricas con validación cruzada
        
        Args:
            model: Modelo entrenado
            X: Features
            y: Target
            cv: Número de folds
            scoring: Métrica para scoring
            
        Returns:
            Dict con métricas de validación cruzada
        """
        try:
            # Realizar validación cruzada
            cv_scores = cross_val_score(model, X, y, cv=cv, scoring=scoring)
            
            metrics = {
                'cv_mean_score': float(np.mean(cv_scores)),
                'cv_std_score': float(np.std(cv_scores)),
                'cv_min_score': float(np.min(cv_scores)),
                'cv_max_score': float(np.max(cv_scores)),
                'cv_scores': cv_scores.tolist(),
                'cv_folds': int(cv),
                'cv_scoring': scoring,
                'cv_coefficient_variation': float(np.std(cv_scores) / np.mean(cv_scores)) if np.mean(cv_scores) != 0 else 0
            }
            
            self.logger.info(f"Validación cruzada completada: {scoring}={np.mean(cv_scores):.3f}±{np.std(cv_scores):.3f}")
            
            return metrics
            
        except Exception as e:
            self.logger.error(f"Error en validación cruzada: {str(e)}")
            raise
    
    def calculate_model_comparison_metrics(self, 
                                         models_metrics: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Comparar múltiples modelos y calcular métricas de comparación
        
        Args:
            models_metrics: Lista de métricas de diferentes modelos
            
        Returns:
            Dict con comparación de modelos
        """
        try:
            if not models_metrics:
                return {}
            
            # Agrupar por tipo de métrica
            metric_type = models_metrics[0].get('metric_type', 'unknown')
            
            comparison = {
                'metric_type': metric_type,
                'models_count': len(models_metrics),
                'timestamp': datetime.now().isoformat(),
                'models': {}
            }
            
            # Métricas clave según tipo
            key_metrics = self._get_key_metrics_by_type(metric_type)
            
            # Comparar cada métrica clave
            for metric in key_metrics:
                metric_values = []
                model_names = []
                
                for model_metrics in models_metrics:
                    if metric in model_metrics:
                        metric_values.append(model_metrics[metric])
                        model_names.append(model_metrics.get('model_name', 'unknown'))
                
                if metric_values:
                    # Encontrar mejor modelo para esta métrica
                    if metric in ['mse', 'mae', 'rmse', 'davies_bouldin_index']:
                        # Menor es mejor
                        best_idx = np.argmin(metric_values)
                    else:
                        # Mayor es mejor
                        best_idx = np.argmax(metric_values)
                    
                    comparison['models'][metric] = {
                        'values': metric_values,
                        'model_names': model_names,
                        'best_model': model_names[best_idx],
                        'best_value': metric_values[best_idx],
                        'std': float(np.std(metric_values)),
                        'range': float(max(metric_values) - min(metric_values))
                    }
            
            # Ranking general
            comparison['overall_ranking'] = self._calculate_overall_ranking(
                models_metrics, key_metrics
            )
            
            return comparison
            
        except Exception as e:
            self.logger.error(f"Error comparando modelos: {str(e)}")
            raise
    
    def _calculate_regression_quality_score(self, metrics: Dict[str, float]) -> float:
        """Calcular score de calidad para regresión (0-1)"""
        r2 = metrics.get('r2_score', 0)
        mape = metrics.get('mape', 100)
        
        # Normalizar métricas
        r2_normalized = max(0, min(1, r2))  # R² ya está en [0,1]
        mape_normalized = max(0, min(1, (100 - mape) / 100))  # Invertir MAPE
        
        return 0.7 * r2_normalized + 0.3 * mape_normalized
    
    def _calculate_classification_quality_score(self, metrics: Dict[str, Any]) -> float:
        """Calcular score de calidad para clasificación (0-1)"""
        accuracy = metrics.get('accuracy', 0)
        f1 = metrics.get('f1_score', 0)
        precision = metrics.get('precision', 0)
        recall = metrics.get('recall', 0)
        
        return 0.4 * accuracy + 0.3 * f1 + 0.15 * precision + 0.15 * recall
    
    def _calculate_clustering_quality_score(self, metrics: Dict[str, float]) -> float:
        """Calcular score de calidad para clustering (0-1)"""
        silhouette = metrics.get('silhouette_score', -1)
        davies_bouldin = metrics.get('davies_bouldin_index', float('inf'))
        
        # Normalizar silhouette [-1,1] -> [0,1]
        silhouette_normalized = (silhouette + 1) / 2
        
        # Normalizar Davies-Bouldin (menor es mejor)
        db_normalized = max(0, min(1, 1 / (1 + davies_bouldin)))
        
        return 0.6 * silhouette_normalized + 0.4 * db_normalized
    
    def _calculate_inertia(self, X: np.ndarray, labels: np.ndarray) -> float:
        """Calcular inercia de clustering"""
        inertia = 0
        for k in np.unique(labels):
            cluster_points = X[labels == k]
            if len(cluster_points) > 0:
                centroid = np.mean(cluster_points, axis=0)
                inertia += np.sum((cluster_points - centroid) ** 2)
        return inertia
    
    def _calculate_cluster_separation(self, X: np.ndarray, labels: np.ndarray) -> Dict[str, float]:
        """Calcular métricas de separación entre clusters"""
        centroids = {}
        for k in np.unique(labels):
            cluster_points = X[labels == k]
            if len(cluster_points) > 0:
                centroids[k] = np.mean(cluster_points, axis=0)
        
        # Distancia mínima entre centroides
        min_centroid_distance = float('inf')
        max_centroid_distance = 0
        
        centroid_list = list(centroids.values())
        for i in range(len(centroid_list)):
            for j in range(i + 1, len(centroid_list)):
                dist = np.linalg.norm(centroid_list[i] - centroid_list[j])
                min_centroid_distance = min(min_centroid_distance, dist)
                max_centroid_distance = max(max_centroid_distance, dist)
        
        return {
            'min_centroid_distance': float(min_centroid_distance) if min_centroid_distance != float('inf') else 0,
            'max_centroid_distance': float(max_centroid_distance),
            'centroid_distance_ratio': float(max_centroid_distance / min_centroid_distance) if min_centroid_distance > 0 else 0
        }
    
    def _calculate_trend_metrics(self, y_true: np.ndarray, y_pred: np.ndarray) -> Dict[str, float]:
        """Calcular métricas de tendencia para series temporales"""
        # Tendencias lineales
        x = np.arange(len(y_true))
        true_trend = np.polyfit(x, y_true, 1)[0]  # Pendiente
        pred_trend = np.polyfit(x, y_pred, 1)[0]
        
        trend_error = abs(true_trend - pred_trend)
        trend_correlation = np.corrcoef(y_true, y_pred)[0, 1] if len(y_true) > 1 else 0
        
        return {
            'true_trend_slope': float(true_trend),
            'pred_trend_slope': float(pred_trend),
            'trend_error': float(trend_error),
            'trend_correlation': float(trend_correlation)
        }
    
    def _calculate_time_series_accuracy(self, y_true: np.ndarray, y_pred: np.ndarray) -> float:
        """Calcular accuracy específica para series temporales"""
        # Accuracy basada en porcentaje de error aceptable
        relative_errors = np.abs((y_true - y_pred) / np.where(y_true != 0, np.abs(y_true), 1))
        
        # Considerar "correcto" si el error relativo es < 20%
        correct_predictions = relative_errors < 0.2
        
        return float(np.mean(correct_predictions))
    
    def _get_key_metrics_by_type(self, metric_type: str) -> List[str]:
        """Obtener métricas clave según tipo de modelo"""
        metric_mappings = {
            'regression': ['r2_score', 'mse', 'mae', 'rmse', 'mape'],
            'classification': ['accuracy', 'precision', 'recall', 'f1_score'],
            'clustering': ['silhouette_score', 'calinski_harabasz_index', 'davies_bouldin_index'],
            'time_series': ['ts_accuracy', 'directional_accuracy', 'r2_score', 'mae']
        }
        
        return metric_mappings.get(metric_type, ['accuracy'])
    
    def _calculate_overall_ranking(self, 
                                 models_metrics: List[Dict[str, Any]], 
                                 key_metrics: List[str]) -> List[Dict[str, Any]]:
        """Calcular ranking general de modelos"""
        model_scores = {}
        
        for model_metrics in models_metrics:
            model_name = model_metrics.get('model_name', 'unknown')
            quality_score = model_metrics.get('quality_score', 0)
            model_scores[model_name] = quality_score
        
        # Ordenar por score descendente
        ranked_models = sorted(model_scores.items(), key=lambda x: x[1], reverse=True)
        
        return [
            {
                'rank': i + 1,
                'model_name': model_name,
                'quality_score': score
            }
            for i, (model_name, score) in enumerate(ranked_models)
        ]
    
    def save_metrics_history(self, metrics: Dict[str, Any]):
        """Guardar métricas en historial"""
        metrics_entry = {
            **metrics,
            'timestamp': datetime.now().isoformat()
        }
        self.metric_history.append(metrics_entry)
        
        # Mantener solo últimas 100 entradas
        if len(self.metric_history) > 100:
            self.metric_history = self.metric_history[-100:]
    
    def get_metrics_summary(self) -> Dict[str, Any]:
        """Obtener resumen de métricas calculadas"""
        if not self.metric_history:
            return {'message': 'No hay métricas en historial'}
        
        summary = {
            'total_calculations': len(self.metric_history),
            'metric_types': list(set(m.get('metric_type', 'unknown') for m in self.metric_history)),
            'latest_calculation': self.metric_history[-1]['timestamp'] if self.metric_history else None,
            'models_evaluated': list(set(m.get('model_name', 'unknown') for m in self.metric_history))
        }
        
        return summary


# Instancia global del calculador
metrics_calculator = MLMetricsCalculator()

def get_metrics_calculator() -> MLMetricsCalculator:
    """Obtener instancia del calculador de métricas"""
    return metrics_calculator