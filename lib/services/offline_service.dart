import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/asistencia_model.dart';
import 'api_service.dart';
import 'sync_service.dart';

// Enums para el sistema offline
enum ConnectionStatus { online, offline, connecting }

enum EventType { asistencia, sesionInicio, sesionFin, actualizacionPerfil }

enum EventStatus { pending, syncing, completed, failed }

// Modelo para eventos offline
class OfflineEvent {
  final String id;
  final EventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final EventStatus status;
  final int retryCount;
  final String? errorMessage;

  OfflineEvent({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.status = EventStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'data': json.encode(data),
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'retry_count': retryCount,
      'error_message': errorMessage,
    };
  }

  factory OfflineEvent.fromJson(Map<String, dynamic> json) {
    return OfflineEvent(
      id: json['id'],
      type: EventType.values.firstWhere((e) => e.name == json['type']),
      data: jsonDecode(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      status: EventStatus.values.firstWhere((e) => e.name == json['status']),
      retryCount: json['retry_count'] ?? 0,
      errorMessage: json['error_message'],
    );
  }

  OfflineEvent copyWith({
    EventStatus? status,
    int? retryCount,
    String? errorMessage,
  }) {
    return OfflineEvent(
      id: id,
      type: type,
      data: data,
      timestamp: timestamp,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class OfflineService extends ChangeNotifier {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  // Servicios dependientes
  final ApiService _apiService = ApiService();
  final SyncService _syncService = SyncService();

  // Estado de conectividad
  ConnectionStatus _connectionStatus = ConnectionStatus.offline;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  // Base de datos local
  Database? _database;

  // Cola de eventos
  List<OfflineEvent> _pendingEvents = [];
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Configuración
  static const int maxRetries = 3;
  static const Duration syncInterval = Duration(seconds: 30);

  // Getters
  ConnectionStatus get connectionStatus => _connectionStatus;
  List<OfflineEvent> get pendingEvents => List.unmodifiable(_pendingEvents);
  bool get isOffline => _connectionStatus == ConnectionStatus.offline;
  bool get isOnline => _connectionStatus == ConnectionStatus.online;
  bool get isSyncing => _isSyncing;
  int get pendingEventCount => _pendingEvents.length;

  // ==================== INICIALIZACIÓN ====================

  /// Inicializar el servicio offline
  Future<void> initialize() async {
    try {
      // Inicializar base de datos SQLite
      await _initializeDatabase();

      // Cargar eventos pendientes
      await _loadPendingEvents();

      // Configurar monitoreo de conectividad
      await _setupConnectivityMonitoring();

      // Verificar estado inicial de conexión
      await _checkInitialConnectivity();

      debugPrint('🔄 OfflineService inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error inicializando OfflineService: $e');
    }
  }

  /// Inicializar base de datos SQLite
  Future<void> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'acees_offline.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabla para eventos offline
        await db.execute('''
          CREATE TABLE offline_events (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            data TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            status TEXT NOT NULL,
            retry_count INTEGER DEFAULT 0,
            error_message TEXT
          )
        ''');

        // Tabla para cache de estudiantes
        await db.execute('''
          CREATE TABLE cached_students (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            cached_at TEXT NOT NULL,
            expires_at TEXT NOT NULL
          )
        ''');

        // Tabla para cache de asistencias
        await db.execute('''
          CREATE TABLE cached_asistencias (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            cached_at TEXT NOT NULL
          )
        ''');

        debugPrint('📊 Base de datos offline creada');
      },
    );
  }

  /// Configurar monitoreo de conectividad
  Future<void> _setupConnectivityMonitoring() async {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  /// Verificar conectividad inicial
  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    await _onConnectivityChanged(result);
  }

  /// Manejar cambios de conectividad
  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    final wasOffline = _connectionStatus == ConnectionStatus.offline;

    if (result == ConnectivityResult.none) {
      _connectionStatus = ConnectionStatus.offline;
      _stopSyncTimer();
      debugPrint('🔴 Conexión perdida - Modo offline activado');
    } else {
      _connectionStatus = ConnectionStatus.connecting;
      notifyListeners();

      // Verificar conectividad real con el servidor
      final hasServerConnection = await _testServerConnection();

      if (hasServerConnection) {
        _connectionStatus = ConnectionStatus.online;
        debugPrint('🟢 Conexión establecida - Modo online');

        // Si estábamos offline, iniciar sincronización
        if (wasOffline) {
          await _onBackOnline();
        }

        _startSyncTimer();
      } else {
        _connectionStatus = ConnectionStatus.offline;
        debugPrint('🔴 Sin conexión al servidor - Mantener modo offline');
      }
    }

    notifyListeners();
  }

  /// Probar conexión con el servidor
  Future<bool> _testServerConnection() async {
    try {
      await _apiService.testConnection();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Manejar reconexión
  Future<void> _onBackOnline() async {
    debugPrint(
      '🔄 Reconectado - Iniciando sincronización de eventos pendientes',
    );

    // Cargar eventos pendientes desde la base de datos
    await _loadPendingEvents();

    // Sincronizar eventos pendientes
    if (_pendingEvents.isNotEmpty) {
      await _processPendingEvents();
    }

    // Sincronizar datos generales
    await _syncService.performSync(isAutomatic: true);
  }

  // ==================== GESTIÓN DE EVENTOS OFFLINE ====================

  /// Agregar evento a la cola offline
  Future<void> addOfflineEvent(
    EventType type,
    Map<String, dynamic> data,
  ) async {
    final event = OfflineEvent(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      data: data,
      timestamp: DateTime.now(),
    );

    _pendingEvents.add(event);
    await _saveEventToDatabase(event);

    debugPrint('📝 Evento offline agregado: ${type.name}');

    // Si estamos online, intentar sincronizar inmediatamente
    if (isOnline && !_isSyncing) {
      _processPendingEvents();
    }

    notifyListeners();
  }

  /// Cargar eventos pendientes desde la base de datos
  Future<void> _loadPendingEvents() async {
    if (_database == null) return;

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'offline_events',
        where: 'status IN (?, ?)',
        whereArgs: [EventStatus.pending.name, EventStatus.failed.name],
        orderBy: 'timestamp ASC',
      );

      _pendingEvents = maps.map((map) => OfflineEvent.fromJson(map)).toList();

      debugPrint('📋 Cargados ${_pendingEvents.length} eventos pendientes');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error cargando eventos pendientes: $e');
    }
  }

  /// Guardar evento en base de datos
  Future<void> _saveEventToDatabase(OfflineEvent event) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        'offline_events',
        event.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Error guardando evento: $e');
    }
  }

  /// Actualizar estado de evento en base de datos
  Future<void> _updateEventInDatabase(OfflineEvent event) async {
    if (_database == null) return;

    try {
      await _database!.update(
        'offline_events',
        event.toJson(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
    } catch (e) {
      debugPrint('❌ Error actualizando evento: $e');
    }
  }

  /// Eliminar evento de base de datos
  Future<void> _deleteEventFromDatabase(String eventId) async {
    if (_database == null) return;

    try {
      await _database!.delete(
        'offline_events',
        where: 'id = ?',
        whereArgs: [eventId],
      );
    } catch (e) {
      debugPrint('❌ Error eliminando evento: $e');
    }
  }

  // ==================== PROCESAMIENTO DE EVENTOS ====================

  /// Procesar eventos pendientes
  Future<void> _processPendingEvents() async {
    if (_isSyncing || isOffline || _pendingEvents.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    debugPrint('🔄 Procesando ${_pendingEvents.length} eventos pendientes...');

    final eventsToProcess = List<OfflineEvent>.from(_pendingEvents);
    int processed = 0;
    int failed = 0;

    for (final event in eventsToProcess) {
      try {
        await _processEvent(event);
        processed++;
      } catch (e) {
        failed++;
        debugPrint('❌ Error procesando evento ${event.id}: $e');
      }
    }

    debugPrint('✅ Eventos procesados: $processed exitosos, $failed fallidos');

    _isSyncing = false;
    notifyListeners();
  }

  /// Procesar un evento individual
  Future<void> _processEvent(OfflineEvent event) async {
    // Marcar como sincronizando
    final syncingEvent = event.copyWith(status: EventStatus.syncing);
    await _updateEventStatus(syncingEvent);

    try {
      switch (event.type) {
        case EventType.asistencia:
          await _processAsistenciaEvent(event);
          break;
        case EventType.sesionInicio:
          await _processSesionInicioEvent(event);
          break;
        case EventType.sesionFin:
          await _processSesionFinEvent(event);
          break;
        case EventType.actualizacionPerfil:
          await _processActualizacionPerfilEvent(event);
          break;
      }

      // Marcar como completado y eliminar
      await _markEventCompleted(event.id);
    } catch (e) {
      // Incrementar contador de reintentos
      final retryCount = event.retryCount + 1;

      if (retryCount >= maxRetries) {
        // Marcar como fallido permanentemente
        final failedEvent = event.copyWith(
          status: EventStatus.failed,
          retryCount: retryCount,
          errorMessage: e.toString(),
        );
        await _updateEventStatus(failedEvent);
      } else {
        // Marcar como pendiente para reintento
        final retryEvent = event.copyWith(
          status: EventStatus.pending,
          retryCount: retryCount,
          errorMessage: e.toString(),
        );
        await _updateEventStatus(retryEvent);
      }

      rethrow;
    }
  }

  /// Procesar evento de asistencia
  Future<void> _processAsistenciaEvent(OfflineEvent event) async {
    final asistencia = AsistenciaModel.fromJson(event.data);
    await _apiService.registrarAsistencia(asistencia);
  }

  /// Procesar evento de inicio de sesión
  Future<void> _processSesionInicioEvent(OfflineEvent event) async {
    // Implementar lógica de sincronización de sesiones
    debugPrint('🔄 Procesando inicio de sesión offline');
  }

  /// Procesar evento de fin de sesión
  Future<void> _processSesionFinEvent(OfflineEvent event) async {
    // Implementar lógica de sincronización de sesiones
    debugPrint('🔄 Procesando fin de sesión offline');
  }

  /// Procesar evento de actualización de perfil
  Future<void> _processActualizacionPerfilEvent(OfflineEvent event) async {
    // Implementar lógica de actualización de perfil
    debugPrint('🔄 Procesando actualización de perfil offline');
  }

  /// Actualizar estado de evento
  Future<void> _updateEventStatus(OfflineEvent event) async {
    final index = _pendingEvents.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _pendingEvents[index] = event;
    }

    await _updateEventInDatabase(event);
    notifyListeners();
  }

  /// Marcar evento como completado
  Future<void> _markEventCompleted(String eventId) async {
    _pendingEvents.removeWhere((e) => e.id == eventId);
    await _deleteEventFromDatabase(eventId);
    notifyListeners();
  }

  // ==================== GESTIÓN DE TIMERS ====================

  /// Iniciar timer de sincronización
  void _startSyncTimer() {
    _stopSyncTimer();
    _syncTimer = Timer.periodic(syncInterval, (timer) {
      if (isOnline && _pendingEvents.isNotEmpty) {
        _processPendingEvents();
      }
    });
  }

  /// Detener timer de sincronización
  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // ==================== MÉTODOS PÚBLICOS ====================

  /// Forzar verificación de conectividad y sincronización
  Future<void> forceSyncPendingEvents() async {
    debugPrint('🔄 Forzando verificación de conectividad...');

    try {
      // Forzar verificación de conectividad
      _connectionStatus = ConnectionStatus.connecting;
      notifyListeners();

      // Probar conexión real con el servidor
      final hasConnection = await _testServerConnection();

      if (hasConnection) {
        _connectionStatus = ConnectionStatus.online;
        debugPrint('✅ Conexión restablecida');

        // Procesar eventos pendientes si hay conexión
        if (_pendingEvents.isNotEmpty) {
          await _processPendingEvents();
        }

        _startSyncTimer();
      } else {
        _connectionStatus = ConnectionStatus.offline;
        debugPrint('❌ Sin conexión al servidor');
        throw Exception('No se pudo conectar al servidor');
      }
    } catch (e) {
      _connectionStatus = ConnectionStatus.offline;
      debugPrint('❌ Error en verificación forzada: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Limpiar eventos fallidos
  Future<void> clearFailedEvents() async {
    if (_database == null) return;

    try {
      await _database!.delete(
        'offline_events',
        where: 'status = ?',
        whereArgs: [EventStatus.failed.name],
      );

      _pendingEvents.removeWhere((e) => e.status == EventStatus.failed);

      debugPrint('🗑️ Eventos fallidos eliminados');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error limpiando eventos fallidos: $e');
    }
  }

  /// Obtener estadísticas de eventos
  Map<String, int> getEventStatistics() {
    final stats = <String, int>{};

    for (final status in EventStatus.values) {
      stats[status.name] =
          _pendingEvents.where((e) => e.status == status).length;
    }

    return stats;
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _stopSyncTimer();
    _database?.close();
    super.dispose();
  }
}
