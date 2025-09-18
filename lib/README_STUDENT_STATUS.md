# Consulta de Estado del Estudiante - Control de Acceso NFC

## Descripción
Esta funcionalidad permite a los guardias y administradores consultar el estado completo de cualquier estudiante, incluyendo su información personal, estado de presencia, historial de asistencias, estadísticas y alertas.

## Arquitectura

### Modelo de Datos

#### StudentStatusModel
- **Ubicación**: `lib/models/student_status_model.dart`
- **Propósito**: Modelo completo que encapsula toda la información del estado del estudiante
- **Características**:
  - Información básica del estudiante
  - Estado de presencia actual
  - Historial de asistencias recientes
  - Decisiones manuales recientes
  - Estadísticas calculadas
  - Alertas y recomendaciones

### Servicios

#### StudentStatusService
- **Ubicación**: `lib/services/student_status_service.dart`
- **Propósito**: Servicio para consultar información del estado del estudiante
- **Endpoints principales**:
  - `GET /estudiantes/{codigo}/estado` - Estado completo del estudiante
  - `GET /estudiantes/dni/{dni}/estado` - Estado por DNI
  - `GET /estudiantes/{codigo}/asistencias` - Historial de asistencias
  - `GET /estudiantes/{codigo}/presencia` - Presencia actual
  - `GET /estudiantes/{codigo}/decisiones` - Decisiones manuales
  - `GET /estudiantes/{codigo}/estadisticas` - Estadísticas
  - `GET /estudiantes/{codigo}/alertas` - Alertas
  - `GET /estudiantes/buscar` - Búsqueda de estudiantes
  - `GET /estudiantes/recientes` - Estudiantes recientes
  - `GET /estudiantes/alertas` - Estudiantes con alertas

### ViewModels

#### StudentStatusViewModel
- **Ubicación**: `lib/viewmodels/student_status_viewmodel.dart`
- **Propósito**: Gestión del estado y lógica de negocio para la consulta de estudiantes
- **Funcionalidades**:
  - Consulta de estado por código o DNI
  - Búsqueda de estudiantes
  - Gestión de estudiantes recientes
  - Filtrado y estadísticas
  - Carga de datos relacionados

### Vistas

#### StudentStatusView
- **Ubicación**: `lib/views/student_status_view.dart`
- **Propósito**: Vista principal de consulta con pestañas
- **Pestañas**:
  - **Búsqueda**: Búsqueda de estudiantes por nombre, código o DNI
  - **Recientes**: Lista de estudiantes consultados recientemente
  - **Alertas**: Estudiantes que requieren atención especial

#### StudentStatusDetailView
- **Ubicación**: `lib/views/student_status_detail_view.dart`
- **Propósito**: Vista detallada del estado de un estudiante específico
- **Pestañas**:
  - **Resumen**: Información general y estadísticas rápidas
  - **Presencia**: Estado actual de presencia en el campus
  - **Asistencias**: Historial de asistencias recientes
  - **Estadísticas**: Patrones de asistencia y análisis

#### StudentSearchView
- **Ubicación**: `lib/views/student_search_view.dart`
- **Propósito**: Búsqueda avanzada con filtros
- **Filtros disponibles**:
  - Estado (activo/inactivo)
  - Facultad
  - Escuela
  - Búsqueda por texto

## Funcionalidades Implementadas

### 1. Consulta Básica
- **Por código universitario**: Búsqueda directa usando el código del estudiante
- **Por DNI**: Búsqueda alternativa usando el DNI
- **Información mostrada**:
  - Datos personales completos
  - Estado de presencia actual
  - Última actividad registrada
  - Tiempo en campus (si está presente)

### 2. Búsqueda Avanzada
- **Búsqueda por texto**: Nombre, código o DNI
- **Filtros múltiples**: Estado, facultad, escuela
- **Resultados en tiempo real**: Búsqueda mientras se escribe
- **Estadísticas de búsqueda**: Contadores de resultados por categoría

### 3. Estado de Presencia
- **Estado actual**: En campus o fuera del campus
- **Información detallada**:
  - Hora de entrada/salida
  - Punto de entrada/salida
  - Guardia responsable
  - Tiempo transcurrido en campus
- **Indicadores visuales**: Colores y iconos para fácil identificación

### 4. Historial de Asistencias
- **Asistencias recientes**: Últimas 50 asistencias por defecto
- **Filtros por fecha**: Rango personalizable
- **Información detallada**:
  - Fecha y hora
  - Tipo de acceso (entrada/salida)
  - Punto de control
  - Autorización manual (si aplica)
  - Guardia responsable

### 5. Estadísticas y Análisis
- **Estadísticas básicas**:
  - Asistencias hoy/semana/mes
  - Total de entradas y salidas
  - Autorizaciones manuales
- **Patrones de asistencia**:
  - Distribución por día de la semana
  - Distribución por hora del día
  - Tendencias temporales
- **Decisiones manuales**:
  - Total de decisiones
  - Autorizadas vs rechazadas
  - Razones de rechazo más comunes

### 6. Alertas y Recomendaciones
- **Alertas automáticas**:
  - Estudiante inactivo
  - Muchas autorizaciones manuales
  - Tiempo excesivo en campus
  - Patrón de asistencia irregular
- **Recomendaciones**:
  - Próxima acción sugerida
  - Estado de acceso permitido
  - Requisitos especiales

### 7. Gestión de Estudiantes
- **Estudiantes recientes**: Lista de consultas recientes
- **Estudiantes con alertas**: Lista prioritaria
- **Búsqueda inteligente**: Sugerencias y autocompletado
- **Filtros dinámicos**: Por estado, facultad, escuela

## Integración en la Aplicación

### Para Administradores
- **Ubicación**: Dashboard de administración
- **Acceso**: Botón "Consultar Estudiante" en acciones rápidas
- **Funcionalidades completas**: Todas las características disponibles

### Para Guardias
- **Ubicación**: Vista principal de NFC
- **Acceso**: Botón "Consultar Estado Estudiante"
- **Funcionalidades**: Consulta básica y búsqueda

## Flujo de Uso

### 1. Acceso a la Funcionalidad
1. Usuario (admin o guardia) accede a la funcionalidad
2. Se presenta la vista principal con pestañas
3. Usuario puede buscar o navegar por las opciones disponibles

### 2. Búsqueda de Estudiante
1. Usuario ingresa criterios de búsqueda
2. Sistema muestra resultados en tiempo real
3. Usuario selecciona estudiante de la lista
4. Se navega a la vista detallada

### 3. Consulta de Estado Detallado
1. Se carga toda la información del estudiante
2. Se presentan las pestañas con diferentes aspectos
3. Usuario puede navegar entre resumen, presencia, asistencias y estadísticas
4. Se muestran alertas y recomendaciones relevantes

### 4. Análisis y Toma de Decisiones
1. Usuario revisa el estado completo del estudiante
2. Evalúa alertas y recomendaciones
3. Toma decisiones basadas en la información disponible
4. Puede realizar acciones adicionales (verificación manual, etc.)

## Características Técnicas

### Rendimiento
- **Carga asíncrona**: Datos se cargan en segundo plano
- **Cache inteligente**: Información reciente se mantiene en memoria
- **Paginación**: Listas grandes se cargan por partes
- **Filtros eficientes**: Búsquedas optimizadas

### Experiencia de Usuario
- **Interfaz intuitiva**: Navegación clara y consistente
- **Indicadores visuales**: Estados claramente identificables
- **Feedback inmediato**: Loading states y mensajes de error
- **Responsive**: Adaptable a diferentes tamaños de pantalla

### Integración Offline
- **Funciona offline**: Usa datos en caché cuando no hay conexión
- **Sincronización**: Se actualiza cuando se restaura la conexión
- **Fallback**: Muestra datos locales si el servidor no está disponible

## Consideraciones de Seguridad

### Acceso a Datos
- **Autenticación requerida**: Solo usuarios autenticados
- **Autorización por rol**: Diferentes niveles de acceso
- **Auditoría**: Registro de consultas realizadas

### Privacidad
- **Datos sensibles**: Información personal protegida
- **Logs de acceso**: Registro de quién consulta qué
- **Retención de datos**: Políticas de limpieza de datos

## Próximas Mejoras

### Funcionalidades Adicionales
1. **Exportación de reportes**: PDF/Excel del estado del estudiante
2. **Notificaciones push**: Alertas en tiempo real
3. **Análisis predictivo**: Predicción de patrones de asistencia
4. **Integración con calendario**: Eventos y horarios
5. **Chat interno**: Comunicación con el estudiante

### Mejoras Técnicas
1. **Búsqueda por voz**: Comandos de voz para búsqueda
2. **Códigos QR**: Escaneo de códigos para acceso rápido
3. **API GraphQL**: Consultas más eficientes
4. **Real-time updates**: Actualizaciones en tiempo real
5. **Machine Learning**: Análisis inteligente de patrones

## Uso Recomendado

### Para Administradores
- Revisar estudiantes con alertas regularmente
- Analizar patrones de asistencia por facultad/escuela
- Monitorear el uso de autorizaciones manuales
- Generar reportes de actividad estudiantil

### Para Guardias
- Consultar estado antes de permitir acceso
- Verificar información en casos de duda
- Revisar historial en situaciones especiales
- Reportar comportamientos inusuales

Esta funcionalidad proporciona una herramienta completa y eficiente para la gestión y consulta del estado de los estudiantes, mejorando significativamente la capacidad de los guardias y administradores para tomar decisiones informadas.
