import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class SessionGuardService extends ChangeNotifier {
  static final SessionGuardService _instance = SessionGuardService._internal();
  factory SessionGuardService() => _instance;
  SessionGuardService._internal();

  // Estado de la sesión
  bool _isSessionActive = false;
  String? _sessionToken;
  String? _guardiaId;
  String? _guardiaNombre;
  String? _puntoControl;
  DateTime? _sessionStartTime;

  // Control de conflictos
  bool _hasConflict = false;
  Map<String, dynamic>? _conflictData;

  // Heartbeat automático
  Timer? _heartbeatTimer;
  Timer? _conflictCheckTimer;

  // Getters
  bool get isSessionActive => _isSessionActive;
  String? get sessionToken => _sessionToken;
  String? get guardiaId => _guardiaId;
  String? get guardiaNombre => _guardiaNombre;
  String? get puntoControl => _puntoControl;
  bool get hasConflict => _hasConflict;
  Map<String, dynamic>? get conflictData => _conflictData;
  DateTime? get sessionStartTime => _sessionStartTime;

  // Headers para requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Iniciar sesión de guardia con verificación de concurrencia
  Future<SessionResult> iniciarSesion({
    required String guardiaId,
    required String guardiaNombre,
    required String puntoControl,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sesiones/iniciar'),
        headers: _headers,
        body: json.encode({
          'guardia_id': guardiaId,
          'guardia_nombre': guardiaNombre,
          'punto_control': puntoControl,
          'device_info': deviceInfo ?? _getDefaultDeviceInfo(),
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);

        _sessionToken = data['session_token'];
        _guardiaId = guardiaId;
        _guardiaNombre = guardiaNombre;
        _puntoControl = puntoControl;
        _isSessionActive = true;
        _sessionStartTime = DateTime.now();
        _hasConflict = false;
        _conflictData = null;

        // Iniciar heartbeat automático
        _startHeartbeat();

        // Iniciar monitoreo de conflictos
        _startConflictMonitoring();

        notifyListeners();

        return SessionResult.success(
          sessionToken: _sessionToken!,
          message: data['message'],
        );
      } else if (response.statusCode == 409) {
        // Conflicto detectado
        final data = json.decode(response.body);
        _hasConflict = true;
        _conflictData = data['active_guard'];

        notifyListeners();

        return SessionResult.conflict(
          message: data['error'],
          conflictData: data['active_guard'],
        );
      } else {
        return SessionResult.error(
          'Error al iniciar sesión: ${response.statusCode}',
        );
      }
    } catch (e) {
      return SessionResult.error('Error de conexión: $e');
    }
  }

  /// Finalizar sesión actual
  Future<bool> finalizarSesion() async {
    if (!_isSessionActive || _sessionToken == null) return true;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sesiones/finalizar'),
        headers: _headers,
        body: json.encode({'session_token': _sessionToken}),
      );

      if (response.statusCode == 200) {
        _limpiarSesion();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error finalizando sesión: $e');
      // En caso de error de conexión, limpiar sesión localmente
      _limpiarSesion();
      return true;
    }
  }

  /// Resolver conflicto tomando control del punto
  Future<SessionResult> resolverConflicto({bool forzarControl = false}) async {
    if (!_hasConflict || _guardiaId == null) {
      return SessionResult.error('No hay conflicto para resolver');
    }

    // Si es forzar control, intentar iniciar sesión nuevamente
    if (forzarControl) {
      return await iniciarSesion(
        guardiaId: _guardiaId!,
        guardiaNombre: _guardiaNombre ?? 'Guardia',
        puntoControl: _puntoControl ?? 'Principal',
      );
    }

    return SessionResult.error('Resolución de conflicto cancelada');
  }

  /// Verificar estado de sesión y conflictos
  Future<void> verificarEstadoSesion() async {
    if (!_isSessionActive || _sessionToken == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sesiones/activas'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final sesionesActivas = json.decode(response.body) as List;

        // Verificar si nuestra sesión sigue activa
        final nuestraSesion = sesionesActivas.firstWhere(
          (s) => s['session_token'] == _sessionToken,
          orElse: () => null,
        );

        if (nuestraSesion == null) {
          // Nuestra sesión ya no está activa
          _limpiarSesion();
          return;
        }

        // Verificar conflictos en nuestro punto de control
        final conflictoEnPunto =
            sesionesActivas
                .where(
                  (s) =>
                      s['punto_control'] == _puntoControl &&
                      s['session_token'] != _sessionToken,
                )
                .toList();

        if (conflictoEnPunto.isNotEmpty) {
          _hasConflict = true;
          _conflictData = conflictoEnPunto.first;
          notifyListeners();
        } else if (_hasConflict) {
          _hasConflict = false;
          _conflictData = null;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error verificando estado de sesión: $e');
    }
  }

  /// Heartbeat para mantener sesión activa
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => _sendHeartbeat(),
    );
  }

  /// Enviar heartbeat al servidor
  Future<void> _sendHeartbeat() async {
    if (!_isSessionActive || _sessionToken == null) {
      _heartbeatTimer?.cancel();
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sesiones/heartbeat'),
        headers: _headers,
        body: json.encode({'session_token': _sessionToken}),
      );

      if (response.statusCode == 404) {
        // Sesión expirada o no encontrada
        final data = json.decode(response.body);
        if (data['session_expired'] == true) {
          _limpiarSesion();
        }
      }
    } catch (e) {
      debugPrint('Error en heartbeat: $e');
    }
  }

  /// Monitoreo periódico de conflictos
  void _startConflictMonitoring() {
    _conflictCheckTimer?.cancel();
    _conflictCheckTimer = Timer.periodic(
      const Duration(seconds: 15),
      (timer) => verificarEstadoSesion(),
    );
  }

  /// Limpiar datos de sesión
  void _limpiarSesion() {
    _isSessionActive = false;
    _sessionToken = null;
    _guardiaId = null;
    _guardiaNombre = null;
    _puntoControl = null;
    _sessionStartTime = null;
    _hasConflict = false;
    _conflictData = null;

    _heartbeatTimer?.cancel();
    _conflictCheckTimer?.cancel();

    notifyListeners();
  }

  /// Información por defecto del dispositivo
  Map<String, dynamic> _getDefaultDeviceInfo() {
    return {
      'platform': defaultTargetPlatform.name,
      'app_version': '1.0.0',
      'device_id': 'mobile_device',
    };
  }

  /// Obtener tiempo transcurrido de la sesión
  Duration? get tiempoSesion {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!);
  }

  /// Obtener sesiones activas (solo para admins)
  Future<List<Map<String, dynamic>>> getSesionesActivas() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sesiones/activas'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      debugPrint('Error obteniendo sesiones activas: $e');
      return [];
    }
  }

  /// Cancelar la sesión actual
  Future<void> cancelSession() async {
    if (_sessionToken != null) {
      await finalizarSesion();
    }
  }

  /// Forzar toma de control de la sesión
  Future<void> forceSessionTakeover() async {
    try {
      if (_guardiaId != null && _puntoControl != null) {
        // Solicitar forzar finalización al backend
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/sesiones/forzar-finalizacion'),
          headers: _headers,
          body: json.encode({
            'guardia_id': _guardiaId,
            'admin_id': _guardiaId, // En este caso, el guardia actúa como admin
          }),
        );

        if (response.statusCode == 200) {
          // Reintentar iniciar sesión
          final result = await iniciarSesion(
            guardiaId: _guardiaId!,
            guardiaNombre: _guardiaNombre!,
            puntoControl: _puntoControl!,
          );

          if (result.isSuccess) {
            _hasConflict = false;
            _conflictData = null;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error en forzar toma de control: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _conflictCheckTimer?.cancel();
    super.dispose();
  }
}

/// Resultado de operaciones de sesión
class SessionResult {
  final bool isSuccess;
  final bool isConflict;
  final String message;
  final String? sessionToken;
  final Map<String, dynamic>? conflictData;

  SessionResult._({
    required this.isSuccess,
    required this.isConflict,
    required this.message,
    this.sessionToken,
    this.conflictData,
  });

  factory SessionResult.success({
    required String sessionToken,
    required String message,
  }) {
    return SessionResult._(
      isSuccess: true,
      isConflict: false,
      message: message,
      sessionToken: sessionToken,
    );
  }

  factory SessionResult.conflict({
    required String message,
    required Map<String, dynamic> conflictData,
  }) {
    return SessionResult._(
      isSuccess: false,
      isConflict: true,
      message: message,
      conflictData: conflictData,
    );
  }

  factory SessionResult.error(String message) {
    return SessionResult._(
      isSuccess: false,
      isConflict: false,
      message: message,
    );
  }
}
