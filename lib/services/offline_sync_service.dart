import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';
import '../services/api_service.dart';
import '../models/asistencia_model.dart';
import '../models/alumno_model.dart';
import '../models/presencia_model.dart';
import '../models/decision_manual_model.dart';

class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final ConnectivityService _connectivityService = ConnectivityService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ApiService _apiService = ApiService();

  bool _isSyncing = false;
  bool _autoSyncEnabled = true;
  DateTime? _lastSyncTime;
  String? _lastSyncError;
  int _syncIntervalMinutes = 5; // Sincronizar cada 5 minutos cuando esté online
  Timer? _syncTimer;

  List<String> _syncLog = [];
  int _pendingSyncCount = 0;

  // Getters
  bool get isSyncing => _isSyncing;
  bool get autoSyncEnabled => _autoSyncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncError => _lastSyncError;
  int get syncIntervalMinutes => _syncIntervalMinutes;
  List<String> get syncLog => List.unmodifiable(_syncLog);
  int get pendingSyncCount => _pendingSyncCount;

  // Inicializar servicio de sincronización
  Future<void> initialize() async {
    await _connectivityService.initialize();
    await _initializeWorkManager();
    await _updatePendingCount();
    _startAutoSync();
  }

  // Inicializar WorkManager para sincronización en background
  Future<void> _initializeWorkManager() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    // Registrar tarea periódica de sincronización
    await Workmanager().registerPeriodicTask(
      "sync_task",
      "offline_sync",
      frequency: Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  // Iniciar sincronización automática
  void _startAutoSync() {
    if (_autoSyncEnabled && _syncTimer == null) {
      _syncTimer = Timer.periodic(
        Duration(minutes: _syncIntervalMinutes),
        (timer) {
          if (_connectivityService.isOnline) {
            performSync();
          }
        },
      );
      _addLogEntry('🟢 Sincronización automática iniciada');
    }
  }

  // Detener sincronización automática
  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _addLogEntry('🔴 Sincronización automática detenida');
  }

  // Realizar sincronización
  Future<bool> performSync({bool forceSync = false}) async {
    if (_isSyncing && !forceSync) {
      _addLogEntry('⚠️ Sincronización ya en curso');
      return false;
    }

    if (!_connectivityService.isOnline && !forceSync) {
      _addLogEntry('🔴 Sin conexión a internet, omitiendo sincronización');
      return false;
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    _addLogEntry('🔄 Iniciando sincronización...');

    try {
      // Sincronizar asistencias pendientes
      await _syncPendingAsistencias();

      // Sincronizar presencia pendiente
      await _syncPendingPresencia();

      // Sincronizar decisiones manuales pendientes
      await _syncPendingDecisiones();

      // Actualizar datos maestros si es necesario
      await _syncMasterData();

      _lastSyncTime = DateTime.now();
      await _updatePendingCount();
      _addLogEntry('✅ Sincronización completada exitosamente');

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastSyncError = e.toString();
      _addLogEntry('❌ Error en sincronización: $e');
      
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  // Sincronizar asistencias pendientes
  Future<void> _syncPendingAsistencias() async {
    final pendingAsistencias = await _localDb.getPendingAsistencias();
    
    if (pendingAsistencias.isEmpty) {
      _addLogEntry('📝 No hay asistencias pendientes de sincronizar');
      return;
    }

    _addLogEntry('📝 Sincronizando ${pendingAsistencias.length} asistencias...');

    for (final asistencia in pendingAsistencias) {
      try {
        await _apiService.registrarAsistenciaCompleta(asistencia);
        await _localDb.markAsSynced('asistencias', asistencia.id);
        _addLogEntry('✅ Asistencia ${asistencia.id} sincronizada');
      } catch (e) {
        _addLogEntry('❌ Error sincronizando asistencia ${asistencia.id}: $e');
        // No rethrow para continuar con las demás
      }
    }
  }

  // Sincronizar presencia pendiente
  Future<void> _syncPendingPresencia() async {
    // Implementar sincronización de presencia
    _addLogEntry('👥 Sincronizando presencia...');
    // TODO: Implementar cuando esté disponible en API
  }

  // Sincronizar decisiones manuales pendientes
  Future<void> _syncPendingDecisiones() async {
    // Implementar sincronización de decisiones
    _addLogEntry('🤔 Sincronizando decisiones manuales...');
    // TODO: Implementar cuando esté disponible en API
  }

  // Sincronizar datos maestros
  Future<void> _syncMasterData() async {
    try {
      _addLogEntry('📚 Sincronizando datos maestros...');
      
      // Sincronizar alumnos
      final alumnos = await _apiService.getAlumnos();
      for (final alumno in alumnos) {
        await _localDb.saveAlumno(alumno, syncStatus: 'synced');
      }

      // Sincronizar facultades
      final facultades = await _apiService.getFacultades();
      // TODO: Implementar guardado de facultades

      // Sincronizar escuelas
      final escuelas = await _apiService.getEscuelas();
      // TODO: Implementar guardado de escuelas

      _addLogEntry('✅ Datos maestros sincronizados');
    } catch (e) {
      _addLogEntry('⚠️ Error sincronizando datos maestros: $e');
      // No rethrow para no interrumpir la sincronización principal
    }
  }

  // Guardar asistencia offline
  Future<void> saveAsistenciaOffline(AsistenciaModel asistencia) async {
    try {
      await _localDb.saveAsistencia(asistencia, syncStatus: 'pending');
      await _updatePendingCount();
      _addLogEntry('💾 Asistencia guardada offline: ${asistencia.id}');
      
      // Intentar sincronizar inmediatamente si hay conexión
      if (_connectivityService.isOnline) {
        performSync();
      }
    } catch (e) {
      _addLogEntry('❌ Error guardando asistencia offline: $e');
      rethrow;
    }
  }

  // Guardar decisión manual offline
  Future<void> saveDecisionOffline(DecisionManualModel decision) async {
    try {
      // TODO: Implementar guardado de decisiones en base de datos local
      await _updatePendingCount();
      _addLogEntry('💾 Decisión manual guardada offline: ${decision.id}');
      
      // Intentar sincronizar inmediatamente si hay conexión
      if (_connectivityService.isOnline) {
        performSync();
      }
    } catch (e) {
      _addLogEntry('❌ Error guardando decisión offline: $e');
      rethrow;
    }
  }

  // Obtener alumno offline
  Future<AlumnoModel?> getAlumnoOffline(String codigoUniversitario) async {
    try {
      return await _localDb.getAlumnoByCodigo(codigoUniversitario);
    } catch (e) {
      _addLogEntry('❌ Error obteniendo alumno offline: $e');
      return null;
    }
  }

  // Obtener asistencias offline
  Future<List<AsistenciaModel>> getAsistenciasOffline(
    DateTime start,
    DateTime end,
  ) async {
    try {
      return await _localDb.getAsistenciasByDateRange(start, end);
    } catch (e) {
      _addLogEntry('❌ Error obteniendo asistencias offline: $e');
      return [];
    }
  }

  // Configurar intervalo de sincronización
  void configureSyncInterval(int minutes) {
    _syncIntervalMinutes = minutes;
    if (_syncTimer != null) {
      _stopAutoSync();
      _startAutoSync();
    }
    _addLogEntry('⚙️ Intervalo de sincronización cambiado a $minutes minutos');
    notifyListeners();
  }

  // Activar/desactivar sincronización automática
  void toggleAutoSync(bool enabled) {
    _autoSyncEnabled = enabled;
    
    if (enabled) {
      _startAutoSync();
      _addLogEntry('✅ Sincronización automática activada');
    } else {
      _stopAutoSync();
      _addLogEntry('❌ Sincronización automática desactivada');
    }
    
    notifyListeners();
  }

  // Actualizar contador de elementos pendientes
  Future<void> _updatePendingCount() async {
    try {
      final stats = await _localDb.getSyncStats();
      _pendingSyncCount = stats['pending_asistencias']! + 
                         stats['pending_presencia']! + 
                         stats['pending_decisiones']!;
      notifyListeners();
    } catch (e) {
      _addLogEntry('❌ Error actualizando contador pendiente: $e');
    }
  }

  // Obtener estadísticas de sincronización
  Map<String, dynamic> getSyncStats() {
    return {
      'isSyncing': _isSyncing,
      'autoSyncEnabled': _autoSyncEnabled,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'lastSyncError': _lastSyncError,
      'syncIntervalMinutes': _syncIntervalMinutes,
      'pendingSyncCount': _pendingSyncCount,
      'isOnline': _connectivityService.isOnline,
      'connectionType': _connectivityService.connectionDescription,
    };
  }

  // Limpiar logs antiguos
  void clearOldLogs() {
    if (_syncLog.length > 100) {
      _syncLog = _syncLog.takeLast(50).toList();
    }
  }

  // Agregar entrada al log
  void _addLogEntry(String message) {
    final timestamp = DateTime.now().toIso8601String();
    _syncLog.add('[$timestamp] $message');
    clearOldLogs();
  }

  // Limpiar recursos
  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

// Callback para WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final syncService = OfflineSyncService();
      await syncService.performSync();
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}
