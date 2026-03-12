"""
Procesador de Datos Unificado - Sistema ACEES Group
Funcionalidades comunes de procesamiento de datos para todos los servicios ML
"""
import pandas as pd
import numpy as np
from typing import Dict, List, Any, Optional, Tuple, Union
from datetime import datetime, timedelta
import logging
from sklearn.preprocessing import StandardScaler, MinMaxScaler, LabelEncoder
from sklearn.model_selection import train_test_split
import warnings

class DataProcessor:
    """
    Procesador unificado de datos para ML
    Proporciona funciones comunes de limpieza, transformación y preparación
    """
    
    def __init__(self):
        self.logger = logging.getLogger("ml.data_processor")
        self.scalers = {}
        self.encoders = {}
        self.feature_columns = []
        self.target_column = None
        
    def clean_data(self, df: pd.DataFrame, **kwargs) -> pd.DataFrame:
        """
        Limpieza básica de datos
        
        Args:
            df: DataFrame a limpiar
            **kwargs: Configuraciones adicionales
            
        Returns:
            DataFrame limpio
        """
        df_clean = df.copy()
        initial_rows = len(df_clean)
        
        # Eliminar duplicados
        if kwargs.get('remove_duplicates', True):
            df_clean = df_clean.drop_duplicates()
            self.logger.info(f"Duplicados eliminados: {initial_rows - len(df_clean)}")
        
        # Eliminar filas completamente vacías
        df_clean = df_clean.dropna(how='all')
        
        # Limpiar fechas inválidas
        if 'fechaHora' in df_clean.columns:
            df_clean = self._clean_datetime_column(df_clean, 'fechaHora')
        
        # Limpiar valores string vacíos
        df_clean = df_clean.replace('', np.nan)
        df_clean = df_clean.replace('null', np.nan)
        df_clean = df_clean.replace('NULL', np.nan)
        
        # Convertir tipos de datos apropiados
        df_clean = self._convert_data_types(df_clean)
        
        self.logger.info(f"Limpieza completada: {len(df_clean)}/{initial_rows} filas mantenidas")
        return df_clean
    
    def _clean_datetime_column(self, df: pd.DataFrame, column: str) -> pd.DataFrame:
        """Limpiar columna de fecha/hora"""
        try:
            df[column] = pd.to_datetime(df[column], errors='coerce')
            # Eliminar fechas inválidas o futuras
            future_cutoff = datetime.now() + timedelta(days=1)
            past_cutoff = datetime.now() - timedelta(days=365*5)  # 5 años atrás
            
            invalid_dates = (df[column].isna()) | (df[column] > future_cutoff) | (df[column] < past_cutoff)
            
            if invalid_dates.sum() > 0:
                self.logger.warning(f"Fechas inválidas eliminadas: {invalid_dates.sum()}")
                df = df[~invalid_dates]
                
        except Exception as e:
            self.logger.error(f"Error procesando columna datetime {column}: {str(e)}")
            
        return df
    
    def _convert_data_types(self, df: pd.DataFrame) -> pd.DataFrame:
        """Convertir tipos de datos apropiados"""
        df_converted = df.copy()
        
        # Intentar convertir columnas numéricas
        numerical_candidates = ['count', 'total', 'num_', 'cantidad']
        
        for col in df_converted.columns:
            if any(candidate in col.lower() for candidate in numerical_candidates):
                try:
                    df_converted[col] = pd.to_numeric(df_converted[col], errors='coerce')
                except:
                    continue
        
        return df_converted
    
    def create_temporal_features(self, df: pd.DataFrame, datetime_col: str = 'fechaHora') -> pd.DataFrame:
        """
        Crear características temporales desde columna datetime
        
        Args:
            df: DataFrame con columna datetime
            datetime_col: Nombre de la columna datetime
            
        Returns:
            DataFrame con features temporales agregadas
        """
        df_temporal = df.copy()
        
        if datetime_col not in df_temporal.columns:
            self.logger.warning(f"Columna {datetime_col} no encontrada")
            return df_temporal
        
        # Asegurar que sea datetime
        df_temporal[datetime_col] = pd.to_datetime(df_temporal[datetime_col])
        
        # Features básicas temporales
        df_temporal['year'] = df_temporal[datetime_col].dt.year
        df_temporal['month'] = df_temporal[datetime_col].dt.month
        df_temporal['day'] = df_temporal[datetime_col].dt.day
        df_temporal['hour'] = df_temporal[datetime_col].dt.hour
        df_temporal['minute'] = df_temporal[datetime_col].dt.minute
        df_temporal['day_of_week'] = df_temporal[datetime_col].dt.dayofweek  # 0=Monday
        df_temporal['day_of_year'] = df_temporal[datetime_col].dt.dayofyear
        df_temporal['week_of_year'] = df_temporal[datetime_col].dt.isocalendar().week
        
        # Features cíclicas (sin/cos para capturar naturaleza cíclica)
        df_temporal['hour_sin'] = np.sin(2 * np.pi * df_temporal['hour'] / 24)
        df_temporal['hour_cos'] = np.cos(2 * np.pi * df_temporal['hour'] / 24)
        df_temporal['day_of_week_sin'] = np.sin(2 * np.pi * df_temporal['day_of_week'] / 7)
        df_temporal['day_of_week_cos'] = np.cos(2 * np.pi * df_temporal['day_of_week'] / 7)
        df_temporal['month_sin'] = np.sin(2 * np.pi * df_temporal['month'] / 12)
        df_temporal['month_cos'] = np.cos(2 * np.pi * df_temporal['month'] / 12)
        
        # Features de negocio específicas
        df_temporal['is_weekend'] = df_temporal['day_of_week'].isin([5, 6]).astype(int)
        df_temporal['is_business_hour'] = ((df_temporal['hour'] >= 7) & 
                                          (df_temporal['hour'] <= 18) &
                                          (df_temporal['day_of_week'] < 5)).astype(int)
        
        # Clasificación horarios
        df_temporal['time_period'] = pd.cut(
            df_temporal['hour'],
            bins=[0, 6, 12, 18, 24],
            labels=['madrugada', 'mañana', 'tarde', 'noche'],
            include_lowest=True
        )
        
        # Features de temporadas académicas (específico para universidad)
        df_temporal['is_semester_time'] = self._is_semester_period(df_temporal[datetime_col])
        df_temporal['is_exam_period'] = self._is_exam_period(df_temporal[datetime_col])
        
        self.logger.info(f"Features temporales creadas: {len([c for c in df_temporal.columns if c not in df.columns])}")
        return df_temporal
    
    def _is_semester_period(self, dates: pd.Series) -> pd.Series:
        """Determinar si fecha está en período semestral"""
        # Períodos típicos universitarios (ajustar según calendario específico)
        semester_periods = [
            (2, 6),   # Febrero - Junio
            (8, 12),  # Agosto - Diciembre
        ]
        
        is_semester = pd.Series(False, index=dates.index)
        
        for start_month, end_month in semester_periods:
            is_semester |= (dates.dt.month >= start_month) & (dates.dt.month <= end_month)
        
        return is_semester.astype(int)
    
    def _is_exam_period(self, dates: pd.Series) -> pd.Series:
        """Determinar si fecha está en período de exámenes"""
        # Típicamente últimas 2 semanas de cada semestre
        exam_periods = [
            (5, 3), (5, 4),  # Mayo semanas 3-4
            (6, 1), (6, 2),  # Junio semanas 1-2  
            (11, 3), (11, 4), # Noviembre semanas 3-4
            (12, 1), (12, 2)  # Diciembre semanas 1-2
        ]
        
        is_exam = pd.Series(False, index=dates.index)
        
        for month, week in exam_periods:
            month_mask = dates.dt.month == month
            week_mask = dates.dt.isocalendar().week == dates[month_mask].dt.isocalendar().week.mode().iloc[0] + week - 1
            is_exam |= month_mask & week_mask
        
        return is_exam.astype(int)
    
    def aggregate_by_time_window(self, 
                                df: pd.DataFrame, 
                                datetime_col: str = 'fechaHora',
                                window: str = '1H',
                                agg_functions: Dict[str, List[str]] = None) -> pd.DataFrame:
        """
        Agregar datos por ventana temporal
        
        Args:
            df: DataFrame con datos temporales
            datetime_col: Columna datetime para agrupar
            window: Ventana temporal ('1H', '30min', '1D', etc.)
            agg_functions: Diccionario {columna: [funciones_agregación]}
            
        Returns:
            DataFrame agregado por ventana temporal
        """
        if agg_functions is None:
            agg_functions = {
                'count': ['count', 'sum'],
                'total': ['sum', 'mean'],
            }
        
        df_agg = df.copy()
        df_agg[datetime_col] = pd.to_datetime(df_agg[datetime_col])
        df_agg = df_agg.set_index(datetime_col)
        
        # Realizar agregación
        aggregated_data = []
        
        for col, functions in agg_functions.items():
            if col in df_agg.columns:
                for func in functions:
                    agg_col_name = f"{col}_{func}_{window}"
                    if func == 'count':
                        aggregated_data.append(df_agg[col].resample(window).count().rename(agg_col_name))
                    elif func == 'sum':
                        aggregated_data.append(df_agg[col].resample(window).sum().rename(agg_col_name))
                    elif func == 'mean':
                        aggregated_data.append(df_agg[col].resample(window).mean().rename(agg_col_name))
                    elif func == 'max':
                        aggregated_data.append(df_agg[col].resample(window).max().rename(agg_col_name))
                    elif func == 'min':
                        aggregated_data.append(df_agg[col].resample(window).min().rename(agg_col_name))
                    elif func == 'std':
                        aggregated_data.append(df_agg[col].resample(window).std().rename(agg_col_name))
        
        # Combinar todas las agregaciones
        if aggregated_data:
            df_result = pd.concat(aggregated_data, axis=1)
            df_result = df_result.fillna(0)  # Llenar NaN con 0
            df_result = df_result.reset_index()
            
            self.logger.info(f"Agregación temporal completada: {len(df_result)} ventanas de {window}")
            return df_result
        else:
            self.logger.warning("No se pudo realizar agregación temporal")
            return df
    
    def create_lag_features(self, 
                           df: pd.DataFrame, 
                           target_col: str, 
                           lags: List[int] = None) -> pd.DataFrame:
        """
        Crear características lag para series temporales
        
        Args:
            df: DataFrame ordenado temporalmente
            target_col: Columna objetivo para crear lags
            lags: Lista de períodos lag (default: [1, 2, 3, 24, 168])
            
        Returns:
            DataFrame con features lag agregadas
        """
        if lags is None:
            lags = [1, 2, 3, 24, 168]  # 1h, 2h, 3h, 1día, 1semana
        
        if target_col not in df.columns:
            self.logger.warning(f"Columna {target_col} no encontrada para lags")
            return df
        
        df_lag = df.copy()
        
        for lag in lags:
            lag_col = f"{target_col}_lag_{lag}"
            df_lag[lag_col] = df_lag[target_col].shift(lag)
            
            # Rolling features
            if lag >= 3:
                rolling_mean_col = f"{target_col}_rolling_mean_{lag}"
                rolling_std_col = f"{target_col}_rolling_std_{lag}"
                
                df_lag[rolling_mean_col] = df_lag[target_col].rolling(window=lag, min_periods=1).mean()
                df_lag[rolling_std_col] = df_lag[target_col].rolling(window=lag, min_periods=1).std()
        
        # Eliminar filas con NaN causadas por shift (solo las necesarias)
        df_lag = df_lag.dropna(subset=[f"{target_col}_lag_1"])
        
        self.logger.info(f"Features lag creadas: {len(lags) * 3} aproximadamente")
        return df_lag
    
    def scale_features(self, 
                      df: pd.DataFrame, 
                      feature_columns: List[str], 
                      scaler_type: str = 'standard',
                      fit_transform: bool = True) -> pd.DataFrame:
        """
        Escalar características numéricas
        
        Args:
            df: DataFrame con características
            feature_columns: Lista de columnas a escalar
            scaler_type: 'standard' o 'minmax'  
            fit_transform: True=fit y transform, False=solo transform
            
        Returns:
            DataFrame con características escaladas
        """
        df_scaled = df.copy()
        
        # Inicializar scaler si no existe
        scaler_key = f"{scaler_type}_{'-'.join(feature_columns[:3])}"  # Key truncada
        
        if fit_transform or scaler_key not in self.scalers:
            if scaler_type == 'standard':
                self.scalers[scaler_key] = StandardScaler()
            elif scaler_type == 'minmax':
                self.scalers[scaler_key] = MinMaxScaler()
            else:
                raise ValueError(f"scaler_type no soportado: {scaler_type}")
        
        scaler = self.scalers[scaler_key]
        
        # Filtrar columnas que existen
        existing_columns = [col for col in feature_columns if col in df_scaled.columns]
        
        if not existing_columns:
            self.logger.warning("Ninguna columna de features encontrada para escalar")
            return df_scaled
        
        # Escalar solo columnas numéricas
        numeric_columns = df_scaled[existing_columns].select_dtypes(include=[np.number]).columns.tolist()
        
        if numeric_columns:
            if fit_transform:
                df_scaled[numeric_columns] = scaler.fit_transform(df_scaled[numeric_columns])
            else:
                df_scaled[numeric_columns] = scaler.transform(df_scaled[numeric_columns])
            
            self.logger.info(f"Escalado aplicado a {len(numeric_columns)} columnas con {scaler_type}")
        else:
            self.logger.warning("No se encontraron columnas numéricas para escalar")
        
        return df_scaled
    
    def encode_categorical(self, 
                          df: pd.DataFrame, 
                          categorical_columns: List[str], 
                          encoding_type: str = 'label',
                          fit_transform: bool = True) -> pd.DataFrame:
        """
        Codificar variables categóricas
        
        Args:
            df: DataFrame con variables categóricas
            categorical_columns: Lista de columnas categóricas
            encoding_type: 'label', 'onehot' (futuro)
            fit_transform: True=fit y transform, False=solo transform
            
        Returns:
            DataFrame con variables codificadas
        """
        df_encoded = df.copy()
        
        for col in categorical_columns:
            if col not in df_encoded.columns:
                continue
            
            if encoding_type == 'label':
                encoder_key = f"label_{col}"
                
                if fit_transform or encoder_key not in self.encoders:
                    self.encoders[encoder_key] = LabelEncoder()
                
                encoder = self.encoders[encoder_key]
                
                # Manejar valores NaN
                non_null_mask = df_encoded[col].notna()
                
                if non_null_mask.sum() > 0:
                    if fit_transform:
                        df_encoded.loc[non_null_mask, col] = encoder.fit_transform(
                            df_encoded.loc[non_null_mask, col].astype(str)
                        )
                    else:
                        # Para transform, manejar valores no vistos
                        try:
                            df_encoded.loc[non_null_mask, col] = encoder.transform(
                                df_encoded.loc[non_null_mask, col].astype(str)
                            )
                        except ValueError as e:
                            self.logger.warning(f"Valores no vistos en {col}, usando valor por defecto")
                            # Asignar valor por defecto para valores no vistos
                            df_encoded.loc[non_null_mask, col] = 0
        
        self.logger.info(f"Encoding aplicado a {len(categorical_columns)} columnas")
        return df_encoded
    
    def split_train_test(self, 
                        df: pd.DataFrame, 
                        target_column: str,
                        test_size: float = 0.2,
                        temporal_split: bool = True) -> Tuple[pd.DataFrame, pd.DataFrame, pd.Series, pd.Series]:
        """
        División train/test con opción temporal
        
        Args:
            df: DataFrame completo
            target_column: Columna objetivo
            test_size: Proporción para test
            temporal_split: True=split temporal, False=random split
            
        Returns:
            Tuple (X_train, X_test, y_train, y_test)
        """
        if target_column not in df.columns:
            raise ValueError(f"Columna objetivo {target_column} no encontrada")
        
        # Separar features y target
        X = df.drop(columns=[target_column])
        y = df[target_column]
        
        if temporal_split and 'fechaHora' in df.columns:
            # Split temporal - últimos registros para test
            split_index = int(len(df) * (1 - test_size))
            
            X_train = X.iloc[:split_index]
            X_test = X.iloc[split_index:]
            y_train = y.iloc[:split_index]
            y_test = y.iloc[split_index:]
            
            self.logger.info(f"Split temporal aplicado: train={len(X_train)}, test={len(X_test)}")
        else:
            # Split aleatorio
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=test_size, random_state=42, stratify=None
            )
            
            self.logger.info(f"Split aleatorio aplicado: train={len(X_train)}, test={len(X_test)}")
        
        return X_train, X_test, y_train, y_test
    
    def get_processing_summary(self) -> Dict[str, Any]:
        """
        Obtener resumen del procesamiento aplicado
        
        Returns:
            Dict con resumen de transformaciones
        """
        return {
            'scalers_fitted': list(self.scalers.keys()),
            'encoders_fitted': list(self.encoders.keys()),
            'feature_columns': self.feature_columns,
            'target_column': self.target_column,
            'processing_timestamp': datetime.now().isoformat()
        }