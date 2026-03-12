# -*- coding: utf-8 -*-
"""
Entrenamiento de Modelos ML para Acees Group
Basado en metodología del proyecto de enfermedades cardíacas
Adaptado para predicción de accesos universitarios
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from typing import Dict, List, Tuple, Any
import warnings
warnings.filterwarnings("ignore")

# Sklearn imports (igual que tu proyecto médico)
from sklearn.model_selection import train_test_split, cross_val_score, cross_validate, RandomizedSearchCV
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.metrics import (
    mean_absolute_error, mean_squared_error, r2_score,
    accuracy_score, precision_score, recall_score, f1_score, 
    confusion_matrix, classification_report
)

# Modelos de regresión (principales para Acees)
from sklearn.linear_model import LinearRegression, Ridge, Lasso
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.tree import DecisionTreeRegressor
from sklearn.svm import SVR
from sklearn.neighbors import KNeighborsRegressor

# Modelos de clasificación (para horarios pico)
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.tree import DecisionTreeClassifier
from sklearn.svm import SVC
from sklearn.neighbors import KNeighborsClassifier

# Data preparation
from data_preparation import AceesDatasetCreator

class AceesMLTrainer:
    """
    Entrenador de modelos ML para Acees Group
    Sigue la misma metodología que el proyecto médico
    """
    
    def __init__(self, mongo_uri: str):
        self.creator = AceesDatasetCreator(mongo_uri)
        self.random_state = 42
        np.random.seed(self.random_state)
        
        # Configurar visualización (igual que tu proyecto)
        plt.rc('font', size=12)
        plt.rc('axes', labelsize=12, titlesize=12)
        plt.rc('legend', fontsize=11)
        plt.rc('xtick', labelsize=10)
        plt.rc('ytick', labelsize=10)
    
    def prepare_data(self, months: int = 3, problem_type: str = "regression") -> Tuple[pd.DataFrame, pd.Series, Dict]:
        """
        Preparar datos siguiendo tu metodología médica
        """
        print("="*80)
        print("PREPARACIÓN DE DATOS - ACEES GROUP ML")
        print("="*80)
        
        # Recopilar datos históricos
        df = self.creator.collect_historical_data(months=months)
        summary = self.creator.get_dataset_summary(df)
        
        # Crear dataset según tipo de problema
        if problem_type == "regression":
            X, y = self.creator.create_regression_dataset(df)
            print(f"\n✅ Problema de REGRESIÓN configurado")
            print(f"   Target: Número de accesos por hora")
        
        elif problem_type == "classification":
            X, y = self.creator.create_classification_dataset(df, threshold=50)
            print(f"\n✅ Problema de CLASIFICACIÓN configurado")
            print(f"   Target: Horario pico (≥50 accesos) vs Normal")
        
        elif problem_type == "multiclass":
            X, y = self.creator.create_multiclass_dataset(df)
            print(f"\n✅ Problema MULTI-CLASE configurado")
            print(f"   Target: Nivel congestión (0=vacío, 1=bajo, 2=medio, 3=alto)")
        
        return X, y, summary
    
    def split_data(self, X: pd.DataFrame, y: pd.Series, test_size: float = 0.2) -> Tuple:
        """
        División estratificada del dataset (igual que proyecto médico)
        """
        # Para regresión, no podemos usar stratify directamente
        if y.dtype in ['int64', 'float64'] and len(y.unique()) > 10:
            # Es regresión - división simple
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=test_size, random_state=self.random_state
            )
        else:
            # Es clasificación - división estratificada
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=test_size, random_state=self.random_state, stratify=y
            )
        
        print(f"\n✅ División del dataset:")
        print(f"   Train set: {X_train.shape}")
        print(f"   Test set: {X_test.shape}")
        
        return X_train, X_test, y_train, y_test
    
    def create_preprocessor(self, X: pd.DataFrame) -> ColumnTransformer:
        """
        Pipeline de preprocesamiento (igual que tu proyecto médico)
        """
        # Identificar tipos de columnas
        numeric_features = X.select_dtypes(include=[np.number]).columns.tolist()
        categorical_features = X.select_dtypes(include=['object', 'category']).columns.tolist()
        
        print(f"\n✅ Preprocesamiento configurado:")
        print(f"   Variables numéricas: {numeric_features}")
        print(f"   Variables categóricas: {categorical_features}")
        
        # Pipelines de transformación
        numeric_pipe = Pipeline([
            ('scaler', StandardScaler())
        ])
        
        categorical_pipe = Pipeline([
            ('onehot', OneHotEncoder(drop='first', sparse_output=False, handle_unknown='ignore'))
        ])
        
        # ColumnTransformer
        preprocessor = ColumnTransformer([
            ('num', numeric_pipe, numeric_features),
            ('cat', categorical_pipe, categorical_features)
        ], remainder='drop')
        
        return preprocessor
    
    def get_regression_models(self) -> Dict:
        """
        Modelos de regresión para predecir número de accesos
        """
        return {
            "Linear Regression": LinearRegression(),
            "Ridge Regression": Ridge(random_state=self.random_state),
            "Random Forest": RandomForestRegressor(random_state=self.random_state, n_estimators=100),
            "Gradient Boosting": GradientBoostingRegressor(random_state=self.random_state),
            "Decision Tree": DecisionTreeRegressor(random_state=self.random_state),
            "SVR": SVR(),
            "KNN": KNeighborsRegressor()
        }
    
    def get_classification_models(self) -> Dict:
        """
        Modelos de clasificación para horarios pico
        """
        return {
            "Logistic Regression": LogisticRegression(random_state=self.random_state, max_iter=1000),
            "Random Forest": RandomForestClassifier(random_state=self.random_state, n_estimators=100),
            "Gradient Boosting": GradientBoostingClassifier(random_state=self.random_state),
            "Decision Tree": DecisionTreeClassifier(random_state=self.random_state),
            "SVC": SVC(random_state=self.random_state, probability=True),
            "KNN": KNeighborsClassifier()
        }
    
    def evaluate_regression_model(self, name: str, model: Any, X: pd.DataFrame, y: pd.Series, cv: int = 10) -> Dict:
        """
        Evaluación de modelo de regresión (adaptado de tu función médica)
        """
        scoring = {
            'mae': 'neg_mean_absolute_error',
            'mse': 'neg_mean_squared_error', 
            'r2': 'r2'
        }
        
        scores = cross_validate(model, X, y, scoring=scoring, cv=cv, n_jobs=-1)
        
        # Convertir a positivo (sklearn devuelve negativos)
        mae_scores = -scores['test_mae']
        mse_scores = -scores['test_mse']
        r2_scores = scores['test_r2']
        rmse_scores = np.sqrt(mse_scores)
        
        print(f"\n{'='*60}")
        print(f"{name}")
        print(f"{'='*60}")
        print(f"MAE:   {mae_scores.mean():.4f} ± {mae_scores.std():.4f}")
        print(f"RMSE:  {rmse_scores.mean():.4f} ± {rmse_scores.std():.4f}")
        print(f"R²:    {r2_scores.mean():.4f} ± {r2_scores.std():.4f}")
        
        return {
            'model_name': name,
            'mae': mae_scores.mean(),
            'rmse': rmse_scores.mean(), 
            'r2': r2_scores.mean(),
            'mae_std': mae_scores.std(),
            'rmse_std': rmse_scores.std(),
            'r2_std': r2_scores.std()
        }
    
    def evaluate_classification_model(self, name: str, model: Any, X: pd.DataFrame, y: pd.Series, cv: int = 10) -> Dict:
        """
        Evaluación de modelo de clasificación (igual que tu proyecto médico)
        """
        scoring = {
            'accuracy': 'accuracy',
            'precision': 'precision_macro',
            'recall': 'recall_macro',
            'f1': 'f1_macro'
        }
        
        scores = cross_validate(model, X, y, scoring=scoring, cv=cv, n_jobs=-1)
        
        print(f"\n{'='*60}")
        print(f"{name}")
        print(f"{'='*60}")
        print(f"Accuracy:  {scores['test_accuracy'].mean():.4f} ± {scores['test_accuracy'].std():.4f}")
        print(f"Precision: {scores['test_precision'].mean():.4f} ± {scores['test_precision'].std():.4f}")
        print(f"Recall:    {scores['test_recall'].mean():.4f} ± {scores['test_recall'].std():.4f}")
        print(f"F1-Score:  {scores['test_f1'].mean():.4f} ± {scores['test_f1'].std():.4f}")
        
        return {
            'model_name': name,
            'accuracy': scores['test_accuracy'].mean(),
            'precision': scores['test_precision'].mean(),
            'recall': scores['test_recall'].mean(),
            'f1': scores['test_f1'].mean()
        }
    
    def train_and_evaluate(self, problem_type: str = "regression", months: int = 3) -> Dict:
        """
        Pipeline completo de entrenamiento (igual estructura que proyecto médico)
        """
        # 1. Preparar datos
        X, y, summary = self.prepare_data(months=months, problem_type=problem_type)
        
        # 2. División train/test
        X_train, X_test, y_train, y_test = self.split_data(X, y)
        
        # 3. Preprocesamiento
        preprocessor = self.create_preprocessor(X_train)
        
        # 4. Crear pipelines de modelos
        if problem_type == "regression":
            base_models = self.get_regression_models()
            evaluate_func = self.evaluate_regression_model
        else:
            base_models = self.get_classification_models()
            evaluate_func = self.evaluate_classification_model
        
        models = {}
        for name, model in base_models.items():
            models[name] = Pipeline([
                ('prep', preprocessor),
                ('model', model)
            ])
        
        # 5. Evaluación con validación cruzada
        print("\n" + "="*80)
        print("EVALUACIÓN DE MODELOS (Validación Cruzada)")
        print("="*80)
        
        results = []
        for name, model in models.items():
            try:
                result = evaluate_func(name, model, X_train, y_train, cv=10)
                results.append(result)
            except Exception as e:
                print(f"❌ Error con {name}: {e}")
        
        # 6. Resumen de resultados (igual que tu proyecto)
        results_df = pd.DataFrame(results)
        if problem_type == "regression":
            results_df = results_df.sort_values('r2', ascending=False)
            print(f"\n{'='*80}")
            print("RESUMEN DE RESULTADOS - REGRESIÓN")
            print("="*80)
            print(results_df[['model_name', 'mae', 'rmse', 'r2']].to_string(index=False))
        else:
            results_df = results_df.sort_values('f1', ascending=False)
            print(f"\n{'='*80}")
            print("RESUMEN DE RESULTADOS - CLASIFICACIÓN") 
            print("="*80)
            print(results_df[['model_name', 'accuracy', 'precision', 'recall', 'f1']].to_string(index=False))
        
        return {
            'results': results_df,
            'models': models,
            'preprocessor': preprocessor,
            'X_train': X_train,
            'y_train': y_train,
            'X_test': X_test,
            'y_test': y_test,
            'summary': summary
        }

# Ejemplo de uso - ejecutar entrenamiento
if __name__ == "__main__":
    # Configuración
    MONGO_URI = "mongodb+srv://Angel:angel12345@cluster0.pas0twe.mongodb.net"
    
    print("INICIANDO ENTRENAMIENTO ML - ACEES GROUP")
    print("Basado en metodología de proyecto médico")
    print("="*80)
    
    # Crear trainer
    trainer = AceesMLTrainer(MONGO_URI)
    
    # Entrenar modelo de regresión
    results_regression = trainer.train_and_evaluate(
        problem_type="regression", 
        months=3
    )
    
    # Entrenar modelo de clasificación  
    results_classification = trainer.train_and_evaluate(
        problem_type="classification",
        months=3
    )
    
    print("\n🎯 ENTRENAMIENTO COMPLETADO")
    print("="*80)
    print("Modelos entrenados y evaluados:")
    print("- Regresión: Predice número de accesos por hora")
    print("- Clasificación: Predice horarios pico vs normales")
    print("- Metodología: Igual que proyecto médico pero adaptada para datos temporales")