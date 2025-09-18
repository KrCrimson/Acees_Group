# Funcionalidad Offline - Control de Acceso NFC

## Descripción
Esta implementación agrega capacidades offline completas a la aplicación de control de acceso, permitiendo que los guardias puedan registrar asistencias y realizar operaciones sin conexión a internet.

## Arquitectura Offline

### Servicios Principales

#### 1. ConnectivityService
- **Ubicación**: `lib/services/connectivity_service.dart`
- **Propósito**: Monitorea el estado de conectividad de la aplicación
- **Características**:
  - Detección automática de cambios de conectividad
  - Soporte para WiFi, datos móviles, Ethernet
  - Estadísticas de tiempo online/offline
  - Notificaciones de cambio de estado

#### 2. LocalDatabaseService
- **Ubicación**: `lib/services/local_database_service.dart`
- **Propósito**: Almacenamiento local usando SQLite
- **Características**:
  - Base de datos SQLite local
  - Tablas para alumnos, asistencias, usuarios, etc.
  - Gestión de estado de sincronización
  - Limpieza automática de datos antiguos

#### 3. OfflineSyncService
- **Ubicación**: `lib/services/offline_sync_service.dart`
- **Propósito**: Sincronización automática de datos offline
- **Características**:
  - Sincronización automática cuando hay conexión
  - Cola de elementos pendientes
  - Sincronización en background con WorkManager
  - Logs detallados de sincronización

#### 4. HybridApiService
- **Ubicación**: `lib/services/hybrid_api_service.dart`
- **Propósito**: Servicio híbrido que combina funcionalidad online/offline
- **Características**:
  - Fallback automático a datos locales
  - Cache inteligente de datos
  - Transparente para el resto de la aplicación

### Widgets de UI

#### 1. ConnectivityStatusWidget
- **Ubicación**: `lib/widgets/connectivity_status_widget.dart`
- **Propósito**: Indicadores visuales de estado de conectividad
- **Componentes**:
  - `ConnectivityStatusWidget`: Indicador compacto
  - `ConnectivityStatusBanner`: Banner de estado offline
  - `SyncProgressDialog`: Diálogo de progreso de sincronización
  - `OfflineModeIndicator`: Wrapper para modo offline

#### 2. OfflineConfigView
- **Ubicación**: `lib/views/admin/offline_config_view.dart`
- **Propósito**: Configuración y monitoreo de funcionalidad offline
- **Características**:
  - Configuración de sincronización automática
  - Estadísticas de sincronización
  - Log de sincronización
  - Control manual de sincronización

## Funcionalidades Offline

### 1. Registro de Asistencias
- **Modo Online**: Registro directo en servidor + cache local
- **Modo Offline**: Guardado local para sincronización posterior
- **Sincronización**: Automática cuando se restaura la conexión

### 2. Verificación de Alumnos
- **Modo Online**: Verificación en servidor + cache local
- **Modo Offline**: Verificación usando cache local
- **Fallback**: Si no hay datos en cache, muestra error

### 3. Reportes y Estadísticas
- **Modo Online**: Datos actualizados del servidor
- **Modo Offline**: Datos del cache local (últimos 30 días)
- **Sincronización**: Actualización automática cuando hay conexión

### 4. Decisiones Manuales
- **Modo Online**: Registro directo en servidor
- **Modo Offline**: Guardado local para sincronización posterior

## Configuración

### Dependencias Agregadas
```yaml
# Offline functionality
sqflite: ^2.3.0
path: ^1.8.3
connectivity_plus: ^5.0.2
hive: ^2.2.3
hive_flutter: ^1.1.0
workmanager: ^0.5.2
```

### Inicialización
```dart
// En main.dart
await Hive.initFlutter();
await _initializeOfflineServices();
```

### Providers
```dart
// Servicios offline
ChangeNotifierProvider(create: (_) => ConnectivityService()),
ChangeNotifierProvider(create: (_) => OfflineSyncService()),
ChangeNotifierProvider(create: (_) => HybridApiService()),
```

## Uso

### 1. Indicadores de Estado
```dart
// Indicador compacto
ConnectivityStatusWidget()

// Banner de estado offline
ConnectivityStatusBanner()

// Wrapper para modo offline
OfflineModeIndicator(child: YourWidget())
```

### 2. Configuración Offline
```dart
// Navegar a configuración offline
Navigator.push(context, MaterialPageRoute(
  builder: (context) => OfflineConfigView(),
));
```

### 3. Sincronización Manual
```dart
// Obtener servicio de sincronización
final syncService = Provider.of<OfflineSyncService>(context, listen: false);

// Sincronizar manualmente
await syncService.performSync();
```

## Flujo de Datos

### Modo Online
1. Usuario realiza acción
2. HybridApiService intenta operación en servidor
3. Si exitosa: guarda en cache local
4. Si falla: usa datos de cache local

### Modo Offline
1. Usuario realiza acción
2. HybridApiService guarda en base de datos local
3. Marca como pendiente de sincronización
4. OfflineSyncService sincroniza cuando hay conexión

### Sincronización
1. OfflineSyncService detecta conexión
2. Obtiene elementos pendientes de base de datos local
3. Envía al servidor uno por uno
4. Marca como sincronizado si es exitoso
5. Mantiene en cola si falla

## Consideraciones Técnicas

### Almacenamiento Local
- **SQLite**: Para datos estructurados (alumnos, asistencias)
- **Hive**: Para configuración y preferencias
- **SharedPreferences**: Para configuración simple

### Sincronización
- **Automática**: Cada 5 minutos cuando hay conexión
- **Manual**: Disponible en configuración offline
- **Background**: WorkManager para sincronización en background

### Gestión de Errores
- **Fallback**: Siempre intenta usar datos locales si falla el servidor
- **Retry**: Reintenta sincronización de elementos fallidos
- **Logs**: Registro detallado de todas las operaciones

### Rendimiento
- **Cache**: Datos maestros se mantienen en cache local
- **Limpieza**: Datos antiguos se eliminan automáticamente
- **Optimización**: Consultas optimizadas para base de datos local

## Monitoreo y Debugging

### Logs de Sincronización
- Disponibles en OfflineConfigView
- Incluyen timestamps y detalles de errores
- Límite de 100 entradas (se limpian automáticamente)

### Estadísticas
- Elementos pendientes de sincronización
- Última sincronización exitosa
- Tiempo offline/online
- Errores de sincronización

### Indicadores Visuales
- Estado de conectividad en tiempo real
- Contador de elementos pendientes
- Indicador de sincronización en progreso

## Limitaciones

### Datos Offline
- Solo datos de los últimos 30 días
- Algunas funcionalidades requieren conexión (login, gestión de usuarios)
- Reportes limitados a datos locales

### Sincronización
- Requiere conexión estable para sincronización exitosa
- Elementos grandes pueden tardar en sincronizar
- Conflictos de datos se resuelven con datos del servidor

## Próximas Mejoras

1. **Resolución de Conflictos**: Manejo inteligente de conflictos de datos
2. **Sincronización Incremental**: Solo sincronizar cambios
3. **Compresión**: Comprimir datos para sincronización más rápida
4. **Offline First**: Diseño completamente offline-first
5. **Analytics**: Métricas detalladas de uso offline
