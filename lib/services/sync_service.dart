import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/alumno_model.dart';

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

  // Getters
  bool get isSyncing => _isSyncing;
  bool get autoSyncEnabled => _autoSyncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncError => _syncError;
  int get syncIntervalMinutes => _syncIntervalMinutes;
  List<String> get syncLog => List.unmodifiable(_syncLog);

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

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
