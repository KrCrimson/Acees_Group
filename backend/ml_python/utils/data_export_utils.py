"""
Utilidades de Exportación de Datos ML - Sistema ACEES Group
Funciones para export y generación de reportes ML
"""
import pandas as pd
import numpy as np
import json
import csv
from typing import Dict, List, Any, Optional, Union
from datetime import datetime, date
import logging
from pathlib import Path
import xlsxwriter
from io import BytesIO, StringIO
import base64
import zipfile

class MLDataExportUtils:
    """
    Utilidades para exportación de datos y reportes ML
    """
    
    def __init__(self):
        self.logger = logging.getLogger("ml.export")
        self.supported_formats = ['json', 'csv', 'excel', 'parquet', 'pickle']
    
    def export_model_metrics(self, 
                           metrics: Dict[str, Any], 
                           format: str = 'json',
                           include_metadata: bool = True) -> Union[str, bytes, Dict]:
        """
        Exportar métricas de modelo
        
        Args:
            metrics: Diccionario con métricas del modelo
            format: Formato de exportación ('json', 'csv', 'excel')
            include_metadata: Incluir metadatos de exportación
            
        Returns:
            Datos exportados según formato
        """
        try:
            # Preparar datos para exportación
            export_data = self._prepare_metrics_for_export(metrics, include_metadata)
            
            if format.lower() == 'json':
                return self._export_to_json(export_data)
            
            elif format.lower() == 'csv':
                return self._export_metrics_to_csv(export_data)
                
            elif format.lower() == 'excel':
                return self._export_metrics_to_excel(export_data)
                
            else:
                raise ValueError(f"Formato no soportado: {format}")
                
        except Exception as e:
            self.logger.error(f"Error exportando métricas: {str(e)}")
            raise
    
    def export_training_history(self, 
                              history: List[Dict[str, Any]], 
                              format: str = 'csv') -> Union[str, bytes]:
        """
        Exportar historial de entrenamiento
        
        Args:
            history: Lista de métricas por época/iteración
            format: Formato de exportación
            
        Returns:
            Datos exportados
        """
        try:
            if not history:
                raise ValueError("No hay historial para exportar")
            
            # Convertir a DataFrame
            df = pd.DataFrame(history)
            
            # Añadir columna de época/iteración
            df['iteration'] = range(1, len(df) + 1)
            
            # Reordenar columnas
            cols = ['iteration'] + [col for col in df.columns if col != 'iteration']
            df = df[cols]
            
            return self._export_dataframe(df, format, 'training_history')
            
        except Exception as e:
            self.logger.error(f"Error exportando historial: {str(e)}")
            raise
    
    def export_predictions(self, 
                         y_true: np.ndarray, 
                         y_pred: np.ndarray,
                         timestamps: Optional[np.ndarray] = None,
                         feature_names: Optional[List[str]] = None,
                         additional_data: Optional[Dict[str, np.ndarray]] = None,
                         format: str = 'csv') -> Union[str, bytes]:
        """
        Exportar resultados de predicciones
        
        Args:
            y_true: Valores reales
            y_pred: Valores predichos  
            timestamps: Timestamps opcionales
            feature_names: Nombres de features
            additional_data: Datos adicionales para incluir
            format: Formato de exportación
            
        Returns:
            Datos exportados
        """
        try:
            # Crear DataFrame base
            data = {
                'real_value': y_true,
                'predicted_value': y_pred,
                'error': y_pred - y_true,
                'absolute_error': np.abs(y_pred - y_true),
                'squared_error': (y_pred - y_true) ** 2
            }
            
            # Añadir timestamps si están disponibles
            if timestamps is not None:
                if isinstance(timestamps[0], (datetime, date)):
                    data['timestamp'] = timestamps
                else:
                    data['timestamp'] = pd.to_datetime(timestamps)
            else:
                data['index'] = range(len(y_true))
            
            # Añadir datos adicionales
            if additional_data:
                for key, values in additional_data.items():
                    if len(values) == len(y_true):
                        data[key] = values
            
            df = pd.DataFrame(data)
            
            # Calcular métricas resumen
            summary_stats = {
                'mae': np.mean(df['absolute_error']),
                'mse': np.mean(df['squared_error']),
                'rmse': np.sqrt(np.mean(df['squared_error'])),
                'r2_score': 1 - (np.sum(df['squared_error']) / np.sum((y_true - np.mean(y_true))**2)) if len(y_true) > 1 else 0,
                'mean_error': np.mean(df['error']),
                'std_error': np.std(df['error']),
                'total_predictions': len(df),
                'export_timestamp': datetime.now().isoformat()
            }
            
            if format.lower() == 'excel':
                return self._export_predictions_to_excel(df, summary_stats)
            else:
                return self._export_dataframe(df, format, 'predictions')
                
        except Exception as e:
            self.logger.error(f"Error exportando predicciones: {str(e)}")
            raise
    
    def export_clustering_results(self, 
                                X: np.ndarray, 
                                cluster_labels: np.ndarray,
                                centroids: Optional[np.ndarray] = None,
                                feature_names: Optional[List[str]] = None,
                                format: str = 'csv') -> Union[str, bytes]:
        """
        Exportar resultados de clustering
        
        Args:
            X: Datos originales
            cluster_labels: Etiquetas de cluster
            centroids: Centroids opcionales
            feature_names: Nombres de features
            format: Formato de exportación
            
        Returns:
            Datos exportados
        """
        try:
            # Crear DataFrame con datos y clusters
            if feature_names and len(feature_names) == X.shape[1]:
                df = pd.DataFrame(X, columns=feature_names)
            else:
                df = pd.DataFrame(X, columns=[f'feature_{i}' for i in range(X.shape[1])])
            
            df['cluster_label'] = cluster_labels
            df['sample_id'] = range(len(df))
            
            # Reordenar columnas
            cols = ['sample_id', 'cluster_label'] + [col for col in df.columns if col not in ['sample_id', 'cluster_label']]
            df = df[cols]
            
            # Calcular estadísticas por cluster
            cluster_stats = self._calculate_cluster_statistics(X, cluster_labels, centroids)
            
            if format.lower() == 'excel':
                return self._export_clustering_to_excel(df, cluster_stats, centroids, feature_names)
            else:
                return self._export_dataframe(df, format, 'clustering_results')
                
        except Exception as e:
            self.logger.error(f"Error exportando clustering: {str(e)}")
            raise
    
    def create_comprehensive_ml_report(self, 
                                     model_info: Dict[str, Any],
                                     metrics: Dict[str, Any],
                                     training_history: Optional[List[Dict]] = None,
                                     predictions_data: Optional[Dict[str, Any]] = None,
                                     format: str = 'excel') -> bytes:
        """
        Crear reporte ML completo
        
        Args:
            model_info: Información del modelo
            metrics: Métricas de evaluación
            training_history: Historial de entrenamiento
            predictions_data: Datos de predicciones
            format: Formato (excel recomendado para reporte completo)
            
        Returns:
            Reporte en bytes
        """
        try:
            if format.lower() != 'excel':
                # Para formatos simples, retornar JSON con toda la información
                full_report = {
                    'report_metadata': {
                        'generated_at': datetime.now().isoformat(),
                        'report_type': 'comprehensive_ml_report',
                        'version': '1.0'
                    },
                    'model_information': model_info,
                    'performance_metrics': metrics,
                    'training_history': training_history,
                    'predictions_summary': predictions_data
                }
                return self._export_to_json(full_report).encode('utf-8')
            
            # Crear reporte Excel completo
            buffer = BytesIO()
            workbook = xlsxwriter.Workbook(buffer, {'in_memory': True})
            
            # Formatos para el workbook
            header_format = workbook.add_format({
                'bold': True,
                'font_size': 12,
                'bg_color': '#366092',
                'font_color': 'white',
                'align': 'center',
                'valign': 'vcenter',
                'border': 1
            })
            
            cell_format = workbook.add_format({
                'align': 'left',
                'valign': 'vcenter',
                'border': 1
            })
            
            number_format = workbook.add_format({
                'num_format': '0.0000',
                'align': 'right',
                'valign': 'vcenter',
                'border': 1
            })
            
            # Hoja 1: Resumen del modelo
            self._create_model_summary_sheet(workbook, model_info, metrics, header_format, cell_format, number_format)
            
            # Hoja 2: Métricas detalladas
            self._create_metrics_sheet(workbook, metrics, header_format, cell_format, number_format)
            
            # Hoja 3: Historial de entrenamiento (si está disponible)
            if training_history:
                self._create_training_history_sheet(workbook, training_history, header_format, cell_format, number_format)
            
            # Hoja 4: Datos de predicciones (si está disponible)
            if predictions_data:
                self._create_predictions_sheet(workbook, predictions_data, header_format, cell_format, number_format)
            
            workbook.close()
            buffer.seek(0)
            return buffer.getvalue()
            
        except Exception as e:
            self.logger.error(f"Error creando reporte completo: {str(e)}")
            raise
    
    def export_feature_importance(self, 
                                feature_names: List[str], 
                                importance_scores: np.ndarray,
                                format: str = 'csv') -> Union[str, bytes]:
        """
        Exportar importancia de features
        """
        try:
            df = pd.DataFrame({
                'feature_name': feature_names,
                'importance_score': importance_scores
            })
            
            # Ordenar por importancia descendente
            df = df.sort_values('importance_score', ascending=False)
            df['rank'] = range(1, len(df) + 1)
            
            # Añadir porcentaje de importancia
            total_importance = df['importance_score'].sum()
            df['importance_percentage'] = (df['importance_score'] / total_importance * 100) if total_importance > 0 else 0
            df['cumulative_importance'] = df['importance_percentage'].cumsum()
            
            # Reordenar columnas
            df = df[['rank', 'feature_name', 'importance_score', 'importance_percentage', 'cumulative_importance']]
            
            return self._export_dataframe(df, format, 'feature_importance')
            
        except Exception as e:
            self.logger.error(f"Error exportando importancia de features: {str(e)}")
            raise
    
    def _prepare_metrics_for_export(self, metrics: Dict[str, Any], include_metadata: bool) -> Dict[str, Any]:
        """Preparar métricas para exportación"""
        export_data = metrics.copy()
        
        if include_metadata:
            export_data['export_metadata'] = {
                'exported_at': datetime.now().isoformat(),
                'export_format': 'ml_metrics',
                'version': '1.0'
            }
        
        return export_data
    
    def _export_to_json(self, data: Any) -> str:
        """Exportar a JSON con manejo de tipos especiales"""
        def json_serializer(obj):
            if isinstance(obj, (datetime, date)):
                return obj.isoformat()
            elif isinstance(obj, np.ndarray):
                return obj.tolist()
            elif isinstance(obj, (np.int64, np.int32)):
                return int(obj)
            elif isinstance(obj, (np.float64, np.float32)):
                return float(obj)
            raise TypeError(f"Objeto {type(obj)} no es serializable JSON")
        
        return json.dumps(data, indent=2, default=json_serializer, ensure_ascii=False)
    
    def _export_dataframe(self, df: pd.DataFrame, format: str, filename_prefix: str) -> Union[str, bytes]:
        """Exportar DataFrame a diferentes formatos"""
        if format.lower() == 'csv':
            return df.to_csv(index=False)
        
        elif format.lower() == 'json':
            return df.to_json(orient='records', date_format='iso', indent=2)
        
        elif format.lower() == 'excel':
            buffer = BytesIO()
            df.to_excel(buffer, index=False, sheet_name=filename_prefix)
            buffer.seek(0)
            return buffer.getvalue()
        
        elif format.lower() == 'parquet':
            buffer = BytesIO()
            df.to_parquet(buffer, index=False)
            buffer.seek(0)
            return buffer.getvalue()
        
        else:
            raise ValueError(f"Formato no soportado: {format}")
    
    def _export_metrics_to_csv(self, metrics: Dict[str, Any]) -> str:
        """Exportar métricas a CSV"""
        output = StringIO()
        writer = csv.writer(output)
        
        # Headers
        writer.writerow(['metric_name', 'metric_value', 'metric_type'])
        
        # Escribir métricas aplanadas
        for key, value in self._flatten_dict(metrics).items():
            metric_type = type(value).__name__
            writer.writerow([key, str(value), metric_type])
        
        return output.getvalue()
    
    def _export_metrics_to_excel(self, metrics: Dict[str, Any]) -> bytes:
        """Exportar métricas a Excel"""
        buffer = BytesIO()
        workbook = xlsxwriter.Workbook(buffer, {'in_memory': True})
        worksheet = workbook.add_worksheet('Metrics')
        
        # Formatos
        header_format = workbook.add_format({'bold': True, 'bg_color': '#366092', 'font_color': 'white'})
        cell_format = workbook.add_format({'align': 'left'})
        
        # Headers
        headers = ['Metric Name', 'Metric Value', 'Metric Type']
        for col, header in enumerate(headers):
            worksheet.write(0, col, header, header_format)
        
        # Datos
        row = 1
        for key, value in self._flatten_dict(metrics).items():
            worksheet.write(row, 0, key, cell_format)
            worksheet.write(row, 1, str(value), cell_format)
            worksheet.write(row, 2, type(value).__name__, cell_format)
            row += 1
        
        # Ajustar ancho de columnas
        worksheet.set_column('A:C', 20)
        
        workbook.close()
        buffer.seek(0)
        return buffer.getvalue()
    
    def _flatten_dict(self, d: Dict[str, Any], parent_key: str = '', sep: str = '.') -> Dict[str, Any]:
        """Aplanar diccionario anidado"""
        items = []
        for k, v in d.items():
            new_key = f"{parent_key}{sep}{k}" if parent_key else k
            if isinstance(v, dict):
                items.extend(self._flatten_dict(v, new_key, sep=sep).items())
            else:
                items.append((new_key, v))
        return dict(items)
    
    def _calculate_cluster_statistics(self, X: np.ndarray, labels: np.ndarray, centroids: Optional[np.ndarray] = None) -> Dict[str, Any]:
        """Calcular estadísticas de clustering"""
        n_clusters = len(np.unique(labels))
        
        stats = {
            'total_samples': len(X),
            'n_clusters': n_clusters,
            'cluster_sizes': {},
            'cluster_proportions': {},
            'intra_cluster_distances': {}
        }
        
        for cluster_id in range(n_clusters):
            cluster_mask = labels == cluster_id
            cluster_data = X[cluster_mask]
            
            stats['cluster_sizes'][f'cluster_{cluster_id}'] = len(cluster_data)
            stats['cluster_proportions'][f'cluster_{cluster_id}'] = len(cluster_data) / len(X)
            
            if len(cluster_data) > 1:
                # Distancia intra-cluster promedio
                if centroids is not None and cluster_id < len(centroids):
                    distances = np.linalg.norm(cluster_data - centroids[cluster_id], axis=1)
                    stats['intra_cluster_distances'][f'cluster_{cluster_id}'] = np.mean(distances)
        
        return stats
    
    def _create_model_summary_sheet(self, workbook, model_info, metrics, header_format, cell_format, number_format):
        """Crear hoja de resumen del modelo"""
        worksheet = workbook.add_worksheet('Model Summary')
        
        # Información del modelo
        worksheet.write('A1', 'Model Information', header_format)
        worksheet.write('A2', 'Model Type', cell_format)
        worksheet.write('B2', model_info.get('model_type', 'N/A'), cell_format)
        worksheet.write('A3', 'Algorithm', cell_format)
        worksheet.write('B3', model_info.get('algorithm', 'N/A'), cell_format)
        worksheet.write('A4', 'Training Date', cell_format)
        worksheet.write('B4', model_info.get('training_date', 'N/A'), cell_format)
        
        # Métricas principales
        worksheet.write('A6', 'Key Metrics', header_format)
        row = 7
        for key, value in metrics.items():
            if isinstance(value, (int, float)):
                worksheet.write(row, 0, key, cell_format)
                worksheet.write(row, 1, value, number_format)
                row += 1
        
        worksheet.set_column('A:B', 25)
    
    def _create_metrics_sheet(self, workbook, metrics, header_format, cell_format, number_format):
        """Crear hoja de métricas detalladas"""
        worksheet = workbook.add_worksheet('Detailed Metrics')
        
        worksheet.write('A1', 'Metric Name', header_format)
        worksheet.write('B1', 'Value', header_format)
        worksheet.write('C1', 'Type', header_format)
        
        row = 2
        for key, value in self._flatten_dict(metrics).items():
            worksheet.write(row, 0, key, cell_format)
            if isinstance(value, (int, float)):
                worksheet.write(row, 1, value, number_format)
            else:
                worksheet.write(row, 1, str(value), cell_format)
            worksheet.write(row, 2, type(value).__name__, cell_format)
            row += 1
        
        worksheet.set_column('A:C', 20)
    
    def _create_training_history_sheet(self, workbook, history, header_format, cell_format, number_format):
        """Crear hoja de historial de entrenamiento"""
        worksheet = workbook.add_worksheet('Training History')
        
        if not history:
            return
        
        # Headers
        df = pd.DataFrame(history)
        df['iteration'] = range(1, len(df) + 1)
        
        cols = ['iteration'] + [col for col in df.columns if col != 'iteration']
        
        for col, header in enumerate(cols):
            worksheet.write(0, col, header, header_format)
        
        # Datos
        for row, (_, data) in enumerate(df.iterrows(), 1):
            for col, value in enumerate(data[cols]):
                if isinstance(value, (int, float)):
                    worksheet.write(row, col, value, number_format)
                else:
                    worksheet.write(row, col, str(value), cell_format)
        
        worksheet.set_column('A:Z', 15)
    
    def _create_predictions_sheet(self, workbook, predictions_data, header_format, cell_format, number_format):
        """Crear hoja de predicciones"""
        worksheet = workbook.add_worksheet('Predictions')
        
        # Aquí iría la lógica específica para predictions_data
        # Dependiendo de la estructura de los datos
        pass


# Instancia global
export_utils = MLDataExportUtils()

def get_export_utils() -> MLDataExportUtils:
    """Obtener instancia de utilidades de exportación"""
    return export_utils