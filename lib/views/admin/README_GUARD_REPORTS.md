# Reportes de Actividad de Guardias

## Descripción
Esta funcionalidad permite generar reportes detallados sobre la actividad de los guardias en el sistema de control de acceso. Incluye análisis de asistencias, autorizaciones manuales, y estadísticas de rendimiento.

## Archivos Implementados

### Modelos
- `lib/models/guard_report_model.dart` - Modelos de datos para reportes de guardias
  - `GuardReportModel` - Reporte individual de un guardia
  - `GuardActivitySummaryModel` - Resumen general de actividad

### Servicios
- `lib/services/guard_reports_service.dart` - Servicio para obtener datos de reportes de guardias
  - Métodos para obtener resúmenes, rankings, y estadísticas
  - Soporte para exportación a CSV y PDF

### ViewModels
- `lib/viewmodels/guard_reports_viewmodel.dart` - Lógica de negocio para reportes de guardias
  - Gestión de estado y datos
  - Filtros y análisis locales
  - Integración con el servicio de reportes

### Vistas
- `lib/views/admin/guard_reports_view.dart` - Interfaz de usuario para reportes de guardias
  - 4 pestañas: Resumen General, Ranking Guardias, Actividad Diaria, Autorizaciones
  - Filtros de fecha
  - Gráficos y estadísticas visuales

### Extensiones
- `lib/viewmodels/reports_viewmodel.dart` - Extendido con funcionalidades específicas de guardias
- `lib/views/admin/reports_view.dart` - Actualizado para incluir pestaña de guardias

## Funcionalidades

### 1. Resumen General
- Total de asistencias en el período
- Número de guardias activos
- Cantidad de autorizaciones manuales
- Puerta más utilizada
- Facultad más atendida
- Promedio diario de actividad

### 2. Ranking de Guardias
- Lista ordenada por actividad
- Estadísticas individuales de cada guardia
- Entradas vs salidas
- Autorizaciones manuales
- Promedio diario de asistencias

### 3. Actividad Diaria
- Gráfico de actividad por día de la semana
- Análisis de patrones de trabajo
- Detalle por día

### 4. Autorizaciones
- Lista de guardias con más autorizaciones manuales
- Análisis de casos que requieren intervención manual
- Estadísticas de autorizaciones por guardia

## Características Técnicas

### Filtros de Fecha
- Selector de rango de fechas
- Actualización automática de datos al cambiar fechas
- Validación de rangos de fecha

### Análisis de Datos
- Cálculo de estadísticas en tiempo real
- Análisis de tendencias
- Identificación de patrones de actividad

### Interfaz de Usuario
- Diseño responsive
- Indicadores de carga
- Manejo de errores
- Actualización por pull-to-refresh

## Uso

1. Navegar a la sección de Reportes en el panel de administración
2. Seleccionar la pestaña "Guardias"
3. Configurar el rango de fechas deseado
4. Explorar las diferentes pestañas para análisis específicos

## Dependencias

- `provider` - Para gestión de estado
- `http` - Para comunicación con la API
- `flutter/material.dart` - Para componentes de UI

## Notas de Implementación

- Los datos se obtienen del servicio de API cuando está disponible
- Se incluye fallback a análisis local cuando el servicio no responde
- La funcionalidad está integrada con el sistema existente de reportes
- Compatible con la arquitectura MVVM del proyecto
