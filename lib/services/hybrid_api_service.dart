import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/local_database_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_sync_service.dart';
import '../models/alumno_model.dart';
import '../models/asistencia_model.dart';
import '../models/usuario_model.dart';
import '../models/facultad_escuela_model.dart';
import '../models/presencia_model.dart';
import '../models/decision_manual_model.dart';

class HybridApiService extends ChangeNotifier {
  static final HybridApiService _instance = HybridApiService._internal();
  factory HybridApiService() => _instance;
  HybridApiService._internal();

  final ApiService _apiService = ApiService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineSyncService _syncService = OfflineSyncService();

  bool _isOnline = true;
  String? _lastError;

  // Getters
  bool get isOnline => _isOnline;
  String? get lastError => _lastError;

  // Inicializar servicio híbrido
  Future<void> initialize() async {
    await _connectivityService.initialize();
    await _syncService.initialize();
    
    _isOnline = _connectivityService.isOnline;
    _connectivityService.addListener(_onConnectivityChanged);
    
    // Intentar sincronizar datos pendientes al inicializar
    if (_isOnline) {
      await _syncService.performSync();
    }
  }

  // Callback cuando cambia la conectividad
  void _onConnectivityChanged() {
    final wasOnline = _isOnline;
    _isOnline = _connectivityService.isOnline;
    
    if (!wasOnline && _isOnline) {
      // Conexión restaurada, sincronizar datos pendientes
      _syncService.performSync();
    }
    
    notifyListeners();
  }

  // ==================== ALUMNOS ====================

  Future<AlumnoModel> getAlumnoByCodigo(String codigo) async {
    try {
      if (_isOnline) {
        // Intentar obtener del servidor
        try {
          final alumno = await _apiService.getAlumnoByCodigo(codigo);
          // Guardar en cache local
          await _localDb.saveAlumno(alumno, syncStatus: 'synced');
          return alumno;
        } catch (e) {
          // Si falla el servidor, intentar obtener de cache local
          final localAlumno = await _localDb.getAlumnoByCodigo(codigo);
          if (localAlumno != null) {
            _setError('Usando datos en caché: ${e.toString()}');
            return localAlumno;
          }
          rethrow;
        }
      } else {
        // Modo offline, obtener de cache local
        final localAlumno = await _localDb.getAlumnoByCodigo(codigo);
        if (localAlumno == null) {
          throw Exception('Alumno no encontrado en cache local');
        }
        return localAlumno;
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<List<AlumnoModel>> getAlumnos() async {
    try {
      if (_isOnline) {
        // Intentar obtener del servidor
        try {
          final alumnos = await _apiService.getAlumnos();
          // Guardar en cache local
          for (final alumno in alumnos) {
            await _localDb.saveAlumno(alumno, syncStatus: 'synced');
          }
          return alumnos;
        } catch (e) {
          // Si falla el servidor, usar cache local
          final localAlumnos = await _localDb.getAllAlumnos();
          _setError('Usando datos en caché: ${e.toString()}');
          return localAlumnos;
        }
      } else {
        // Modo offline, usar cache local
        return await _localDb.getAllAlumnos();
      }
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  // ==================== ASISTENCIAS ====================

  Future<void> registrarAsistencia(AsistenciaModel asistencia) async {
    try {
      if (_isOnline) {
        // Intentar registrar en servidor
        try {
          await _apiService.registrarAsistenciaCompleta(asistencia);
          // Guardar como sincronizada
          await _localDb.saveAsistencia(asistencia, syncStatus: 'synced');
        } catch (e) {
          // Si falla el servidor, guardar para sincronizar después
          await _localDb.saveAsistencia(asistencia, syncStatus: 'pending');
          _setError('Asistencia guardada offline: ${e.toString()}');
        }
      } else {
        // Modo offline, guardar para sincronizar después
        await _localDb.saveAsistencia(asistencia, syncStatus: 'pending');
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<List<AsistenciaModel>> getAsistencias() async {
    try {
      if (_isOnline) {
        // Intentar obtener del servidor
        try {
          return await _apiService.getAsistencias();
        } catch (e) {
          // Si falla el servidor, usar cache local
          final localAsistencias = await _localDb.getAsistenciasByDateRange(
            DateTime.now().subtract(Duration(days: 30)),
            DateTime.now(),
          );
          _setError('Usando datos en caché: ${e.toString()}');
          return localAsistencias;
        }
      } else {
        // Modo offline, usar cache local
        return await _localDb.getAsistenciasByDateRange(
          DateTime.now().subtract(Duration(days: 30)),
          DateTime.now(),
        );
      }
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  // ==================== USUARIOS ====================

  Future<UsuarioModel> login(String email, String password) async {
    try {
      if (_isOnline) {
        return await _apiService.login(email, password);
      } else {
        throw Exception('Login requiere conexión a internet');
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<List<UsuarioModel>> getUsuarios() async {
    try {
      if (_isOnline) {
        return await _apiService.getUsuarios();
      } else {
        throw Exception('Obtener usuarios requiere conexión a internet');
      }
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  // ==================== FACULTADES Y ESCUELAS ====================

  Future<List<FacultadModel>> getFacultades() async {
    try {
      if (_isOnline) {
        return await _apiService.getFacultades();
      } else {
        // TODO: Implementar cache local de facultades
        return [];
      }
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<List<EscuelaModel>> getEscuelas({String? siglasFacultad}) async {
    try {
      if (_isOnline) {
        return await _apiService.getEscuelas(siglasFacultad: siglasFacultad);
      } else {
        // TODO: Implementar cache local de escuelas
        return [];
      }
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  // ==================== PRESENCIA ====================

  Future<List<PresenciaModel>> getPresenciaActual() async {
    try {
      if (_isOnline) {
        return await _apiService.getPresenciaActual();
      } else {
        // TODO: Implementar cache local de presencia
        return [];
      }
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<void> actualizarPresencia(
    String estudianteDni,
    String tipoAcceso,
    String puntoControl,
    String guardiaId,
  ) async {
    try {
      if (_isOnline) {
        await _apiService.actualizarPresencia(
          estudianteDni,
          tipoAcceso,
          puntoControl,
          guardiaId,
        );
      } else {
        // TODO: Implementar guardado offline de presencia
        throw Exception('Actualizar presencia requiere conexión a internet');
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  // ==================== DECISIONES MANUALES ====================

  Future<void> registrarDecisionManual(DecisionManualModel decision) async {
    try {
      if (_isOnline) {
        await _apiService.registrarDecisionManual(decision);
      } else {
        // Guardar para sincronizar después
        await _syncService.saveDecisionOffline(decision);
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  // ==================== MÉTODOS DE SINCRONIZACIÓN ====================

  Future<bool> performSync() async {
    return await _syncService.performSync();
  }

  Future<void> saveAsistenciaOffline(AsistenciaModel asistencia) async {
    await _syncService.saveAsistenciaOffline(asistencia);
  }

  // ==================== MÉTODOS DE ESTADO ====================

  Map<String, dynamic> getConnectionStatus() {
    return {
      'isOnline': _isOnline,
      'connectionType': _connectivityService.connectionDescription,
      'lastError': _lastError,
      'pendingSyncCount': _syncService.pendingSyncCount,
      'lastSyncTime': _syncService.lastSyncTime?.toIso8601String(),
    };
  }

  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // Limpiar recursos
  @override
  void dispose() {
    _connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
