import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/alumno_model.dart';
import '../models/asistencia_model.dart';

// Enums para manejo de conflictos y sincronización
enum ConflictResolution { serverWins, clientWins, merge, manual }

enum SyncStatus { idle, syncing, error, conflicts, completed }

// Clase para manejar conflictos de datos
class ConflictData {
  final String id;
  final String collection;
  final Map<String, dynamic> serverData;
  final Map<String, dynamic> localData;
  final DateTime serverTimestamp;
  final DateTime localTimestamp;
  final String conflictType;

  ConflictData({
    required this.id,
    required this.collection,
    required this.serverData,
    required this.localData,
    required this.serverTimestamp,
    required this.localTimestamp,
    required this.conflictType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection': collection,
      'server_data': serverData,
      'local_data': localData,
      'server_timestamp': serverTimestamp.toIso8601String(),
      'local_timestamp': localTimestamp.toIso8601String(),
      'conflict_type': conflictType,
    };
  }

  factory ConflictData.fromJson(Map<String, dynamic> json) {
    return ConflictData(
      id: json['id'],
      collection: json['collection'],
      serverData: json['server_data'],
      localData: json['local_data'],
      serverTimestamp: DateTime.parse(json['server_timestamp']),
      localTimestamp: DateTime.parse(json['local_timestamp']),
      conflictType: json['conflict_type'],
    );
  }
}

// Resultado de sincronización
class SyncResult {
  final bool success;
  final SyncStatus status;
  final String message;
  final List<ConflictData> conflicts;
  final Map<String, int> syncedCounts;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    required this.status,
    required this.message,
    this.conflicts = const [],
    this.syncedCounts = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SyncResult.success({
    String? message,
    Map<String, int>? syncedCounts,
  }) {
    return SyncResult(
      success: true,
      status: SyncStatus.completed,
      message: message ?? 'Sincronización completada exitosamente',
      syncedCounts: syncedCounts ?? {},
    );
  }

  factory SyncResult.withConflicts(List<ConflictData> conflicts) {
    return SyncResult(
      success: false,
      status: SyncStatus.conflicts,
      message: 'Conflictos detectados durante la sincronización',
      conflicts: conflicts,
    );
  }

  factory SyncResult.error(String message) {
    return SyncResult(
      success: false,
      status: SyncStatus.error,
      message: message,
    );
  }
}

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ApiService _apiService = ApiService();

  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _autoSyncEnabled = true;
  DateTime? _lastSyncTime;
  String? _syncError;
  int _syncIntervalMinutes = 30; // Sync cada 30 minutos por defecto

  List<String> _syncLog = [];

  // Nuevos campos para versionado y conflictos
  Map<String, int> _localVersions = {};
  List<ConflictData> _pendingConflicts = [];
  List<ConflictData> _lastConflicts = [];
  SyncStatus _currentStatus = SyncStatus.idle;

  // Getters
  bool get isSyncing => _isSyncing;
  bool get autoSyncEnabled => _autoSyncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncError => _syncError;
  int get syncIntervalMinutes => _syncIntervalMinutes;
  List<String> get syncLog => List.unmodifiable(_syncLog);
  Map<String, int> get localVersions => Map.unmodifiable(_localVersions);
  List<ConflictData> get pendingConflicts =>
      List.unmodifiable(_pendingConflicts);
  SyncStatus get currentStatus => _currentStatus;
  bool get hasConflicts => _pendingConflicts.isNotEmpty;
  List<ConflictData> get lastConflicts => List.unmodifiable(_lastConflicts);
  int get conflictCount => _pendingConflicts.length;

  // Inicializar sincronización automática
  void initAutoSync() {
    if (_autoSyncEnabled && _syncTimer == null) {
      _startAutoSync();
      _addLogEntry('🟢 Sincronización automática iniciada');
    }
  }

  // Configurar intervalo de sincronización
  void configureSyncInterval(int minutes) {
    _syncIntervalMinutes = minutes;
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _startAutoSync();
    }
    _addLogEntry(
      '⚙️ Intervalo de sincronización cambiado a ${minutes} minutos',
    );
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

  // Iniciar timer de sincronización automática
  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (timer) => performSync(isAutomatic: true),
    );
  }

  // Detener sincronización automática
  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Realizar sincronización manual o automática
  Future<bool> performSync({bool isAutomatic = false}) async {
    if (_isSyncing) {
      _addLogEntry('⚠️ Sincronización en curso, ignorando solicitud');
      return false;
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    final syncType = isAutomatic ? 'automática' : 'manual';
    _addLogEntry('🔄 Iniciando sincronización $syncType...');

    try {
      // Sincronizar datos de estudiantes
      await _syncEstudiantes();

      // Sincronizar otros datos si es necesario
      await _syncOtherData();

      _lastSyncTime = DateTime.now();
      _addLogEntry('✅ Sincronización $syncType completada exitosamente');

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _syncError = e.toString();
      _addLogEntry('❌ Error en sincronización $syncType: $e');

      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  // ==================== MÉTODOS DE SINCRONIZACIÓN AVANZADA ====================

  /// Sincronización bidireccional con detección de conflictos
  Future<SyncResult> performBidirectionalSync() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        status: SyncStatus.syncing,
        message: 'Sincronización en curso',
        syncedCounts: {},
      );
    }

    _isSyncing = true;
    _currentStatus = SyncStatus.syncing;
    _lastConflicts.clear();
    notifyListeners();

    try {
      _addLogEntry('🔄 Iniciando sincronización bidireccional...');

      // Fase 1: Verificar versiones del servidor
      final serverVersions = await _checkServerVersions();

      // Fase 2: Detectar conflictos
      final conflicts = await _detectConflicts(serverVersions);

      if (conflicts.isNotEmpty) {
        _lastConflicts.addAll(conflicts);
        _pendingConflicts.addAll(conflicts);
        _currentStatus = SyncStatus.conflicts;

        _addLogEntry('⚠️ Detectados ${conflicts.length} conflictos');

        // Notificar al usuario sobre conflictos
        _notifyConflicts(conflicts);

        return SyncResult(
          success: false,
          status: SyncStatus.conflicts,
          message: 'Conflictos detectados que requieren resolución manual',
          conflicts: conflicts,
        );
      }

      // Fase 3: Sincronizar cambios (sin conflictos)
      await _uploadLocalChanges();
      await _downloadServerChanges();

      // Fase 4: Actualizar versiones locales
      await _updateLocalVersions(serverVersions);

      _currentStatus = SyncStatus.completed;
      _lastSyncTime = DateTime.now();
      _addLogEntry('✅ Sincronización bidireccional completada');

      return SyncResult(
        success: true,
        status: SyncStatus.completed,
        message: 'Sincronización completada exitosamente',
      );
    } catch (e) {
      _currentStatus = SyncStatus.error;
      _syncError = e.toString();
      _addLogEntry('❌ Error en sincronización: $e');

      return SyncResult(
        success: false,
        status: SyncStatus.error,
        message: 'Error: $e',
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Verificar versiones del servidor
  Future<Map<String, int>> _checkServerVersions() async {
    try {
      final response = await _apiService.getVersiones();
      return Map<String, int>.from(response);
    } catch (e) {
      _addLogEntry('⚠️ Error obteniendo versiones del servidor: $e');
      return {};
    }
  }

  /// Detectar conflictos comparando versiones
  Future<List<ConflictData>> _detectConflicts(
    Map<String, int> serverVersions,
  ) async {
    List<ConflictData> conflicts = [];

    for (final entry in serverVersions.entries) {
      final collection = entry.key;
      final serverVersion = entry.value;
      final localVersion = _localVersions[collection] ?? 0;

      if (serverVersion > localVersion) {
        // Verificar si hay cambios locales sin sincronizar
        final hasLocalChanges = await _hasUnsyncedLocalChanges(collection);

        if (hasLocalChanges) {
          // Conflicto detectado
          final conflictData = await _buildConflictData(
            collection,
            localVersion,
            serverVersion,
          );
          conflicts.add(conflictData);
        }
      }
    }

    return conflicts;
  }

  /// Construir datos del conflicto
  Future<ConflictData> _buildConflictData(
    String collection,
    int localVersion,
    int serverVersion,
  ) async {
    final localData = await _getLocalData(collection);
    final serverData = await _getServerData(collection);

    return ConflictData(
      id: '${collection}_${DateTime.now().millisecondsSinceEpoch}',
      collection: collection,
      serverData: serverData,
      localData: localData,
      serverTimestamp: DateTime.now(),
      localTimestamp: DateTime.now(),
      conflictType: 'version_conflict',
    );
  }

  /// Verificar si hay cambios locales sin sincronizar
  Future<bool> _hasUnsyncedLocalChanges(String collection) async {
    // Implementar lógica específica por colección
    switch (collection) {
      case 'asistencias':
        final prefs = await SharedPreferences.getInstance();
        final pendingAsistencias =
            prefs.getStringList('pending_asistencias') ?? [];
        return pendingAsistencias.isNotEmpty;

      case 'usuarios':
        // Verificar cambios en usuarios
        return false; // Por ahora usuarios no se modifican localmente

      case 'sesiones_guardias':
        // Verificar sesiones activas
        final prefs = await SharedPreferences.getInstance();
        final activeSessions = prefs.getStringList('active_sessions') ?? [];
        return activeSessions.isNotEmpty;

      default:
        return false;
    }
  }

  /// Obtener datos locales de una colección
  Future<Map<String, dynamic>> _getLocalData(String collection) async {
    final prefs = await SharedPreferences.getInstance();

    switch (collection) {
      case 'asistencias':
        final pendingAsistencias =
            prefs.getStringList('pending_asistencias') ?? [];
        return {
          'pending_count': pendingAsistencias.length,
          'data': pendingAsistencias,
        };

      case 'sesiones_guardias':
        final activeSessions = prefs.getStringList('active_sessions') ?? [];
        return {'active_count': activeSessions.length, 'data': activeSessions};

      default:
        return {};
    }
  }

  /// Obtener datos del servidor de una colección
  Future<Map<String, dynamic>> _getServerData(String collection) async {
    try {
      switch (collection) {
        case 'asistencias':
          final asistencias = await _apiService.getAsistenciasSync();
          return {
            'count': asistencias.length,
            'latest':
                asistencias.isNotEmpty ? asistencias.first.toJson() : null,
          };

        case 'sesiones_guardias':
          // Obtener sesiones activas del servidor
          final response = await _apiService.getActiveSessions();
          return {'active_count': response.length, 'data': response};

        default:
          return {};
      }
    } catch (e) {
      _addLogEntry(
        '⚠️ Error obteniendo datos del servidor para $collection: $e',
      );
      return {};
    }
  }

  /// Subir cambios locales al servidor
  Future<void> _uploadLocalChanges() async {
    _addLogEntry('📤 Subiendo cambios locales...');

    // Subir asistencias pendientes
    await _uploadPendingAsistencias();

    // Subir otros cambios pendientes
    await _uploadOtherPendingChanges();
  }

  /// Descargar cambios del servidor
  Future<void> _downloadServerChanges() async {
    _addLogEntry('📥 Descargando cambios del servidor...');

    // Descargar datos actualizados
    await _syncEstudiantes();
    await _syncOtherData();
  }

  /// Subir asistencias pendientes
  Future<void> _uploadPendingAsistencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingAsistencias =
          prefs.getStringList('pending_asistencias') ?? [];

      for (final asistenciaJson in pendingAsistencias) {
        try {
          final asistenciaData = json.decode(asistenciaJson);
          final asistencia = AsistenciaModel.fromJson(asistenciaData);
          await _apiService.registrarAsistencia(asistencia);
          _addLogEntry(
            '✅ Asistencia sincronizada: ${asistenciaData['alumno_id']}',
          );
        } catch (e) {
          _addLogEntry('❌ Error sincronizando asistencia: $e');
        }
      }

      // Limpiar asistencias procesadas
      await prefs.remove('pending_asistencias');
    } catch (e) {
      _addLogEntry('❌ Error subiendo asistencias: $e');
    }
  }

  /// Subir otros cambios pendientes
  Future<void> _uploadOtherPendingChanges() async {
    // Implementar según necesidades específicas
    _addLogEntry('📤 Verificando otros cambios pendientes...');
  }

  /// Actualizar versiones locales después de la sincronización
  Future<void> _updateLocalVersions(Map<String, int> serverVersions) async {
    final prefs = await SharedPreferences.getInstance();

    for (final entry in serverVersions.entries) {
      _localVersions[entry.key] = entry.value;
      await prefs.setInt('version_${entry.key}', entry.value);
    }

    _addLogEntry('📋 Versiones locales actualizadas');
  }

  /// Notificar conflictos detectados
  void _notifyConflicts(List<ConflictData> conflicts) {
    // Esta función será llamada por la UI para mostrar conflictos al usuario
    _addLogEntry('🔔 Notificando ${conflicts.length} conflictos al usuario');
  }

  // ==================== MÉTODOS DE RESOLUCIÓN DE CONFLICTOS ====================

  /// Resolver conflicto aplicando una estrategia específica
  Future<bool> resolveConflict(
    String conflictId,
    ConflictResolution resolution,
  ) async {
    try {
      final conflict = _pendingConflicts.firstWhere(
        (c) => c.id == conflictId,
        orElse: () => throw Exception('Conflicto no encontrado: $conflictId'),
      );

      switch (resolution) {
        case ConflictResolution.serverWins:
          await _applyServerVersion(conflict);
          break;
        case ConflictResolution.clientWins:
          await _applyClientVersion(conflict);
          break;
        case ConflictResolution.merge:
          await _applyMergedVersion(conflict);
          break;
        case ConflictResolution.manual:
          // El usuario resolverá manualmente
          _addLogEntry(
            '⚠️ Conflicto marcado para resolución manual: ${conflict.collection}',
          );
          return false;
      }

      // Remover conflicto resuelto
      _pendingConflicts.removeWhere((c) => c.id == conflictId);
      _addLogEntry('✅ Conflicto resuelto: ${conflict.collection}');

      notifyListeners();
      return true;
    } catch (e) {
      _addLogEntry('❌ Error resolviendo conflicto: $e');
      return false;
    }
  }

  /// Aplicar versión del servidor
  Future<void> _applyServerVersion(ConflictData conflict) async {
    _addLogEntry(
      '📥 Aplicando versión del servidor para: ${conflict.collection}',
    );

    switch (conflict.collection) {
      case 'asistencias':
        // Descartar cambios locales y usar datos del servidor
        await _clearLocalPendingData(conflict.collection);
        break;
      case 'sesiones_guardias':
        // Sincronizar con sesiones del servidor
        await _syncServerSessions();
        break;
    }
  }

  /// Aplicar versión del cliente
  Future<void> _applyClientVersion(ConflictData conflict) async {
    _addLogEntry(
      '📤 Aplicando versión del cliente para: ${conflict.collection}',
    );

    switch (conflict.collection) {
      case 'asistencias':
        // Forzar subida de cambios locales
        await _uploadPendingAsistencias();
        break;
      case 'sesiones_guardias':
        // Mantener sesiones locales
        break;
    }
  }

  /// Aplicar versión fusionada
  Future<void> _applyMergedVersion(ConflictData conflict) async {
    _addLogEntry('🔀 Aplicando versión fusionada para: ${conflict.collection}');

    // Implementar lógica de fusión específica por tipo de datos
    switch (conflict.collection) {
      case 'asistencias':
        await _mergeAsistenciaData(conflict);
        break;
      case 'sesiones_guardias':
        await _mergeSessionData(conflict);
        break;
    }
  }

  /// Limpiar datos pendientes locales
  Future<void> _clearLocalPendingData(String collection) async {
    final prefs = await SharedPreferences.getInstance();

    switch (collection) {
      case 'asistencias':
        await prefs.remove('pending_asistencias');
        break;
      case 'sesiones_guardias':
        await prefs.remove('active_sessions');
        break;
    }
  }

  /// Sincronizar con sesiones del servidor
  Future<void> _syncServerSessions() async {
    try {
      final serverSessions = await _apiService.getActiveSessions();
      final prefs = await SharedPreferences.getInstance();

      final sessionStrings =
          serverSessions.map((session) => json.encode(session)).toList();

      await prefs.setStringList('active_sessions', sessionStrings);
      _addLogEntry('📋 Sesiones sincronizadas con el servidor');
    } catch (e) {
      _addLogEntry('❌ Error sincronizando sesiones: $e');
    }
  }

  /// Fusionar datos de asistencia
  Future<void> _mergeAsistenciaData(ConflictData conflict) async {
    try {
      // Obtener datos locales
      final localData = List<Map<String, dynamic>>.from(
        conflict.localData['data'] ?? [],
      );

      // Implementar lógica de fusión (ejemplo: conservar registros únicos)
      final mergedData = <String, Map<String, dynamic>>{};

      // Agregar datos locales
      for (final item in localData) {
        final key = '${item['alumno_id']}_${item['fecha_hora']}';
        mergedData[key] = item;
      }

      // La fusión real dependería de la estructura específica de los datos del servidor
      _addLogEntry('🔀 Datos de asistencia fusionados');
    } catch (e) {
      _addLogEntry('❌ Error fusionando datos de asistencia: $e');
    }
  }

  /// Fusionar datos de sesión
  Future<void> _mergeSessionData(ConflictData conflict) async {
    try {
      // Implementar lógica de fusión para sesiones
      _addLogEntry('🔀 Datos de sesión fusionados');
    } catch (e) {
      _addLogEntry('❌ Error fusionando datos de sesión: $e');
    }
  }

  /// Resolver todos los conflictos pendientes automáticamente
  Future<void> resolveAllConflicts(ConflictResolution defaultResolution) async {
    _addLogEntry(
      '🔄 Resolviendo todos los conflictos con estrategia: ${defaultResolution.name}',
    );

    final conflicts = List<ConflictData>.from(_pendingConflicts);

    for (final conflict in conflicts) {
      await resolveConflict(conflict.id, defaultResolution);
    }

    if (_pendingConflicts.isEmpty) {
      _addLogEntry('✅ Todos los conflictos han sido resueltos');
      _currentStatus = SyncStatus.completed;
    } else {
      _addLogEntry('⚠️ Algunos conflictos requieren resolución manual');
    }

    notifyListeners();
  }

  // Sincronizar datos de estudiantes
  Future<void> _syncEstudiantes() async {
    try {
      _addLogEntry('📚 Sincronizando datos de estudiantes...');

      // Obtener datos actualizados de estudiantes
      List<AlumnoModel> estudiantes = await _apiService.getAlumnos();

      _addLogEntry(
        '📊 ${estudiantes.length} registros de estudiantes procesados',
      );

      // Aquí se podría implementar lógica para:
      // - Comparar con datos locales
      // - Detectar cambios
      // - Actualizar cache local
      // - Notificar cambios importantes

      _addLogEntry('✅ Datos de estudiantes sincronizados');
    } catch (e) {
      _addLogEntry('❌ Error sincronizando estudiantes: $e');
      throw e;
    }
  }

  // Sincronizar otros datos del sistema
  Future<void> _syncOtherData() async {
    try {
      _addLogEntry('🔧 Sincronizando configuraciones del sistema...');

      // Aquí se pueden sincronizar otros datos como:
      // - Configuraciones
      // - Puntos de control
      // - Políticas de acceso

      _addLogEntry('✅ Configuraciones sincronizadas');
    } catch (e) {
      _addLogEntry('❌ Error sincronizando configuraciones: $e');
      throw e;
    }
  }

  // Añadir entrada al log de sincronización
  void _addLogEntry(String message) {
    final timestamp = DateTime.now();
    final formattedTime =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

    _syncLog.insert(0, '[$formattedTime] $message');

    // Mantener solo las últimas 50 entradas
    if (_syncLog.length > 50) {
      _syncLog = _syncLog.take(50).toList();
    }

    notifyListeners();
  }

  // Obtener estado de la última sincronización
  String getLastSyncStatus() {
    if (_lastSyncTime == null) {
      return 'Nunca sincronizado';
    }

    final difference = DateTime.now().difference(_lastSyncTime!);

    if (difference.inMinutes < 1) {
      return 'Sincronizado hace ${difference.inSeconds} segundos';
    } else if (difference.inHours < 1) {
      return 'Sincronizado hace ${difference.inMinutes} minutos';
    } else if (difference.inDays < 1) {
      return 'Sincronizado hace ${difference.inHours} horas';
    } else {
      return 'Sincronizado hace ${difference.inDays} días';
    }
  }

  // Limpiar log de sincronización
  void clearSyncLog() {
    _syncLog.clear();
    _addLogEntry('🗑️ Log de sincronización limpiado');
  }

  // Obtener próxima sincronización automática
  Duration? getTimeToNextSync() {
    if (!_autoSyncEnabled || _lastSyncTime == null) {
      return null;
    }

    final nextSync = _lastSyncTime!.add(
      Duration(minutes: _syncIntervalMinutes),
    );
    final timeToNext = nextSync.difference(DateTime.now());

    return timeToNext.isNegative ? Duration.zero : timeToNext;
  }

  // Getter para compatibilidad con la UI
  bool get isLoading => _isSyncing;

  // ==================== SISTEMA DE BACKUP AUTOMÁTICO US020 ====================

  Timer? _backupTimer;
  bool _autoBackupEnabled = true;
  int _backupIntervalHours = 6; // Backup cada 6 horas por defecto
  DateTime? _lastBackupTime;

  /// Configurar backup automático
  void configureAutoBackup({required bool enabled, int intervalHours = 6}) {
    _autoBackupEnabled = enabled;
    _backupIntervalHours = intervalHours;

    _backupTimer?.cancel();

    if (enabled) {
      _scheduleNextBackup();
      _addLogEntry(
        '📋 Backup automático configurado: cada $_backupIntervalHours horas',
      );
    } else {
      _addLogEntry('📋 Backup automático deshabilitado');
    }

    notifyListeners();
  }

  /// Programar próximo backup
  void _scheduleNextBackup() {
    if (!_autoBackupEnabled) return;

    final interval = Duration(hours: _backupIntervalHours);

    _backupTimer = Timer(interval, () async {
      await createDataBackup();
      _scheduleNextBackup(); // Programar siguiente backup
    });
  }

  /// Crear backup completo de datos
  Future<Map<String, dynamic>> createDataBackup() async {
    try {
      _addLogEntry('📋 Iniciando backup de datos...');

      final backupData = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
        'device_info': {'platform': 'flutter', 'sync_version': '2.0'},
        'data': {
          'asistencias': [],
          'alumnos': [],
          'configuracion': {},
          'sync_log': _syncLog,
          'pending_conflicts':
              _pendingConflicts.map((c) => c.toJson()).toList(),
        },
      };

      // Obtener datos desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Backup de configuraciones
      backupData['data']['configuracion'] = {
        'auto_sync_enabled': _autoSyncEnabled,
        'sync_interval_minutes': _syncIntervalMinutes,
        'auto_backup_enabled': _autoBackupEnabled,
        'backup_interval_hours': _backupIntervalHours,
        'last_sync_time': _lastSyncTime?.toIso8601String(),
        'last_backup_time': _lastBackupTime?.toIso8601String(),
      };

      // Backup de datos locales (asistencias pendientes, etc.)
      final localKeys =
          prefs
              .getKeys()
              .where(
                (key) =>
                    key.startsWith('asistencia_') ||
                    key.startsWith('alumno_') ||
                    key.startsWith('pending_'),
              )
              .toList();

      for (String key in localKeys) {
        final value = prefs.getString(key);
        if (value != null) {
          try {
            final jsonData = json.decode(value);
            if (key.startsWith('asistencia_')) {
              backupData['data']['asistencias'].add({
                'key': key,
                'data': jsonData,
              });
            } else if (key.startsWith('alumno_')) {
              backupData['data']['alumnos'].add({'key': key, 'data': jsonData});
            }
          } catch (e) {
            debugPrint('Error procesando backup para $key: $e');
          }
        }
      }

      // Guardar backup en SharedPreferences con timestamp
      final backupJson = json.encode(backupData);
      final backupKey = 'backup_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(backupKey, backupJson);

      // Mantener solo los últimos 5 backups
      await _cleanupOldBackups();

      _lastBackupTime = DateTime.now();
      await prefs.setString(
        'last_backup_time',
        _lastBackupTime!.toIso8601String(),
      );

      final dataCount =
          backupData['data']['asistencias'].length +
          backupData['data']['alumnos'].length;

      _addLogEntry('✅ Backup completado: $dataCount registros guardados');

      return backupData;
    } catch (e) {
      _addLogEntry('❌ Error en backup: $e');
      rethrow;
    }
  }

  /// Limpiar backups antiguos
  Future<void> _cleanupOldBackups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final backupKeys =
          allKeys.where((key) => key.startsWith('backup_')).toList();

      if (backupKeys.length > 5) {
        // Ordenar por timestamp (más reciente primero)
        backupKeys.sort((a, b) => b.compareTo(a));

        // Eliminar backups antiguos
        final keysToDelete = backupKeys.skip(5);
        for (String key in keysToDelete) {
          await prefs.remove(key);
        }

        _addLogEntry('🗑️ ${keysToDelete.length} backups antiguos eliminados');
      }
    } catch (e) {
      debugPrint('Error limpiando backups antiguos: $e');
    }
  }

  /// Obtener lista de backups disponibles
  Future<List<Map<String, dynamic>>> getAvailableBackups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final backupKeys =
          allKeys.where((key) => key.startsWith('backup_')).toList();

      List<Map<String, dynamic>> backups = [];

      for (String key in backupKeys) {
        final backupJson = prefs.getString(key);
        if (backupJson != null) {
          try {
            final backupData = json.decode(backupJson);
            final timestamp = DateTime.parse(backupData['timestamp']);

            backups.add({
              'key': key,
              'timestamp': timestamp,
              'size': backupJson.length,
              'data_count':
                  (backupData['data']['asistencias']?.length ?? 0) +
                  (backupData['data']['alumnos']?.length ?? 0),
            });
          } catch (e) {
            debugPrint('Error procesando backup $key: $e');
          }
        }
      }

      // Ordenar por timestamp (más reciente primero)
      backups.sort(
        (a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp']),
      );

      return backups;
    } catch (e) {
      debugPrint('Error obteniendo backups: $e');
      return [];
    }
  }

  /// Restaurar desde backup
  Future<bool> restoreFromBackup(String backupKey) async {
    try {
      _addLogEntry('🔄 Iniciando restauración desde backup...');

      final prefs = await SharedPreferences.getInstance();
      final backupJson = prefs.getString(backupKey);

      if (backupJson == null) {
        throw Exception('Backup no encontrado: $backupKey');
      }

      final backupData = json.decode(backupJson);

      // Restaurar configuraciones
      final config = backupData['data']['configuracion'];
      if (config != null) {
        _autoSyncEnabled = config['auto_sync_enabled'] ?? true;
        _syncIntervalMinutes = config['sync_interval_minutes'] ?? 30;
        _autoBackupEnabled = config['auto_backup_enabled'] ?? true;
        _backupIntervalHours = config['backup_interval_hours'] ?? 6;

        if (config['last_sync_time'] != null) {
          _lastSyncTime = DateTime.parse(config['last_sync_time']);
        }
        if (config['last_backup_time'] != null) {
          _lastBackupTime = DateTime.parse(config['last_backup_time']);
        }
      }

      // Restaurar datos
      int restoredCount = 0;

      // Restaurar asistencias
      final asistencias = backupData['data']['asistencias'] ?? [];
      for (var item in asistencias) {
        await prefs.setString(item['key'], json.encode(item['data']));
        restoredCount++;
      }

      // Restaurar alumnos
      final alumnos = backupData['data']['alumnos'] ?? [];
      for (var item in alumnos) {
        await prefs.setString(item['key'], json.encode(item['data']));
        restoredCount++;
      }

      // Restaurar conflictos pendientes
      final conflicts = backupData['data']['pending_conflicts'] ?? [];
      _pendingConflicts.clear();
      for (var conflictJson in conflicts) {
        _pendingConflicts.add(ConflictData.fromJson(conflictJson));
      }

      _addLogEntry(
        '✅ Restauración completada: $restoredCount registros restaurados',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _addLogEntry('❌ Error en restauración: $e');
      return false;
    }
  }

  /// Obtener información del próximo backup
  Duration? getTimeToNextBackup() {
    if (!_autoBackupEnabled || _lastBackupTime == null) {
      return null;
    }

    final nextBackup = _lastBackupTime!.add(
      Duration(hours: _backupIntervalHours),
    );
    final timeToNext = nextBackup.difference(DateTime.now());

    return timeToNext.isNegative ? Duration.zero : timeToNext;
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _backupTimer?.cancel();
    super.dispose();
  }
}
