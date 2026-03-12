"""
Servicio de Regresión Lineal ML - Sistema ACEES Group
Implementación de regresión lineal para predicción de asistencias (RF009.1)
"""
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import logging
from sklearn.linear_model import LinearRegression, Ridge, Lasso, ElasticNet
from sklearn.preprocessing import StandardScaler, PolynomialFeatures
from sklearn.model_selection import cross_val_score, GridSearchCV
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
import pickle
import joblib
from pathlib import Path

from backend.ml_python.core.base_ml_service import BaseMLService
from backend.ml_python.core.model_manager import get_model_manager
from backend.ml_python.utils.metrics_calculator import get_metrics_calculator
from backend.ml_python.config.ml_config import get_ml_config
from backend.ml_python.data.dataset_builder import get_dataset_builder

class LinearRegressionMLService(BaseMLService):
    """
    Servicio de regresión lineal para predicción
    Implementa RF009.1: R² >= 0.7 en predicciones
    """
    
    def __init__(self):
        super().__init__()
        self.service_name = "LinearRegressionMLService"
        self.model_manager = get_model_manager()
        self.ml_config = get_ml_config()
        
        # Configuraciones específicas (RF009.1)
        self.target_r2_score = self.ml_config.TARGET_R2_SCORE
        self.min_samples_train = self.ml_config.min_training_samples
        
        # Modelos disponibles
        self.model_types = {
            'linear': LinearRegression(),
            'ridge': Ridge(alpha=1.0),
            'lasso': Lasso(alpha=1.0),
            'elastic_net': ElasticNet(alpha=1.0, l1_ratio=0.5)
        }
        
        # Cachés
        self.current_model = None
        self.current_scaler = None
        self.current_poly_features = None
        self.training_history = []
        
        self.logger.info(f"Inicializado {self.service_name} - Target R²: {self.target_r2_score}")
    
    async def train_model(self, 
                         training_config: Dict[str, Any],
                         dataset_id: Optional[str] = None,
                         custom_data: Optional[pd.DataFrame] = None) -> Dict[str, Any]:
        """
        Entrenar modelo de regresión lineal
        
        Args:
            training_config: Configuración de entrenamiento
            dataset_id: ID del dataset preprocesado
            custom_data: Datos personalizados
            
        Returns:
            Resultado del entrenamiento con métricas
        """
        try:
            self.logger.info("Iniciando entrenamiento de regresión lineal")
            
            # Obtener datos de entrenamiento
            if dataset_id:
                train_data = await self.model_manager.load_dataset(dataset_id)
                X_train = train_data['train']['X']
                y_train = train_data['train']['y'] 
                X_val = train_data.get('validation', {}).get('X')
                y_val = train_data.get('validation', {}).get('y')
            elif custom_data is not None:
                # Usar datos personalizados
                target_column = training_config.get('target_column', 'count')
                if target_column not in custom_data.columns:
                    raise ValueError(f"Columna objetivo '{target_column}' no encontrada")
                
                X_train = custom_data.drop(target_column, axis=1)
                y_train = custom_data[target_column]
                X_val = y_val = None
            else:
                # Construir dataset automáticamente
                dataset_builder = await get_dataset_builder()
                dataset_result = await dataset_builder.build_dataset(
                    model_type="regression",
                    dataset_config=training_config.get('dataset_config', {}),
                    target_column=training_config.get('target_column', 'count')
                )
                
                splits = dataset_result['splits']
                # Cargar splits (esto sería implementado en model_manager)
                X_train = splits['train']['X']
                y_train = splits['train']['y']
                X_val = splits.get('validation', {}).get('X')
                y_val = splits.get('validation', {}).get('y')
            
            # Validar datos
            if len(X_train) < self.min_samples_train:
                raise ValueError(f"Datos insuficientes: {len(X_train)} < {self.min_samples_train}")
            
            # Preprocesamiento
            X_train_processed, y_train_processed = await self._preprocess_training_data(
                X_train, y_train, training_config
            )
            
            # Seleccionar y configurar modelo
            model_name = training_config.get('model_type', 'ridge')
            model = await self._configure_model(model_name, training_config)
            
            # Entrenamiento
            model.fit(X_train_processed, y_train_processed)
            self.current_model = model
            
            # Evaluación en entrenamiento
            y_train_pred = model.predict(X_train_processed)
            train_metrics = await self._calculate_metrics(y_train_processed, y_train_pred, "train")
            
            # Evaluación en validación si está disponible
            val_metrics = {}
            if X_val is not None and y_val is not None:
                X_val_processed = await self._apply_preprocessing(X_val)
                y_val_pred = model.predict(X_val_processed)
                val_metrics = await self._calculate_metrics(y_val, y_val_pred, "validation")
            
            # Validación cruzada
            cv_scores = cross_val_score(model, X_train_processed, y_train_processed, 
                                      cv=min(5, len(X_train) // 10), 
                                      scoring='r2')
            
            # Verificar cumplimiento RF009.1
            final_r2 = val_metrics.get('r2_score', train_metrics.get('r2_score', 0))
            meets_requirement = final_r2 >= self.target_r2_score
            
            # Guardar modelo si cumple requisitos
            model_id = None
            if meets_requirement or training_config.get('force_save', False):
                model_metadata = {
                    'model_type': 'linear_regression',
                    'algorithm': model_name,
                    'target_r2': self.target_r2_score,
                    'achieved_r2': final_r2,
                    'meets_rf009_1': meets_requirement,
                    'training_samples': len(X_train),
                    'feature_count': X_train_processed.shape[1],
                    'training_config': training_config,
                    'training_timestamp': datetime.now().isoformat(),
                    'cross_val_scores': cv_scores.tolist()
                }
                
                model_artifacts = {
                    'model': model,
                    'scaler': self.current_scaler,
                    'poly_features': self.current_poly_features,
                    'feature_names': list(X_train.columns)
                }
                
                model_id = await self.model_manager.save_model(
                    model_artifacts, model_metadata
                )
            
            # Resultado del entrenamiento
            result = {
                'success': True,
                'model_id': model_id,
                'model_type': model_name,
                'metrics': {
                    'train': train_metrics,
                    'validation': val_metrics,
                    'cross_validation': {
                        'mean_r2': cv_scores.mean(),
                        'std_r2': cv_scores.std(),
                        'scores': cv_scores.tolist()
                    }
                },
                'rf009_1_compliance': {
                    'target_r2': self.target_r2_score,
                    'achieved_r2': final_r2,
                    'meets_requirement': meets_requirement,
                    'requirement_status': 'PASS' if meets_requirement else 'FAIL'
                },
                'model_info': {
                    'algorithm': model_name,
                    'features': X_train_processed.shape[1],
                    'samples': len(X_train),
                    'hyperparameters': self._get_model_params(model)
                },
                'training_completed_at': datetime.now().isoformat()
            }
            
            # Registrar en historial
            self.training_history.append({
                'timestamp': datetime.now(),
                'model_type': model_name,
                'r2_score': final_r2,
                'meets_rf009_1': meets_requirement,
                'model_id': model_id
            })
            
            self.logger.info(f"Entrenamiento completado - R²: {final_r2:.3f}, RF009.1: {'PASS' if meets_requirement else 'FAIL'}")
            return result
            
        except Exception as e:
            self.logger.error(f"Error en entrenamiento: {str(e)}")
            raise
    
    async def predict(self, 
                     X: pd.DataFrame,
                     model_id: Optional[str] = None,
                     return_confidence: bool = False) -> Dict[str, Any]:
        """
        Realizar predicciones con modelo entrenado
        
        Args:
            X: Features para predicción
            model_id: ID del modelo específico (usa actual si None)
            return_confidence: Retornar intervalos de confianza
            
        Returns:
            Predicciones y metadatos
        """
        try:
            self.logger.info(f"Realizando predicciones para {len(X)} muestras")
            
            # Cargar modelo si se especifica ID
            if model_id:
                model_artifacts = await self.model_manager.load_model(model_id)
                model = model_artifacts['model']
                scaler = model_artifacts.get('scaler')
                poly_features = model_artifacts.get('poly_features')
                feature_names = model_artifacts.get('feature_names', [])
            else:
                # Usar modelo actual
                if self.current_model is None:
                    raise ValueError("No hay modelo entrenado disponible")
                model = self.current_model
                scaler = self.current_scaler
                poly_features = self.current_poly_features
                feature_names = []
            
            # Preprocesar datos
            X_processed = X.copy()
            
            # Aplicar escalado
            if scaler:
                numeric_cols = X_processed.select_dtypes(include=[np.number]).columns
                X_processed[numeric_cols] = scaler.transform(X_processed[numeric_cols])
            
            # Aplicar features polinomiales
            if poly_features:
                X_processed = pd.DataFrame(
                    poly_features.transform(X_processed),
                    columns=poly_features.get_feature_names_out(),
                    index=X.index
                )
            
            # Realizar predicciones
            predictions = model.predict(X_processed)
            
            # Calcular intervalos de confianza si se solicita
            prediction_intervals = None
            if return_confidence and hasattr(model, 'predict') and len(predictions) > 1:
                # Estimación simple de intervalos usando residuos de entrenamiento
                # (En producción se usaría un método más robusto)
                residual_std = getattr(model, '_residual_std', np.std(predictions) * 0.1)
                confidence_level = 0.95
                z_score = 1.96  # Para 95% confianza
                
                prediction_intervals = {
                    'lower_bound': predictions - z_score * residual_std,
                    'upper_bound': predictions + z_score * residual_std,
                    'confidence_level': confidence_level
                }
            
            # Preparar resultado
            result = {
                'success': True,
                'predictions': predictions.tolist(),
                'prediction_count': len(predictions),
                'model_info': {
                    'model_id': model_id,
                    'model_type': type(model).__name__,
                    'feature_count': X_processed.shape[1]
                }
            }
            
            if prediction_intervals:
                result['confidence_intervals'] = {
                    'lower_bound': prediction_intervals['lower_bound'].tolist(),
                    'upper_bound': prediction_intervals['upper_bound'].tolist(),
                    'confidence_level': prediction_intervals['confidence_level']
                }
            
            if hasattr(X, 'index'):
                result['predictions_df'] = pd.DataFrame({
                    'prediction': predictions
                }, index=X.index).to_dict('records')
            
            result['prediction_timestamp'] = datetime.now().isoformat()
            
            self.logger.info(f"Predicciones completadas: {len(predictions)} valores")
            return result
            
        except Exception as e:
            self.logger.error(f"Error en predicción: {str(e)}")
            raise
    
    async def evaluate_model(self, 
                           X_test: pd.DataFrame,
                           y_test: pd.Series,
                           model_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Evaluar modelo en datos de test
        
        Args:
            X_test: Features de test
            y_test: Valores reales de test
            model_id: ID del modelo específico
            
        Returns:
            Métricas de evaluación
        """
        try:
            self.logger.info("Evaluando modelo en datos de test")
            
            # Obtener predicciones
            prediction_result = await self.predict(X_test, model_id)
            predictions = np.array(prediction_result['predictions'])
            
            # Calcular métricas
            metrics_calculator = await get_metrics_calculator()
            detailed_metrics = await metrics_calculator.calculate_regression_metrics(
                y_test.values, predictions
            )
            
            # Verificar cumplimiento RF009.1 en test
            test_r2 = detailed_metrics['r2_score']
            meets_rf009_1 = test_r2 >= self.target_r2_score
            
            # Análisis de errores
            errors = predictions - y_test.values
            error_analysis = {
                'mean_error': float(np.mean(errors)),
                'std_error': float(np.std(errors)),
                'max_error': float(np.max(np.abs(errors))),
                'error_percentiles': {
                    '25th': float(np.percentile(errors, 25)),
                    '50th': float(np.percentile(errors, 50)),
                    '75th': float(np.percentile(errors, 75)),
                    '90th': float(np.percentile(errors, 90)),
                    '95th': float(np.percentile(errors, 95))
                }
            }
            
            # Resultado de evaluación
            evaluation_result = {
                'success': True,
                'test_samples': len(X_test),
                'metrics': detailed_metrics,
                'rf009_1_test_compliance': {
                    'target_r2': self.target_r2_score,
                    'achieved_r2': test_r2,
                    'meets_requirement': meets_rf009_1,
                    'requirement_status': 'PASS' if meets_rf009_1 else 'FAIL'
                },
                'error_analysis': error_analysis,
                'prediction_quality': {
                    'within_10_percent': np.sum(np.abs(errors / y_test.values) <= 0.1) / len(y_test),
                    'within_20_percent': np.sum(np.abs(errors / y_test.values) <= 0.2) / len(y_test),
                    'within_30_percent': np.sum(np.abs(errors / y_test.values) <= 0.3) / len(y_test)
                },
                'evaluation_timestamp': datetime.now().isoformat()
            }
            
            self.logger.info(f"Evaluación completada - R² Test: {test_r2:.3f}")
            return evaluation_result
            
        except Exception as e:
            self.logger.error(f"Error en evaluación: {str(e)}")
            raise
    
    async def hyperparameter_tuning(self, 
                                  X_train: pd.DataFrame,
                                  y_train: pd.Series,
                                  tuning_config: Dict[str, Any]) -> Dict[str, Any]:
        """
        Optimización de hiperparámetros
        
        Args:
            X_train: Features de entrenamiento
            y_train: Target de entrenamiento
            tuning_config: Configuración de tuning
            
        Returns:
            Mejores hiperparámetros y resultados
        """
        try:
            self.logger.info("Iniciando optimización de hiperparámetros")
            
            # Preprocesar datos
            X_processed, y_processed = await self._preprocess_training_data(
                X_train, y_train, tuning_config
            )
            
            # Configurar parametrización
            model_type = tuning_config.get('model_type', 'ridge')
            param_grids = tuning_config.get('param_grids', self._get_default_param_grids())
            
            if model_type not in param_grids:
                raise ValueError(f"Tipo de modelo no soportado para tuning: {model_type}")
            
            # Configurar modelo base
            base_model = self.model_types[model_type]
            
            # Grid Search
            cv_folds = tuning_config.get('cv_folds', 5)
            scoring = tuning_config.get('scoring', 'r2')
            
            grid_search = GridSearchCV(
                base_model,
                param_grids[model_type],
                cv=cv_folds,
                scoring=scoring,
                n_jobs=-1,
                verbose=1
            )
            
            # Ejecutar búsqueda
            grid_search.fit(X_processed, y_processed)
            
            # Mejores parámetros
            best_model = grid_search.best_estimator_
            best_params = grid_search.best_params_
            best_score = grid_search.best_score_
            
            # Evaluación del mejor modelo
            best_predictions = best_model.predict(X_processed)
            best_metrics = await self._calculate_metrics(y_processed, best_predictions, "tuning")
            
            # Verificar cumplimiento RF009.1
            meets_rf009_1 = best_metrics['r2_score'] >= self.target_r2_score
            
            # Resultado del tuning
            tuning_result = {
                'success': True,
                'best_model_type': model_type,
                'best_parameters': best_params,
                'best_cv_score': best_score,
                'best_metrics': best_metrics,
                'rf009_1_compliance': {
                    'target_r2': self.target_r2_score,
                    'achieved_r2': best_metrics['r2_score'],
                    'meets_requirement': meets_rf009_1,
                    'requirement_status': 'PASS' if meets_rf009_1 else 'FAIL'
                },
                'cv_results': {
                    'mean_test_scores': grid_search.cv_results_['mean_test_score'].tolist(),
                    'params': grid_search.cv_results_['params']
                },
                'tuning_completed_at': datetime.now().isoformat()
            }
            
            # Actualizar modelo actual si es mejor
            if meets_rf009_1 and best_metrics['r2_score'] > getattr(self, '_best_r2_score', 0):
                self.current_model = best_model
                self._best_r2_score = best_metrics['r2_score']
            
            self.logger.info(f"Tuning completado - Mejor R²: {best_score:.3f}")
            return tuning_result
            
        except Exception as e:
            self.logger.error(f"Error en tuning de hiperparámetros: {str(e)}")
            raise
    
    async def _preprocess_training_data(self, 
                                      X: pd.DataFrame, 
                                      y: pd.Series, 
                                      config: Dict[str, Any]) -> Tuple[pd.DataFrame, pd.Series]:
        """Preprocesar datos de entrenamiento"""
        try:
            X_processed = X.copy()
            y_processed = y.copy()
            
            # Manejar valores nulos
            if X_processed.isnull().sum().sum() > 0:
                # Para numéricas: mediana
                numeric_cols = X_processed.select_dtypes(include=[np.number]).columns
                X_processed[numeric_cols] = X_processed[numeric_cols].fillna(
                    X_processed[numeric_cols].median()
                )
                
                # Para categóricas: moda
                cat_cols = X_processed.select_dtypes(include=['object']).columns
                for col in cat_cols:
                    X_processed[col] = X_processed[col].fillna(X_processed[col].mode()[0] if len(X_processed[col].mode()) > 0 else 'unknown')
            
            # Escalado de features numéricas
            if config.get('scale_features', True):
                from sklearn.preprocessing import StandardScaler
                self.current_scaler = StandardScaler()
                numeric_cols = X_processed.select_dtypes(include=[np.number]).columns
                if len(numeric_cols) > 0:
                    X_processed[numeric_cols] = self.current_scaler.fit_transform(X_processed[numeric_cols])
            
            # Features polinomiales
            poly_degree = config.get('polynomial_degree', None)
            if poly_degree and poly_degree > 1:
                self.current_poly_features = PolynomialFeatures(
                    degree=poly_degree, 
                    include_bias=False
                )
                numeric_cols = X_processed.select_dtypes(include=[np.number]).columns
                if len(numeric_cols) > 0 and len(numeric_cols) <= 10:  # Limitar para evitar explosión
                    X_poly = self.current_poly_features.fit_transform(X_processed[numeric_cols])
                    feature_names = self.current_poly_features.get_feature_names_out(numeric_cols)
                    X_processed = pd.DataFrame(X_poly, columns=feature_names, index=X_processed.index)
            
            # Codificación categórica
            cat_cols = X_processed.select_dtypes(include=['object']).columns
            if len(cat_cols) > 0:
                X_processed = pd.get_dummies(X_processed, columns=cat_cols, drop_first=True)
            
            return X_processed, y_processed
            
        except Exception as e:
            self.logger.error(f"Error en preprocesamiento: {str(e)}")
            raise
    
    async def _apply_preprocessing(self, X: pd.DataFrame) -> pd.DataFrame:
        """Aplicar preprocesamiento usando transformadores entrenados"""
        try:
            X_processed = X.copy()
            
            # Aplicar escalado
            if self.current_scaler:
                numeric_cols = X_processed.select_dtypes(include=[np.number]).columns
                X_processed[numeric_cols] = self.current_scaler.transform(X_processed[numeric_cols])
            
            # Aplicar features polinomiales
            if self.current_poly_features:
                numeric_cols = X_processed.select_dtypes(include=[np.number]).columns
                X_poly = self.current_poly_features.transform(X_processed[numeric_cols])
                feature_names = self.current_poly_features.get_feature_names_out(numeric_cols)
                X_processed = pd.DataFrame(X_poly, columns=feature_names, index=X.index)
            
            return X_processed
            
        except Exception as e:
            self.logger.error(f"Error aplicando preprocesamiento: {str(e)}")
            raise
    
    async def _configure_model(self, model_name: str, config: Dict[str, Any]):
        """Configurar modelo con hiperparámetros"""
        try:
            if model_name == 'linear':
                return LinearRegression()
            
            elif model_name == 'ridge':
                alpha = config.get('alpha', 1.0)
                return Ridge(alpha=alpha, random_state=42)
            
            elif model_name == 'lasso':
                alpha = config.get('alpha', 1.0)
                return Lasso(alpha=alpha, random_state=42, max_iter=2000)
            
            elif model_name == 'elastic_net':
                alpha = config.get('alpha', 1.0)
                l1_ratio = config.get('l1_ratio', 0.5)
                return ElasticNet(alpha=alpha, l1_ratio=l1_ratio, random_state=42, max_iter=2000)
            
            else:
                raise ValueError(f"Tipo de modelo no soportado: {model_name}")
                
        except Exception as e:
            self.logger.error(f"Error configurando modelo: {str(e)}")
            raise
    
    async def _calculate_metrics(self, y_true: np.ndarray, y_pred: np.ndarray, split_name: str) -> Dict[str, Any]:
        """Calcular métricas de evaluación"""
        try:
            metrics_calculator = await get_metrics_calculator()
            metrics = await metrics_calculator.calculate_regression_metrics(y_true, y_pred)
            
            # RF009.1 compliance check específico
            meets_rf009_1 = metrics['r2_score'] >= self.target_r2_score
            metrics['rf009_1_compliant'] = meets_rf009_1
            metrics['split'] = split_name
            
            return metrics
            
        except Exception as e:
            self.logger.error(f"Error calculando métricas: {str(e)}")
            raise
    
    def _get_model_params(self, model) -> Dict[str, Any]:
        """Obtener parámetros del modelo"""
        try:
            return model.get_params()
        except:
            return {}
    
    def _get_default_param_grids(self) -> Dict[str, List[Dict[str, Any]]]:
        """Obtener grillas de parámetros por defecto"""
        return {
            'ridge': {
                'alpha': [0.1, 1.0, 10.0, 100.0]
            },
            'lasso': {
                'alpha': [0.1, 1.0, 10.0]
            },
            'elastic_net': {
                'alpha': [0.1, 1.0, 10.0],
                'l1_ratio': [0.1, 0.5, 0.7, 0.9]
            }
        }
    
    async def get_training_history(self) -> List[Dict[str, Any]]:
        """Obtener historial de entrenamientos"""
        return [
            {
                'timestamp': entry['timestamp'].isoformat(),
                'model_type': entry['model_type'],
                'r2_score': entry['r2_score'],
                'meets_rf009_1': entry['meets_rf009_1'],
                'model_id': entry['model_id']
            }
            for entry in self.training_history
        ]
    
    async def get_best_model_info(self) -> Dict[str, Any]:
        """Obtener información del mejor modelo"""
        try:
            if not self.training_history:
                return {'message': 'No hay modelos entrenados'}
            
            # Filtrar modelos que cumplen RF009.1
            compliant_models = [m for m in self.training_history if m['meets_rf009_1']]
            
            if compliant_models:
                best_model = max(compliant_models, key=lambda x: x['r2_score'])
            else:
                best_model = max(self.training_history, key=lambda x: x['r2_score'])
            
            return {
                'best_model_id': best_model['model_id'],
                'r2_score': best_model['r2_score'],
                'meets_rf009_1': best_model['meets_rf009_1'],
                'trained_at': best_model['timestamp'].isoformat(),
                'model_type': best_model['model_type']
            }
            
        except Exception as e:
            self.logger.error(f"Error obteniendo mejor modelo: {str(e)}")
            return {'error': str(e)}


# Instancia global
linear_regression_service = LinearRegressionMLService()

async def get_linear_regression_service() -> LinearRegressionMLService:
    """Obtener instancia del servicio de regresión lineal"""
    return linear_regression_service