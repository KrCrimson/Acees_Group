"""
Utilidades de Visualización ML - Sistema ACEES Group
Generación de visualizaciones para análisis y reportes ML
"""
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import seaborn as sns
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd
import numpy as np
from typing import Dict, List, Any, Optional, Tuple, Union
import logging
from datetime import datetime, timedelta
import base64
from io import BytesIO
import warnings

warnings.filterwarnings('ignore')
plt.style.use('seaborn-v0_8')

class MLVisualizationUtils:
    """
    Utilidades para visualización de datos y resultados ML
    """
    
    def __init__(self):
        self.logger = logging.getLogger("ml.visualization")
        self.color_palette = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b']
        
        # Configuración matplotlib
        plt.rcParams['figure.figsize'] = (12, 8)
        plt.rcParams['font.size'] = 10
        plt.rcParams['axes.grid'] = True
        plt.rcParams['grid.alpha'] = 0.3
    
    def plot_training_metrics(self, 
                            metrics_history: List[Dict[str, Any]],
                            save_path: Optional[str] = None) -> Union[str, bytes]:
        """
        Visualizar evolución de métricas de entrenamiento
        
        Args:
            metrics_history: Lista de métricas por época/iteración
            save_path: Ruta para guardar gráfico
            
        Returns:
            Path del archivo o bytes de la imagen
        """
        try:
            if not metrics_history:
                return self._create_empty_plot("No hay datos de entrenamiento")
            
            # Crear subplots
            fig, axes = plt.subplots(2, 2, figsize=(15, 10))
            fig.suptitle('Evolución de Métricas de Entrenamiento', fontsize=16)
            
            # Extraer métricas
            iterations = range(len(metrics_history))
            
            # Gráfico 1: Loss/Error
            if 'mse' in metrics_history[0]:
                mse_values = [m.get('mse', 0) for m in metrics_history]
                axes[0, 0].plot(iterations, mse_values, 'b-', label='MSE', linewidth=2)
            if 'mae' in metrics_history[0]:
                mae_values = [m.get('mae', 0) for m in metrics_history]
                axes[0, 0].plot(iterations, mae_values, 'r-', label='MAE', linewidth=2)
            
            axes[0, 0].set_title('Error de Entrenamiento')
            axes[0, 0].set_xlabel('Iteración')
            axes[0, 0].set_ylabel('Error')
            axes[0, 0].legend()
            
            # Gráfico 2: R²/Accuracy
            if 'r2_score' in metrics_history[0]:
                r2_values = [m.get('r2_score', 0) for m in metrics_history]
                axes[0, 1].plot(iterations, r2_values, 'g-', label='R²', linewidth=2)
                axes[0, 1].axhline(y=0.7, color='red', linestyle='--', alpha=0.7, label='Umbral (0.7)')
            elif 'accuracy' in metrics_history[0]:
                acc_values = [m.get('accuracy', 0) for m in metrics_history]
                axes[0, 1].plot(iterations, acc_values, 'g-', label='Accuracy', linewidth=2)
                axes[0, 1].axhline(y=0.8, color='red', linestyle='--', alpha=0.7, label='Umbral (0.8)')
            
            axes[0, 1].set_title('Precisión del Modelo')
            axes[0, 1].set_xlabel('Iteración')
            axes[0, 1].set_ylabel('Score')
            axes[0, 1].legend()
            
            # Gráfico 3: Convergencia
            if 'loss' in metrics_history[0]:
                loss_values = [m.get('loss', 0) for m in metrics_history]
                axes[1, 0].semilogy(iterations, loss_values, 'purple', linewidth=2)
                axes[1, 0].set_title('Convergencia (Log Scale)')
                axes[1, 0].set_xlabel('Iteración')
                axes[1, 0].set_ylabel('Loss (log)')
            
            # Gráfico 4: Métricas adicionales
            if 'validation_score' in metrics_history[0]:
                val_scores = [m.get('validation_score', 0) for m in metrics_history]
                train_scores = [m.get('train_score', 0) for m in metrics_history]
                axes[1, 1].plot(iterations, train_scores, 'b-', label='Entrenamiento', linewidth=2)
                axes[1, 1].plot(iterations, val_scores, 'r-', label='Validación', linewidth=2)
                axes[1, 1].set_title('Entrenamiento vs Validación')
                axes[1, 1].legend()
            
            plt.tight_layout()
            
            return self._save_or_return_plot(fig, save_path)
            
        except Exception as e:
            self.logger.error(f"Error generando gráfico de entrenamiento: {str(e)}")
            return self._create_error_plot(str(e))
    
    def plot_prediction_results(self, 
                              y_true: np.ndarray, 
                              y_pred: np.ndarray,
                              timestamps: Optional[np.ndarray] = None,
                              title: str = "Resultados de Predicción",
                              save_path: Optional[str] = None) -> Union[str, bytes]:
        """
        Visualizar resultados de predicción
        
        Args:
            y_true: Valores reales
            y_pred: Valores predichos
            timestamps: Timestamps opcionales
            title: Título del gráfico
            save_path: Ruta para guardar
            
        Returns:
            Path o bytes de la imagen
        """
        try:
            fig, axes = plt.subplots(2, 2, figsize=(15, 10))
            fig.suptitle(title, fontsize=16)
            
            # Gráfico 1: Serie temporal
            if timestamps is not None:
                axes[0, 0].plot(timestamps, y_true, 'b-', label='Real', alpha=0.8, linewidth=2)
                axes[0, 0].plot(timestamps, y_pred, 'r-', label='Predicción', alpha=0.8, linewidth=2)
                axes[0, 0].xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
                axes[0, 0].xaxis.set_major_locator(mdates.HourLocator(interval=4))
                plt.setp(axes[0, 0].xaxis.get_majorticklabels(), rotation=45)
            else:
                x_vals = np.arange(len(y_true))
                axes[0, 0].plot(x_vals, y_true, 'b-', label='Real', alpha=0.8, linewidth=2)
                axes[0, 0].plot(x_vals, y_pred, 'r-', label='Predicción', alpha=0.8, linewidth=2)
            
            axes[0, 0].set_title('Comparación Temporal')
            axes[0, 0].set_xlabel('Tiempo')
            axes[0, 0].set_ylabel('Valor')
            axes[0, 0].legend()
            
            # Gráfico 2: Scatter plot
            axes[0, 1].scatter(y_true, y_pred, alpha=0.6, s=30)
            
            # Línea perfecta
            min_val, max_val = min(y_true.min(), y_pred.min()), max(y_true.max(), y_pred.max())
            axes[0, 1].plot([min_val, max_val], [min_val, max_val], 'r--', alpha=0.8, linewidth=2)
            
            axes[0, 1].set_title('Real vs Predicción')
            axes[0, 1].set_xlabel('Valores Reales')
            axes[0, 1].set_ylabel('Valores Predichos')
            
            # R²
            r2 = np.corrcoef(y_true, y_pred)[0, 1] ** 2 if len(y_true) > 1 else 0
            axes[0, 1].text(0.05, 0.95, f'R² = {r2:.3f}', transform=axes[0, 1].transAxes, 
                           bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))
            
            # Gráfico 3: Distribución de errores
            errors = y_pred - y_true
            axes[1, 0].hist(errors, bins=30, alpha=0.7, color='skyblue', edgecolor='black')
            axes[1, 0].axvline(np.mean(errors), color='red', linestyle='--', linewidth=2, label=f'Media: {np.mean(errors):.3f}')
            axes[1, 0].set_title('Distribución de Errores')
            axes[1, 0].set_xlabel('Error (Pred - Real)')
            axes[1, 0].set_ylabel('Frecuencia')
            axes[1, 0].legend()
            
            # Gráfico 4: Errores absolutos en el tiempo
            abs_errors = np.abs(errors)
            if timestamps is not None:
                axes[1, 1].plot(timestamps, abs_errors, 'orange', alpha=0.8, linewidth=1)
                axes[1, 1].xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
                plt.setp(axes[1, 1].xaxis.get_majorticklabels(), rotation=45)
            else:
                axes[1, 1].plot(abs_errors, 'orange', alpha=0.8, linewidth=1)
            
            axes[1, 1].axhline(np.mean(abs_errors), color='red', linestyle='--', 
                              label=f'MAE: {np.mean(abs_errors):.3f}')
            axes[1, 1].set_title('Error Absoluto en el Tiempo')
            axes[1, 1].set_xlabel('Tiempo')
            axes[1, 1].set_ylabel('Error Absoluto')
            axes[1, 1].legend()
            
            plt.tight_layout()
            
            return self._save_or_return_plot(fig, save_path)
            
        except Exception as e:
            self.logger.error(f"Error generando gráfico de predicción: {str(e)}")
            return self._create_error_plot(str(e))
    
    def plot_clustering_results(self, 
                              X: np.ndarray, 
                              cluster_labels: np.ndarray,
                              centroids: Optional[np.ndarray] = None,
                              title: str = "Resultados de Clustering",
                              save_path: Optional[str] = None) -> Union[str, bytes]:
        """
        Visualizar resultados de clustering
        """
        try:
            n_clusters = len(np.unique(cluster_labels))
            
            if X.shape[1] == 2:
                # Datos 2D - visualización directa
                fig, ax = plt.subplots(1, 1, figsize=(10, 8))
                
                scatter = ax.scatter(X[:, 0], X[:, 1], c=cluster_labels, 
                                   cmap='viridis', alpha=0.7, s=50)
                
                if centroids is not None:
                    ax.scatter(centroids[:, 0], centroids[:, 1], 
                             c='red', marker='x', s=200, linewidths=3, label='Centroids')
                
                ax.set_title(f'{title} (K={n_clusters})')
                ax.set_xlabel('Feature 1')
                ax.set_ylabel('Feature 2')
                plt.colorbar(scatter)
                
                if centroids is not None:
                    ax.legend()
                
            else:
                # Datos multi-dimensionales - usar PCA para visualización
                from sklearn.decomposition import PCA
                
                pca = PCA(n_components=2)
                X_pca = pca.fit_transform(X)
                
                fig, axes = plt.subplots(1, 2, figsize=(15, 6))
                
                # Gráfico 1: Clustering en espacio PCA
                scatter = axes[0].scatter(X_pca[:, 0], X_pca[:, 1], c=cluster_labels, 
                                        cmap='viridis', alpha=0.7, s=50)
                axes[0].set_title(f'{title} - PCA View (K={n_clusters})')
                axes[0].set_xlabel(f'PC1 ({pca.explained_variance_ratio_[0]:.2%} var)')
                axes[0].set_ylabel(f'PC2 ({pca.explained_variance_ratio_[1]:.2%} var)')
                plt.colorbar(scatter, ax=axes[0])
                
                # Gráfico 2: Distribución por cluster
                cluster_sizes = np.bincount(cluster_labels)
                axes[1].bar(range(n_clusters), cluster_sizes, 
                           color=plt.cm.viridis(np.linspace(0, 1, n_clusters)))
                axes[1].set_title('Distribución de Clusters')
                axes[1].set_xlabel('Cluster')
                axes[1].set_ylabel('Número de Puntos')
                
                # Añadir texto con tamaños
                for i, size in enumerate(cluster_sizes):
                    axes[1].text(i, size + max(cluster_sizes)*0.01, str(size), 
                               ha='center', va='bottom')
            
            plt.tight_layout()
            
            return self._save_or_return_plot(fig, save_path)
            
        except Exception as e:
            self.logger.error(f"Error generando gráfico de clustering: {str(e)}")
            return self._create_error_plot(str(e))
    
    def plot_peak_hours_analysis(self, 
                               hourly_data: pd.DataFrame,
                               predictions: Optional[pd.DataFrame] = None,
                               title: str = "Análisis Horarios Pico",
                               save_path: Optional[str] = None) -> Union[str, bytes]:
        """
        Visualizar análisis de horarios pico (US037)
        """
        try:
            fig, axes = plt.subplots(2, 2, figsize=(15, 10))
            fig.suptitle(title, fontsize=16)
            
            # Gráfico 1: Patrón diario promedio
            if 'hour' in hourly_data.columns and 'count' in hourly_data.columns:
                hourly_avg = hourly_data.groupby('hour')['count'].mean()
                
                axes[0, 0].bar(hourly_avg.index, hourly_avg.values, 
                              color='steelblue', alpha=0.7, edgecolor='black')
                axes[0, 0].set_title('Patrón Diario Promedio')
                axes[0, 0].set_xlabel('Hora del Día')
                axes[0, 0].set_ylabel('Promedio de Accesos')
                axes[0, 0].set_xticks(range(0, 24, 2))
                
                # Marcar horarios pico
                peak_threshold = hourly_avg.quantile(0.8)
                axes[0, 0].axhline(peak_threshold, color='red', linestyle='--', 
                                  alpha=0.8, label=f'Umbral Pico (80%): {peak_threshold:.1f}')
                axes[0, 0].legend()
            
            # Gráfico 2: Patrón semanal
            if 'day_of_week' in hourly_data.columns:
                weekday_labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                weekday_avg = hourly_data.groupby('day_of_week')['count'].mean()
                
                axes[0, 1].bar(range(7), weekday_avg.values, 
                              color='lightcoral', alpha=0.7, edgecolor='black')
                axes[0, 1].set_title('Patrón Semanal')
                axes[0, 1].set_xlabel('Día de la Semana')
                axes[0, 1].set_ylabel('Promedio de Accesos')
                axes[0, 1].set_xticks(range(7))
                axes[0, 1].set_xticklabels(weekday_labels)
            
            # Gráfico 3: Series temporal con predicciones
            if 'hourlyDateTime' in hourly_data.columns:
                hourly_data_sorted = hourly_data.sort_values('hourlyDateTime')
                
                axes[1, 0].plot(hourly_data_sorted['hourlyDateTime'], 
                               hourly_data_sorted['count'], 
                               'b-', label='Real', alpha=0.8, linewidth=1)
                
                if predictions is not None and 'predicted_count' in predictions.columns:
                    axes[1, 0].plot(predictions['hourlyDateTime'], 
                                   predictions['predicted_count'], 
                                   'r-', label='Predicción', alpha=0.8, linewidth=2)
                
                axes[1, 0].set_title('Serie Temporal')
                axes[1, 0].set_xlabel('Tiempo')
                axes[1, 0].set_ylabel('Número de Accesos')
                axes[1, 0].legend()
                
                # Formato fechas
                axes[1, 0].xaxis.set_major_formatter(mdates.DateFormatter('%d/%m'))
                plt.setp(axes[1, 0].xaxis.get_majorticklabels(), rotation=45)
            
            # Gráfico 4: Mapa de calor por hora y día
            if all(col in hourly_data.columns for col in ['hour', 'day_of_week', 'count']):
                # Crear pivot table para heatmap
                pivot_data = hourly_data.pivot_table(
                    values='count', index='hour', columns='day_of_week', aggfunc='mean'
                )
                
                im = axes[1, 1].imshow(pivot_data.values, cmap='YlOrRd', aspect='auto')
                axes[1, 1].set_title('Mapa de Calor: Hora vs Día')
                axes[1, 1].set_xlabel('Día de la Semana')
                axes[1, 1].set_ylabel('Hora del Día')
                
                # Configurar ticks
                axes[1, 1].set_xticks(range(7))
                axes[1, 1].set_xticklabels(['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                axes[1, 1].set_yticks(range(0, 24, 2))
                axes[1, 1].set_yticklabels(range(0, 24, 2))
                
                plt.colorbar(im, ax=axes[1, 1])
            
            plt.tight_layout()
            
            return self._save_or_return_plot(fig, save_path)
            
        except Exception as e:
            self.logger.error(f"Error generando análisis horarios pico: {str(e)}")
            return self._create_error_plot(str(e))
    
    def create_model_comparison_chart(self, 
                                    comparison_data: Dict[str, Any],
                                    save_path: Optional[str] = None) -> Union[str, bytes]:
        """
        Crear gráfico de comparación entre modelos
        """
        try:
            if not comparison_data.get('models'):
                return self._create_empty_plot("No hay datos de comparación")
            
            fig, axes = plt.subplots(2, 2, figsize=(15, 10))
            fig.suptitle('Comparación de Modelos ML', fontsize=16)
            
            # Obtener ranking
            ranking = comparison_data.get('overall_ranking', [])
            
            if ranking:
                # Gráfico 1: Ranking general
                model_names = [r['model_name'] for r in ranking]
                quality_scores = [r['quality_score'] for r in ranking]
                
                bars = axes[0, 0].bar(range(len(model_names)), quality_scores, 
                                     color=self.color_palette[:len(model_names)])
                axes[0, 0].set_title('Ranking de Calidad General')
                axes[0, 0].set_xlabel('Modelos')
                axes[0, 0].set_ylabel('Score de Calidad')
                axes[0, 0].set_xticks(range(len(model_names)))
                axes[0, 0].set_xticklabels(model_names, rotation=45)
                
                # Añadir valores en las barras
                for bar, score in zip(bars, quality_scores):
                    axes[0, 0].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
                                   f'{score:.3f}', ha='center', va='bottom')
            
            # Gráficos adicionales según métricas disponibles
            models_data = comparison_data.get('models', {})
            
            # Seleccionar métricas más importantes
            important_metrics = []
            for metric in ['r2_score', 'accuracy', 'silhouette_score', 'mse']:
                if metric in models_data:
                    important_metrics.append(metric)
            
            # Gráficos de métricas específicas
            for i, metric in enumerate(important_metrics[:3]):  # Máximo 3 métricas adicionales
                ax_idx = [(0, 1), (1, 0), (1, 1)][i]
                
                metric_data = models_data[metric]
                values = metric_data['values']
                names = metric_data['model_names']
                best_model = metric_data['best_model']
                
                colors = ['red' if name == best_model else 'steelblue' for name in names]
                
                bars = axes[ax_idx].bar(range(len(names)), values, color=colors, alpha=0.7)
                axes[ax_idx].set_title(f'{metric.replace("_", " ").title()}')
                axes[ax_idx].set_xlabel('Modelos')
                axes[ax_idx].set_ylabel(metric)
                axes[ax_idx].set_xticks(range(len(names)))
                axes[ax_idx].set_xticklabels(names, rotation=45)
                
                # Highlight mejor modelo
                axes[ax_idx].text(0.02, 0.98, f'Mejor: {best_model}', 
                                transform=axes[ax_idx].transAxes, va='top',
                                bbox=dict(boxstyle='round', facecolor='yellow', alpha=0.7))
            
            plt.tight_layout()
            
            return self._save_or_return_plot(fig, save_path)
            
        except Exception as e:
            self.logger.error(f"Error generando comparación de modelos: {str(e)}")
            return self._create_error_plot(str(e))
    
    def _save_or_return_plot(self, fig, save_path: Optional[str]) -> Union[str, bytes]:
        """Guardar plot o retornar como bytes"""
        try:
            if save_path:
                fig.savefig(save_path, dpi=150, bbox_inches='tight', facecolor='white')
                plt.close(fig)
                return save_path
            else:
                # Retornar como bytes para envío en API
                buffer = BytesIO()
                fig.savefig(buffer, format='png', dpi=150, bbox_inches='tight', facecolor='white')
                buffer.seek(0)
                plot_bytes = buffer.getvalue()
                plt.close(fig)
                return plot_bytes
                
        except Exception as e:
            plt.close(fig)
            raise e
    
    def _create_empty_plot(self, message: str) -> bytes:
        """Crear plot vacío con mensaje"""
        fig, ax = plt.subplots(1, 1, figsize=(8, 6))
        ax.text(0.5, 0.5, message, ha='center', va='center', fontsize=14,
               transform=ax.transAxes)
        ax.set_xlim(0, 1)
        ax.set_ylim(0, 1)
        ax.axis('off')
        
        return self._save_or_return_plot(fig, None)
    
    def _create_error_plot(self, error_message: str) -> bytes:
        """Crear plot con mensaje de error"""
        fig, ax = plt.subplots(1, 1, figsize=(8, 6))
        ax.text(0.5, 0.5, f'Error generando visualización:\n{error_message}', 
               ha='center', va='center', fontsize=12, color='red',
               transform=ax.transAxes)
        ax.set_xlim(0, 1)
        ax.set_ylim(0, 1)
        ax.axis('off')
        
        return self._save_or_return_plot(fig, None)


# Instancia global
visualization_utils = MLVisualizationUtils()

def get_visualization_utils() -> MLVisualizationUtils:
    """Obtener instancia de utilidades de visualización"""
    return visualization_utils