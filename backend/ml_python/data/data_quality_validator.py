"""
Validador de Calidad de Datos ML - Sistema ACEES Group
Validación automática de calidad de datos para ML (US030)
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import logging
from dataclasses import dataclass
from enum import Enum

from backend.ml_python.core.base_ml_service import BaseMLService
from backend.ml_python.config.ml_config import get_ml_config

class DataQualityRuleType(Enum):
    """Tipos de reglas de calidad de datos"""
    COMPLETENESS = "completeness"
    UNIQUENESS = "uniqueness" 
    VALIDITY = "validity"
    CONSISTENCY = "consistency"
    ACCURACY = "accuracy"
    TIMELINESS = "timeliness"

@dataclass
class DataQualityRule:
    """Definición de regla de calidad"""
    name: str
    rule_type: DataQualityRuleType
    description: str
    threshold: float  # Valor mínimo aceptable (0.0 - 1.0)
    severity: str  # 'critical', 'warning', 'info'
    columns: Optional[List[str]] = None
    condition: Optional[str] = None

@dataclass
class DataQualityResult:
    """Resultado de validación de calidad"""
    rule_name: str
    passed: bool
    score: float
    threshold: float
    severity: str
    details: str
    affected_columns: List[str]
    affected_rows: int

class MLDataQualityValidator(BaseMLService):
    """
    Validador automático de calidad de datos para ML
    """
    
    def __init__(self):
        super().__init__()
        self.service_name = "MLDataQualityValidator"
        self.ml_config = get_ml_config()
        
        # Configurar reglas por defecto
        self.default_rules = self._setup_default_rules()
        
        self.logger.info(f"Inicializado {self.service_name} con {len(self.default_rules)} reglas")
    
    def _setup_default_rules(self) -> List[DataQualityRule]:
        """Configurar reglas de calidad por defecto"""
        return [
            # Reglas de completitud
            DataQualityRule(
                name="completeness_critical",
                rule_type=DataQualityRuleType.COMPLETENESS,
                description="Porcentaje mínimo de valores no nulos en columnas críticas",
                threshold=0.95,
                severity="critical",
                columns=["hourlyDateTime", "count", "area"]
            ),
            DataQualityRule(
                name="completeness_general",
                rule_type=DataQualityRuleType.COMPLETENESS,
                description="Porcentaje mínimo de valores no nulos general",
                threshold=0.8,
                severity="warning"
            ),
            
            # Reglas de unicidad
            DataQualityRule(
                name="uniqueness_primary_keys",
                rule_type=DataQualityRuleType.UNIQUENESS,
                description="Porcentaje máximo de duplicados en claves primarias",
                threshold=0.05,  # Máximo 5% duplicados
                severity="critical",
                columns=["hourlyDateTime", "area"]
            ),
            
            # Reglas de validez
            DataQualityRule(
                name="validity_count_positive",
                rule_type=DataQualityRuleType.VALIDITY,
                description="Valores de conteo deben ser positivos",
                threshold=0.98,
                severity="critical",
                columns=["count"],
                condition="count >= 0"
            ),
            DataQualityRule(
                name="validity_datetime_format",
                rule_type=DataQualityRuleType.VALIDITY,
                description="Formato válido de fechas",
                threshold=1.0,
                severity="critical",
                columns=["hourlyDateTime"]
            ),
            
            # Reglas de consistencia
            DataQualityRule(
                name="consistency_temporal",
                rule_type=DataQualityRuleType.CONSISTENCY,
                description="Consistencia temporal en las fechas",
                threshold=0.95,
                severity="warning"
            ),
            DataQualityRule(
                name="consistency_area_names",
                rule_type=DataQualityRuleType.CONSISTENCY,
                description="Consistencia en nombres de áreas",
                threshold=0.9,
                severity="warning",
                columns=["area"]
            ),
            
            # Reglas de precisión
            DataQualityRule(
                name="accuracy_outlier_detection",
                rule_type=DataQualityRuleType.ACCURACY,
                description="Detección de outliers extremos",
                threshold=0.02,  # Máximo 2% outliers extremos
                severity="warning",
                columns=["count"]
            ),
            
            # Reglas de oportunidad
            DataQualityRule(
                name="timeliness_data_recency",
                rule_type=DataQualityRuleType.TIMELINESS,
                description="Datos deben ser recientes",
                threshold=0.8,
                severity="warning"
            )
        ]
    
    async def validate_dataset(self, 
                             df: pd.DataFrame,
                             custom_rules: Optional[List[DataQualityRule]] = None,
                             model_type: str = "general") -> Dict[str, Any]:
        """
        Validar calidad del dataset completo
        
        Args:
            df: DataFrame a validar
            custom_rules: Reglas personalizadas adicionales
            model_type: Tipo de modelo para reglas específicas
            
        Returns:
            Reporte completo de calidad
        """
        try:
            self.logger.info(f"Iniciando validación de calidad para dataset de {len(df)} registros")
            
            # Combinar reglas
            rules_to_apply = self.default_rules.copy()
            if custom_rules:
                rules_to_apply.extend(custom_rules)
            
            # Añadir reglas específicas por tipo de modelo
            rules_to_apply.extend(self._get_model_specific_rules(model_type))
            
            # Ejecutar validaciones
            results = []
            for rule in rules_to_apply:
                try:
                    result = await self._apply_quality_rule(df, rule)
                    results.append(result)
                except Exception as e:
                    self.logger.error(f"Error aplicando regla {rule.name}: {str(e)}")
                    # Añadir resultado de fallo
                    results.append(DataQualityResult(
                        rule_name=rule.name,
                        passed=False,
                        score=0.0,
                        threshold=rule.threshold,
                        severity=rule.severity,
                        details=f"Error ejecutando regla: {str(e)}",
                        affected_columns=[],
                        affected_rows=0
                    ))
            
            # Generar reporte
            report = await self._generate_quality_report(df, results)
            
            self.logger.info(f"Validación completada. Score general: {report['overall_score']:.3f}")
            return report
            
        except Exception as e:
            self.logger.error(f"Error en validación de calidad: {str(e)}")
            raise
    
    async def _apply_quality_rule(self, df: pd.DataFrame, rule: DataQualityRule) -> DataQualityResult:
        """Aplicar regla específica de calidad"""
        try:
            if rule.rule_type == DataQualityRuleType.COMPLETENESS:
                return await self._check_completeness(df, rule)
            elif rule.rule_type == DataQualityRuleType.UNIQUENESS:
                return await self._check_uniqueness(df, rule)
            elif rule.rule_type == DataQualityRuleType.VALIDITY:
                return await self._check_validity(df, rule)
            elif rule.rule_type == DataQualityRuleType.CONSISTENCY:
                return await self._check_consistency(df, rule)
            elif rule.rule_type == DataQualityRuleType.ACCURACY:
                return await self._check_accuracy(df, rule)
            elif rule.rule_type == DataQualityRuleType.TIMELINESS:
                return await self._check_timeliness(df, rule)
            else:
                raise ValueError(f"Tipo de regla no soportado: {rule.rule_type}")
                
        except Exception as e:
            self.logger.error(f"Error aplicando regla {rule.name}: {str(e)}")
            raise
    
    async def _check_completeness(self, df: pd.DataFrame, rule: DataQualityRule) -> DataQualityResult:
        """Verificar completitud de datos"""
        try:
            columns_to_check = rule.columns if rule.columns else df.columns
            
            # Verificar que las columnas existan
            existing_columns = [col for col in columns_to_check if col in df.columns]
            if not existing_columns:
                return DataQualityResult(
                    rule_name=rule.name,
                    passed=False,
                    score=0.0,
                    threshold=rule.threshold,
                    severity=rule.severity,
                    details="Ninguna de las columnas especificadas existe",
                    affected_columns=columns_to_check,
                    affected_rows=0
                )
            
            # Calcular completitud
            if len(existing_columns) == 1:
                # Una sola columna
                col = existing_columns[0]
                non_null_count = df[col].notna().sum()
                total_count = len(df)
                completeness = non_null_count / total_count if total_count > 0 else 0
                affected_rows = total_count - non_null_count
            else:
                # Múltiples columnas
                non_null_counts = df[existing_columns].notna().sum()
                total_possible = len(df) * len(existing_columns)
                completeness = non_null_counts.sum() / total_possible if total_possible > 0 else 0
                affected_rows = len(df) - df[existing_columns].notna().all(axis=1).sum()
            
            passed = completeness >= rule.threshold
            
            return DataQualityResult(
                rule_name=rule.name,
                passed=passed,
                score=completeness,
                threshold=rule.threshold,
                severity=rule.severity,
                details=f"Completitud: {completeness:.3f} ({'PASS' if passed else 'FAIL'})",
                affected_columns=existing_columns,
                affected_rows=affected_rows
            )
            
        except Exception as e:
            raise Exception(f"Error verificando completitud: {str(e)}")
    
    async def _check_uniqueness(self, df: pd.DataFrame, rule: DataQualityRule) -> DataQualityResult:
        """Verificar unicidad de datos"""
        try:
            columns_to_check = rule.columns if rule.columns else df.columns
            existing_columns = [col for col in columns_to_check if col in df.columns]
            
            if not existing_columns:
                return DataQualityResult(
                    rule_name=rule.name,
                    passed=False,
                    score=0.0,
                    threshold=rule.threshold,
                    severity=rule.severity,
                    details="Columnas no encontradas",
                    affected_columns=columns_to_check,
                    affected_rows=0
                )
            
            # Verificar duplicados
            duplicates = df.duplicated(subset=existing_columns, keep=False)
            duplicate_count = duplicates.sum()
            total_count = len(df)
            
            # Score de unicidad (inverso del ratio de duplicados)
            duplicate_ratio = duplicate_count / total_count if total_count > 0 else 0
            uniqueness_score = 1 - duplicate_ratio
            
            # Para esta regla, el threshold es el máximo de duplicados permitido
            passed = duplicate_ratio <= rule.threshold
            
            return DataQualityResult(
                rule_name=rule.name,
                passed=passed,
                score=uniqueness_score,
                threshold=rule.threshold,
                severity=rule.severity,
                details=f"Duplicados: {duplicate_count}/{total_count} ({duplicate_ratio:.3f})",
                affected_columns=existing_columns,
                affected_rows=duplicate_count
            )
            
        except Exception as e:
            raise Exception(f"Error verificando unicidad: {str(e)}")
    
    async def _check_validity(self, df: pd.DataFrame, rule: DataQualityRule) -> DataQualityResult:
        """Verificar validez de datos"""
        try:
            columns_to_check = rule.columns if rule.columns else df.columns
            existing_columns = [col for col in columns_to_check if col in df.columns]
            
            if not existing_columns:
                return DataQualityResult(
                    rule_name=rule.name,
                    passed=False,
                    score=0.0,
                    threshold=rule.threshold,
                    severity=rule.severity,
                    details="Columnas no encontradas",
                    affected_columns=columns_to_check,
                    affected_rows=0
                )
            
            total_rows = len(df)
            valid_rows = 0
            
            for col in existing_columns:
                if rule.condition:
                    # Aplicar condición específica
                    condition = rule.condition.replace(col, f"df['{col}']")
                    try:
                        valid_mask = eval(condition)
                        valid_rows += valid_mask.sum()
                    except Exception as e:
                        self.logger.error(f"Error evaluando condición {rule.condition}: {str(e)}")
                        continue
                else:
                    # Validaciones por defecto según tipo de columna
                    if col == 'hourlyDateTime':
                        # Validar formato de fecha
                        valid_dates = pd.to_datetime(df[col], errors='coerce').notna()
                        valid_rows += valid_dates.sum()
                    elif df[col].dtype in ['int64', 'float64']:
                        # Valores numéricos válidos (no NaN, no infinitos)
                        valid_numeric = np.isfinite(df[col])
                        valid_rows += valid_numeric.sum()
                    else:
                        # Para otros tipos, considerar válidos los no-nulos
                        valid_rows += df[col].notna().sum()
            
            # Score promedio por columna
            max_possible_valid = total_rows * len(existing_columns)
            validity_score = valid_rows / max_possible_valid if max_possible_valid > 0 else 0
            
            passed = validity_score >= rule.threshold
            affected_rows = max_possible_valid - valid_rows
            
            return DataQualityResult(
                rule_name=rule.name,
                passed=passed,
                score=validity_score,
                threshold=rule.threshold,
                severity=rule.severity,
                details=f"Validez: {validity_score:.3f} ({valid_rows}/{max_possible_valid})",
                affected_columns=existing_columns,
                affected_rows=affected_rows
            )
            
        except Exception as e:
            raise Exception(f"Error verificando validez: {str(e)}")
    
    async def _check_consistency(self, df: pd.DataFrame, rule: DataQualityRule) -> DataQualityResult:
        """Verificar consistencia de datos"""
        try:
            if rule.name == "consistency_temporal":
                return await self._check_temporal_consistency(df, rule)
            elif rule.name == "consistency_area_names":
                return await self._check_area_names_consistency(df, rule)
            else:
                # Consistencia general
                return DataQualityResult(
                    rule_name=rule.name,
                    passed=True,
                    score=1.0,
                    threshold=rule.threshold,
                    severity=rule.severity,
                    details="Regla de consistencia no implementada específicamente",
                    affected_columns=[],
                    affected_rows=0
                )
                
        except Exception as e:
            raise Exception(f"Error verificando consistencia: {str(e)}")
    
    async def _check_temporal_consistency(self, df: pd.DataFrame, rule: DataQualityRule) -> DataQualityResult:
        """Verificar consistencia temporal"""
        try:
            if 'hourlyDateTime' not in df.columns:
                return DataQualityResult(
                    rule_name=rule.name,
                    passed=False,
                    score=0.0,
                    threshold=rule.threshold,
                    severity=rule.severity,
                    details="Columna hourlyDateTime no encontrada",
                    affected_columns=['hourlyDateTime'],
                    affected_rows=0
                )
            
            # Convertir a datetime
            df_temp = df.copy()
            df_temp['hourlyDateTime'] = pd.to_datetime(df_temp['hourlyDateTime'], errors='coerce')
            
            # Verificaciones temporales
            valid_timestamps = df_temp['hourlyDateTime'].notna()
            
            # Verificar orden cronológico (si está ordenado)
            chronological_order = True
            if len(df_temp) > 1:
                sorted_df = df_temp.sort_values('hourlyDateTime')
                chronological_order = df_temp['hourlyDateTime'].equals(sorted_df['hourlyDateTime'])
            
            # Verificar rangos razonables (últimos 5 años)
            now = datetime.now()
            five_years_ago = now - timedelta(days=5*365)
            reasonable_dates = ((df_temp['hourlyDateTime'] >= five_years_ago) & 
                              (df_temp['hourlyDateTime'] <= now)).sum()
            
            # Score combinado
            consistency_factors = [
                valid_timestamps.sum() / len(df),
                1.0 if chronological_order else 0.5,
                reasonable_dates / len(df)
            ]
            
            consistency_score = np.mean(consistency_factors)
            passed = consistency_score >= rule.threshold
            affected_rows = len(df) - valid_timestamps.sum()
            
            return DataQualityResult(
                rule_name=rule.name,
                passed=passed,
                score=consistency_score,
                threshold=rule.threshold,
                severity=rule.severity,
                details=f"Consistencia temporal: {consistency_score:.3f}",
                affected_columns=['hourlyDateTime'],
                affected_rows=affected_rows
            )
            
        except Exception as e:
            raise Exception(f"Error verificando consistencia temporal: {str(e)}")
    
    async def _check_area_names_consistency(self, df: pd.DataFrame, rule: DataQualityRule) -> DataQualityResult:
        """Verificar consistencia de nombres de áreas"""
        try:
            if 'area' not in df.columns:
                return DataQualityResult(
                    rule_name=rule.name,
                    passed=False,
                    score=0.0,
                    threshold=rule.threshold,
                    severity=rule.severity,
                    details="Columna area no encontrada",
                    affected_columns=['area'],
                    affected_rows=0
                )
            
            # Verificar patrones inconsistentes en nombres de áreas
            area_names = df['area'].dropna().astype(str)
            unique_areas = area_names.unique()
            
            # Detectar posibles inconsistencias
            inconsistencies = 0
            total_checks = 0
            
            for area in unique_areas:
                # Verificar espacios extras
                if area != area.strip():
                    inconsistencies += (area_names == area).sum()
                
                # Verificar capitalización inconsistente
                similar_areas = [a for a in unique_areas if a.lower() == area.lower() and a != area]
                if similar_areas:
                    inconsistencies += (area_names.isin([area] + similar_areas)).sum()
                
                total_checks += (area_names == area).sum()
            
            # Score de consistencia
            consistency_score = 1 - (inconsistencies / len(area_names)) if len(area_names) > 0 else 1.0
            passed = consistency_score >= rule.threshold
            
            return DataQualityResult(
                rule_name=rule.name,
                passed=passed,
                score=consistency_score,
                threshold=rule.threshold,
                severity=rule.severity,
                details=f"Consistencia áreas: {consistency_score:.3f} ({len(unique_areas)} áreas únicas)",
                affected_columns=['area'],
                affected_rows=inconsistencies
            )
            
        except Exception as e:
            raise Exception(f"Error verificando consistencia de áreas: {str(e)}")
    
    async def _check_accuracy(self, df: pd.DataFrame, rule: DataQualityRule) -> DataQualityResult:
        """Verificar precisión de datos (detección de outliers)"""
        try:
            columns_to_check = rule.columns if rule.columns else df.select_dtypes(include=[np.number]).columns
            existing_columns = [col for col in columns_to_check if col in df.columns]
            
            if not existing_columns:
                return DataQualityResult(
                    rule_name=rule.name,
                    passed=True,
                    score=1.0,
                    threshold=rule.threshold,
                    severity=rule.severity,
                    details="No hay columnas numéricas para verificar",
                    affected_columns=[],
                    affected_rows=0
                )
            
            total_outliers = 0
            total_values = 0
            
            for col in existing_columns:
                if col in df.columns and df[col].dtype in ['int64', 'float64']:
                    values = df[col].dropna()
                    
                    if len(values) > 0:
                        # Detección de outliers usando IQR
                        Q1 = values.quantile(0.25)
                        Q3 = values.quantile(0.75)
                        IQR = Q3 - Q1
                        
                        lower_bound = Q1 - 3 * IQR  # 3 IQR para outliers extremos
                        upper_bound = Q3 + 3 * IQR
                        
                        outliers = ((values < lower_bound) | (values > upper_bound)).sum()
                        total_outliers += outliers
                        total_values += len(values)
            
            # Score de precisión (inverso del ratio de outliers)
            outlier_ratio = total_outliers / total_values if total_values > 0 else 0
            accuracy_score = 1 - outlier_ratio
            
            # Para esta regla, el threshold es el máximo de outliers permitido
            passed = outlier_ratio <= rule.threshold
            
            return DataQualityResult(
                rule_name=rule.name,
                passed=passed,
                score=accuracy_score,
                threshold=rule.threshold,
                severity=rule.severity,
                details=f"Outliers: {total_outliers}/{total_values} ({outlier_ratio:.3f})",
                affected_columns=existing_columns,
                affected_rows=total_outliers
            )
            
        except Exception as e:
            raise Exception(f"Error verificando precisión: {str(e)}")
    
    async def _check_timeliness(self, df: pd.DataFrame, rule: DataQualityRule) -> DataQualityResult:
        """Verificar oportunidad de datos"""
        try:
            if 'hourlyDateTime' not in df.columns:
                return DataQualityResult(
                    rule_name=rule.name,
                    passed=False,
                    score=0.0,
                    threshold=rule.threshold,
                    severity=rule.severity,
                    details="No hay columna de fecha para verificar oportunidad",
                    affected_columns=['hourlyDateTime'],
                    affected_rows=0
                )
            
            # Convertir a datetime
            df_temp = df.copy()
            df_temp['hourlyDateTime'] = pd.to_datetime(df_temp['hourlyDateTime'], errors='coerce')
            
            # Verificar qué tan recientes son los datos
            now = datetime.now()
            max_date = df_temp['hourlyDateTime'].max()
            
            if pd.isna(max_date):
                timeliness_score = 0.0
            else:
                days_old = (now - max_date).days
                # Score decrece exponencialmente con la edad
                # 100% para datos de hoy, 80% para 1 semana, etc.
                timeliness_score = max(0.0, 1.0 - (days_old / 30.0))
            
            passed = timeliness_score >= rule.threshold
            
            return DataQualityResult(
                rule_name=rule.name,
                passed=passed,
                score=timeliness_score,
                threshold=rule.threshold,
                severity=rule.severity,
                details=f"Oportunidad: {timeliness_score:.3f} (último dato: {max_date})",
                affected_columns=['hourlyDateTime'],
                affected_rows=0 if passed else len(df)
            )
            
        except Exception as e:
            raise Exception(f"Error verificando oportunidad: {str(e)}")
    
    def _get_model_specific_rules(self, model_type: str) -> List[DataQualityRule]:
        """Obtener reglas específicas por tipo de modelo"""
        specific_rules = []
        
        if model_type == "regression":
            specific_rules.extend([
                DataQualityRule(
                    name="regression_target_distribution",
                    rule_type=DataQualityRuleType.ACCURACY,
                    description="Distribución de variable objetivo para regresión",
                    threshold=0.1,  # Máximo 10% outliers en variable objetivo
                    severity="warning",
                    columns=["count"]
                )
            ])
        
        elif model_type == "clustering":
            specific_rules.extend([
                DataQualityRule(
                    name="clustering_feature_variance",
                    rule_type=DataQualityRuleType.VALIDITY,
                    description="Varianza mínima en features para clustering",
                    threshold=0.95,
                    severity="warning"
                )
            ])
        
        elif model_type == "time_series":
            specific_rules.extend([
                DataQualityRule(
                    name="time_series_regularity",
                    rule_type=DataQualityRuleType.CONSISTENCY,
                    description="Regularidad temporal en series de tiempo",
                    threshold=0.9,
                    severity="critical"
                )
            ])
        
        return specific_rules
    
    async def _generate_quality_report(self, df: pd.DataFrame, results: List[DataQualityResult]) -> Dict[str, Any]:
        """Generar reporte completo de calidad"""
        try:
            # Agrupar resultados por severidad
            critical_failures = [r for r in results if r.severity == "critical" and not r.passed]
            warnings = [r for r in results if r.severity == "warning" and not r.passed]
            info_items = [r for r in results if r.severity == "info" and not r.passed]
            
            # Calcular scores por categoría
            completeness_results = [r for r in results if "completeness" in r.rule_name]
            uniqueness_results = [r for r in results if "uniqueness" in r.rule_name]
            validity_results = [r for r in results if "validity" in r.rule_name]
            consistency_results = [r for r in results if "consistency" in r.rule_name]
            accuracy_results = [r for r in results if "accuracy" in r.rule_name]
            timeliness_results = [r for r in results if "timeliness" in r.rule_name]
            
            def calculate_category_score(category_results):
                if not category_results:
                    return 1.0
                return np.mean([r.score for r in category_results])
            
            category_scores = {
                'completeness': calculate_category_score(completeness_results),
                'uniqueness': calculate_category_score(uniqueness_results),
                'validity': calculate_category_score(validity_results),
                'consistency': calculate_category_score(consistency_results),
                'accuracy': calculate_category_score(accuracy_results),
                'timeliness': calculate_category_score(timeliness_results)
            }
            
            # Score general ponderado
            weights = {
                'completeness': 0.25,
                'uniqueness': 0.15,
                'validity': 0.25,
                'consistency': 0.15,
                'accuracy': 0.10,
                'timeliness': 0.10
            }
            
            overall_score = sum(score * weights[category] 
                              for category, score in category_scores.items())
            
            # Determinar status general
            if critical_failures:
                overall_status = "CRITICAL"
            elif len(warnings) > 3:
                overall_status = "WARNING"
            elif overall_score < 0.8:
                overall_status = "NEEDS_IMPROVEMENT"
            else:
                overall_status = "GOOD"
            
            # Estadísticas básicas del dataset
            dataset_stats = {
                'total_rows': len(df),
                'total_columns': len(df.columns),
                'memory_usage_mb': df.memory_usage(deep=True).sum() / (1024**2),
                'null_values_total': df.isnull().sum().sum(),
                'duplicate_rows': df.duplicated().sum(),
                'numeric_columns': len(df.select_dtypes(include=[np.number]).columns),
                'categorical_columns': len(df.select_dtypes(include=['object']).columns),
                'datetime_columns': len(df.select_dtypes(include=['datetime64']).columns)
            }
            
            # Generar recomendaciones
            recommendations = await self._generate_recommendations(results, df)
            
            # Reporte completo
            quality_report = {
                'overall_score': round(overall_score, 3),
                'overall_status': overall_status,
                'validation_timestamp': datetime.now().isoformat(),
                'dataset_stats': dataset_stats,
                'category_scores': {k: round(v, 3) for k, v in category_scores.items()},
                'rule_results': [
                    {
                        'rule_name': r.rule_name,
                        'passed': r.passed,
                        'score': round(r.score, 3),
                        'threshold': r.threshold,
                        'severity': r.severity,
                        'details': r.details,
                        'affected_columns': r.affected_columns,
                        'affected_rows': r.affected_rows
                    }
                    for r in results
                ],
                'issues': {
                    'critical': len(critical_failures),
                    'warnings': len(warnings),
                    'info': len(info_items)
                },
                'critical_failures': [
                    {
                        'rule': r.rule_name,
                        'details': r.details,
                        'affected_rows': r.affected_rows
                    }
                    for r in critical_failures
                ],
                'recommendations': recommendations,
                'is_ml_ready': overall_score >= 0.8 and len(critical_failures) == 0,
                'quality_certification': {
                    'meets_ml_standards': overall_score >= 0.8,
                    'certification_level': self._get_certification_level(overall_score),
                    'valid_until': (datetime.now() + timedelta(days=30)).isoformat()
                }
            }
            
            return quality_report
            
        except Exception as e:
            self.logger.error(f"Error generando reporte de calidad: {str(e)}")
            raise
    
    async def _generate_recommendations(self, results: List[DataQualityResult], df: pd.DataFrame) -> List[str]:
        """Generar recomendaciones basadas en resultados"""
        recommendations = []
        
        # Analizar fallos por tipo
        failed_results = [r for r in results if not r.passed]
        
        for result in failed_results:
            if "completeness" in result.rule_name:
                if result.affected_rows > len(df) * 0.1:
                    recommendations.append(f"Considerar imputación para {result.affected_columns} - {result.affected_rows} registros afectados")
                else:
                    recommendations.append(f"Remover registros incompletos en {result.affected_columns}")
            
            elif "uniqueness" in result.rule_name:
                recommendations.append(f"Investigar y remover duplicados en {result.affected_columns}")
            
            elif "validity" in result.rule_name:
                recommendations.append(f"Validar y corregir valores inválidos en {result.affected_columns}")
            
            elif "accuracy" in result.rule_name and result.affected_rows > 0:
                recommendations.append(f"Revisar {result.affected_rows} outliers potenciales")
            
            elif "consistency" in result.rule_name:
                recommendations.append(f"Estandarizar formato y valores en {result.affected_columns}")
        
        # Recomendaciones generales
        if df.isnull().sum().sum() > len(df) * len(df.columns) * 0.1:
            recommendations.append("Dataset tiene alto porcentaje de valores nulos - considerar estrategia de imputación")
        
        if len(df) < self.ml_config.min_training_samples:
            recommendations.append(f"Dataset pequeño ({len(df)} registros) - considerar obtener más datos")
        
        return recommendations
    
    def _get_certification_level(self, score: float) -> str:
        """Determinar nivel de certificación"""
        if score >= 0.95:
            return "PREMIUM"
        elif score >= 0.85:
            return "STANDARD"
        elif score >= 0.75:
            return "BASIC"
        else:
            return "INSUFFICIENT"


# Instancia global
quality_validator = MLDataQualityValidator()

async def get_quality_validator() -> MLDataQualityValidator:
    """Obtener instancia del validador de calidad"""
    return quality_validator