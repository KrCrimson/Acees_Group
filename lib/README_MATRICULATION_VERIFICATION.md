# Verificación de Vigencia de Matrícula - Control de Acceso NFC

## Descripción
Esta funcionalidad permite a los guardias y administradores verificar la vigencia de la matrícula de los estudiantes antes de permitir el acceso al campus. Incluye verificación automática en el flujo NFC y herramientas de consulta manual.

## Arquitectura

### Modelo de Datos

#### MatriculationModel
- **Ubicación**: `lib/models/matriculation_model.dart`
- **Propósito**: Modelo completo que encapsula toda la información de matrícula
- **Características**:
  - Información académica (ciclo, año, tipo)
  - Estado de vigencia y fechas
  - Información de pago
  - Alertas y recomendaciones
  - Validaciones automáticas

### Servicios

#### MatriculationService
- **Ubicación**: `lib/services/matriculation_service.dart`
- **Propósito**: Servicio para verificar y consultar información de matrículas
- **Endpoints principales**:
  - `GET /matriculas/verificar/{codigo}` - Verificar vigencia por código
  - `GET /matriculas/verificar/dni/{dni}` - Verificar vigencia por DNI
  - `GET /matriculas/historial/{codigo}` - Historial de matrículas
  - `GET /matriculas/por-vencer` - Matrículas por vencer
  - `GET /matriculas/vencidas` - Matrículas vencidas
  - `GET /matriculas/pendiente-pago` - Matrículas pendientes de pago
  - `GET /matriculas/estadisticas` - Estadísticas generales
  - `GET /matriculas/buscar` - Búsqueda avanzada
  - `GET /matriculas/validar-acceso/{codigo}` - Validación de acceso

### ViewModels

#### MatriculationViewModel
- **Ubicación**: `lib/viewmodels/matriculation_viewmodel.dart`
- **Propósito**: Gestión del estado y lógica de negocio para verificación de matrículas
- **Funcionalidades**:
  - Verificación de vigencia por código o DNI
  - Búsqueda y filtrado de matrículas
  - Gestión de alertas y estadísticas
  - Carga de datos relacionados

### Vistas

#### MatriculationVerificationView
- **Ubicación**: `lib/views/matriculation_verification_view.dart`
- **Propósito**: Vista principal de verificación con pestañas
- **Pestañas**:
  - **Verificar**: Búsqueda rápida por código o DNI
  - **Por Vencer**: Matrículas que vencen pronto
  - **Vencidas**: Matrículas ya vencidas
  - **Pendientes**: Matrículas con problemas de pago

#### MatriculationDetailView
- **Ubicación**: `lib/views/matriculation_detail_view.dart`
- **Propósito**: Vista detallada de una matrícula específica
- **Pestañas**:
  - **Información**: Datos académicos y estado de vigencia
  - **Pago**: Información de pago y comprobantes
  - **Historial**: Historial de matrículas del estudiante

#### MatriculationSearchView
- **Ubicación**: `lib/views/matriculation_search_view.dart`
- **Propósito**: Búsqueda avanzada con filtros múltiples
- **Filtros disponibles**:
  - Ciclo académico
  - Año académico
  - Estado de matrícula
  - Facultad
  - Búsqueda por texto libre

## Funcionalidades Implementadas

### 1. Verificación Automática en NFC
- **Integración completa**: Verificación automática en el flujo de escaneo NFC
- **Validación en cascada**: Primero estado del estudiante, luego matrícula
- **Manejo de errores**: Fallback graceful si no se puede verificar matrícula
- **Información detallada**: Incluye detalles de matrícula en la respuesta

### 2. Verificación Manual
- **Búsqueda rápida**: Por código universitario o DNI
- **Resultado inmediato**: Estado de vigencia y recomendación de acceso
- **Información completa**: Datos académicos, fechas, alertas
- **Navegación fácil**: Acceso directo a vista detallada

### 3. Gestión de Matrículas
- **Matrículas por vencer**: Lista de matrículas que vencen en los próximos 30 días
- **Matrículas vencidas**: Lista de matrículas ya vencidas
- **Matrículas pendientes**: Matrículas con problemas de pago
- **Estadísticas**: Contadores y análisis generales

### 4. Búsqueda Avanzada
- **Filtros múltiples**: Ciclo, año, estado, facultad
- **Búsqueda por texto**: Código, DNI, nombre
- **Resultados en tiempo real**: Búsqueda mientras se escribe
- **Estadísticas de búsqueda**: Contadores por categoría

### 5. Información Detallada
- **Datos académicos**: Período, ciclo, año, tipo de matrícula
- **Estado de vigencia**: Vigente, vencida, por vencer, suspendida, cancelada
- **Información de pago**: Monto, estado, fecha, comprobante
- **Historial completo**: Todas las matrículas del estudiante
- **Alertas y recomendaciones**: Advertencias y próximas acciones

## Estados de Matrícula

### 1. Vigente
- **Condiciones**: Activa, estado "VIGENTE", no vencida, pago completo
- **Acceso**: Permitido
- **Indicador**: Verde con check
- **Recomendación**: Acceso permitido

### 2. Vencida
- **Condiciones**: Fecha de vencimiento pasada
- **Acceso**: Denegado
- **Indicador**: Rojo con error
- **Recomendación**: Acceso denegado - Matrícula vencida

### 3. Por Vencer
- **Condiciones**: Vigente pero vence en 30 días o menos
- **Acceso**: Permitido con advertencia
- **Indicador**: Naranja con warning
- **Recomendación**: Acceso permitido con advertencia

### 4. Pendiente de Pago
- **Condiciones**: Estado "PENDIENTE_PAGO" o pago incompleto
- **Acceso**: Denegado
- **Indicador**: Amarillo con pending
- **Recomendación**: Verificar con administración

### 5. Suspendida
- **Condiciones**: Estado "SUSPENDIDA"
- **Acceso**: Denegado
- **Indicador**: Púrpura con pause
- **Recomendación**: Acceso denegado - Matrícula suspendida

### 6. Cancelada
- **Condiciones**: Estado "CANCELADA"
- **Acceso**: Denegado
- **Indicador**: Gris con cancel
- **Recomendación**: Acceso denegado - Matrícula cancelada

## Integración en el Flujo NFC

### 1. Verificación en Cascada
```
1. Escaneo NFC → Código universitario
2. Verificación de estado del estudiante
3. Si estado OK → Verificación de matrícula
4. Si matrícula OK → Acceso permitido
5. Si matrícula NO OK → Autorización manual requerida
```

### 2. Información de Respuesta
- **Acceso permitido**: Incluye alertas de matrícula si las hay
- **Acceso denegado**: Incluye detalles completos de la matrícula
- **Error de verificación**: Permite acceso con advertencia

### 3. Manejo de Errores
- **Error de conexión**: Permite acceso con advertencia
- **Matrícula no encontrada**: Requiere autorización manual
- **Error del servidor**: Fallback a verificación manual

## Características Técnicas

### Rendimiento
- **Verificación rápida**: Consulta optimizada por código universitario
- **Cache inteligente**: Información reciente se mantiene en memoria
- **Verificación en paralelo**: Estado y matrícula se verifican eficientemente
- **Fallback graceful**: Funciona aunque falle la verificación de matrícula

### Experiencia de Usuario
- **Interfaz intuitiva**: Navegación clara y consistente
- **Indicadores visuales**: Estados claramente identificables
- **Feedback inmediato**: Loading states y mensajes de error
- **Responsive**: Adaptable a diferentes tamaños de pantalla

### Integración Offline
- **Funciona offline**: Usa datos en caché cuando no hay conexión
- **Sincronización**: Se actualiza cuando se restaura la conexión
- **Fallback**: Muestra datos locales si el servidor no está disponible

## Flujo de Uso

### 1. Verificación Automática (NFC)
1. Estudiante escanea pulsera NFC
2. Sistema verifica estado del estudiante
3. Sistema verifica vigencia de matrícula
4. Sistema determina si permite acceso
5. Guardia ve resultado y toma acción

### 2. Verificación Manual
1. Guardia accede a la funcionalidad
2. Ingresa código o DNI del estudiante
3. Sistema muestra resultado de verificación
4. Guardia puede ver detalles completos
5. Guardia toma decisión basada en la información

### 3. Consulta de Matrículas
1. Administrador accede a la funcionalidad
2. Navega por las diferentes pestañas
3. Ve listas de matrículas por categoría
4. Puede buscar y filtrar matrículas
5. Accede a detalles específicos

## Consideraciones de Seguridad

### Acceso a Datos
- **Autenticación requerida**: Solo usuarios autenticados
- **Autorización por rol**: Diferentes niveles de acceso
- **Auditoría**: Registro de verificaciones realizadas

### Privacidad
- **Datos sensibles**: Información académica protegida
- **Logs de acceso**: Registro de quién verifica qué
- **Retención de datos**: Políticas de limpieza de datos

## Próximas Mejoras

### Funcionalidades Adicionales
1. **Notificaciones push**: Alertas de matrículas por vencer
2. **Renovación automática**: Proceso de renovación de matrícula
3. **Integración con pagos**: Verificación de pagos en tiempo real
4. **Reportes automáticos**: Generación de reportes de matrículas
5. **API de terceros**: Integración con sistemas académicos

### Mejoras Técnicas
1. **Verificación en tiempo real**: Actualizaciones automáticas
2. **Machine Learning**: Predicción de problemas de matrícula
3. **API GraphQL**: Consultas más eficientes
4. **Webhooks**: Notificaciones automáticas
5. **Analytics**: Análisis de patrones de acceso

## Uso Recomendado

### Para Administradores
- Revisar matrículas por vencer regularmente
- Monitorear matrículas vencidas y pendientes
- Generar reportes de estado de matrículas
- Configurar alertas automáticas

### Para Guardias
- Verificar matrícula antes de permitir acceso
- Consultar detalles en casos de duda
- Reportar problemas de matrícula
- Mantener registro de verificaciones

## Beneficios Implementados

1. **Control de Acceso Mejorado**: Verificación automática de matrícula
2. **Prevención de Accesos No Autorizados**: Bloqueo de estudiantes sin matrícula vigente
3. **Información Completa**: Datos detallados para toma de decisiones
4. **Gestión Eficiente**: Herramientas para administrar matrículas
5. **Integración Transparente**: Funciona automáticamente en el flujo NFC
6. **Alertas Proactivas**: Identificación de problemas antes de que ocurran
7. **Interfaz Intuitiva**: Fácil de usar para guardias y administradores
8. **Escalabilidad**: Preparado para grandes volúmenes de datos

La funcionalidad de verificación de vigencia de matrícula está completamente implementada y integrada en el flujo de verificación NFC. Los guardias pueden verificar automáticamente la vigencia de la matrícula durante el escaneo NFC, y los administradores tienen herramientas completas para gestionar y consultar el estado de las matrículas de los estudiantes.
